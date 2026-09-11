import type { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify'
import { z } from 'zod'

// ─── Token claims ─────────────────────────────────────────────────────────────
// Tokens are minted by identity-bridge (POST /auth/token) with these claims,
// issuer 'chusterm:identity-bridge' and audience 'chusterm:internal'.
const tokenPayloadSchema = z.object({
  userId: z.number().int().positive(),
  accountId: z.number().int().positive(),
  role: z.string().min(1),
})

export interface AuthContext {
  userId: number
  accountId: number
  role: string
}

declare module 'fastify' {
  interface FastifyRequest {
    /** Verified JWT claims — populated by the auth guard on authenticated requests. */
    auth: AuthContext
  }
}

// Routes that never require authentication (liveness probes only).
const PUBLIC_PATHS = new Set(['/health', '/'])

/**
 * Fail fast: the service must never sign/verify tokens with a missing or
 * fallback secret (CRM-H2). Called at boot inside buildApp().
 */
export function requireJwtSecret(): string {
  const secret = process.env.SERVICE_JWT_SECRET
  if (!secret || secret.trim().length === 0) {
    throw new Error(
      'SERVICE_JWT_SECRET is required — refusing to start without a JWT secret',
    )
  }
  return secret
}

/**
 * Registers a global onRequest hook that verifies the Bearer JWT on every
 * route except PUBLIC_PATHS and attaches the verified claims to request.auth.
 * Tenant scoping (accountId) must always come from request.auth, never from
 * client input (CRM-C1/CRM-C2).
 */
export function registerAuthGuard(app: FastifyInstance): void {
  app.addHook('onRequest', async (request: FastifyRequest, reply: FastifyReply) => {
    const path = request.url.split('?')[0]
    if (PUBLIC_PATHS.has(path)) return

    try {
      await request.jwtVerify()
    } catch {
      return reply.status(401).send({
        error: 'UNAUTHORIZED',
        message: 'Missing or invalid bearer token',
      })
    }

    const parsed = tokenPayloadSchema.safeParse(request.user)
    if (!parsed.success) {
      return reply.status(401).send({
        error: 'UNAUTHORIZED',
        message: 'Malformed token claims',
      })
    }

    request.auth = parsed.data
  })
}
