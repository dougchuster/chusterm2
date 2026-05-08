import {
  pgTable,
  uuid,
  varchar,
  integer,
  boolean,
  timestamp,
  jsonb,
  smallint,
  text,
} from 'drizzle-orm/pg-core'

// ─── Seed-required tables (8) ────────────────────────────────────────────────

export const leadSources = pgTable('lead_sources', {
  id: uuid('id').primaryKey().defaultRandom(),
  accountId: integer('account_id').notNull(),
  name: varchar('name', { length: 255 }).notNull(),
  channel: varchar('channel', { length: 100 }).notNull(),
  isPaid: boolean('is_paid').notNull().default(false),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow().$onUpdateFn(() => new Date()),
})

export const lossReasons = pgTable('loss_reasons', {
  id: uuid('id').primaryKey().defaultRandom(),
  accountId: integer('account_id').notNull(),
  label: varchar('label', { length: 255 }).notNull(),
  slug: varchar('slug', { length: 120 }),
  position: integer('position').notNull().default(0),
  archivedAt: timestamp('archived_at'),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow().$onUpdateFn(() => new Date()),
})

export const courseInterests = pgTable('course_interests', {
  id: uuid('id').primaryKey().defaultRandom(),
  accountId: integer('account_id').notNull(),
  name: varchar('name', { length: 255 }).notNull(),
  modalities: jsonb('modalities').notNull().default([]).$type<string[]>(),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow().$onUpdateFn(() => new Date()),
})

export const campuses = pgTable('campuses', {
  id: uuid('id').primaryKey().defaultRandom(),
  accountId: integer('account_id').notNull(),
  name: varchar('name', { length: 255 }).notNull(),
  city: varchar('city', { length: 100 }).notNull(),
  state: varchar('state', { length: 2 }).notNull(),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow().$onUpdateFn(() => new Date()),
})

export const leadProfiles = pgTable('lead_profiles', {
  id: uuid('id').primaryKey().defaultRandom(),
  accountId: integer('account_id').notNull(),
  chatwootContactId: integer('chatwoot_contact_id').notNull(),
  fullName: varchar('full_name', { length: 255 }).notNull(),
  phone: varchar('phone', { length: 30 }).notNull(),
  email: varchar('email', { length: 255 }).notNull(),
  courseInterest: varchar('course_interest', { length: 255 }),
  campusInterest: varchar('campus_interest', { length: 255 }),
  preferredShift: varchar('preferred_shift', { length: 50 }),
  enrollmentUrgency: varchar('enrollment_urgency', { length: 50 }),
  relationshipStatus: varchar('relationship_status', { length: 50 }).notNull().default('lead'),
  lifecycleStage: varchar('lifecycle_stage', { length: 100 }).notNull().default('lead'),
  lifecycleStageChangedAt: timestamp('lifecycle_stage_changed_at'),
  becameLeadAt: timestamp('became_lead_at'),
  becameCustomerAt: timestamp('became_customer_at'),
  firstDealWonAt: timestamp('first_deal_won_at'),
  lastInteractionAt: timestamp('last_interaction_at'),
  ownerId: integer('owner_id'),
  ownerAssignedAt: timestamp('owner_assigned_at'),
  ownerSource: varchar('owner_source', { length: 50 }),
  stage: varchar('stage', { length: 100 }).notNull().default('new_lead'),
  score: integer('score').notNull().default(0),
  sourceChannel: varchar('source_channel', { length: 100 }),
  utmSource: varchar('utm_source', { length: 255 }),
  utmCampaign: varchar('utm_campaign', { length: 255 }),
  deletedAt: timestamp('deleted_at'),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow().$onUpdateFn(() => new Date()),
})

export const crmLabels = pgTable('crm_labels', {
  id: uuid('id').primaryKey().defaultRandom(),
  accountId: integer('account_id').notNull(),
  category: varchar('category', { length: 80 }).notNull(),
  slug: varchar('slug', { length: 160 }).notNull(),
  displayName: varchar('display_name', { length: 160 }).notNull(),
  color: varchar('color', { length: 20 }).notNull().default('#8b8b99'),
  description: text('description'),
  scope: varchar('scope', { length: 50 }).notNull().default('all'),
  isSystem: boolean('is_system').notNull().default(false),
  archivedAt: timestamp('archived_at'),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow().$onUpdateFn(() => new Date()),
})

export const crmLabelgings = pgTable('crm_labelgings', {
  id: uuid('id').primaryKey().defaultRandom(),
  accountId: integer('account_id').notNull(),
  labelId: uuid('label_id').notNull(),
  targetType: varchar('target_type', { length: 50 }).notNull(),
  targetId: varchar('target_id', { length: 100 }).notNull(),
  source: varchar('source', { length: 50 }).notNull().default('manual'),
  confidence: smallint('confidence'),
  createdById: integer('created_by_id'),
  createdAt: timestamp('created_at').notNull().defaultNow(),
})

