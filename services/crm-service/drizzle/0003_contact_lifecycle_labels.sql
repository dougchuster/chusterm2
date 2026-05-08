ALTER TABLE "lead_profiles" ADD COLUMN IF NOT EXISTS "relationship_status" varchar(50) DEFAULT 'lead' NOT NULL;--> statement-breakpoint
ALTER TABLE "lead_profiles" ADD COLUMN IF NOT EXISTS "lifecycle_stage" varchar(100) DEFAULT 'lead' NOT NULL;--> statement-breakpoint
ALTER TABLE "lead_profiles" ADD COLUMN IF NOT EXISTS "lifecycle_stage_changed_at" timestamp;--> statement-breakpoint
ALTER TABLE "lead_profiles" ADD COLUMN IF NOT EXISTS "became_lead_at" timestamp;--> statement-breakpoint
ALTER TABLE "lead_profiles" ADD COLUMN IF NOT EXISTS "became_customer_at" timestamp;--> statement-breakpoint
ALTER TABLE "lead_profiles" ADD COLUMN IF NOT EXISTS "first_deal_won_at" timestamp;--> statement-breakpoint
ALTER TABLE "lead_profiles" ADD COLUMN IF NOT EXISTS "last_interaction_at" timestamp;--> statement-breakpoint
ALTER TABLE "lead_profiles" ADD COLUMN IF NOT EXISTS "owner_id" integer;--> statement-breakpoint
ALTER TABLE "lead_profiles" ADD COLUMN IF NOT EXISTS "owner_assigned_at" timestamp;--> statement-breakpoint
ALTER TABLE "lead_profiles" ADD COLUMN IF NOT EXISTS "owner_source" varchar(50);--> statement-breakpoint

CREATE TABLE IF NOT EXISTS "crm_labels" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"account_id" integer NOT NULL,
	"category" varchar(80) NOT NULL,
	"slug" varchar(160) NOT NULL,
	"display_name" varchar(160) NOT NULL,
	"color" varchar(20) DEFAULT '#8b8b99' NOT NULL,
	"description" text,
	"scope" varchar(50) DEFAULT 'all' NOT NULL,
	"is_system" boolean DEFAULT false NOT NULL,
	"archived_at" timestamp,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL
);--> statement-breakpoint

CREATE TABLE IF NOT EXISTS "crm_labelgings" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"account_id" integer NOT NULL,
	"label_id" uuid NOT NULL,
	"target_type" varchar(50) NOT NULL,
	"target_id" varchar(100) NOT NULL,
	"source" varchar(50) DEFAULT 'manual' NOT NULL,
	"confidence" smallint,
	"created_by_id" integer,
	"created_at" timestamp DEFAULT now() NOT NULL
);--> statement-breakpoint

CREATE UNIQUE INDEX IF NOT EXISTS "crm_labels_account_slug_idx" ON "crm_labels" ("account_id","slug");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "crm_labels_account_category_idx" ON "crm_labels" ("account_id","category");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "crm_labelgings_target_idx" ON "crm_labelgings" ("account_id","target_type","target_id");--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "crm_labelgings_unique_idx" ON "crm_labelgings" ("account_id","label_id","target_type","target_id");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "lead_profiles_relationship_idx" ON "lead_profiles" ("account_id","relationship_status");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "lead_profiles_lifecycle_idx" ON "lead_profiles" ("account_id","lifecycle_stage");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "lead_profiles_owner_idx" ON "lead_profiles" ("account_id","owner_id");--> statement-breakpoint

UPDATE "lead_profiles"
SET
	"became_lead_at" = COALESCE("became_lead_at", "created_at"),
	"last_interaction_at" = COALESCE("last_interaction_at", "updated_at", "created_at"),
	"lifecycle_stage_changed_at" = COALESCE("lifecycle_stage_changed_at", "updated_at", "created_at")
WHERE "deleted_at" IS NULL;--> statement-breakpoint

UPDATE "lead_profiles" AS lp
SET
	"relationship_status" = 'customer',
	"lifecycle_stage" = CASE
		WHEN won_counts.won_count >= 2 THEN 'recurring_customer'
		ELSE 'customer'
	END,
	"became_customer_at" = COALESCE(lp."became_customer_at", won_counts.first_won_at),
	"first_deal_won_at" = COALESCE(lp."first_deal_won_at", won_counts.first_won_at),
	"lifecycle_stage_changed_at" = now()
