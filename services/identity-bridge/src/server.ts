import { buildApp } from './app.js'

const PORT = Number(process.env.IDENTITY_BRIDGE_PORT ?? 4002)
const HOST = '0.0.0.0'

async function start(): Promise<void> {
  // IB-M2: fail fast at boot instead of failing per-request on real traffic.
  if (!process.env.SERVICE_JWT_SECRET) {
    console.error('SERVICE_JWT_SECRET is required — refusing to start')
    process.exit(1)
  }

  const app = await buildApp()

  try {
    await app.listen({ port: PORT, host: HOST })
    app.log.info(`identity-bridge listening on ${HOST}:${PORT}`)
  } catch (err) {
    app.log.error({ err }, 'Failed to start server')
    process.exit(1)
  }
}

start()
