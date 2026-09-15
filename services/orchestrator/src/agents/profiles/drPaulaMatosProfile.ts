import {
  DR_LETICIA_NEW_LEAD_CLOSING_FACT,
  DR_LETICIA_PUBLIC_INTRO,
  DR_LETICIA_PUBLIC_NAME,
  DR_PAULA_MATOS_SLUG,
  buildDrLeticiaPriorityResponse,
  buildDrPaulaFallbackResponse,
  buildDrPaulaMessages,
  buildMemorySummary,
  buildPrivateTriageNote,
  drLeticiaResponseIncludesNewLeadClosing,
  drPaulaResponsesAreNearDuplicates,
  ensureDrLeticiaNewLeadClosing,
  extractPrevidenciarioTriage,
  normalizeDrPaulaResponse,
  retrieveDrPaulaKnowledge,
  scorePrevidenciarioLead,
} from '../drPaulaMatos.js'
import { DR_PAULA_MATOS_LLM_MODEL } from '../../llm/client.js'
import { normalizeText } from '../../routes/agentContract.js'

import type { AgentProfile } from './types.js'

function isKnownDrLeticiaOpening(content: string): boolean {
  const normalized = normalizeText(content)
  return (
    (normalized.includes('sou a dra. leticia') ||
      normalized.includes('sou a dra leticia') ||
      normalized.includes(
        'assistente de atendimento da equipe da dra. paula matos',
      ) ||
      normalized.includes('aqui e a dra paula matos')) &&
    (normalized.includes('atendimento inicial da dra. paula matos') ||
      normalized.includes('como posso ajudar voce hoje') ||
      normalized.includes('como posso te ajudar hoje'))
  )
}

export const drPaulaMatosProfile: AgentProfile = {
  slug: DR_PAULA_MATOS_SLUG,
  llmModel: DR_PAULA_MATOS_LLM_MODEL,
  publicName: DR_LETICIA_PUBLIC_NAME,
  publicIntro: DR_LETICIA_PUBLIC_INTRO,
  publicIdentityPattern: /\bdra\.? leticia\b/u,
  newLeadClosingFact: DR_LETICIA_NEW_LEAD_CLOSING_FACT,

  isKnownAgentOpening: isKnownDrLeticiaOpening,
  responsesAreNearDuplicates: drPaulaResponsesAreNearDuplicates,
  extractTriage: extractPrevidenciarioTriage,
  scoreLead: scorePrevidenciarioLead,
  buildMemorySummary,
  retrieveKnowledge: retrieveDrPaulaKnowledge,
  buildMessages: buildDrPaulaMessages,
  buildFallbackResponse: buildDrPaulaFallbackResponse,
  buildPriorityResponse: buildDrLeticiaPriorityResponse,
  buildPrivateTriageNote,
  normalizeResponse: normalizeDrPaulaResponse,
  ensureNewLeadClosing: ensureDrLeticiaNewLeadClosing,
  responseIncludesNewLeadClosing: drLeticiaResponseIncludesNewLeadClosing,
}
