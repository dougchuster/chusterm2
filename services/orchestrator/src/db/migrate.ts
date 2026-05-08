import postgres from 'postgres'
import { drizzle } from 'drizzle-orm/postgres-js'
import { migrate } from 'drizzle-orm/postgres-js/migrator'
import { fileURLToPath } from 'url'
import { dirname, join } from 'path'

const __filename = fileURLToPath(import.meta.url)
const __dirname = dirname(__filename)

export async function runMigrations(): Promise<void> {
  const connectionString =
    process.env.ORCHESTRATOR_DB_URL ??
    'postgresql://chusterm:chusterm_pass@localhost:5436/chusterm_ai'

  // Migration client uses max:1 — single connection is sufficient and safe for DDL.
  const migrationClient = postgres(connectionString, { max: 1 })
  const db = drizzle(migrationClient)

  try {
    const migrationsFolder = join(__dirname, '../../drizzle')
    await migrate(db, { migrationsFolder })
  } finally {
    await migrationClient.end()
  }
}

// Allow direct execution: `node dist/db/migrate.js`
if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  runMigrations()
    .then(() => {
      console.log('Migrations completed successfully')
      process.exit(0)
    })
    .catch((err) => {
      console.error('Migration failed:', err)
      process.exit(1)
    })
}
