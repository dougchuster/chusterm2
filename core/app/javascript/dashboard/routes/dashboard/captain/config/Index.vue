<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';

import PageLayout from 'dashboard/components-next/captain/PageLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import CaptainAgentConfigsAPI from 'dashboard/api/captain/agentConfigs';

const ASSISTANT_FEATURES = [
  {
    key: 'feature_faq',
    label: 'FAQ e RAG',
    description: 'Usa FAQs e documentos como base de conhecimento.',
  },
  {
    key: 'feature_memory',
    label: 'Memória persistente',
    description: 'Mantém contexto resumido entre interações da conversa.',
  },
  {
    key: 'feature_contact_attributes',
    label: 'Atributos do contato',
    description: 'Permite ler dados do contato para contextualizar respostas.',
  },
  {
    key: 'feature_citation',
    label: 'Citações de fonte',
    description: 'Inclui referências quando a resposta usa conhecimento.',
  },
];

const AI_MODES = [
  { key: 'auto', label: 'Automático' },
  { key: 'supervised', label: 'Supervisionado' },
  { key: 'paused', label: 'Pausado' },
  { key: 'human_only', label: 'Somente humano' },
];

const HANDOFF_STRATEGIES = [
  { key: 'human_request', label: 'Pedido humano' },
  { key: 'manual_only', label: 'Manual' },
];

const AUTO_RESOLVE_MODES = [
  { key: 'evaluated', label: 'Avaliado pela IA' },
  { key: 'legacy', label: 'Legado' },
  { key: 'disabled', label: 'Desativado' },
];

const INVENTORY_ROUTES = {
  faqs: 'captain_assistants_responses_index',
  documents: 'captain_assistants_documents_index',
  scenarios: 'captain_assistants_scenarios_index',
  playbooks: 'captain_assistants_scenarios_index',
  tools: 'captain_tools_index',
  campaigns: 'captain_score_settings_index',
  conversation_memory: 'captain_score_settings_index',
  flows: 'captain_flow_list',
};

const INVENTORY_LABELS = {
  faqs: 'FAQs',
  documents: 'Documentos',
  scenarios: 'Cenários',
  playbooks: 'Playbooks',
  tools: 'Ferramentas',
  campaigns: 'Campanhas',
  conversation_memory: 'Memória',
  flows: 'Fluxos',
};

const route = useRoute();
const store = useStore();

const isFetching = ref(false);
const isSaving = ref(false);
const payload = ref(null);
const assistantForm = ref({});
const accountFeatureForm = ref({});
const accountModelForm = ref({});
const accountSettingsForm = ref({});
const inboxForms = ref([]);

const assistantId = computed(() => Number(route.params.assistantId));
const modelCatalog = computed(() => payload.value?.model_catalog || {});
const inventory = computed(() => payload.value?.inventory || {});

const allModelOptions = computed(() =>
  Object.entries(modelCatalog.value.models || {}).map(([id, model]) => ({
    id,
    label: `${model.display_name || id} (${model.provider || 'provider'})`,
  }))
);

function splitLines(value) {
  return String(value || '')
    .split('\n')
    .map(item => item.trim())
    .filter(Boolean);
}

const featureRows = computed(() =>
  Object.entries(modelCatalog.value.features || {}).map(([key, config]) => ({
    key,
    models: config?.models || [],
    selected: accountModelForm.value[key],
    enabled: accountFeatureForm.value[key] === true,
  }))
);

const responseGuidelinesText = computed({
  get: () => (assistantForm.value.response_guidelines || []).join('\n'),
  set: value => {
    assistantForm.value.response_guidelines = splitLines(value);
  },
});

const guardrailsText = computed({
  get: () => (assistantForm.value.guardrails || []).join('\n'),
  set: value => {
    assistantForm.value.guardrails = splitLines(value);
  },
});

const numberOrNull = value => {
  if (value === '' || value === null || value === undefined) return null;
  return Number(value);
};

const routeTo = key => {
  const name = INVENTORY_ROUTES[key];
  if (name === 'captain_flow_list') {
    return { name, params: { accountId: route.params.accountId } };
  }

  return {
    name,
    params: {
      accountId: route.params.accountId,
      assistantId: route.params.assistantId,
    },
  };
};

