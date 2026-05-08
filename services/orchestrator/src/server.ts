import { buildApp } from './app.js'
import { runMigrations } from './db/migrate.js'

const PORT = Number(process.env.ORCHESTRATOR_PORT ?? 4001)
const HOST = '0.0.0.0'

async function main() {
  const app = await buildApp()

  // Run migrations before accepting traffic.
  // In production this is safe because the Drizzle migrator is idempotent.
  try {
    app.log.info('Running database migrations...')
    await runMigrations()
    app.log.info('Database migrations completed')
  } catch (err) {
    app.log.error({ err }, 'Database migration failed — aborting startup')
    process.exit(1)
  }

  try {
    await app.listen({ port: PORT, host: HOST })
    app.log.info(`Orchestrator service listening on ${HOST}:${PORT}`)
  } catch (err) {
    app.log.error({ err }, 'Failed to start server')
    process.exit(1)
  }

  // Graceful shutdown
  const shutdown = async (signal: string) => {
    app.log.info({ signal }, 'Shutdown signal received')
    try {
      await app.close()
      app.log.info('Server closed gracefully')
    } catch (err) {
      app.log.error({ err }, 'Error during shutdown')
    } finally {
      process.exit(0)
    }
  }

  process.on('SIGTERM', () => shutdown('SIGTERM'))
  process.on('SIGINT', () => shutdown('SIGINT'))
}

main()
