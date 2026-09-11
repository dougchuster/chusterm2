import type { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify'
import crypto from 'node:crypto'
import jwt, { type SignOptions } from 'jsonwebtoken'
import { z } from 'zod'

// ─── Schemas ─────────────────────────────────────────────────────────────────

const validateBodySchema = z.object({
  token: z.string().min(1, 'token is required'),
})

// IB-M1: role is restricted to an allowlist — never a free-form client string.
const ROLE_ALLOWLIST = ['administrator', 'agent', 'service'] as const

const tokenBodySchema = z.object({
  userId: z.number().int().positive(),
  accountId: z.number().int().positive(),
  role: z.enum(ROLE_ALLOWLIST),
})

const JWT_ISSUER = 'chusterm:identity-bridge'
const JWT_AUDIENCE = 'chusterm:internal'

// IB-H1: verify enforces the same constraints used at sign time.
const VERIFY_OPTIONS: jwt.VerifyOptions = {
  algorithms: ['HS256'],
  issuer: JWT_ISSUER,
  audience: JWT_AUDIENCE,
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

function getSecret(): string {
  const secret = process.env.SERVICE_JWT_SECRET
  if (!secret) {
    throw new Error('SERVICE_JWT_SECRET is not set')
  }
  return secret
}

function getExpiry(): SignOptions['expiresIn'] {
  return (process.env.SERVICE_JWT_EXPIRY ?? '15m') as SignOptions['expiresIn']
}

function extractBearer(authHeader: string | undefined): string | null {
  if (!authHeader) return null
  const parts = authHeader.split(' ')
  if (parts.length !== 2 || parts[0].toLowerCase() !== 'bearer') return null
  return parts[1] ?? null
}

/**
 * IB-C1: POST /auth/token is server-to-server only. Callers must present the
 * shared SERVICE_AUTH_TOKEN in the x-service-token header. Comparison is
 * constant-time. When SERVICE_AUTH_TOKEN is unset the endpoint fails closed
 * (503) and never issues a token.
 */
function serviceTokenConfigured(): boolean {
  return Boolean(process.env.SERVICE_AUTH_TOKEN)
}

function isValidServiceToken(header: string | undefined): boolean {
  const expected = process.env.SERVICE_AUTH_TOKEN
  if (!expected || !header) return false
  const presented = Buffer.from(header)
  const expectedBuf = Buffer.from(expected)
  return presented.length === expectedBuf.length && crypto.timingSafeEqual(presented, expectedBuf)
}

// ─── Rate limiting (IB-H2) ────────────────────────────────────────────────────
// @fastify/rate-limit is not a dependency, so a tiny fixed-window limiter is
// implemented inline: max 30 requests/minute per client IP on /auth/*.
const RATE_LIMIT_WINDOW_MS = 60_000
const RATE_LIMIT_MAX = 30
const rateBuckets = new Map<string, { count: number; resetAt: number }>()

function rateLimitExceeded(ip: string): boolean {
  const now = Date.now()

  // Bound memory: sweep expired buckets when the map grows large.
  if (rateBuckets.size > 5000) {
    for (const [key, bucket] of rateBuckets) {
      if (bucket.resetAt <= now) rateBuckets.delete(key)
    }
  }

  const bucket = rateBuckets.get(ip)
  if (!bucket || bucket.resetAt <= now) {
    rateBuckets.set(ip, { count: 1, resetAt: now + RATE_LIMIT_WINDOW_MS })
    return false
  }
  bucket.count += 1
  return bucket.count > RATE_LIMIT_MAX
}

// ─── Route handler ───────────────────────────────────────────────────────────

export async function authRoutes(app: FastifyInstance): Promise<void> {
  app.addHook('onRequest', async (request: FastifyRequest, reply: FastifyReply) => {
    if (rateLimitExceeded(request.ip)) {
      return reply.status(429).send({
        error: 'RATE_LIMITED',
        message: 'Too many requests — try again later',
      })
    }
  })

  /**
   * POST /auth/validate
   * Validates a JWT signed with SERVICE_JWT_SECRET.
   * Returns { valid, payload? } on success or { valid: false, error } on failure.
   * Never throws 5xx for token errors — validation failures are domain-level.
   */
  app.post('/auth/validate', async (request: FastifyRequest, reply: FastifyReply) => {
    const parseResult = validateBodySchema.safeParse(request.body)

    if (!parseResult.success) {
      return reply.status(400).send({
        error: 'BAD_REQUEST',
        message: parseResult.error.errors[0]?.message ?? 'Invalid request body',
      })
    }

    const { token } = parseResult.data

    let secret: string
    try {
      secret = getSecret()
    } catch {
      request.log.error('SERVICE_JWT_SECRET is not configured')
      return reply.status(500).send({
        error: 'INTERNAL_ERROR',
        message: 'Service misconfiguration',
      })
    }

    try {
      const payload = jwt.verify(token, secret, VERIFY_OPTIONS)
      return reply.status(200).send({ valid: true, payload })
    } catch (err) {
      const message = err instanceof jwt.TokenExpiredError
        ? 'Token expired'
        : err instanceof jwt.JsonWebTokenError
          ? 'Invalid token'
          : 'Token verification failed'

      return reply.status(200).send({ valid: false, error: message })
    }
  })

  /**
   * POST /auth/token
   * Issues a short-lived service-to-service JWT.
   * Server-to-server only: requires the x-service-token shared secret.
   * Returns { token, expiresIn }.
   */
  app.post('/auth/token', async (request: FastifyRequest, reply: FastifyReply) => {
    // Fail closed: without SERVICE_AUTH_TOKEN configured, never issue tokens.
    if (!serviceTokenConfigured()) {
      request.log.error('SERVICE_AUTH_TOKEN is not configured — token issuance disabled')
      return reply.status(503).send({
        error: 'SERVICE_UNAVAILABLE',
        message: 'Token issuance is not configured',
      })
    }

    if (!isValidServiceToken(request.headers['x-service-token'] as string | undefined)) {
      request.log.warn({ ip: request.ip }, 'Rejected token mint attempt with invalid service token')
      return reply.status(401).send({
        error: 'UNAUTHORIZED',
        message: 'Invalid or missing service token',
      })
    }

    const parseResult = tokenBodySchema.safeParse(request.body)

    if (!parseResult.success) {
      return reply.status(400).send({
        error: 'BAD_REQUEST',
        message: parseResult.error.errors[0]?.message ?? 'Invalid request body',
      })
    }

    const { userId, accountId, role } = parseResult.data

    let secret: string
    try {
      secret = getSecret()
    } catch {
      request.log.error('SERVICE_JWT_SECRET is not configured')
      return reply.status(500).send({
        error: 'INTERNAL_ERROR',
        message: 'Service misconfiguration',
      })
    }

    const expiresIn = getExpiry()

    try {
      const signOptions: SignOptions = {
        expiresIn,
        issuer: JWT_ISSUER,
        audience: JWT_AUDIENCE,
      }

      const token = jwt.sign({ userId, accountId, role }, secret, signOptions)

      // IB-M3: audit trail for every issuance.
      request.log.info({ userId, accountId, role, ip: request.ip }, 'token issued')

      return reply.status(200).send({ token, expiresIn })
    } catch (err) {
      request.log.error({ err }, 'Failed to sign JWT')
      return reply.status(500).send({
        error: 'INTERNAL_ERROR',
        message: 'Failed to issue token',
      })
    }
  })

  /**
   * GET /auth/me
   * Validates a Bearer token from the Authorization header
   * and returns the decoded payload.
   * Returns 401 if the token is missing or invalid.
   */
  app.get('/auth/me', async (request: FastifyRequest, reply: FastifyReply) => {
    const rawToken = extractBearer(request.headers.authorization)

    if (!rawToken) {
      return reply.status(401).send({
        error: 'UNAUTHORIZED',
        message: 'Missing or malformed Authorization header',
      })
    }

    let secret: string
    try {
      secret = getSecret()
    } catch {
      request.log.error('SERVICE_JWT_SECRET is not configured')
      return reply.status(500).send({
        error: 'INTERNAL_ERROR',
        message: 'Service misconfiguration',
      })
    }

    try {
      const payload = jwt.verify(rawToken, secret, VERIFY_OPTIONS)
      return reply.status(200).send(payload)
    } catch (err) {
      const message = err instanceof jwt.TokenExpiredError
        ? 'Token expired'
        : 'Invalid token'

      return reply.status(401).send({
        error: 'UNAUTHORIZED',
        message,
      })
    }
  })
}
