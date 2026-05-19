CREATE TABLE IF NOT EXISTS "agent_conversation_memories" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"account_id" integer NOT NULL,
	"conversation_id" text NOT NULL,
	"profile_slug" text NOT NULL,
	"sender_name" text,
	"summary" text DEFAULT '' NOT NULL,
	"facts_json" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"triage_json" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"score_json" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"last_user_message" text,
	"message_count" integer DEFAULT 0 NOT NULL,
	"status" text DEFAULT 'active' NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "agent_conversation_memories_conversation_profile_idx" ON "agent_conversation_memories" ("account_id","conversation_id","profile_slug");
