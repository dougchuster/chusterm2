import type { Config } from 'drizzle-kit'

export default {
  schema: './src/db/schema.ts',
  out: './drizzle',
  dialect: 'postgresql',
  dbCredentials: {
    url: process.env.ORCHESTRATOR_DB_URL ?? 'postgresql://chusterm:chusterm_pass@localhost:5436/chusterm_ai',
  },
} satisfies Config
