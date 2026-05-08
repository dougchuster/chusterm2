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
    origin: '*',
    methods: ['GET', 'POST', 'PATCH', 'PUT', 'DELETE', 'OPTIONS'],
  })

  app.register(jwt, {
    secret: process.env.SERVICE_JWT_SECRET ?? 'fallback-dev-secret-change-me',
  })

  app.register(registerRoutes)

  return app
}
