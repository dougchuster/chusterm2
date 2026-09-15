import { drPaulaMatosProfile } from './drPaulaMatosProfile.js'

import type { AgentProfile } from './types.js'

const profiles = new Map<string, AgentProfile>([
  [drPaulaMatosProfile.slug, drPaulaMatosProfile],
])

export const DEFAULT_AGENT_PROFILE = drPaulaMatosProfile

// Resolve o perfil do agente a partir do slug informado pela conversa
// (custom_attributes.agent_profile / chusterm_agent). Slug ausente ou
// desconhecido cai no perfil default — nunca falha o webhook por perfil.
export function resolveAgentProfile(slug?: unknown): AgentProfile {
  if (typeof slug === 'string' && profiles.has(slug)) {
    return profiles.get(slug) as AgentProfile
  }
  return DEFAULT_AGENT_PROFILE
}

export function registerAgentProfile(profile: AgentProfile): void {
  profiles.set(profile.slug, profile)
}

export { drPaulaMatosProfile }
export type { AgentProfile } from './types.js'
