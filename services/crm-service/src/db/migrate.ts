import postgres from 'postgres'
import { drizzle } from 'drizzle-orm/postgres-js'
import { migrate } from 'drizzle-orm/postgres-js/migrator'
import { fileURLToPath } from 'url'
import { dirname, join } from 'path'

const __dirname = dirname(fileURLToPath(import.meta.url))

export async function runMigrations(): Promise<void> {
  const migrationClient = postgres(process.env.CRM_DB_URL!, { max: 1 })
  const db = drizzle(migrationClient)

  try {
    await migrate(db, {
      migrationsFolder: join(__dirname, '../../drizzle'),
    })
  } finally {
    await migrationClient.end()
  }
}
