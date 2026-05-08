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
  // The origin list can be tightened via environment variable if needed.
  await app.register(cors, {
    origin: process.env.CORS_ORIGIN ?? false,
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
