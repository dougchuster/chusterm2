import { buildApp } from './app.js'

const PORT = Number(process.env.IDENTITY_BRIDGE_PORT ?? 4002)
const HOST = '0.0.0.0'

async function start(): Promise<void> {
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
