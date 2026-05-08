import {
  pgTable,
  uuid,
  integer,
  text,
  boolean,
  jsonb,
  timestamp,
  pgEnum,
} from 'drizzle-orm/pg-core'
import { sql } from 'drizzle-orm'

// ─── Enums ────────────────────────────────────────────────────────────────────

export const skillRunStatusEnum = pgEnum('skill_run_status', [
  'pending',
  'completed',
  'failed',
])

// ─── Knowledge Collections ────────────────────────────────────────────────────

export const knowledgeCollections = pgTable('knowledge_collections', {
  id: uuid('id').primaryKey().defaultRandom(),
  accountId: integer('account_id').notNull(),
  name: text('name').notNull(),
  description: text('description').notNull().default(''),
  scope: text('scope').array().notNull().default(sql`ARRAY[]::text[]`),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow(),
})

// ─── Knowledge Articles ───────────────────────────────────────────────────────

export const knowledgeArticles = pgTable('knowledge_articles', {
  id: uuid('id').primaryKey().defaultRandom(),
  accountId: integer('account_id').notNull(),
  collectionId: uuid('collection_id')
    .notNull()
    .references(() => knowledgeCollections.id),
  title: text('title').notNull(),
  content: text('content').notNull(),
  tags: text('tags').array().notNull().default(sql`ARRAY[]::text[]`),
  isPublished: boolean('is_published').notNull().default(false),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow(),
})

// ─── Prompt Versions ──────────────────────────────────────────────────────────

export const promptVersions = pgTable('prompt_versions', {
  id: uuid('id').primaryKey().defaultRandom(),
  accountId: integer('account_id').notNull(),
  skillSlug: text('skill_slug').notNull(),
  version: text('version').notNull(),
  systemPrompt: text('system_prompt').notNull(),
  isActive: boolean('is_active').notNull().default(false),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow(),
})

// ─── Skill Runs ───────────────────────────────────────────────────────────────

export const skillRuns = pgTable('skill_runs', {
  id: uuid('id').primaryKey().defaultRandom(),
  accountId: integer('account_id').notNull(),
  skillSlug: text('skill_slug').notNull(),
  skillVersion: text('skill_version').notNull().default('1.0.0'),
  requestJson: jsonb('request_json').notNull(),
  responseJson: jsonb('response_json'),
  latencyMs: integer('latency_ms'),
  tokensIn: integer('tokens_in'),
  tokensOut: integer('tokens_out'),
  costCents: integer('cost_cents'),
  decision: text('decision'),
  triggeredBy: text('triggered_by'),
  conversationId: text('conversation_id'),
  dealId: text('deal_id'),
  contactId: text('contact_id'),
  status: skillRunStatusEnum('status').notNull().default('pending'),
  errorMessage: text('error_message'),
  createdAt: timestamp('created_at').notNull().defaultNow(),
})
