import Fastify from 'fastify'
import cors from '@fastify/cors'
import jwt from '@fastify/jwt'
import { registerRoutes } from './routes/index.js'

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
  await fastify.register(cors, {
    origin: process.env.CORS_ORIGIN ?? true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  })

  // ─── JWT ───────────────────────────────────────────────────────────────────
  // JWT is registered but route-level verification is opt-in via preHandler.
  // Internal service-to-service calls use a shared secret from the environment.
  await fastify.register(jwt, {
    secret: process.env.JWT_SECRET ?? 'orchestrator-dev-secret-change-in-production',
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
    const statusCode = error.statusCode ?? 500
    return reply.status(statusCode).send({
      error: statusCode >= 500 ? 'INTERNAL_SERVER_ERROR' : 'REQUEST_ERROR',
      message:
        statusCode >= 500
          ? 'An unexpected error occurred'
          : (error.message ?? 'Bad request'),
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
