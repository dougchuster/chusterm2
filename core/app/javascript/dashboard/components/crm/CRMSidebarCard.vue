<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text, vue/prefer-separate-static-class -->
<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import CrmAPI from '../../api/crm';
import CRMDealDrawer from './CRMDealDrawer.vue';
import CRMCategoryBadge from './CRMCategoryBadge.vue';
import CRMScoreAudit from './CRMScoreAudit.vue';
import CRMContactSummary from 'dashboard/components-next/Contacts/CRMContactSummary.vue';
import ContactLabels from 'dashboard/components-next/Contacts/ContactLabels/ContactLabels.vue';

const props = defineProps({
  conversationDatabaseId: { type: [Number, String], default: null },
  conversationDisplayId: { type: [Number, String], required: true },
  contact: { type: Object, default: () => ({}) },
});

const route = useRoute();
const store = useStore();

const deal = ref(null);
const loading = ref(false);
const error = ref(null);
const triageLoading = ref(false);
const scoreLoading = ref(false);
const drawerOpen = ref(false);
const pendingActivities = ref([]);
const activitiesLoading = ref(false);
const ownerUpdating = ref(false);
const relationshipUpdating = ref(false);
const assigneeUpdating = ref(false);
const activitySaving = ref(false);
const createDealLoading = ref(false);
const selectedOwnerId = ref('');
const selectedAssigneeId = ref('');
const quickActivity = ref({
  title: '',
  kind: 'follow_up',
  priority: 'normal',
  due_at: '',
});

const accountId = computed(() => route.params.accountId);
const agentList = useMapGetter('agents/getVerifiedAgents');
const currentChat = useMapGetter('getSelectedChat');

const urgencyColors = {
  critica: 'bg-ds-state-danger-soft text-ds-state-danger',
  alta: 'bg-ds-state-warning-soft text-ds-state-warning',
  media: 'bg-ds-state-warning-soft text-ds-state-warning',
  baixa: 'bg-ds-state-success-soft text-ds-state-success',
};

const urgencyLabels = {
  critica: 'Crítica',
  alta: 'Alta',
  media: 'Media',
  baixa: 'Baixa',
};

const sourceLabels = {
  jusbrasil: 'JusBrasil',
  whatsapp: 'WhatsApp direto',
  instagram: 'Instagram',
  facebook: 'Facebook',
  google_ads: 'Google Ads',
  meta_ads: 'Meta Ads',
  indicacao: 'Indicacao',
  site: 'Site',
  email: 'Email',
  tiktok: 'TikTok',
  cliente_base: 'Cliente Base',
  outro: 'Outro',
};

const operationalStatusLabels = {
  active: 'Lead ativo',
  base_client: 'Cliente Base',
  converted_client: 'Cliente convertido',
  returning_client: 'Retorno de cliente',
  invalid: 'Invalido',
  spam: 'Spam',
  duplicated: 'Duplicado',
  no_lead: 'Não é lead',
  archived: 'Arquivado',
};

const temperatureLabels = {
  prioridade_alta: 'Lead quente',
  qualificado: 'Lead morno',
  medio_potencial: 'Lead morno',
  baixo_potencial: 'Lead frio',
};

const temperatureClasses = {
  prioridade_alta:
    'bg-ds-state-danger-soft text-ds-state-danger ring-ds-state-danger/25',
  qualificado:
    'bg-ds-state-warning-soft text-ds-state-warning ring-ds-state-warning/25',
  medio_potencial:
    'bg-ds-state-warning-soft text-ds-state-warning ring-ds-state-warning/25',
  baixo_potencial:
    'bg-ds-bg-sunken text-ds-fg-muted ring-ds-border-subtle',
};

const lifecycleLabels = {
  visitor: 'Visitante',
  lead: 'Lead',
  qualified_lead: 'Lead qualificado',
  lead_qualified: 'Lead qualificado',
  triage: 'Em triagem',
  in_triage: 'Em triagem',
  consultation_scheduled: 'Consulta agendada',
  customer: 'Cliente',
  active_customer: 'Cliente ativo',
  recurring_customer: 'Recorrente',
  recurring: 'Recorrente',
  ex_customer: 'Ex-cliente',
  lost: 'Perdido',
};

async function loadPendingActivities() {
  if (!deal.value?.id) return;
  activitiesLoading.value = true;
  try {
    const { data } = await CrmAPI.getActivities({
      deal_id: deal.value.id,
      status: 'pending',
      per_page: 3,
    });
    pendingActivities.value = Array.isArray(data) ? data : data?.payload || [];
  } catch {
    // Non-critical.
  } finally {
    activitiesLoading.value = false;
  }
}

