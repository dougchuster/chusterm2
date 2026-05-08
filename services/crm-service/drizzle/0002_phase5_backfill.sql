UPDATE "deals" AS d
SET
	"pipeline_id" = ps."pipeline_id",
	"stage_id" = ps."id",
	"probability_pct" = ps."probability_pct",
	"updated_at" = now()
FROM "pipeline_stages" AS ps
WHERE d."account_id" = ps."account_id"
	AND d."stage" = ps."name"
	AND d."deleted_at" IS NULL
	AND d."pipeline_id" IS NULL;
--> statement-breakpoint
UPDATE "deals"
SET "closed_at" = COALESCE("closed_at", "updated_at", now())
WHERE lower("stage") IN ('ganho', 'won', 'perdido', 'lost')
	AND "closed_at" IS NULL;
--> statement-breakpoint
INSERT INTO "loss_reasons" ("account_id", "label", "slug", "position")
SELECT accounts."account_id", reasons."label", reasons."slug", reasons."position"
FROM (
	SELECT DISTINCT "account_id" FROM "pipelines"
	UNION
	SELECT DISTINCT "account_id" FROM "deals"
	UNION
	SELECT DISTINCT "account_id" FROM "lead_profiles"
) AS accounts
CROSS JOIN (
	VALUES
		('Sem contato', 'sem-contato', 0),
		('Sem interesse', 'sem-interesse', 1),
		('Preco', 'preco', 2),
		('Prazo', 'prazo', 3),
		('Matriculado em concorrente', 'matriculado-em-concorrente', 4)
) AS reasons("label", "slug", "position")
WHERE NOT EXISTS (
	SELECT 1
	FROM "loss_reasons" AS lr
	WHERE lr."account_id" = accounts."account_id"
		AND lr."slug" = reasons."slug"
);
