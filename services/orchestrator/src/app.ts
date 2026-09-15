import Fastify from 'fastify'
import cors from '@fastify/cors'
import jwt from '@fastify/jwt'
import { registerRoutes } from './routes/index.js'
import { requireJwtSecret } from './plugins/auth.js'

export async function buildApp() {
  const fastify = Fastify({
    logger: {
      level: process.env.LOG_LEVEL ?? 'info',
      transport:
        process.env.NODE_ENV !== 'production'
          ? { target: 'pino-pretty', options: { colorize: true } }
          : undefined,
    },
  })

  // ─── CORS ──────────────────────────────────────────────────────────────────
  // Serviço interno: sem CORS_ORIGIN explícito, nenhuma origem cross-site é
  // permitida (SEC-07). Nunca refletir qualquer origem por default.
  // CORS_ORIGIN é uma allowlist separada por vírgulas.
  const corsOrigins = (process.env.CORS_ORIGIN ?? '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean)
  await fastify.register(cors, {
    origin: corsOrigins.length > 0 ? corsOrigins : false,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  })

  // ─── JWT (ORC-H1) ──────────────────────────────────────────────────────────
  // Sem fallback de segredo — requireJwtSecret() lança quando ausente.
  // Opções de verificação espelham o formato de JWT do antigo identity-bridge
  // (serviço removido em CRM-040) — o issuer é mantido por compatibilidade com
  // tokens já emitidos; novos emissores devem usar o mesmo iss/aud.
  await fastify.register(jwt, {
    secret: requireJwtSecret(),
    verify: {
      allowedIss: 'chusterm:identity-bridge',
      allowedAud: 'chusterm:internal',
      algorithms: ['HS256'],
      // allowedIss/allowedAud só validam claims presentes — exigir a presença.
      requiredClaims: ['iss', 'aud'],
    },
  })

  // ─── Security headers ──────────────────────────────────────────────────────
  // Conjunto mínimo (sem dependência de @fastify/helmet).
  fastify.addHook('onSend', async (_request, reply) => {
    reply.header('X-Content-Type-Options', 'nosniff')
    reply.header('X-Frame-Options', 'DENY')
    reply.header('Referrer-Policy', 'no-referrer')
  })

  // ─── Routes ────────────────────────────────────────────────────────────────
  await registerRoutes(fastify)

  // ─── Global error handler ──────────────────────────────────────────────────
  fastify.setErrorHandler((error, request, reply) => {
    request.log.error(
      { err: error, method: request.method, url: request.url },
      'Unhandled application error',
    )

    // Never expose internal error details in production
    const statusCode =
      typeof error === 'object' &&
      error !== null &&
      'statusCode' in error &&
      typeof error.statusCode === 'number'
        ? error.statusCode
        : 500
    const errorMessage = error instanceof Error ? error.message : 'Bad request'
    return reply.status(statusCode).send({
      error: statusCode >= 500 ? 'INTERNAL_SERVER_ERROR' : 'REQUEST_ERROR',
      message:
        statusCode >= 500
          ? 'An unexpected error occurred'
          : errorMessage,
    })
  })

  // ─── Not-found handler ─────────────────────────────────────────────────────
  fastify.setNotFoundHandler((request, reply) => {
    return reply.status(404).send({
      error: 'NOT_FOUND',
      message: `Route ${request.method} ${request.url} not found`,
    })
  })

  return fastify
}