async function loadDeal() {
  if (!props.conversationDatabaseId) return;
  loading.value = true;
  error.value = null;
  try {
    const { data } = await CrmAPI.getDeals({
      conversation_id: props.conversationDatabaseId,
      per_page: 1,
    });
    const list = Array.isArray(data) ? data : data?.data || [];
    deal.value = list[0] || null;
    if (deal.value?.id) loadPendingActivities();
  } catch (e) {
    error.value = e?.response?.data?.error || e?.response?.data?.message || 'Erro ao carregar oportunidade';
  } finally {
    loading.value = false;
  }
}

async function runTriage() {
  if (!props.conversationDatabaseId) return;
  triageLoading.value = true;
  error.value = null;
  try {
    const { data } = await CrmAPI.triageFromConversation(
      props.conversationDatabaseId
    );
    deal.value = data;
    window.setTimeout(loadDeal, 400);
  } catch (e) {
    error.value = e?.response?.data?.error || e?.response?.data?.message || 'Erro ao executar triagem';
  } finally {
    triageLoading.value = false;
  }
}

async function createDealFromConversation() {
  if (!props.conversationDatabaseId || !props.contact?.id) return;

  createDealLoading.value = true;
  error.value = null;
  try {
    const { data } = await CrmAPI.createDeal({
      title: props.contact?.name || `Contato ${props.contact.id}`,
      contact_id: props.contact.id,
      conversation_id: props.conversationDatabaseId,
      inbox_id: currentChat.value?.inbox_id,
      owner_id: selectedOwnerId.value ? Number(selectedOwnerId.value) : null,
      assignee_id: selectedAssigneeId.value
        ? Number(selectedAssigneeId.value)
        : null,
      source: currentChat.value?.meta?.channel || 'whatsapp',
      operational_status: 'active',
    });
    deal.value = data;
    loadPendingActivities();
  } catch (e) {
    error.value = e?.response?.data?.error || 'Erro ao criar lead no CRM';
  } finally {
    createDealLoading.value = false;
  }
}

async function recalcScore() {
  if (!deal.value) return;
  scoreLoading.value = true;
  error.value = null;
  try {
    const { data } = await CrmAPI.recomputeScore(deal.value.id);
    deal.value = {
      ...deal.value,
      score_total: data.total_score,
      score_classification: data.classification,
      score_reason: data.reason,
      latest_score: {
        total_score: data.total_score,
        classification: data.classification,
        reason: data.reason,
        factors: data.factors,
        calculated_by: data.factors?.calculated_by,
      },
      crm_pipeline_stage_id:
        data.crm_pipeline_stage_id || deal.value.crm_pipeline_stage_id,
    };
    window.setTimeout(loadDeal, 400);
  } catch (e) {
    error.value = e?.response?.data?.error || e?.response?.data?.message || 'Erro ao recalcular score';
  } finally {
    scoreLoading.value = false;
  }
}

function handleDealSaved(updatedDeal) {
  deal.value = { ...deal.value, ...updatedDeal };
  loadPendingActivities();
}

async function updateRelationshipStatus(status) {
  if (!props.contact?.id) return;

  relationshipUpdating.value = true;
  try {
    await store.dispatch('contacts/update', {
      id: props.contact.id,
      relationshipStatus: status,
      lifecycleStage: status === 'customer' ? 'customer' : 'lead',
    });
  } finally {
    relationshipUpdating.value = false;
  }
}

async function updateOwner() {
  if (!props.contact?.id) return;

  ownerUpdating.value = true;
  try {
    await store.dispatch('contacts/update', {
      id: props.contact.id,
      crmOwnerId: selectedOwnerId.value ? Number(selectedOwnerId.value) : null,
      crmOwnerSource: 'manual',
    });
  } finally {
    ownerUpdating.value = false;
  }
}

async function updateConversationAssignee() {
  if (!props.conversationDisplayId) return;

  assigneeUpdating.value = true;
  try {
    const assigneeId = selectedAssigneeId.value
      ? Number(selectedAssigneeId.value)
      : null;
    await store.dispatch('assignAgent', {
      conversationId: props.conversationDisplayId,
      agentId: assigneeId,
    });
    if (deal.value?.id) {
      const { data } = await CrmAPI.updateDeal(deal.value.id, {
        assignee_id: assigneeId,
      });
      deal.value = { ...deal.value, ...data };
    }
  } finally {
    assigneeUpdating.value = false;
  }
}