export const deals = pgTable('deals', {
  id: uuid('id').primaryKey().defaultRandom(),
  accountId: integer('account_id').notNull(),
  leadProfileId: uuid('lead_profile_id').notNull(),
  pipelineId: uuid('pipeline_id'),
  stageId: uuid('stage_id'),
  title: varchar('title', { length: 255 }).notNull(),
  stage: varchar('stage', { length: 100 }).notNull().default('new'),
  probabilityPct: smallint('probability_pct').notNull().default(0),
  score: integer('score').notNull().default(0),
  ownerId: integer('owner_id'),
  courseId: uuid('course_id'),
  expectedRevenue: integer('expected_revenue'),
  lossReasonId: uuid('loss_reason_id'),
  lostReasonNote: varchar('lost_reason_note', { length: 500 }),
  closedAt: timestamp('closed_at'),
  deletedAt: timestamp('deleted_at'),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow().$onUpdateFn(() => new Date()),
})

export const activities = pgTable('activities', {
  id: uuid('id').primaryKey().defaultRandom(),
  accountId: integer('account_id').notNull(),
  leadProfileId: uuid('lead_profile_id').notNull(),
  dealId: uuid('deal_id'),
  activityType: varchar('activity_type', { length: 100 }).notNull(),
  title: varchar('title', { length: 255 }).notNull(),
  description: varchar('description', { length: 1000 }),
  priority: varchar('priority', { length: 20 }).notNull().default('normal'),
  dueAt: timestamp('due_at'),
  reminderAt: timestamp('reminder_at'),
  outcome: varchar('outcome', { length: 255 }),
  completedAt: timestamp('completed_at'),
  deletedAt: timestamp('deleted_at'),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow().$onUpdateFn(() => new Date()),
})

export const appointments = pgTable('appointments', {
  id: uuid('id').primaryKey().defaultRandom(),
  accountId: integer('account_id').notNull(),
  leadProfileId: uuid('lead_profile_id').notNull(),
  dealId: uuid('deal_id'),
  appointmentType: varchar('appointment_type', { length: 100 }).notNull(),
  scheduledAt: timestamp('scheduled_at').notNull(),
  status: varchar('status', { length: 50 }).notNull().default('pending'),
  cancelledAt: timestamp('cancelled_at'),
  deletedAt: timestamp('deleted_at'),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow().$onUpdateFn(() => new Date()),
})

// ─── Phase 5 tables (4) ──────────────────────────────────────────────────────

export const pipelines = pgTable('pipelines', {
  id: uuid('id').primaryKey().defaultRandom(),
  accountId: integer('account_id').notNull(),
  name: varchar('name', { length: 255 }).notNull(),
  slug: varchar('slug', { length: 100 }).notNull(),
  isDefault: boolean('is_default').notNull().default(false),
  position: integer('position').notNull().default(0),
  archivedAt: timestamp('archived_at'),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow().$onUpdateFn(() => new Date()),
})

export const pipelineStages = pgTable('pipeline_stages', {
  id: uuid('id').primaryKey().defaultRandom(),
  pipelineId: uuid('pipeline_id').notNull(),
  accountId: integer('account_id').notNull(),
  name: varchar('name', { length: 255 }).notNull(),
  position: integer('position').notNull().default(0),
  probabilityPct: smallint('probability_pct').notNull().default(0),
  expectedDurationDays: integer('expected_duration_days'),
  color: varchar('color', { length: 20 }).notNull().default('#6366f1'),
  archivedAt: timestamp('archived_at'),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow().$onUpdateFn(() => new Date()),
})

export const scoreModels = pgTable('score_models', {
  id: uuid('id').primaryKey().defaultRandom(),
  accountId: integer('account_id').notNull(),
  name: varchar('name', { length: 255 }).notNull(),
  version: varchar('version', { length: 50 }).notNull(),
  weightsJson: jsonb('weights_json').notNull().default({}),
  status: varchar('status', { length: 20 }).notNull().default('active'),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow().$onUpdateFn(() => new Date()),
})

export const scoreComponents = pgTable('score_components', {
  id: uuid('id').primaryKey().defaultRandom(),
  contactId: uuid('contact_id').notNull(),
  modelId: uuid('model_id').notNull(),
  fit: integer('fit').notNull().default(0),
  engagement: integer('engagement').notNull().default(0),
  intent: integer('intent').notNull().default(0),
  total: integer('total').notNull().default(0),
  factorsJson: jsonb('factors_json').notNull().default({}),
  computedAt: timestamp('computed_at').notNull().defaultNow(),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow().$onUpdateFn(() => new Date()),
})

export const auditEvents = pgTable('audit_events', {
  id: uuid('id').primaryKey().defaultRandom(),
  accountId: integer('account_id').notNull(),
  actorType: varchar('actor_type', { length: 50 }).notNull().default('system'),
  actorId: varchar('actor_id', { length: 100 }),
  entityType: varchar('entity_type', { length: 100 }).notNull(),
  entityId: varchar('entity_id', { length: 100 }).notNull(),
  action: varchar('action', { length: 100 }).notNull(),
  beforeJson: jsonb('before_json').notNull().default({}),
  afterJson: jsonb('after_json').notNull().default({}),
  metadataJson: jsonb('metadata_json').notNull().default({}),
  createdAt: timestamp('created_at').notNull().defaultNow(),
})
