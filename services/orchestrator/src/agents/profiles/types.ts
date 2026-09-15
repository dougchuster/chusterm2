import type OpenAI from 'openai'

import type {
  AgentMessage,
  KnowledgeDocument,
  PrevidenciarioScoreOutput,
  PrevidenciarioTriageSnapshot,
} from '../drPaulaMatos.js'

// Contrato de um perfil de agente atendido pelo orchestrator. Cada perfil
// encapsula identidade pública, modelo de LLM, triagem/score do nicho e os
// builders de prompt/resposta. A rota /agent/message resolve o perfil por
// payload (conversation.custom_attributes.agent_profile) e nunca referencia
// símbolos específicos de nicho diretamente.
export interface AgentProfile {
  slug: string
  llmModel: string
  publicName: string
  publicIntro: string
  // Detecta se uma mensagem pública já carrega a identidade do perfil
  // (usado para não repetir a apresentação no histórico).
  publicIdentityPattern: RegExp
  // Chave gravada em memory.factsJson quando o fechamento de lead novo é enviado.
  newLeadClosingFact: string

  isKnownAgentOpening(content: string): boolean
  responsesAreNearDuplicates(first: string, second: string): boolean
  extractTriage(input: {
    text: string
    previous?: Partial<PrevidenciarioTriageSnapshot> | null
    now?: Date
  }): PrevidenciarioTriageSnapshot
  scoreLead(input: {
    triage: PrevidenciarioTriageSnapshot
    latestMessage?: string
    messageCount?: number
  }): PrevidenciarioScoreOutput
  buildMemorySummary(
    triage: PrevidenciarioTriageSnapshot,
    score: PrevidenciarioScoreOutput,
  ): string
  retrieveKnowledge(query: string, limit?: number): KnowledgeDocument[]
  buildMessages(input: {
    conversation: AgentMessage[]
    memorySummary: string
    triage: PrevidenciarioTriageSnapshot
    score: PrevidenciarioScoreOutput
    retrievedDocuments: KnowledgeDocument[]
  }): OpenAI.Chat.Completions.ChatCompletionMessageParam[]
  buildFallbackResponse(input: {
    triage: PrevidenciarioTriageSnapshot
    retrievedDocuments: KnowledgeDocument[]
    conversation?: AgentMessage[]
  }): string
  buildPriorityResponse(conversation: AgentMessage[]): string | null
  buildPrivateTriageNote(input: {
    triage: PrevidenciarioTriageSnapshot
    score: PrevidenciarioScoreOutput
  }): string
  normalizeResponse(rawContent: string): string | null
  ensureNewLeadClosing(
    response: string,
    input: {
      conversation: AgentMessage[]
      closingAlreadySent?: boolean
      isNewLead?: boolean
    },
  ): string
  responseIncludesNewLeadClosing(value: string): boolean
}