async function createQuickActivity() {
  if (!quickActivity.value.title.trim()) return;

  activitySaving.value = true;
  error.value = null;
  try {
    const payload = {
      crm_deal_id: deal.value?.id,
      contact_id: props.contact?.id,
      conversation_id: props.conversationDatabaseId,
      owner_id: selectedOwnerId.value ? Number(selectedOwnerId.value) : null,
      assignee_id: selectedAssigneeId.value
        ? Number(selectedAssigneeId.value)
        : null,
      kind: quickActivity.value.kind,
      priority: quickActivity.value.priority,
      title: quickActivity.value.title.trim(),
      due_at: quickActivity.value.due_at || null,
    };
    const { data } = await CrmAPI.createActivity(payload);
    pendingActivities.value = [data, ...pendingActivities.value].slice(0, 3);
    quickActivity.value = {
      title: '',
      kind: 'follow_up',
      priority: 'normal',
      due_at: '',
    };
  } catch (e) {
    error.value = e?.response?.data?.error || 'Erro ao criar atividade';
  } finally {
    activitySaving.value = false;
  }
}

const scoreColor = computed(() => {
  const s = deal.value?.score_total || 0;
  if (s >= 80) return 'text-ds-state-danger';
  if (s >= 60) return 'text-ds-state-success';
  if (s >= 40) return 'text-ds-state-warning';
  return 'text-ds-fg-subtle';
});

const crmDealUrl = computed(() => {
  if (!deal.value?.id || !accountId.value) return '';
  return `/app/accounts/${accountId.value}/crm/deals/${deal.value.id}`;
});

const lifecycleLabel = computed(() => {
  const stage = props.contact?.lifecycle_stage || 'lead';
  return lifecycleLabels[stage] || stage;
});

const ownerName = computed(
  () => props.contact?.crm_owner?.name || 'Sem responsável'
);

const currentAssigneeName = computed(
  () => currentChat.value?.meta?.assignee?.name || 'Sem atendente'
);

const crmContact = computed(() => ({
  relationshipStatus: props.contact?.relationship_status,
  lifecycleStage: props.contact?.lifecycle_stage,
  crmOwnerId: props.contact?.crm_owner_id,
  crmOwner: props.contact?.crm_owner,
}));

const sourceLabel = computed(() => {
  if (!deal.value?.source) return 'Origem não informada';
  return sourceLabels[deal.value.source] || deal.value.source;
});

const operationalStatusLabel = computed(() => {
  const status = deal.value?.operational_status || 'active';
  return operationalStatusLabels[status] || status;
});

const leadTemperature = computed(() => {
  const classification = deal.value?.score_classification;
  if (!classification) return null;

  return {
    label: temperatureLabels[classification] || classification,
    className:
      temperatureClasses[classification] ||
      'bg-ds-bg-sunken text-ds-fg-muted ring-ds-border-subtle',
  };
});

const handleCrmSummaryUpdate = data => {
  updateRelationshipStatus(data.relationshipStatus);
};

watch(
  () => props.contact?.crm_owner_id,
  ownerId => {
    selectedOwnerId.value = ownerId ? String(ownerId) : '';
  },
  { immediate: true }
);

watch(
  () => currentChat.value?.meta?.assignee?.id,
  assigneeId => {
    selectedAssigneeId.value = assigneeId ? String(assigneeId) : '';
  },
  { immediate: true }
);

watch(() => props.conversationDatabaseId, loadDeal, { immediate: true });

onMounted(() => {
  if (!agentList.value?.length) {
    store.dispatch('agents/get');
  }
});
</script>

