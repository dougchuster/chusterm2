// UX-05: fonte única das listas de domínio do CRM no front.
// Busca do backend (GET /crm/options, espelho de Crm::DomainOptions) com
// fallback local para o board nunca quebrar se a chamada falhar.
// Não redeclarar essas listas nas páginas — importar daqui.
import CrmAPI from 'dashboard/api/crm';

export const CRM_OPTIONS_FALLBACK = {
  legal_areas: [
    { value: 'comercial', label: 'Comercial / Vendas' },
    { value: 'servicos', label: 'Prestação de Serviços' },
    { value: 'consultoria', label: 'Consultoria' },
    { value: 'tecnologia', label: 'Tecnologia / SaaS' },
    { value: 'saude', label: 'Saúde / Clínicas' },
    { value: 'imobiliario', label: 'Imobiliário' },
    { value: 'financeiro', label: 'Financeiro / Contábil' },
    { value: 'educacao', label: 'Educação / Treinamento' },
    { value: 'varejo', label: 'Varejo / E-commerce' },
    { value: 'juridico', label: 'Jurídico' },
    { value: 'previdenciario', label: 'Previdenciário' },
    { value: 'civel', label: 'Cível' },
    { value: 'trabalhista', label: 'Trabalhista' },
    { value: 'outro', label: 'Outro' },
  ],
  lead_sources: [
    { value: 'whatsapp', label: 'WhatsApp' },
    { value: 'instagram', label: 'Instagram' },
    { value: 'facebook', label: 'Facebook' },
    { value: 'google_ads', label: 'Google Ads' },
    { value: 'meta_ads', label: 'Meta Ads' },
    { value: 'site', label: 'Site / Landing Page' },
    { value: 'indicacao', label: 'Indicação' },
    { value: 'prospeccao_ativa', label: 'Prospecção Ativa' },
    { value: 'evento', label: 'Evento / Feira' },
    { value: 'lista_importada', label: 'Lista importada' },
    { value: 'cliente_base', label: 'Cliente Base' },
    { value: 'jusbrasil', label: 'JusBrasil' },
    { value: 'outros', label: 'Outros' },
  ],
  urgency_levels: [
    { value: 'critica', label: 'Crítica' },
    { value: 'alta', label: 'Alta' },
    { value: 'media', label: 'Média' },
    { value: 'baixa', label: 'Baixa' },
  ],
  disposition_reasons: [
    { value: 'invalid', label: 'Inválido' },
    { value: 'spam', label: 'Spam' },
    { value: 'duplicated', label: 'Duplicado' },
    { value: 'no_lead', label: 'Não é lead' },
  ],
};

// UX-04: labels dos códigos estruturados de pausa da IA (handoff_reason_code
// de captain_conversation_states) — compartilhados por card e drawer
export const AI_HANDOFF_REASON_LABELS = {
  human_takeover: 'Humano assumiu a conversa',
  customer_contact: 'Contato já é cliente',
  unreadable_media: 'Mídia não pôde ser transcrita/analisada',
  ai_handoff: 'IA decidiu transferir',
  score_auto_handoff: 'Score alto — prioridade automática',
};

// Lookups síncronos de label (badges e células renderizam sem esperar fetch)
export const LEGAL_AREA_LABELS = Object.fromEntries(
  CRM_OPTIONS_FALLBACK.legal_areas.map(({ value, label }) => [value, label])
);

export const URGENCY_LEVEL_LABELS = Object.fromEntries(
  CRM_OPTIONS_FALLBACK.urgency_levels.map(({ value, label }) => [value, label])
);

let cachedOptions = null;
let inflight = null;

export async function fetchCrmOptions() {
  if (cachedOptions) return cachedOptions;
  if (inflight) return inflight;

  inflight = CrmAPI.getOptions()
    .then(({ data }) => {
      cachedOptions = { ...CRM_OPTIONS_FALLBACK, ...(data || {}) };
      return cachedOptions;
    })
    .catch(() => {
      cachedOptions = CRM_OPTIONS_FALLBACK;
      return cachedOptions;
    })
    .finally(() => {
      inflight = null;
    });

  return inflight;
}
