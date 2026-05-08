import type { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify'
import jwt, { type SignOptions } from 'jsonwebtoken'
import { z } from 'zod'

// ─── Schemas ─────────────────────────────────────────────────────────────────

const validateBodySchema = z.object({
  token: z.string().min(1, 'token is required'),
})

const tokenBodySchema = z.object({
  userId: z.number().int().positive(),
  accountId: z.number().int().positive(),
  role: z.string().min(1, 'role is required'),
})

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

// ─── Route handler ───────────────────────────────────────────────────────────

export async function authRoutes(app: FastifyInstance): Promise<void> {
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
      const payload = jwt.verify(token, secret)
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
   * Returns { token, expiresIn }.
   */
  app.post('/auth/token', async (request: FastifyRequest, reply: FastifyReply) => {
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
        issuer: 'chusterm:identity-bridge',
        audience: 'chusterm:internal',
      }

      const token = jwt.sign({ userId, accountId, role }, secret, signOptions)

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
      const payload = jwt.verify(rawToken, secret)
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
