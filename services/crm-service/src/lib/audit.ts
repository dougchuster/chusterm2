import { db } from '../db/client.js'
import { auditEvents } from '../db/schema.js'

type AuditPayload = {
  accountId: number
  entityType: string
  entityId: string
  action: string
  actorType?: string
  actorId?: string
  before?: Record<string, unknown>
  after?: Record<string, unknown>
  metadata?: Record<string, unknown>
}

export async function writeAuditEvent(payload: AuditPayload): Promise<void> {
  await db.insert(auditEvents).values({
    accountId: payload.accountId,
    actorType: payload.actorType ?? 'system',
    actorId: payload.actorId,
    entityType: payload.entityType,
    entityId: payload.entityId,
    action: payload.action,
    beforeJson: payload.before ?? {},
    afterJson: payload.after ?? {},
    metadataJson: payload.metadata ?? {},
  })
}