<template>
  <div class="crm-sidebar-card space-y-3 p-3 text-ds-fg-default">
    <div v-if="!deal" class="flex items-center justify-end">
      <button
        type="button"
        :disabled="triageLoading"
        class="inline-flex min-h-8 items-center gap-1.5 rounded-lg bg-ds-accent-soft px-2.5 text-xs font-semibold text-ds-accent transition-colors hover:bg-ds-bg-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-border-focus disabled:cursor-not-allowed disabled:opacity-50"
        @click="runTriage"
      >
        <span class="i-lucide-search size-3" />
        {{ triageLoading ? 'Analisando...' : 'Iniciar triagem' }}
      </button>
    </div>

    <div
      class="rounded-xl bg-ds-bg-sunken p-3 text-xs ring-1 ring-inset ring-ds-border-subtle"
    >
      <div
        class="mb-2 text-[10px] font-semibold uppercase tracking-[0.14em] text-ds-fg-subtle"
      >
        Relacionamento
      </div>
      <CRMContactSummary
        :contact="crmContact"
        :is-updating="relationshipUpdating"
        compact
        editable
        @update="handleCrmSummaryUpdate"
      />
      <div class="mt-3 grid grid-cols-1 gap-2">
        <div>
          <div
            class="text-[10px] font-semibold uppercase tracking-[0.14em] text-ds-fg-subtle"
          >
            Etapa
          </div>
          <div class="font-semibold text-ds-fg-default">
            {{ lifecycleLabel }}
          </div>
        </div>
        <div>
          <div
            class="text-[10px] font-semibold uppercase tracking-[0.14em] text-ds-fg-subtle"
          >
            Responsável pelo contato
          </div>
          <div
            class="font-semibold"
            :class="
              contact?.crm_owner
                ? 'text-ds-fg-default'
                : 'text-ds-state-danger'
            "
          >
            {{ ownerName }}
          </div>
          <div class="mt-1 flex gap-1">
            <select
              v-model="selectedOwnerId"
              aria-label="Responsável pelo contato"
              class="h-8 min-w-0 flex-1 rounded-lg border-0 bg-ds-bg-surface px-2 text-xs text-ds-fg-default ring-1 ring-inset ring-ds-border-default focus:outline-none focus:ring-2 focus:ring-ds-border-focus"
              :disabled="ownerUpdating"
            >
              <option value="">Sem responsável</option>
              <option
                v-for="agent in agentList"
                :key="agent.id"
                :value="String(agent.id)"
              >
                {{ agent.name || agent.email }}
              </option>
            </select>
            <button
              type="button"
              class="h-8 rounded-lg bg-ds-accent-soft px-2 text-xs font-semibold text-ds-accent transition-colors hover:bg-ds-bg-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-border-focus disabled:cursor-not-allowed disabled:opacity-50"
              :disabled="ownerUpdating"
              @click="updateOwner"
            >
              Salvar
            </button>
          </div>
        </div>
        <div>
          <div
            class="text-[10px] font-semibold uppercase tracking-[0.14em] text-ds-fg-subtle"
          >
            Responder por
          </div>
          <div
            class="font-semibold"
            :class="
              currentChat?.meta?.assignee
                ? 'text-ds-fg-default'
                : 'text-ds-state-warning'
            "
          >
            {{ currentAssigneeName }}
          </div>
          <div class="mt-1 flex gap-1">
            <select
              v-model="selectedAssigneeId"
              aria-label="Atendente da conversa"
              class="h-8 min-w-0 flex-1 rounded-lg border-0 bg-ds-bg-surface px-2 text-xs text-ds-fg-default ring-1 ring-inset ring-ds-border-default focus:outline-none focus:ring-2 focus:ring-ds-border-focus"
              :disabled="assigneeUpdating"
            >
              <option value="">Sem atendente</option>
              <option
                v-for="agent in agentList"
                :key="agent.id"
                :value="String(agent.id)"
              >
                {{ agent.name || agent.email }}
              </option>
            </select>
            <button
              type="button"
              class="h-8 rounded-lg bg-ds-accent-soft px-2 text-xs font-semibold text-ds-accent transition-colors hover:bg-ds-bg-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-border-focus disabled:cursor-not-allowed disabled:opacity-50"
              :disabled="assigneeUpdating"
              @click="updateConversationAssignee"
            >
              Salvar
            </button>
          </div>
        </div>
      </div>
    </div>

    <div
      v-if="contact?.id"
      class="rounded-xl bg-ds-bg-sunken p-3 text-xs ring-1 ring-inset ring-ds-border-subtle"
    >
      <div
        class="mb-2 text-[10px] font-semibold uppercase tracking-[0.14em] text-ds-fg-subtle"
      >
        Etiquetas do contato
      </div>
      <ContactLabels :contact-id="contact.id" />
    </div>

    <div v-if="loading" class="text-xs text-ds-fg-subtle">Carregando...</div>
    <div
      v-else-if="error"
      class="rounded-lg bg-ds-state-danger-soft p-2 text-xs text-ds-state-danger"
      role="alert"
    >
      {{ error }}
    </div>
    <div
      v-else-if="!deal"
      class="rounded-xl bg-ds-bg-sunken px-3 py-4 text-center text-xs text-ds-fg-subtle"
    >
      <span class="i-lucide-file-search mx-auto mb-1 block size-5 opacity-40" />
      Nenhuma oportunidade vinculada.
      <div class="mt-2 flex justify-center gap-1">
        <button
          type="button"
          class="min-h-8 rounded-lg bg-ds-accent-soft px-3 py-1 text-xs font-semibold text-ds-accent transition-colors hover:bg-ds-bg-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-border-focus disabled:cursor-not-allowed disabled:opacity-50"
          :disabled="createDealLoading"
          @click="createDealFromConversation"
        >
          {{ createDealLoading ? 'Criando...' : 'Criar lead' }}
        </button>
      </div>
    </div>

    <div v-else class="space-y-3">
      <div class="flex items-center justify-between gap-2">
        <span
          class="max-w-[160px] truncate text-xs font-semibold text-ds-fg-default"
          :title="deal.title"
        >
          {{ deal.title }}
        </span>
        <span
          v-if="leadTemperature"
          class="inline-flex shrink-0 items-center gap-1 rounded-full px-2 py-0.5 text-[10px] font-semibold ring-1"
          :class="leadTemperature.className"
          :title="`Score ${deal.score_total || 0}pts`"
        >
          <span class="i-lucide-flame size-3" />
          {{ leadTemperature.label }}
        </span>
      </div>

      <div class="flex items-center gap-2 text-xs text-ds-fg-muted">
        <span class="font-bold" :class="[scoreColor]">
          {{ deal.score_total || 0 }}pts
        </span>
        <span v-if="deal.score_reason" class="truncate">
          {{ deal.score_reason }}
        </span>
      </div>

      <div class="flex flex-wrap items-center gap-1.5">
        <CRMCategoryBadge
          v-if="deal.category || deal.legal_area"
          :category="deal.category || deal.legal_area"
          :label="deal.category_label || deal.legal_area_label"
          compact
        />
        <span
          v-if="deal.urgency_level"
          class="inline-flex items-center rounded-full px-1.5 py-0.5 text-[10px] font-medium capitalize"
          :class="
            urgencyColors[deal.urgency_level] ||
            'bg-ds-bg-sunken text-ds-fg-muted'
          "
        >
          {{ urgencyLabels[deal.urgency_level] || deal.urgency_level }}
        </span>
      </div>

      <div v-if="deal.stage" class="text-xs text-ds-fg-muted">
        Etapa: <span class="font-medium">{{ deal.stage?.name }}</span>
      </div>

      <div class="grid grid-cols-1 gap-1 text-xs text-ds-fg-muted">
        <div>
          Status CRM:
          <span class="font-medium text-ds-fg-default">
            {{ operationalStatusLabel }}
          </span>
        </div>
        <div>
          Origem:
          <span class="font-medium text-ds-fg-default">
            {{ sourceLabel }}
          </span>
          <span v-if="deal.source_detail"> - {{ deal.source_detail }}</span>
        </div>
      </div>

      <div
        v-if="deal.next_best_action"
        class="rounded-lg bg-ds-state-info-soft p-2 text-xs text-ds-state-info"
      >
        <span class="i-lucide-lightbulb mr-1 inline size-3" />
        <span>{{ deal.next_best_action }}</span>
      </div>

      <CRMScoreAudit
        v-if="deal.latest_score"
        :score="deal.latest_score"
        compact
      />

      <div
        v-if="pendingActivities.length > 0"
        class="rounded-xl bg-ds-bg-sunken p-2.5 ring-1 ring-inset ring-ds-border-subtle"
      >
        <div
          class="mb-1 text-[10px] font-semibold uppercase tracking-[0.14em] text-ds-fg-subtle"
        >
          Atividades pendentes
        </div>
        <div
          v-for="act in pendingActivities"
          :key="act.id"
          class="flex items-center gap-1.5 py-0.5 text-xs text-ds-fg-muted"
        >
          <span
            class="inline-block size-1.5 rounded-full"
            :class="
              act.kind === 'ligacao'
                ? 'bg-ds-state-info'
                : act.kind === 'reuniao'
                  ? 'bg-ds-accent-secondary'
                  : 'bg-ds-fg-subtle'
            "
          />
          <span class="truncate">{{ act.title }}</span>
          <span
            v-if="act.due_at"
            class="ml-auto shrink-0 text-[10px] text-ds-fg-subtle"
          >
            {{
              new Date(act.due_at).toLocaleDateString('pt-BR', {
                day: '2-digit',
                month: 'short',
              })
            }}
          </span>
        </div>
      </div>

      <div
        class="rounded-xl bg-ds-bg-sunken p-3 ring-1 ring-inset ring-ds-border-subtle"
      >
        <div
          class="mb-2 text-[10px] font-semibold uppercase tracking-[0.14em] text-ds-fg-subtle"
        >
          Próxima ação
        </div>
        <input
          v-model="quickActivity.title"
          class="mb-1 h-8 w-full rounded-lg border-0 bg-ds-bg-surface px-2 text-xs text-ds-fg-default ring-1 ring-inset ring-ds-border-default placeholder:text-ds-fg-disabled focus:outline-none focus:ring-2 focus:ring-ds-border-focus"
          placeholder="Ex: ligar para confirmar documentos"
        />
        <div class="grid grid-cols-2 gap-1">
          <select
            v-model="quickActivity.kind"
            aria-label="Tipo da próxima ação"
            class="h-8 min-w-0 rounded-lg border-0 bg-ds-bg-surface px-2 text-xs text-ds-fg-default ring-1 ring-inset ring-ds-border-default focus:outline-none focus:ring-2 focus:ring-ds-border-focus"
          >
            <option value="follow_up">Follow-up</option>
            <option value="ligação">Ligação</option>
            <option value="reuniao">Reunião</option>
            <option value="solicitacao_documentos">Pedir documentos</option>
            <option value="analise_documental">Analisar documentos</option>
          </select>
          <select
            v-model="quickActivity.priority"
            aria-label="Prioridade da próxima ação"
            class="h-8 min-w-0 rounded-lg border-0 bg-ds-bg-surface px-2 text-xs text-ds-fg-default ring-1 ring-inset ring-ds-border-default focus:outline-none focus:ring-2 focus:ring-ds-border-focus"
          >
            <option value="normal">Normal</option>
            <option value="alta">Alta</option>
            <option value="critica">Crítica</option>
            <option value="baixa">Baixa</option>
          </select>
        </div>
        <input
          v-model="quickActivity.due_at"
          type="datetime-local"
          aria-label="Data e hora da próxima ação"
          class="mt-1 h-8 w-full rounded-lg border-0 bg-ds-bg-surface px-2 text-xs text-ds-fg-default ring-1 ring-inset ring-ds-border-default focus:outline-none focus:ring-2 focus:ring-ds-border-focus"
        />
        <button
          type="button"
          class="mt-2 h-8 w-full rounded-lg bg-ds-accent px-2 text-xs font-semibold text-ds-fg-on-accent transition-colors hover:bg-ds-accent-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-border-focus disabled:cursor-not-allowed disabled:opacity-50"
          :disabled="activitySaving || !quickActivity.title.trim()"
          @click="createQuickActivity"
        >
          {{ activitySaving ? 'Salvando...' : 'Criar tarefa' }}
        </button>
      </div>

      <div class="mt-2 flex flex-wrap gap-1">
        <a
          v-if="crmDealUrl"
          :href="crmDealUrl"
          class="inline-flex min-h-8 items-center rounded-lg bg-ds-bg-sunken px-2.5 text-xs font-medium text-ds-fg-default no-underline transition-colors hover:bg-ds-bg-hover hover:text-ds-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-border-focus"
        >
          Abrir no CRM
        </a>
        <button
          type="button"
          class="min-h-8 rounded-lg bg-ds-bg-sunken px-2.5 text-xs font-medium text-ds-fg-default transition-colors hover:bg-ds-bg-hover hover:text-ds-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-border-focus"
          @click="drawerOpen = true"
        >
          Editar
        </button>
        <button
          type="button"
          class="min-h-8 rounded-lg bg-ds-bg-sunken px-2.5 text-xs font-medium text-ds-fg-default transition-colors hover:bg-ds-bg-hover hover:text-ds-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-border-focus disabled:cursor-not-allowed disabled:opacity-50"
          :disabled="scoreLoading"
          @click="recalcScore"
        >
          {{ scoreLoading ? 'Recalculando...' : 'Recalcular score' }}
        </button>
      </div>
    </div>

    <CRMDealDrawer
      v-if="deal"
      v-model:show="drawerOpen"
      :deal-id="deal.id"
      @saved="handleDealSaved"
    />
  </div>
</template>