FROM (
	SELECT
		"lead_profile_id",
		COUNT(*)::int AS won_count,
		MIN(COALESCE("closed_at", "updated_at", "created_at")) AS first_won_at
	FROM "deals"
	WHERE lower("stage") IN ('ganho', 'won')
		AND "deleted_at" IS NULL
	GROUP BY "lead_profile_id"
) AS won_counts
WHERE lp."id" = won_counts."lead_profile_id";--> statement-breakpoint

INSERT INTO "crm_labels" ("account_id", "category", "slug", "display_name", "color", "scope", "is_system")
SELECT accounts."account_id", labels."category", labels."slug", labels."display_name", labels."color", labels."scope", true
FROM (
	SELECT DISTINCT "account_id" FROM "lead_profiles"
	UNION
	SELECT DISTINCT "account_id" FROM "deals"
	UNION
	SELECT DISTINCT "account_id" FROM "pipelines"
) AS accounts
CROSS JOIN (
	VALUES
		('rel', 'rel.lead', 'Lead', '#00eefc', 'contact'),
		('rel', 'rel.cliente', 'Cliente', '#4ade80', 'contact'),
		('rel', 'rel.cliente_ativo', 'Cliente ativo', '#34d399', 'contact'),
		('rel', 'rel.recorrente', 'Recorrente', '#a78bfa', 'contact'),
		('rel', 'rel.ex_cliente', 'Ex-cliente', '#8b8b99', 'contact'),
		('temp', 'temp.quente', 'Lead quente', '#f87171', 'all'),
		('temp', 'temp.morno', 'Lead morno', '#fb923c', 'all'),
		('temp', 'temp.frio', 'Lead frio', '#8b8b99', 'all'),
		('status', 'status.em_triagem', 'Em triagem', '#00eefc', 'all'),
		('status', 'status.consulta_agendada', 'Consulta agendada', '#a78bfa', 'all'),
		('status', 'status.aguardando_documento', 'Aguardando documento', '#fb923c', 'all'),
		('status', 'status.sem_responsavel', 'Sem responsável', '#f87171', 'contact'),
		('area', 'area.previdenciario', 'Previdenciário', '#38bdf8', 'all'),
		('area', 'area.trabalhista', 'Trabalhista', '#f472b6', 'all'),
		('area', 'area.civel', 'Cível', '#a78bfa', 'all'),
		('area', 'area.consumidor', 'Consumidor', '#22c55e', 'all'),
		('area', 'area.familia', 'Família', '#fb7185', 'all'),
		('area', 'area.imobiliario', 'Imobiliário', '#f59e0b', 'all'),
		('area', 'area.penal', 'Penal', '#ef4444', 'all'),
		('area', 'area.tributario', 'Tributário', '#14b8a6', 'all'),
		('area', 'area.empresarial', 'Empresarial', '#6366f1', 'all'),
		('area', 'area.auxilio_maternidade', 'Auxílio-maternidade', '#ec4899', 'all')
) AS labels("category", "slug", "display_name", "color", "scope")
WHERE NOT EXISTS (
	SELECT 1
	FROM "crm_labels" AS existing
	WHERE existing."account_id" = accounts."account_id"
		AND existing."slug" = labels."slug"
);--> statement-breakpoint

INSERT INTO "crm_labelgings" ("account_id", "label_id", "target_type", "target_id", "source")
SELECT lp."account_id", label."id", 'contact', lp."id"::text, 'migration'
FROM "lead_profiles" AS lp
JOIN "crm_labels" AS label
	ON label."account_id" = lp."account_id"
	AND label."slug" = CASE
		WHEN lp."relationship_status" = 'customer' THEN 'rel.cliente'
		ELSE 'rel.lead'
	END
WHERE lp."deleted_at" IS NULL
ON CONFLICT DO NOTHING;--> statement-breakpoint

INSERT INTO "crm_labelgings" ("account_id", "label_id", "target_type", "target_id", "source")
SELECT lp."account_id", label."id", 'contact', lp."id"::text, 'migration'
FROM "lead_profiles" AS lp
JOIN "crm_labels" AS label
	ON label."account_id" = lp."account_id"
	AND label."slug" = 'status.sem_responsavel'
WHERE lp."deleted_at" IS NULL
	AND lp."owner_id" IS NULL
ON CONFLICT DO NOTHING;