const hydrate = data => {
  payload.value = data;
  const assistant = data.assistant || {};
  const config = assistant.config || {};

  assistantForm.value = {
    name: assistant.name || '',
    description: assistant.description || '',
    product_name: config.product_name || '',
    instructions: config.instructions || '',
    welcome_message: config.welcome_message || '',
    handoff_message: config.handoff_message || '',
    resolution_message: config.resolution_message || '',
    temperature: config.temperature ?? '',
    llm_provider: config.llm_provider || '',
    llm_main_model: config.llm_main_model || '',
    llm_fallback_model: config.llm_fallback_model || '',
    llm_classifier_model: config.llm_classifier_model || '',
    llm_summarizer_model: config.llm_summarizer_model || '',
    llm_max_tokens: config.llm_max_tokens ?? '',
    llm_timeout_seconds: config.llm_timeout_seconds ?? '',
    llm_cost_limit_cents_per_conversation:
      config.llm_cost_limit_cents_per_conversation ?? '',
    feature_faq: config.feature_faq === true,
    feature_memory: config.feature_memory === true,
    feature_contact_attributes: config.feature_contact_attributes === true,
    feature_citation: config.feature_citation === true,
    response_guidelines: assistant.response_guidelines || [],
    guardrails: assistant.guardrails || [],
  };

  accountFeatureForm.value = {
    ...(data.account_preferences?.captain_features || {}),
  };
  accountModelForm.value = {
    ...(data.account_preferences?.captain_models || {}),
  };
  accountSettingsForm.value = {
    captain_auto_resolve_mode:
      data.account_preferences?.captain_auto_resolve_mode || 'disabled',
    keep_pending_on_bot_failure:
      data.account_preferences?.keep_pending_on_bot_failure === true,
  };
  inboxForms.value = (data.inboxes || []).map(inbox => ({
    id: inbox.id,
    inbox_id: inbox.inbox_id,
    inbox_name: inbox.inbox_name,
    inbox_type: inbox.inbox_type,
    enabled: inbox.enabled,
    auto_reply_enabled: inbox.auto_reply_enabled,
    ai_mode: inbox.ai_mode,
    handoff_strategy: inbox.handoff_strategy,
    response_delay_seconds:
      inbox.routing_config?.response_delay_seconds ??
      inbox.routing_config?.delay_seconds ??
      '',
    response_max_wait_seconds:
      inbox.routing_config?.response_max_wait_seconds ??
      inbox.routing_config?.max_wait_seconds ??
      '',
  }));
};

const fetchConfig = async () => {
  if (!assistantId.value) return;

  isFetching.value = true;
  try {
    const response = await CaptainAgentConfigsAPI.show(assistantId.value);
    hydrate(response.data);
  } catch (error) {
    useAlert('Nao foi possivel carregar o painel do agente.');
  } finally {
    isFetching.value = false;
  }
};

