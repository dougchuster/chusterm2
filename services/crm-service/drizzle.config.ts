import type { Config } from 'drizzle-kit'

export default {
  schema: './src/db/schema.ts',
  out: './drizzle',
  dialect: 'postgresql',
  dbCredentials: {
    url: process.env.CRM_DB_URL ?? 'postgresql://chusterm:chusterm_pass@localhost:5436/chusterm_crm',
  },
} satisfies Config
