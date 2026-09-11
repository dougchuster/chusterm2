import Fastify from 'fastify'
import cors from '@fastify/cors'
import jwt from '@fastify/jwt'
import { registerRoutes } from './routes/index.js'
import { registerAuthGuard, requireJwtSecret } from './plugins/auth.js'

// Explicit comma-separated allowlist from CORS_ORIGIN. In dev with no
// CORS_ORIGIN set we fall back to '*'; in production no origins are allowed
// unless explicitly configured.
function corsOrigin(): string | string[] | boolean {
  const origins = (process.env.CORS_ORIGIN ?? '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean)
  if (origins.length > 0) return origins
  return process.env.NODE_ENV !== 'production' ? '*' : false
}

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
    origin: corsOrigin(),
    methods: ['GET', 'POST', 'PATCH', 'PUT', 'DELETE', 'OPTIONS'],
  })

  // CRM-H2: no secret fallback — requireJwtSecret() throws when unset.
  // Verify options mirror identity-bridge's sign options (IB-H1).
  app.register(jwt, {
    secret: requireJwtSecret(),
    verify: {
      allowedIss: 'chusterm:identity-bridge',
      allowedAud: 'chusterm:internal',
      algorithms: ['HS256'],
      // allowedIss/allowedAud only validate claims when present — require them.
      requiredClaims: ['iss', 'aud'],
    },
  })

  // Minimal security headers (no @fastify/helmet dependency available).
  app.addHook('onSend', async (_request, reply) => {
    reply.header('X-Content-Type-Options', 'nosniff')
    reply.header('X-Frame-Options', 'DENY')
    reply.header('Referrer-Policy', 'no-referrer')
  })

  // CRM-C1: authenticate every route except /health and /.
  registerAuthGuard(app)

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