const saveConfig = async () => {
  isSaving.value = true;
  try {
    const response = await CaptainAgentConfigsAPI.update(assistantId.value, {
      assistant: {
        name: assistantForm.value.name,
        description: assistantForm.value.description,
        response_guidelines: assistantForm.value.response_guidelines,
        guardrails: assistantForm.value.guardrails,
        config: {
          product_name: assistantForm.value.product_name,
          instructions: assistantForm.value.instructions,
          welcome_message: assistantForm.value.welcome_message,
          handoff_message: assistantForm.value.handoff_message,
          resolution_message: assistantForm.value.resolution_message,
          temperature: numberOrNull(assistantForm.value.temperature),
          llm_provider: assistantForm.value.llm_provider,
          llm_main_model: assistantForm.value.llm_main_model,
          llm_fallback_model: assistantForm.value.llm_fallback_model,
          llm_classifier_model: assistantForm.value.llm_classifier_model,
          llm_summarizer_model: assistantForm.value.llm_summarizer_model,
          llm_max_tokens: numberOrNull(assistantForm.value.llm_max_tokens),
          llm_timeout_seconds: numberOrNull(
            assistantForm.value.llm_timeout_seconds
          ),
          llm_cost_limit_cents_per_conversation: numberOrNull(
            assistantForm.value.llm_cost_limit_cents_per_conversation
          ),
          feature_faq: assistantForm.value.feature_faq,
          feature_memory: assistantForm.value.feature_memory,
          feature_contact_attributes:
            assistantForm.value.feature_contact_attributes,
          feature_citation: assistantForm.value.feature_citation,
        },
      },
      account_preferences: {
        captain_features: accountFeatureForm.value,
        captain_models: accountModelForm.value,
        captain_auto_resolve_mode:
          accountSettingsForm.value.captain_auto_resolve_mode,
        keep_pending_on_bot_failure:
          accountSettingsForm.value.keep_pending_on_bot_failure,
      },
      inboxes: inboxForms.value.map(inbox => ({
        inbox_id: inbox.inbox_id,
        enabled: inbox.enabled,
        auto_reply_enabled: inbox.auto_reply_enabled,
        ai_mode: inbox.ai_mode,
        handoff_strategy: inbox.handoff_strategy,
        routing_config: {
          response_delay_seconds: numberOrNull(inbox.response_delay_seconds),
          response_max_wait_seconds: numberOrNull(
            inbox.response_max_wait_seconds
          ),
        },
      })),
    });

    hydrate(response.data);
    await store.dispatch('captainAssistants/show', assistantId.value);
    useAlert('Painel do agente atualizado.');
  } catch (error) {
    useAlert(error?.response?.data?.error || 'Nao foi possivel salvar.');
  } finally {
    isSaving.value = false;
  }
};

const inventoryStats = key => {
  const item = inventory.value[key] || {};

  if (key === 'conversation_memory') {
    return [
      ['Total', item.count || 0],
      ['Auto', item.auto_count || 0],
      ['Humano', item.human_count || 0],
      ['Score alto', item.high_score_count || 0],
    ];
  }

  if (key === 'tools') {
    return [
      ['Total', item.count || 0],
      ['Ativas', item.enabled_count || 0],
      ['Nativas', item.built_in_count || 0],
    ];
  }

  if (key === 'documents') {
    return [
      ['Total', item.count || 0],
      ['Disponiveis', item.available_count || 0],
      ['Processando', item.in_progress_count || 0],
    ];
  }

  if (key === 'faqs') {
    return [
      ['Total', item.count || 0],
      ['Aprovadas', item.approved_count || 0],
      ['Pendentes', item.pending_count || 0],
    ];
  }

  return [
    ['Total', item.count || 0],
    [
      'Ativos',
      item.active_count || item.enabled_count || item.published_count || 0,
    ],
  ];
};

