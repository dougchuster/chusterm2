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

  // 3.1b: a triagem previdenciária alimenta o deal — categoria do pack
  // legal, urgência quando há flag e qualificação quando o score fecha.
  crmToolCalls({ triage, score }) {
    const calls: import('../../crm/tools.js').CrmToolCall[] = []
    if (triage.objective && triage.objective !== 'nao_identificado') {
      calls.push({
        tool: 'set_category',
        args: { value: 'previdenciario', reason: `triagem IA: ${triage.objective}` },
      })
    }
    if (triage.urgencyFlags.length > 0) {
      calls.push({
        tool: 'set_urgency',
        args: { level: 'alta', reason: `flags: ${triage.urgencyFlags.join(', ')}` },
      })
    }
    if (score.classification === 'prioridade_maxima' || score.classification === 'qualificado') {
      calls.push({
        tool: 'mark_qualified',
        args: { reason: `score ${score.total} (${score.classification})` },
      })
    }
    return calls
  },
}
