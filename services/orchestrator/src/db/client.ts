import postgres from 'postgres'
import { drizzle } from 'drizzle-orm/postgres-js'
import * as schema from './schema.js'

const connectionString =
  process.env.ORCHESTRATOR_DB_URL ??
  'postgresql://chusterm:chusterm_pass@localhost:5436/chusterm_ai'

// Use max:1 only in migration/seed contexts; the application pool uses more.
const sql = postgres(connectionString, { max: 10 })

export const db = drizzle(sql, { schema })
export { sql as pgClient }