const formatDate = value => {
  if (!value) return '-';
  return new Intl.DateTimeFormat('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value));
};

watch(assistantId, fetchConfig);
onMounted(fetchConfig);
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
  <PageLayout
    header-title="Painel do Agente"
    :show-pagination-footer="false"
    :show-know-more="false"
    :is-fetching="isFetching"
  >
    <template #body>
      <div v-if="payload" class="flex flex-col gap-6 pb-10">
        <section
          class="flex flex-wrap items-start justify-between gap-4 border-b border-ui-border-subtle/60 pb-5"
        >
          <div class="min-w-0">
            <h1 class="text-xl font-medium text-n-slate-12">
              Configurações existentes no backend
            </h1>
            <p class="mt-1 max-w-3xl text-sm text-n-slate-11">
              Uma tela para operar o agente sem alternar entre muitas páginas.
            </p>
          </div>
          <Button
            type="button"
            label="Salvar ajustes"
            icon="i-lucide-save"
            :is-loading="isSaving"
            @click="saveConfig"
          />
        </section>

        <section class="grid gap-5 xl:grid-cols-[1.15fr_0.85fr]">
          <div
            class="flex flex-col gap-4 rounded-lg border border-ui-border-subtle p-4"
          >
            <div>
              <h2 class="text-base font-medium text-n-slate-12">
                Identidade e comportamento
              </h2>
              <p class="text-sm text-n-slate-11">
                Nome, contexto principal e mensagens padrão do atendimento.
              </p>
            </div>

            <div class="grid gap-3 sm:grid-cols-2">
              <label class="flex flex-col gap-1 text-sm">
                <span class="font-medium text-n-slate-12">Nome</span>
                <input
                  v-model="assistantForm.name"
                  class="h-10 rounded-md border border-ui-border-subtle bg-n-alpha-1 px-3 text-n-slate-12"
                  type="text"
                />
              </label>
              <label class="flex flex-col gap-1 text-sm">
                <span class="font-medium text-n-slate-12">Produto ou área</span>
                <input
                  v-model="assistantForm.product_name"
                  class="h-10 rounded-md border border-ui-border-subtle bg-n-alpha-1 px-3 text-n-slate-12"
                  type="text"
                />
              </label>
            </div>

            <label class="flex flex-col gap-1 text-sm">
              <span class="font-medium text-n-slate-12">Descrição</span>
              <input
                v-model="assistantForm.description"
                class="h-10 rounded-md border border-ui-border-subtle bg-n-alpha-1 px-3 text-n-slate-12"
                type="text"
              />
            </label>

            <label class="flex flex-col gap-1 text-sm">
              <span class="font-medium text-n-slate-12">Instruções</span>
              <textarea
                v-model="assistantForm.instructions"
                class="min-h-44 rounded-md border border-ui-border-subtle bg-n-alpha-1 p-3 text-n-slate-12"
              />
            </label>

            <div class="grid gap-3 md:grid-cols-3">
              <label class="flex flex-col gap-1 text-sm">
                <span class="font-medium text-n-slate-12">
                  Mensagem inicial
                </span>
                <textarea
                  v-model="assistantForm.welcome_message"
                  class="min-h-24 rounded-md border border-ui-border-subtle bg-n-alpha-1 p-3 text-n-slate-12"
                />
              </label>
              <label class="flex flex-col gap-1 text-sm">
                <span class="font-medium text-n-slate-12">
                  Handoff humano
                </span>
                <textarea
                  v-model="assistantForm.handoff_message"
                  class="min-h-24 rounded-md border border-ui-border-subtle bg-n-alpha-1 p-3 text-n-slate-12"
                />
              </label>
              <label class="flex flex-col gap-1 text-sm">
                <span class="font-medium text-n-slate-12"> Encerramento </span>
                <textarea
                  v-model="assistantForm.resolution_message"
                  class="min-h-24 rounded-md border border-ui-border-subtle bg-n-alpha-1 p-3 text-n-slate-12"
                />
              </label>
            </div>
          </div>

          <div
            class="flex flex-col gap-4 rounded-lg border border-ui-border-subtle p-4"
          >
            <div>
              <h2 class="text-base font-medium text-n-slate-12">
                Recursos do agente
              </h2>
              <p class="text-sm text-n-slate-11">
                Flags internas que controlam memória, RAG e contexto do CRM.
              </p>
            </div>

            <label
              v-for="feature in ASSISTANT_FEATURES"
              :key="feature.key"
              class="flex gap-3 rounded-md bg-n-alpha-1 p-3 text-sm"
            >
              <input
                v-model="assistantForm[feature.key]"
                class="mt-1"
                type="checkbox"
              />
              <span class="min-w-0">
                <span class="block font-medium text-n-slate-12">
                  {{ feature.label }}
                </span>
                <span class="block text-n-slate-11">
                  {{ feature.description }}
                </span>
              </span>
            </label>

            <div class="rounded-md bg-n-alpha-1 p-3 text-sm text-n-slate-11">
              Ferramentas disponíveis para o agente:
              <span class="font-semibold text-n-slate-12">
                {{ payload.assistant.available_tools_count }}
              </span>
            </div>
          </div>
        </section>

        <section class="grid gap-5 xl:grid-cols-2">
          <div
            class="flex flex-col gap-4 rounded-lg border border-ui-border-subtle p-4"
          >
            <div>
              <h2 class="text-base font-medium text-n-slate-12">
                Modelo LLM por agente
              </h2>
              <p class="text-sm text-n-slate-11">
                Se ficar vazio, o sistema usa o modelo global da conta.
              </p>
            </div>

            <div class="grid gap-3 sm:grid-cols-2">
              <label class="flex flex-col gap-1 text-sm">
                <span class="font-medium text-n-slate-12">Provedor</span>
                <input
                  v-model="assistantForm.llm_provider"
                  class="h-10 rounded-md border border-ui-border-subtle bg-n-alpha-1 px-3 text-n-slate-12"
                  type="text"
                  placeholder="openai"
                />
              </label>
              <label class="flex flex-col gap-1 text-sm">
                <span class="font-medium text-n-slate-12">Temperatura</span>
                <input
                  v-model.number="assistantForm.temperature"
                  class="h-10 rounded-md border border-ui-border-subtle bg-n-alpha-1 px-3 text-n-slate-12"
                  min="0"
                  max="2"
                  step="0.1"
                  type="number"
                />
              </label>
            </div>

            <div class="grid gap-3 sm:grid-cols-2">
              <label
                v-for="field in [
                  ['llm_main_model', 'Modelo principal'],
                  ['llm_fallback_model', 'Modelo fallback'],
                  ['llm_classifier_model', 'Classificador'],
                  ['llm_summarizer_model', 'Resumo'],
                ]"
                :key="field[0]"
                class="flex flex-col gap-1 text-sm"
              >
                <span class="font-medium text-n-slate-12">
                  {{ field[1] }}
                </span>
                <select
                  v-model="assistantForm[field[0]]"
                  class="h-10 rounded-md border border-ui-border-subtle bg-n-alpha-1 px-3 text-n-slate-12"
                >
                  <option value="">Padrão da conta</option>
                  <option
                    v-for="model in allModelOptions"
                    :key="model.id"
                    :value="model.id"
                  >
                    {{ model.label }}
                  </option>
                </select>
              </label>
            </div>

            <div class="grid gap-3 sm:grid-cols-3">
              <label class="flex flex-col gap-1 text-sm">
                <span class="font-medium text-n-slate-12">Max tokens</span>
                <input
                  v-model.number="assistantForm.llm_max_tokens"
                  class="h-10 rounded-md border border-ui-border-subtle bg-n-alpha-1 px-3 text-n-slate-12"
                  min="256"
                  max="32000"
                  type="number"
                />
              </label>
              <label class="flex flex-col gap-1 text-sm">
                <span class="font-medium text-n-slate-12">Timeout</span>
                <input
                  v-model.number="assistantForm.llm_timeout_seconds"
                  class="h-10 rounded-md border border-ui-border-subtle bg-n-alpha-1 px-3 text-n-slate-12"
                  min="5"
                  max="120"
                  type="number"
                />
              </label>
              <label class="flex flex-col gap-1 text-sm">
                <span class="font-medium text-n-slate-12">Limite custo</span>
                <input
                  v-model.number="
                    assistantForm.llm_cost_limit_cents_per_conversation
                  "
                  class="h-10 rounded-md border border-ui-border-subtle bg-n-alpha-1 px-3 text-n-slate-12"
                  min="0"
                  type="number"
                />
              </label>
            </div>

            <div class="rounded-md bg-n-alpha-1 p-3 text-xs text-n-slate-10">
              Efetivo agora:
              {{ payload.assistant.llm_config_with_defaults.main_model }}
              /
              {{ payload.assistant.llm_config_with_defaults.provider }}
            </div>
          </div>

          <div
            class="flex flex-col gap-4 rounded-lg border border-ui-border-subtle p-4"
          >
            <div>
              <h2 class="text-base font-medium text-n-slate-12">
                Preferencias globais da conta
              </h2>
              <p class="text-sm text-n-slate-11">
                Modelos e recursos compartilhados por editor, assistente e CRM.
              </p>
            </div>

            <div class="grid gap-3 md:grid-cols-2">
              <label class="flex flex-col gap-1 text-sm">
                <span class="font-medium text-n-slate-12">
                  Auto resolver conversas
                </span>
                <select
                  v-model="accountSettingsForm.captain_auto_resolve_mode"
                  class="h-10 rounded-md border border-ui-border-subtle bg-n-alpha-1 px-3 text-n-slate-12"
                >
                  <option
                    v-for="mode in AUTO_RESOLVE_MODES"
                    :key="mode.key"
                    :value="mode.key"
                  >
                    {{ mode.label }}
                  </option>
                </select>
              </label>
              <label
                class="flex items-center gap-2 rounded-md bg-n-alpha-1 p-3 text-sm text-n-slate-12"
              >
                <input
                  v-model="accountSettingsForm.keep_pending_on_bot_failure"
                  type="checkbox"
                />
                Manter pendente quando a IA falhar
              </label>
            </div>

            <div class="flex flex-col gap-3">
              <div
                v-for="feature in featureRows"
                :key="feature.key"
                class="grid gap-2 rounded-md bg-n-alpha-1 p-3 md:grid-cols-[1fr_2fr]"
              >
                <label class="flex items-center gap-2 text-sm text-n-slate-12">
                  <input
                    v-model="accountFeatureForm[feature.key]"
                    type="checkbox"
                  />
                  {{ feature.key }}
                </label>
                <select
                  v-model="accountModelForm[feature.key]"
                  :aria-label="`Modelo para ${feature.key}`"
                  class="h-10 rounded-md border border-ui-border-subtle bg-n-solid-1 px-3 text-sm text-n-slate-12"
                >
                  <option
                    v-for="model in feature.models"
                    :key="model.id"
                    :value="model.id"
                  >
                    {{ model.display_name || model.id }}
                  </option>
                </select>
              </div>
            </div>
          </div>
        </section>

        <section class="grid gap-5 xl:grid-cols-2">
          <div
            class="flex flex-col gap-4 rounded-lg border border-ui-border-subtle p-4"
          >
            <div>
              <h2 class="text-base font-medium text-n-slate-12">Guardrails</h2>
              <p class="text-sm text-n-slate-11">
                Uma regra por linha. Essas regras limitam o comportamento do
                agente.
              </p>
            </div>
            <textarea
              v-model="guardrailsText"
              aria-label="Guardrails do agente"
              class="min-h-52 rounded-md border border-ui-border-subtle bg-n-alpha-1 p-3 text-sm text-n-slate-12"
            />
          </div>

          <div
            class="flex flex-col gap-4 rounded-lg border border-ui-border-subtle p-4"
          >
            <div>
              <h2 class="text-base font-medium text-n-slate-12">
                Diretrizes de resposta
              </h2>
              <p class="text-sm text-n-slate-11">
                Uma diretriz por linha para padronizar linguagem, tom e
                atendimento.
              </p>
            </div>
            <textarea
              v-model="responseGuidelinesText"
              aria-label="Diretrizes de resposta do agente"
              class="min-h-52 rounded-md border border-ui-border-subtle bg-n-alpha-1 p-3 text-sm text-n-slate-12"
            />
          </div>
        </section>

        <section
          class="flex flex-col gap-4 rounded-lg border border-ui-border-subtle p-4"
        >
          <div class="flex flex-wrap items-start justify-between gap-3">
            <div>
              <h2 class="text-base font-medium text-n-slate-12">
                Caixas de entrada vinculadas
              </h2>
              <p class="text-sm text-n-slate-11">
                Configure quando o agente responde sozinho, supervisionado ou
                transfere para humano.
              </p>
            </div>
            <RouterLink
              :to="routeTo('campaigns')"
              class="text-sm font-medium text-n-brand hover:underline"
            >
              Ver score
            </RouterLink>
          </div>

          <div
            v-if="!inboxForms.length"
            class="rounded-md bg-n-alpha-1 p-4 text-sm text-n-slate-10"
          >
            Nenhuma caixa vinculada a este agente.
          </div>

          <div v-else class="flex flex-col gap-3">
            <div
              v-for="inbox in inboxForms"
              :key="inbox.id"
              class="grid gap-3 rounded-md bg-n-alpha-1 p-3 xl:grid-cols-[1.2fr_1fr_1fr_1fr]"
            >
              <div class="min-w-0">
                <p class="truncate text-sm font-medium text-n-slate-12">
                  {{ inbox.inbox_name }}
                </p>
                <p class="text-xs text-n-slate-10">{{ inbox.inbox_type }}</p>
                <div class="mt-3 flex flex-wrap gap-3">
                  <label
                    class="flex items-center gap-2 text-sm text-n-slate-12"
                  >
                    <input v-model="inbox.enabled" type="checkbox" />
                    Ativa
                  </label>
                  <label
                    class="flex items-center gap-2 text-sm text-n-slate-12"
                  >
                    <input v-model="inbox.auto_reply_enabled" type="checkbox" />
                    Auto resposta
                  </label>
                </div>
              </div>
              <label class="flex flex-col gap-1 text-sm">
                <span class="font-medium text-n-slate-12">Modo IA</span>
                <select
                  v-model="inbox.ai_mode"
                  class="h-10 rounded-md border border-ui-border-subtle bg-n-solid-1 px-3 text-n-slate-12"
                >
                  <option
                    v-for="mode in AI_MODES"
                    :key="mode.key"
                    :value="mode.key"
                  >
                    {{ mode.label }}
                  </option>
                </select>
              </label>
              <label class="flex flex-col gap-1 text-sm">
                <span class="font-medium text-n-slate-12">Handoff</span>
                <select
                  v-model="inbox.handoff_strategy"
                  class="h-10 rounded-md border border-ui-border-subtle bg-n-solid-1 px-3 text-n-slate-12"
                >
                  <option
                    v-for="strategy in HANDOFF_STRATEGIES"
                    :key="strategy.key"
                    :value="strategy.key"
                  >
                    {{ strategy.label }}
                  </option>
                </select>
              </label>
              <div class="grid gap-2 sm:grid-cols-2">
                <label class="flex flex-col gap-1 text-sm">
                  <span class="font-medium text-n-slate-12">Delay</span>
                  <input
                    v-model.number="inbox.response_delay_seconds"
                    class="h-10 rounded-md border border-ui-border-subtle bg-n-solid-1 px-3 text-n-slate-12"
                    min="0"
                    type="number"
                  />
                </label>
                <label class="flex flex-col gap-1 text-sm">
                  <span class="font-medium text-n-slate-12">Espera máx.</span>
                  <input
                    v-model.number="inbox.response_max_wait_seconds"
                    class="h-10 rounded-md border border-ui-border-subtle bg-n-solid-1 px-3 text-n-slate-12"
                    min="0"
                    type="number"
                  />
                </label>
              </div>
            </div>
          </div>
        </section>

        <section class="flex flex-col gap-4">
          <div>
            <h2 class="text-base font-medium text-n-slate-12">
              Inventário do backend
            </h2>
            <p class="text-sm text-n-slate-11">
              Tudo que ja existe para este agente, com atalhos para editar nos
              modulos dedicados.
            </p>
          </div>

          <div class="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
            <RouterLink
              v-for="key in Object.keys(INVENTORY_LABELS)"
              :key="key"
              :to="routeTo(key)"
              class="flex min-h-40 flex-col justify-between rounded-lg border border-ui-border-subtle bg-n-alpha-1 p-4 transition-colors hover:bg-n-alpha-2"
            >
              <div>
                <div class="flex items-center justify-between gap-2">
                  <h3 class="text-sm font-medium text-n-slate-12">
                    {{ INVENTORY_LABELS[key] }}
                  </h3>
                  <span
                    class="i-lucide-arrow-up-right size-4 text-n-slate-10"
                  />
                </div>
                <dl class="mt-3 grid grid-cols-2 gap-2">
                  <div
                    v-for="stat in inventoryStats(key)"
                    :key="stat[0]"
                    class="rounded-md bg-n-solid-1 p-2"
                  >
                    <dt class="text-[11px] text-n-slate-10">{{ stat[0] }}</dt>
                    <dd class="text-lg font-semibold text-n-slate-12">
                      {{ stat[1] }}
                    </dd>
                  </div>
                </dl>
              </div>
              <div
                v-if="(inventory[key]?.records || []).length"
                class="mt-3 border-t border-ui-border-subtle/60 pt-3"
              >
                <p
                  v-for="record in inventory[key].records.slice(0, 2)"
                  :key="record.id"
                  class="flex justify-between gap-2 text-xs text-n-slate-10"
                >
                  <span class="truncate">{{ record.title }}</span>
                  <span class="flex-shrink-0">{{
                    formatDate(record.updated_at)
                  }}</span>
                </p>
              </div>
            </RouterLink>
          </div>
        </section>
      </div>
    </template>
  </PageLayout>
</template>
