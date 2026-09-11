import { buildApp } from './app.js'
import { runMigrations } from './db/migrate.js'
import { startLeadScoringWorker } from './jobs/leadScoring.js'

const PORT = parseInt(process.env.CRM_PORT ?? '4000', 10)
const HOST = '0.0.0.0'

async function start(): Promise<void> {
  const app = buildApp()

  try {
    await runMigrations()
    app.log.info('Database migrations completed')
  } catch (err) {
    app.log.warn({ err }, 'Migrations skipped or failed — continuing startup')
  }

  const worker = startLeadScoringWorker(app.log)

  const shutdown = async (signal: string) => {
    app.log.info({ signal }, 'Shutting down...')
    await worker.close()
    await app.close()
    process.exit(0)
  }

  process.on('SIGTERM', () => shutdown('SIGTERM'))
  process.on('SIGINT', () => shutdown('SIGINT'))

  try {
    await app.listen({ port: PORT, host: HOST })
    app.log.info({ port: PORT }, 'CRM Service started')
  } catch (err) {
    app.log.fatal(err)
    process.exit(1)
  }
}

start()
