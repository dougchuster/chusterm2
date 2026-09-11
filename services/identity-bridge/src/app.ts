import Fastify from 'fastify'
import cors from '@fastify/cors'
import { healthRoutes } from './routes/health.js'
import { authRoutes } from './routes/auth.js'

export async function buildApp() {
  const app = Fastify({
    logger: {
      level: process.env.LOG_LEVEL ?? 'info',
    },
  })

  // ─── CORS ─────────────────────────────────────────────────────────────────
  // Internal service — restrict to service-network callers in production.
  // Explicit comma-separated allowlist from CORS_ORIGIN; unset means no
  // cross-site origin is allowed.
  const corsOrigins = (process.env.CORS_ORIGIN ?? '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean)
  await app.register(cors, {
    origin: corsOrigins.length > 0 ? corsOrigins : false,
  })

  // ─── Security headers ───────────────────────────────────────────────────────
  // Minimal set (no @fastify/helmet dependency available).
  app.addHook('onSend', async (_request, reply) => {
    reply.header('X-Content-Type-Options', 'nosniff')
    reply.header('X-Frame-Options', 'DENY')
    reply.header('Referrer-Policy', 'no-referrer')
  })

  // ─── Routes ───────────────────────────────────────────────────────────────
  await app.register(healthRoutes)
  await app.register(authRoutes)

  // ─── Global error handler ─────────────────────────────────────────────────
  // Catches any unhandled throw from route handlers and returns a safe
  // response — no stack traces or internal detail to the caller.
  app.setErrorHandler((err, _request, reply) => {
    app.log.error({ err }, 'Unhandled error')

    const statusCode = err.statusCode && err.statusCode >= 400
      ? err.statusCode
      : 500

    return reply.status(statusCode).send({
      error: statusCode >= 500 ? 'INTERNAL_ERROR' : 'REQUEST_ERROR',
      message: statusCode >= 500
        ? 'An unexpected error occurred'
        : err.message,
    })
  })

  return app
}
