import type { FastifyReply, FastifyRequest } from 'fastify'
import crypto from 'node:crypto'
import { z } from 'zod'

// ─── Token claims ─────────────────────────────────────────────────────────────
// JWTs follow the format minted by the legacy identity-bridge service
// (removed in CRM-040): issuer 'chusterm:identity-bridge' and audience
// 'chusterm:internal'. Issuers are now internal callers sharing the secret.
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
    /**
     * Verified JWT claims — present only when the request authenticated with a
     * Bearer JWT. Requests authenticated via the x-service-token shared secret
     * are trusted internal services and have no tenant claims (auth is
     * undefined); routes must then fall back to the client-supplied accountId.
     */
    auth?: AuthContext
  }
}

/**
 * Fail fast: the orchestrator verifies JWTs minted by identity-bridge with the
 * shared SERVICE_JWT_SECRET. No fallback secret is ever accepted.
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

function isValidServiceToken(header: string | undefined): boolean {
  const expected = process.env.SERVICE_AUTH_TOKEN
  if (!expected || !header) return false
  const presented = Buffer.from(header)
  const expectedBuf = Buffer.from(expected)
  return presented.length === expectedBuf.length && crypto.timingSafeEqual(presented, expectedBuf)
}

/**
 * ORC-H1: auth guard for /skills/:slug/run and /knowledge/*.
 *
 * The orchestrator is called server-to-server (Core), so two credentials
 * are accepted — whichever is presented first that validates:
 *   1. x-service-token: the shared SERVICE_AUTH_TOKEN secret (constant-time
 *      comparison). Trusted internal callers may address any tenant via
 *      accountId.
 *   2. Authorization: Bearer <JWT> in the legacy identity-bridge format. The
 *      tenant is then derived exclusively from the token claims
 *      (request.auth).
 * The /agent/message webhook keeps its own ORCHESTRATOR_WEBHOOK_SECRET check
 * (fail-closed) and does not use this guard.
 */
export async function requireServiceAuth(
  request: FastifyRequest,
  reply: FastifyReply,
): Promise<void> {
  if (isValidServiceToken(request.headers['x-service-token'] as string | undefined)) {
    return
  }

  try {
    await request.jwtVerify()
  } catch {
    return reply.status(401).send({
      error: 'UNAUTHORIZED',
      message: 'Missing or invalid credentials',
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
}

/**
 * Resolves the tenant for a request: the JWT claim when present, otherwise the
 * client-supplied accountId (only reachable by trusted x-service-token callers).
 */
export function resolveAccountId(
  request: FastifyRequest,
  clientAccountId: number | undefined,
): number | null {
  return request.auth?.accountId ?? clientAccountId ?? null
}
