import Fastify from 'fastify'
import cors from '@fastify/cors'
import jwt from '@fastify/jwt'
import { registerRoutes } from './routes/index.js'

export function buildApp() {
  const isDev = process.env.NODE_ENV !== 'production'
  const app = Fastify({
    logger: {
      level: process.env.LOG_LEVEL ?? 'info',
      ...(isDev && {
        transport: { target: 'pino-pretty', options: { colorize: true } },
      }),
    },
  })

  app.register(cors, {
    origin: process.env.CORS_ORIGIN ?? (isDev ? '*' : false),
    methods: ['GET', 'POST', 'PATCH', 'PUT', 'DELETE', 'OPTIONS'],
  })

  app.register(jwt, {
    secret: process.env.SERVICE_JWT_SECRET ?? (isDev ? 'dev-secret-key-for-local-testing-only' : ''),
  })

  app.setErrorHandler((error, request, reply) => {
    request.log.error(
      { err: error, method: request.method, url: request.url },
      'Unhandled application error',
    )

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

  app.register(registerRoutes)

  return app
}

