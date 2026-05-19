import { and, eq } from 'drizzle-orm'
import { db } from '../db/client.js'
import { agentConversationMemories } from '../db/schema.js'

export type AgentConversationMemory = typeof agentConversationMemories.$inferSelect

export async function getAgentConversationMemory(input: {
  accountId: number
  conversationId: string
  profileSlug: string
}): Promise<AgentConversationMemory | null> {
  const [memory] = await db
    .select()
    .from(agentConversationMemories)
    .where(
      and(
        eq(agentConversationMemories.accountId, input.accountId),
        eq(agentConversationMemories.conversationId, input.conversationId),
        eq(agentConversationMemories.profileSlug, input.profileSlug),
      ),
    )
    .limit(1)

  return memory ?? null
}

export async function upsertAgentConversationMemory(input: {
  accountId: number
  conversationId: string
  profileSlug: string
  senderName?: string | null
  summary: string
  factsJson?: Record<string, unknown>
  triageJson: Record<string, unknown>
  scoreJson: Record<string, unknown>
  lastUserMessage: string
  messageCount: number
  status: string
}): Promise<AgentConversationMemory> {
  const now = new Date()
  const [memory] = await db
    .insert(agentConversationMemories)
    .values({
      accountId: input.accountId,
      conversationId: input.conversationId,
      profileSlug: input.profileSlug,
      senderName: input.senderName ?? null,
      summary: input.summary,
      factsJson: input.factsJson ?? {},
      triageJson: input.triageJson,
      scoreJson: input.scoreJson,
      lastUserMessage: input.lastUserMessage,
      messageCount: input.messageCount,
      status: input.status,
      updatedAt: now,
    })
    .onConflictDoUpdate({
      target: [
        agentConversationMemories.accountId,
        agentConversationMemories.conversationId,
        agentConversationMemories.profileSlug,
      ],
      set: {
        senderName: input.senderName ?? null,
        summary: input.summary,
        factsJson: input.factsJson ?? {},
        triageJson: input.triageJson,
        scoreJson: input.scoreJson,
        lastUserMessage: input.lastUserMessage,
        messageCount: input.messageCount,
        status: input.status,
        updatedAt: now,
      },
    })
    .returning()

  return memory
}
