import Fastify from 'fastify'
import cors from '@fastify/cors'
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
  // Serviço interno: sem CORS_ORIGIN explícito, nenhuma origem cross-site é
  // permitida (SEC-07). Nunca refletir qualquer origem por default.
  await fastify.register(cors, {
    origin: process.env.CORS_ORIGIN ?? false,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
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
