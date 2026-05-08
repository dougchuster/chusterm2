CREATE TABLE IF NOT EXISTS "audit_events" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"account_id" integer NOT NULL,
	"actor_type" varchar(50) DEFAULT 'system' NOT NULL,
	"actor_id" varchar(100),
	"entity_type" varchar(100) NOT NULL,
	"entity_id" varchar(100) NOT NULL,
	"action" varchar(100) NOT NULL,
	"before_json" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"after_json" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"metadata_json" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "activities" ADD COLUMN "description" varchar(1000);--> statement-breakpoint
ALTER TABLE "activities" ADD COLUMN "priority" varchar(20) DEFAULT 'normal' NOT NULL;--> statement-breakpoint
ALTER TABLE "activities" ADD COLUMN "reminder_at" timestamp;--> statement-breakpoint
ALTER TABLE "activities" ADD COLUMN "outcome" varchar(255);--> statement-breakpoint
ALTER TABLE "deals" ADD COLUMN "pipeline_id" uuid;--> statement-breakpoint
ALTER TABLE "deals" ADD COLUMN "stage_id" uuid;--> statement-breakpoint
ALTER TABLE "deals" ADD COLUMN "probability_pct" smallint DEFAULT 0 NOT NULL;--> statement-breakpoint
ALTER TABLE "deals" ADD COLUMN "owner_id" integer;--> statement-breakpoint
ALTER TABLE "deals" ADD COLUMN "loss_reason_id" uuid;--> statement-breakpoint
ALTER TABLE "deals" ADD COLUMN "lost_reason_note" varchar(500);--> statement-breakpoint
ALTER TABLE "deals" ADD COLUMN "closed_at" timestamp;--> statement-breakpoint
ALTER TABLE "loss_reasons" ADD COLUMN "slug" varchar(120);--> statement-breakpoint
ALTER TABLE "loss_reasons" ADD COLUMN "position" integer DEFAULT 0 NOT NULL;--> statement-breakpoint
ALTER TABLE "loss_reasons" ADD COLUMN "archived_at" timestamp;
