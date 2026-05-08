import postgres from 'postgres'
import { drizzle } from 'drizzle-orm/postgres-js'
import * as schema from './schema.js'

const sql = postgres(process.env.CRM_DB_URL!, { max: 10 })

export const db = drizzle(sql, { schema })

export { sql }
