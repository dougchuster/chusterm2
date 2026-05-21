<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text, vue/prefer-separate-static-class -->
<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import CrmAPI from 'dashboard/api/crm';
import CRMScoreAudit from 'dashboard/components/crm/CRMScoreAudit.vue';
import CRMLegalAreaBadge from 'dashboard/components/crm/CRMLegalAreaBadge.vue';

const route = useRoute();
const router = useRouter();
const store = useStore();

const dealId = computed(() => Number(route.params.dealId));
const accountId = computed(() => Number(route.params.accountId));

const deal = ref(null);
const stages = ref([]);
const auditEvents = ref([]);
const loading = ref(true);
const saving = ref(false);
const deleting = ref(false);
const scoreRefreshing = ref(false);
const ownerUpdating = ref(false);
const assigneeUpdating = ref(false);
const error = ref('');
const activeTab = ref('overview');
const showNewActivity = ref(false);
const selectedOwnerId = ref('');
const selectedAssigneeId = ref('');

const newActivity = ref({
  kind: 'follow_up',
  title: '',
  description: '',
  priority: 'normal',
  due_at: '',
});

const tabs = [
  { id: 'overview', label: 'Visao 360', icon: 'i-lucide-layout-dashboard' },
  { id: 'messages', label: 'Mensagens', icon: 'i-lucide-message-square' },
  { id: 'files', label: 'Arquivos', icon: 'i-lucide-paperclip' },
  { id: 'activities', label: 'Atividades', icon: 'i-lucide-check-square' },
  { id: 'timeline', label: 'Histórico', icon: 'i-lucide-history' },
  { id: 'campaigns', label: 'Campanhas', icon: 'i-lucide-megaphone' },
  { id: 'lgpd', label: 'LGPD', icon: 'i-lucide-shield-check' },
];

const legalAreas = [
  { value: '', label: 'Sem área' },
  { value: 'previdenciario', label: 'Previdenciario' },
  { value: 'trabalhista', label: 'Trabalhista' },
  { value: 'civil', label: 'Civil' },
  { value: 'familia', label: 'Familia' },
  { value: 'consumidor', label: 'Consumidor' },
  { value: 'empresarial', label: 'Empresarial' },
  { value: 'tributario', label: 'Tributario' },
  { value: 'imobiliario', label: 'Imobiliario' },
  { value: 'penal', label: 'Penal' },
  { value: 'outros', label: 'Outros' },
];

const sources = [
  { value: '', label: 'Sem origem' },
  { value: 'whatsapp', label: 'WhatsApp direto' },
  { value: 'jusbrasil', label: 'JusBrasil' },
  { value: 'instagram', label: 'Instagram' },
  { value: 'facebook', label: 'Facebook' },
  { value: 'google_ads', label: 'Google Ads' },
  { value: 'meta_ads', label: 'Meta Ads' },
  { value: 'indicacao', label: 'Indicacao' },
  { value: 'site', label: 'Site' },
  { value: 'lista_importada', label: 'Lista importada' },
  { value: 'cliente_base', label: 'Cliente Base' },
  { value: 'outros', label: 'Outros' },
];

const operationalStatuses = [
  { value: 'active', label: 'Lead ativo' },
  { value: 'returning_client', label: 'Retorno de cliente' },
  { value: 'base_client', label: 'Cliente Base' },
  { value: 'converted_client', label: 'Cliente convertido' },
  { value: 'invalid', label: 'Invalido' },
  { value: 'spam', label: 'Spam' },
  { value: 'duplicated', label: 'Duplicado' },
  { value: 'no_lead', label: 'Não é lead' },
  { value: 'archived', label: 'Arquivado' },
];

const priorities = [
  { value: 'baixa', label: 'Baixa' },
  { value: 'normal', label: 'Normal' },
  { value: 'alta', label: 'Alta' },
  { value: 'critica', label: 'Crítica' },
];

const activityKinds = [
  { value: 'follow_up', label: 'Follow-up' },
  { value: 'ligacao', label: 'Ligação' },
  { value: 'reuniao', label: 'Reunião' },
  { value: 'solicitacao_documentos', label: 'Pedir documentos' },
  { value: 'analise_documental', label: 'Analise documental' },
  { value: 'envio_proposta', label: 'Envio de proposta' },
  { value: 'envio_contrato', label: 'Envio de contrato' },
  { value: 'revisao_juridica', label: 'Revisão jurídica' },
  { value: 'retorno_cliente', label: 'Retorno ao cliente' },
];

const crmUrl = computed(() => `/app/accounts/${accountId.value}/crm`);
const contact = computed(() => deal.value?.contact || null);
const conversation = computed(() => deal.value?.conversation || null);
const agents = useMapGetter('agents/getVerifiedAgents');
const messages = computed(() => deal.value?.messages || []);
const attachments = computed(() => deal.value?.attachments || []);
const campaignEvents = computed(() => deal.value?.campaign_events || []);
const activities = computed(() => deal.value?.activities || []);
const pendingActivities = computed(() =>
  activities.value.filter(activity => !activity.completed_at)
);
const conversationUrl = computed(() => {
  const displayId =
    conversation.value?.display_id || deal.value?.conversation_id;
  return displayId
    ? `/app/accounts/${accountId.value}/conversations/${displayId}`
    : '';
});

const contactUrl = computed(() =>
  deal.value?.contact_id
    ? `/app/accounts/${accountId.value}/contacts/${deal.value.contact_id}`
    : ''
);

const primaryContactName = computed(
  () => contact.value?.name || deal.value?.contact_name || 'Contato sem nome'
);

const primaryPhone = computed(
  () => contact.value?.phone_number || deal.value?.contact_phone_number || ''
);

const primaryEmail = computed(
  () => contact.value?.email || deal.value?.contact_email || ''
);

const pipelineName = computed(
  () => deal.value?.pipeline?.name || 'Pipeline não informado'
);

const channelName = computed(
  () =>
    deal.value?.inbox?.name ||
    conversation.value?.inbox?.name ||
    'Canal não informado'
);

const currentStageIndex = computed(() =>
  stages.value.findIndex(
    stage => Number(stage.id) === Number(deal.value?.crm_pipeline_stage_id)
  )
);

const currentStageName = computed(
  () =>
    stages.value[currentStageIndex.value]?.name ||
    deal.value?.stage?.name ||
    'Etapa não informada'
);

const ownerName = computed(
  () =>
    contact.value?.crm_owner?.name ||
    agents.value?.find(
      agent => Number(agent.id) === Number(deal.value?.owner_id)
    )?.name ||
    'Sem responsável'
);

const recordFacts = computed(() => [
  {
    label: 'Canal',
    value: channelName.value,
    icon: 'i-lucide-inbox',
  },
  {
    label: 'Pipeline',
    value: pipelineName.value,
    icon: 'i-lucide-git-branch',
  },
  {
    label: 'Etapa atual',
    value: currentStageName.value,
    icon: 'i-lucide-milestone',
  },
  {
    label: 'Responsável',
    value: ownerName.value,
    icon: 'i-lucide-user-check',
  },
]);

const assigneeName = computed(
  () =>
    conversation.value?.assignee?.name ||
    agents.value?.find(
      agent => Number(agent.id) === Number(deal.value?.assignee_id)
    )?.name ||
    'Sem atendente'
);

const scoreTone = computed(() => {
  const score = Number(deal.value?.score_total || 0);
  if (score >= 80) return 'text-ruby-600 bg-ruby-50 dark:bg-ruby-950/30';
  if (score >= 60) return 'text-teal-700 bg-teal-50 dark:bg-teal-950/30';
  if (score >= 40) return 'text-amber-700 bg-amber-50 dark:bg-amber-950/30';
  return 'text-n-slate-11 bg-n-slate-3';
});

const kpis = computed(() => [
  {
    label: 'Mensagens',
    value: messages.value.length,
    icon: 'i-lucide-message-square',
  },
  {
    label: 'Arquivos',
    value: attachments.value.length,
    icon: 'i-lucide-paperclip',
  },
  {
    label: 'Tarefas pendentes',
    value: pendingActivities.value.length,
    icon: 'i-lucide-check-square',
  },
  {
    label: 'Eventos de campanha',
    value: campaignEvents.value.length,
    icon: 'i-lucide-megaphone',
  },
]);

const combinedLabels = computed(() => {
  const contactLabels = (contact.value?.labels || []).map(label => ({
    raw: label,
    title: labelDisplayTitle(label),
    source: 'Contato',
  }));
  const conversationLabels = (conversation.value?.labels || []).map(label => ({
    raw: label,
    title: labelDisplayTitle(label),
    source: 'Atendimento',
  }));
  const seen = new Set();

  return [...contactLabels, ...conversationLabels].filter(label => {
    const key = label.raw.toString();
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
});

const unifiedTimeline = computed(() => {
  const messageItems = messages.value.map(message => ({
    id: `message-${message.id}`,
    type: 'message',
    title: message.private ? 'Nota privada' : messageTitle(message),
    description:
      message.content_for_llm || message.content || 'Mensagem sem texto',
    at: message.created_at,
  }));

  const activityItems = activities.value.map(activity => ({
    id: `activity-${activity.id}`,
    type: 'activity',
    title: activity.completed_at ? 'Atividade concluida' : 'Atividade criada',
    description: activity.title,
    at: activity.completed_at || activity.due_at || activity.created_at,
  }));

  const auditItems = auditEvents.value.map(event => ({
    id: `audit-${event.id}`,
    type: 'audit',
    title: actionLabel(event.action),
    description: payloadSummary(event.payload),
    at: event.created_at,
  }));

  const campaignItems = campaignEvents.value.map(event => ({
    id: `campaign-${event.id}`,
    type: 'campaign',
    title: `Campanha: ${campaignEventLabel(event.event_type)}`,
    description: event.campaign?.title || event.provider || '',
    at: event.occurred_at,
  }));

  return [...messageItems, ...activityItems, ...auditItems, ...campaignItems]
    .filter(item => item.at)
    .sort((a, b) => new Date(b.at) - new Date(a.at));
});

function extractData(response) {
  const payload = response?.data ?? response;
  if (Array.isArray(payload)) return payload;
  return payload?.data || [];
}

async function loadDeal() {
  if (!dealId.value) return;
  loading.value = true;
  error.value = '';
  try {
    const { data } = await CrmAPI.getDeal(dealId.value);
    deal.value = data;
    syncAssignmentForm();
    await loadStages();
  } catch (e) {
    error.value =
      e?.response?.data?.error || 'Não foi possível carregar a ficha.';
  } finally {
    loading.value = false;
  }
}

async function loadStages() {
  if (!deal.value?.crm_pipeline_id) return;
  try {
    const response = await CrmAPI.getPipelineStages(deal.value.crm_pipeline_id);
    stages.value = extractData(response);
  } catch {
    stages.value = [];
  }
}

async function loadAuditEvents() {
  if (!dealId.value) return;
  try {
    const { data } = await CrmAPI.getAuditEvents({
      target_type: 'CrmDeal',
      target_id: dealId.value,
    });
    auditEvents.value = Array.isArray(data) ? data : data?.data || [];
  } catch {
    auditEvents.value = [];
  }
}

async function refreshAll() {
  await Promise.all([loadDeal(), loadAuditEvents()]);
}

async function updateField(field, value) {
  saving.value = true;
  error.value = '';
  try {
    const { data } = await CrmAPI.updateDeal(dealId.value, { [field]: value });
    deal.value = { ...deal.value, ...data };
  } catch (e) {
    error.value = e?.response?.data?.error || 'Não foi possível atualizar.';
  } finally {
    saving.value = false;
  }
}

async function updateOwner() {
  const ownerId = selectedOwnerId.value ? Number(selectedOwnerId.value) : null;
  ownerUpdating.value = true;
  error.value = '';
  try {
    await CrmAPI.updateDeal(dealId.value, { owner_id: ownerId });
    if (contact.value?.id) {
      await store.dispatch('contacts/update', {
        id: contact.value.id,
        crmOwnerId: ownerId,
        crmOwnerSource: 'manual',
      });
    }
    await loadDeal();
  } catch (e) {
    error.value =
      e?.response?.data?.error || 'Não foi possível alterar o responsável.';
  } finally {
    ownerUpdating.value = false;
  }
}

async function updateAssignee() {
  const assigneeId = selectedAssigneeId.value
    ? Number(selectedAssigneeId.value)
    : null;
  assigneeUpdating.value = true;
  error.value = '';
  try {
    if (deal.value?.conversation_id) {
      await store.dispatch('assignAgent', {
        conversationId: deal.value.conversation_id,
        agentId: assigneeId,
      });
    }
    await CrmAPI.updateDeal(dealId.value, { assignee_id: assigneeId });
    await loadDeal();
  } catch (e) {
    error.value =
      e?.response?.data?.error || 'Não foi possível delegar o atendimento.';
  } finally {
    assigneeUpdating.value = false;
  }
}

async function moveStage(stageId) {
  if (!stageId) return;
  saving.value = true;
  try {
    const { data } = await CrmAPI.moveDeal(dealId.value, stageId);
    deal.value = { ...deal.value, ...data };
  } catch (e) {
    error.value = e?.response?.data?.error || 'Não foi possível mover etapa.';
  } finally {
    saving.value = false;
  }
}

async function recalcScore() {
  scoreRefreshing.value = true;
  try {
    await CrmAPI.recomputeScore(dealId.value);
    await loadDeal();
  } catch (e) {
    error.value = e?.response?.data?.error || 'Não foi possível recalcular.';
  } finally {
    scoreRefreshing.value = false;
  }
}

async function markWon() {
  saving.value = true;
  try {
    const { data } = await CrmAPI.markDealWon(dealId.value);
    deal.value = { ...deal.value, ...data };
  } catch (e) {
    error.value = e?.response?.data?.error || 'Não foi possível marcar ganho.';
  } finally {
    saving.value = false;
  }
}

async function markBaseClient() {
  saving.value = true;
  try {
    const { data } = await CrmAPI.markDealBaseClient(dealId.value);
    deal.value = { ...deal.value, ...data };
  } catch (e) {
    error.value =
      e?.response?.data?.error || 'Não foi possível marcar Cliente Base.';
  } finally {
    saving.value = false;
  }
}

async function discard(reason) {
  saving.value = true;
  try {
    const { data } = await CrmAPI.discardDeal(dealId.value, { reason });
    deal.value = { ...deal.value, ...data };
  } catch (e) {
    error.value = e?.response?.data?.error || 'Não foi possível descartar.';
  } finally {
    saving.value = false;
  }
}

async function reopenDeal() {
  saving.value = true;
  try {
    const { data } = await CrmAPI.reopenDeal(dealId.value);
    deal.value = { ...deal.value, ...data };
  } catch (e) {
    error.value = e?.response?.data?.error || 'Não foi possível reabrir.';
  } finally {
    saving.value = false;
  }
}

async function deleteDealPermanently() {
  if (!deal.value?.id) return;
  const confirmed = window.confirm(
    `Excluir definitivamente "${deal.value.title || 'este lead'}" do sistema?\nEssa ação remove o registro do CRM e não pode ser desfeita.`
  );
  if (!confirmed) return;

  deleting.value = true;
  error.value = '';
  try {
    await CrmAPI.deleteDeal(dealId.value);
    router.push(crmUrl.value);
  } catch (e) {
    error.value =
      e?.response?.data?.error || 'Não foi possível excluir este lead.';
  } finally {
    deleting.value = false;
  }
}

async function completeActivity(activity) {
  try {
    await CrmAPI.completeActivity(activity.id, 'Concluída pela ficha 360');
    await loadDeal();
  } catch (e) {
    error.value =
      e?.response?.data?.error || 'Não foi possível concluir tarefa.';
  }
}

async function createActivity() {
  if (!newActivity.value.title.trim()) return;
  saving.value = true;
  try {
    await CrmAPI.createActivity({
      crm_deal_id: dealId.value,
      contact_id: deal.value?.contact_id,
      conversation_id: deal.value?.conversation_id,
      ...newActivity.value,
      due_at: newActivity.value.due_at || null,
    });
    newActivity.value = {
      kind: 'follow_up',
      title: '',
      description: '',
      priority: 'normal',
      due_at: '',
    };
    showNewActivity.value = false;
    await loadDeal();
  } catch (e) {
    error.value = e?.response?.data?.error || 'Não foi possível criar tarefa.';
  } finally {
    saving.value = false;
  }
}

function formatDate(value) {
  if (!value) return 'Não informado';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return 'Não informado';
  return new Intl.DateTimeFormat('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(date);
}

function messageTitle(message) {
  if (message.message_type === 'incoming') return 'Mensagem do contato';
  if (message.sender_name) return `Resposta de ${message.sender_name}`;
  return 'Mensagem enviada';
}

function messageClass(message) {
  if (message.private)
    return 'border-amber-300 bg-amber-50 dark:bg-amber-950/20';
  if (message.message_type === 'incoming') return 'border-n-weak bg-n-slate-1';
  return 'border-teal-200 bg-teal-50 dark:bg-teal-950/20';
}

function syncAssignmentForm() {
  const ownerId = contact.value?.crm_owner_id || deal.value?.owner_id;
  const assigneeId =
    deal.value?.assignee_id || conversation.value?.assignee?.id;

  selectedOwnerId.value = ownerId ? String(ownerId) : '';
  selectedAssigneeId.value = assigneeId ? String(assigneeId) : '';
}

function labelDisplayTitle(label) {
  const raw = label?.toString() || '';
  const parts = raw.split(/[._-]+/).filter(Boolean);
  if (!parts.length) return raw;

  const prefix = parts[0];
  const text =
    parts.length > 1 ? parts.slice(1).map(titleize).join(' ') : titleize(raw);
  const prefixes = {
    area: 'Setor',
    temp: 'Temp',
    status: 'Status',
    doc: 'Doc',
    risk: 'Risco',
    origin: 'Origem',
    service: 'Atendimento',
  };

  if (prefix === 'rel') return text;
  if (prefixes[prefix]) return `${prefixes[prefix]} ${text}`;
  return parts.map(titleize).join(' ');
}

function titleize(value) {
  const text = value.toString();
  if (['cpf', 'rg', 'cnh', 'cnis', 'ctps', 'bpc', 'loas'].includes(text)) {
    return text.toUpperCase();
  }
  return text.charAt(0).toUpperCase() + text.slice(1).toLowerCase();
}

function fileDescription(attachment) {
  const meta = attachment.meta || {};
  return (
    attachment.image_description ||
    meta.image_description ||
    meta.ocr_text ||
    meta.transcribed_text ||
    attachment.fallback_title ||
    attachment.document_guess ||
    meta.document_guess ||
    ''
  );
}

function fileStatus(attachment) {
  const meta = attachment.meta || {};
  return (
    attachment.media_understanding_status ||
    meta.media_understanding_status ||
    ''
  );
}

function actionLabel(action) {
  const labels = {
    deal_created: 'Lead criado',
    deal_updated: 'Lead atualizado',
    deal_moved: 'Etapa alterada',
    deal_marked_won: 'Marcado como ganho',
    deal_marked_lost: 'Marcado como perdido',
    deal_reopened: 'Reaberto',
    deal_archived: 'Arquivado',
    deal_label_applied: 'Etiqueta aplicada',
    deal_owner_assigned: 'Responsável atribuído',
    activity_created: 'Atividade criada',
    activity_completed: 'Atividade concluida',
  };
  return labels[action] || action || 'Evento';
}

function campaignEventLabel(eventType) {
  const labels = {
    sent: 'enviada',
    skipped: 'ignorada',
    failed: 'falhou',
    delivered: 'entregue',
    read: 'lida',
    replied: 'respondida',
    converted: 'convertida',
  };
  return labels[eventType] || eventType;
}

function payloadSummary(payload) {
  if (!payload || typeof payload !== 'object') return '';
  return Object.entries(payload)
    .slice(0, 3)
    .map(([key, value]) => `${key}: ${JSON.stringify(value)}`)
    .join(' | ');
}

watch(() => dealId.value, refreshAll);

onMounted(() => {
  store.dispatch('agents/get');
  refreshAll();
});
</script>

<template>
  <div
    class="deal-details flex h-full flex-col overflow-hidden bg-n-background"
  >
    <header
      class="flex flex-col gap-3 border-b border-n-weak bg-n-slate-1 px-5 py-4 xl:flex-row xl:items-center xl:justify-between"
    >
      <div class="flex min-w-0 items-center gap-3">
        <button
          type="button"
          class="grid size-9 shrink-0 place-content-center rounded-lg border border-n-weak text-n-slate-11 hover:bg-n-slate-3"
          @click="router.push(crmUrl)"
        >
          <span class="i-lucide-arrow-left size-4" />
        </button>
        <div class="min-w-0">
          <div class="flex flex-wrap items-center gap-2">
            <h1 class="m-0 truncate text-xl font-semibold text-n-slate-12">
              {{ deal?.title || 'Ficha do lead' }}
            </h1>
            <span
              v-if="deal?.status"
              class="rounded-full bg-n-slate-3 px-2 py-0.5 text-xs font-semibold text-n-slate-11"
            >
              {{ deal.status }}
            </span>
            <CRMLegalAreaBadge
              v-if="deal?.legal_area"
              :area="deal.legal_area"
            />
          </div>
          <div
            class="mt-1 flex flex-wrap items-center gap-3 text-xs text-n-slate-10"
          >
            <a
              v-if="contactUrl"
              :href="contactUrl"
              class="text-n-brand hover:underline"
            >
              {{ contact?.name || deal?.contact_name || 'Contato' }}
            </a>
            <a
              v-if="conversationUrl"
              :href="conversationUrl"
              class="text-n-brand hover:underline"
            >
              Abrir conversa
            </a>
            <span>Criado em {{ formatDate(deal?.created_at) }}</span>
          </div>
        </div>
      </div>

      <div v-if="deal" class="flex flex-wrap items-center gap-2">
        <button
          type="button"
          class="inline-flex h-9 items-center gap-1.5 rounded-lg px-3 text-sm font-bold"
          :class="scoreTone"
          :disabled="scoreRefreshing"
          @click="recalcScore"
        >
          <span
            :class="
              scoreRefreshing
                ? 'i-lucide-loader-2 animate-spin'
                : 'i-lucide-zap'
            "
            class="size-4"
          />
          {{ deal.score_total || 0 }} pts
        </button>
        <button
          v-if="deal.status === 'open'"
          type="button"
          class="h-9 rounded-lg border border-teal-300 px-3 text-sm font-semibold text-teal-700 hover:bg-teal-50 disabled:opacity-50"
          :disabled="saving"
          @click="markWon"
        >
          Ganho
        </button>
        <button
          v-if="deal.status === 'open'"
          type="button"
          class="h-9 rounded-lg border border-n-weak px-3 text-sm font-semibold text-n-slate-11 hover:bg-n-slate-3 disabled:opacity-50"
          :disabled="saving"
          @click="markBaseClient"
        >
          Cliente Base
        </button>
        <button
          v-if="deal.status === 'open'"
          type="button"
          class="h-9 rounded-lg border border-ruby-300 px-3 text-sm font-semibold text-ruby-700 hover:bg-ruby-50 disabled:opacity-50"
          :disabled="saving"
          @click="discard('invalid')"
        >
          Descartar
        </button>
        <button
          type="button"
          class="h-9 rounded-lg border border-ruby-300 px-3 text-sm font-semibold text-ruby-700 hover:bg-ruby-50 disabled:opacity-50"
          :disabled="saving || deleting"
          @click="deleteDealPermanently"
        >
          <span class="i-lucide-trash-2 mr-1 inline-block size-4 align-[-2px]" />
          {{ deleting ? 'Excluindo...' : 'Excluir' }}
        </button>
        <button
          v-if="deal.status !== 'open'"
          type="button"
          class="h-9 rounded-lg border border-n-weak px-3 text-sm font-semibold text-n-slate-11 hover:bg-n-slate-3 disabled:opacity-50"
          :disabled="saving"
          @click="reopenDeal"
        >
          Reabrir
        </button>
      </div>
    </header>

    <div
      v-if="error"
      class="mx-5 mt-3 rounded-lg border border-ruby-200 bg-ruby-50 p-3 text-sm text-ruby-700 dark:bg-ruby-950/20"
    >
      {{ error }}
      <button type="button" class="ml-2 underline" @click="error = ''">
        Fechar
      </button>
    </div>

    <div
      v-if="loading"
      class="grid flex-1 place-content-center text-sm text-n-slate-10"
    >
      Carregando ficha 360...
    </div>
    <div
      v-else-if="!deal"
      class="grid flex-1 place-content-center text-sm text-n-slate-10"
    >
      Lead não encontrado.
    </div>

    <div v-else class="flex min-h-0 flex-1 flex-col overflow-hidden">
      <section class="crm-record-strip">
        <div class="crm-record-strip__identity">
          <div class="crm-record-avatar">
            {{ primaryContactName.slice(0, 2).toUpperCase() }}
          </div>
          <div class="min-w-0">
            <p class="m-0 text-xs font-semibold uppercase text-n-slate-10">
              Lead / Cliente
            </p>
            <h2 class="m-0 truncate text-lg font-semibold text-n-slate-12">
              {{ primaryContactName }}
            </h2>
            <div class="mt-1 flex flex-wrap gap-2 text-xs text-n-slate-10">
              <span v-if="primaryPhone">{{ primaryPhone }}</span>
              <span v-if="primaryEmail">{{ primaryEmail }}</span>
              <span v-if="!primaryPhone && !primaryEmail">
                Sem telefone ou e-mail registrado
              </span>
            </div>
          </div>
        </div>

        <div class="crm-record-strip__facts">
          <div
            v-for="fact in recordFacts"
            :key="fact.label"
            class="crm-record-fact"
          >
            <span :class="fact.icon" class="size-4 text-n-slate-9" />
            <div class="min-w-0">
              <span class="crm-record-fact__label">{{ fact.label }}</span>
              <strong>{{ fact.value }}</strong>
            </div>
          </div>
        </div>

        <div class="crm-record-strip__actions">
          <a
            v-if="conversationUrl"
            :href="conversationUrl"
            class="crm-secondary-button"
          >
            <span class="i-lucide-message-square size-4" />
            Conversa
          </a>
          <a v-if="contactUrl" :href="contactUrl" class="crm-secondary-button">
            <span class="i-lucide-user-round size-4" />
            Contato
          </a>
          <button
            type="button"
            class="crm-primary-button"
            @click="showNewActivity = true; activeTab = 'activities'"
          >
            <span class="i-lucide-calendar-plus size-4" />
            Nova tarefa
          </button>
        </div>
      </section>

      <section v-if="stages.length" class="crm-stage-path">
        <button
          v-for="(stage, index) in stages"
          :key="stage.id"
          type="button"
          class="crm-stage-path__item"
          :class="{
            'crm-stage-path__item--done': index < currentStageIndex,
            'crm-stage-path__item--active': index === currentStageIndex,
          }"
          :disabled="saving || deal.status !== 'open'"
          @click="moveStage(stage.id)"
        >
          <span class="crm-stage-path__dot">
            <span
              :class="
                index <= currentStageIndex
                  ? 'i-lucide-check size-3'
                  : 'i-lucide-circle size-3'
              "
            />
          </span>
          <span>{{ stage.name }}</span>
        </button>
      </section>

      <section
        class="grid gap-3 border-b border-n-weak p-4 sm:grid-cols-2 xl:grid-cols-4"
      >
        <article
          v-for="item in kpis"
          :key="item.label"
          class="rounded-lg border border-n-weak bg-n-slate-1 p-3"
        >
          <span :class="item.icon" class="mb-2 block size-4 text-n-slate-9" />
          <p class="m-0 text-xs font-medium uppercase text-n-slate-10">
            {{ item.label }}
          </p>
          <strong class="text-xl text-n-slate-12">{{ item.value }}</strong>
        </article>
      </section>

      <nav class="flex gap-1 overflow-x-auto border-b border-n-weak px-4">
        <button
          v-for="tab in tabs"
          :key="tab.id"
          type="button"
          class="inline-flex h-11 shrink-0 items-center gap-2 border-b-2 px-3 text-sm font-medium"
          :class="
            activeTab === tab.id
              ? 'border-n-brand text-n-brand'
              : 'border-transparent text-n-slate-10 hover:text-n-slate-12'
          "
          @click="activeTab = tab.id"
        >
          <span :class="tab.icon" class="size-4" />
          {{ tab.label }}
        </button>
      </nav>

      <main class="min-h-0 flex-1 overflow-y-auto p-4">
        <section
          v-show="activeTab === 'overview'"
          class="grid gap-4 xl:grid-cols-[1fr_22rem]"
        >
          <div class="space-y-4">
            <div class="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
              <label class="crm-field">
                <span>Etapa</span>
                <select
                  :value="deal.crm_pipeline_stage_id"
                  :disabled="saving || deal.status !== 'open'"
                  @change="moveStage(Number($event.target.value))"
                >
                  <option
                    v-for="stage in stages"
                    :key="stage.id"
                    :value="stage.id"
                  >
                    {{ stage.name }}
                  </option>
                </select>
              </label>
              <label class="crm-field">
                <span>Setor jurídico</span>
                <select
                  :value="deal.legal_area || ''"
                  :disabled="saving"
                  @change="updateField('legal_area', $event.target.value)"
                >
                  <option
                    v-for="area in legalAreas"
                    :key="area.value"
                    :value="area.value"
                  >
                    {{ area.label }}
                  </option>
                </select>
              </label>
              <label class="crm-field">
                <span>Urgencia</span>
                <select
                  :value="deal.urgency_level || ''"
                  :disabled="saving"
                  @change="updateField('urgency_level', $event.target.value)"
                >
                  <option value="">Sem urgencia</option>
                  <option value="critica">Crítica</option>
                  <option value="alta">Alta</option>
                  <option value="media">Media</option>
                  <option value="baixa">Baixa</option>
                </select>
              </label>
              <label class="crm-field">
                <span>Status operacional</span>
                <select
                  :value="deal.operational_status || 'active'"
                  :disabled="saving"
                  @change="
                    updateField('operational_status', $event.target.value)
                  "
                >
                  <option
                    v-for="status in operationalStatuses"
                    :key="status.value"
                    :value="status.value"
                  >
                    {{ status.label }}
                  </option>
                </select>
              </label>
              <label class="crm-field">
                <span>Origem</span>
                <select
                  :value="deal.source || ''"
                  :disabled="saving"
                  @change="updateField('source', $event.target.value)"
                >
                  <option
                    v-for="source in sources"
                    :key="source.value"
                    :value="source.value"
                  >
                    {{ source.label }}
                  </option>
                </select>
              </label>
              <label class="crm-field">
                <span>Detalhe da origem</span>
                <input
                  :value="deal.source_detail || ''"
                  :disabled="saving"
                  placeholder="Campanha, anuncio, lista..."
                  @change="updateField('source_detail', $event.target.value)"
                />
              </label>
            </div>

            <div class="grid gap-3 md:grid-cols-2">
              <article class="crm-panel">
                <h2>Resumo do caso</h2>
                <p>{{ deal.summary || 'Nenhum resumo registrado ainda.' }}</p>
              </article>
              <article class="crm-panel">
                <h2>Próxima ação</h2>
                <p>
                  {{
                    deal.next_best_action || 'Nenhuma próxima ação definida.'
                  }}
                </p>
              </article>
            </div>

            <CRMScoreAudit
              v-if="deal.latest_score"
              :score="deal.latest_score"
            />
          </div>

          <aside class="space-y-3">
            <article class="crm-panel">
              <h2>Responsaveis</h2>
              <div class="space-y-3">
                <label class="crm-field">
                  <span>Dono do contato</span>
                  <select
                    v-model="selectedOwnerId"
                    :disabled="ownerUpdating"
                    @change="updateOwner"
                  >
                    <option value="">Sem responsável</option>
                    <option
                      v-for="agent in agents"
                      :key="agent.id"
                      :value="String(agent.id)"
                    >
                      {{ agent.name || agent.email }}
                    </option>
                  </select>
                </label>
                <label class="crm-field">
                  <span>Responder por este atendimento</span>
                  <select
                    v-model="selectedAssigneeId"
                    :disabled="assigneeUpdating"
                    @change="updateAssignee"
                  >
                    <option value="">Sem atendente</option>
                    <option
                      v-for="agent in agents"
                      :key="agent.id"
                      :value="String(agent.id)"
                    >
                      {{ agent.name || agent.email }}
                    </option>
                  </select>
                </label>
                <p class="m-0 text-xs text-n-slate-10">
                  Contato: {{ ownerName }} - Atendimento: {{ assigneeName }}
                </p>
              </div>
            </article>

            <article class="crm-panel">
              <h2>Contato</h2>
              <dl class="crm-dl">
                <div>
                  <dt>Nome</dt>
                  <dd>{{ contact?.name || deal.contact_name || '-' }}</dd>
                </div>
                <div>
                  <dt>Telefone</dt>
                  <dd>
                    {{
                      contact?.phone_number || deal.contact_phone_number || '-'
                    }}
                  </dd>
                </div>
                <div>
                  <dt>E-mail</dt>
                  <dd>{{ contact?.email || deal.contact_email || '-' }}</dd>
                </div>
                <div>
                  <dt>Relacionamento</dt>
                  <dd>{{ contact?.relationship_status || '-' }}</dd>
                </div>
                <div>
                  <dt>Lifecycle</dt>
                  <dd>{{ contact?.lifecycle_stage || '-' }}</dd>
                </div>
              </dl>
            </article>

            <article class="crm-panel">
              <h2>Etiquetas</h2>
              <div class="flex flex-wrap gap-1.5">
                <span
                  v-for="label in combinedLabels"
                  :key="label.raw"
                  class="inline-flex items-center gap-1 rounded-full bg-n-slate-3 px-2 py-1 text-xs text-n-slate-11"
                >
                  <span>{{ label.title }}</span>
                  <span class="text-n-slate-9">- {{ label.source }}</span>
                </span>
                <span
                  v-if="!combinedLabels.length"
                  class="text-sm text-n-slate-10"
                >
                  Sem etiquetas.
                </span>
              </div>
              <p class="mt-3 text-xs text-n-slate-10">
                As etiquetas combinam contato e atendimento para manter Chat,
                CRM e Capitão no mesmo contexto.
              </p>
            </article>
          </aside>
        </section>

        <section v-show="activeTab === 'messages'" class="space-y-3">
          <article
            v-for="message in messages"
            :key="message.id"
            class="rounded-lg border p-3"
            :class="messageClass(message)"
          >
            <div class="mb-2 flex flex-wrap items-center justify-between gap-2">
              <strong class="text-sm text-n-slate-12">{{
                messageTitle(message)
              }}</strong>
              <span class="text-xs text-n-slate-10">{{
                formatDate(message.created_at)
              }}</span>
            </div>
            <p
              class="whitespace-pre-wrap text-sm leading-relaxed text-n-slate-12"
            >
              {{
                message.content_for_llm ||
                message.content ||
                'Mensagem sem texto'
              }}
            </p>
            <div
              v-if="message.attachments?.length"
              class="mt-2 flex flex-wrap gap-2"
            >
              <span
                v-for="attachment in message.attachments"
                :key="attachment.id"
                class="rounded bg-n-alpha-2 px-2 py-1 text-xs text-n-slate-11"
              >
                {{ attachment.file_type }} #{{ attachment.id }}
              </span>
            </div>
          </article>
          <p v-if="!messages.length" class="crm-empty">
            Nenhuma mensagem vinculada.
          </p>
        </section>

        <section
          v-show="activeTab === 'files'"
          class="grid gap-3 md:grid-cols-2 xl:grid-cols-3"
        >
          <article
            v-for="attachment in attachments"
            :key="attachment.id"
            class="rounded-lg border border-n-weak bg-n-slate-1 p-3"
          >
            <div class="mb-2 flex items-center justify-between gap-2">
              <strong class="text-sm capitalize text-n-slate-12">
                {{ attachment.file_type }}
              </strong>
              <span class="text-xs text-n-slate-10">{{
                formatDate(attachment.created_at)
              }}</span>
            </div>
            <p class="min-h-10 text-sm text-n-slate-11">
              {{ fileDescription(attachment) || 'Sem analise registrada.' }}
            </p>
            <div class="mt-2 flex flex-wrap gap-1.5">
              <span
                v-if="
                  attachment.document_guess || attachment.meta?.document_guess
                "
                class="rounded-full bg-n-brand/10 px-2 py-1 text-xs text-n-brand"
              >
                {{
                  attachment.document_guess || attachment.meta?.document_guess
                }}
              </span>
              <span
                v-if="fileStatus(attachment)"
                class="rounded-full bg-n-slate-3 px-2 py-1 text-xs text-n-slate-11"
              >
                {{ fileStatus(attachment) }}
              </span>
            </div>
            <a
              v-if="attachment.data_url || attachment.external_url"
              :href="attachment.data_url || attachment.external_url"
              target="_blank"
              rel="noopener noreferrer"
              class="mt-3 inline-flex text-sm font-medium text-n-brand hover:underline"
            >
              Abrir arquivo
            </a>
          </article>
          <p
            v-if="!attachments.length"
            class="crm-empty md:col-span-2 xl:col-span-3"
          >
            Nenhum arquivo vinculado.
          </p>
        </section>

        <section v-show="activeTab === 'activities'" class="space-y-3">
          <div class="flex items-center justify-between">
            <h2 class="m-0 text-sm font-semibold text-n-slate-12">
              Atividades pendentes: {{ pendingActivities.length }}
            </h2>
            <button
              type="button"
              class="h-9 rounded-lg bg-n-brand px-3 text-sm font-semibold text-white"
              @click="showNewActivity = !showNewActivity"
            >
              Nova tarefa
            </button>
          </div>

          <div v-if="showNewActivity" class="crm-panel space-y-2">
            <div class="grid gap-2 md:grid-cols-3">
              <label class="crm-field">
                <span>Tipo</span>
                <select v-model="newActivity.kind">
                  <option
                    v-for="kind in activityKinds"
                    :key="kind.value"
                    :value="kind.value"
                  >
                    {{ kind.label }}
                  </option>
                </select>
              </label>
              <label class="crm-field">
                <span>Prioridade</span>
                <select v-model="newActivity.priority">
                  <option
                    v-for="priority in priorities"
                    :key="priority.value"
                    :value="priority.value"
                  >
                    {{ priority.label }}
                  </option>
                </select>
              </label>
              <label class="crm-field">
                <span>Prazo</span>
                <input v-model="newActivity.due_at" type="datetime-local" />
              </label>
            </div>
            <label class="crm-field">
              <span>Título</span>
              <input
                v-model="newActivity.title"
                placeholder="Ex: ligar para confirmar documentos"
              />
            </label>
            <label class="crm-field">
              <span>Descrição</span>
              <textarea
                v-model="newActivity.description"
                rows="3"
                placeholder="Contexto para o responsável"
              />
            </label>
            <div class="flex justify-end gap-2">
              <button
                class="crm-secondary-button"
                type="button"
                @click="showNewActivity = false"
              >
                Cancelar
              </button>
              <button
                class="crm-primary-button"
                type="button"
                :disabled="saving || !newActivity.title.trim()"
                @click="createActivity"
              >
                {{ saving ? 'Salvando...' : 'Criar tarefa' }}
              </button>
            </div>
          </div>

          <article
            v-for="activity in activities"
            :key="activity.id"
            class="flex items-start gap-3 rounded-lg border border-n-weak bg-n-slate-1 p-3"
          >
            <span
              class="i-lucide-check-square mt-1 size-4 shrink-0 text-n-slate-9"
            />
            <div class="min-w-0 flex-1">
              <div class="flex flex-wrap items-center gap-2">
                <strong class="text-sm text-n-slate-12">{{
                  activity.title
                }}</strong>
                <span
                  class="rounded-full bg-n-slate-3 px-2 py-0.5 text-xs text-n-slate-11"
                >
                  {{ activity.priority || 'normal' }}
                </span>
              </div>
              <p
                v-if="activity.description"
                class="m-0 mt-1 text-sm text-n-slate-11"
              >
                {{ activity.description }}
              </p>
              <p class="m-0 mt-1 text-xs text-n-slate-10">
                Prazo: {{ formatDate(activity.due_at) }}
              </p>
            </div>
            <button
              v-if="!activity.completed_at"
              type="button"
              class="crm-secondary-button"
              @click="completeActivity(activity)"
            >
              Concluir
            </button>
            <!-- eslint-disable-next-line vue/max-attributes-per-line -->
            <span v-else class="text-sm font-medium text-teal-700"
              >Concluída</span
            >
          </article>
          <p v-if="!activities.length" class="crm-empty">
            Nenhuma atividade registrada.
          </p>
        </section>

        <section v-show="activeTab === 'timeline'" class="space-y-2">
          <article
            v-for="item in unifiedTimeline"
            :key="item.id"
            class="flex gap-3 rounded-lg border border-n-weak bg-n-slate-1 p-3"
          >
            <span class="mt-1 size-2.5 shrink-0 rounded-full bg-n-brand" />
            <div class="min-w-0 flex-1">
              <div class="flex items-center justify-between gap-2">
                <strong class="text-sm text-n-slate-12">{{
                  item.title
                }}</strong>
                <span class="shrink-0 text-xs text-n-slate-10">{{
                  formatDate(item.at)
                }}</span>
              </div>
              <p
                v-if="item.description"
                class="m-0 mt-1 line-clamp-3 text-sm text-n-slate-11"
              >
                {{ item.description }}
              </p>
            </div>
          </article>
          <p v-if="!unifiedTimeline.length" class="crm-empty">
            Histórico ainda vazio.
          </p>
        </section>

        <section v-show="activeTab === 'campaigns'" class="space-y-2">
          <article
            v-for="event in campaignEvents"
            :key="event.id"
            class="rounded-lg border border-n-weak bg-n-slate-1 p-3"
          >
            <div class="flex flex-wrap items-center justify-between gap-2">
              <strong class="text-sm text-n-slate-12">
                {{ event.campaign?.title || 'Campanha' }}
              </strong>
              <span
                class="rounded-full bg-n-slate-3 px-2 py-0.5 text-xs text-n-slate-11"
              >
                {{ campaignEventLabel(event.event_type) }}
              </span>
            </div>
            <p class="m-0 mt-1 text-xs text-n-slate-10">
              {{ formatDate(event.occurred_at) }} -
              {{ event.provider || 'provedor não informado' }}
            </p>
          </article>
          <p v-if="!campaignEvents.length" class="crm-empty">
            Nenhum evento de campanha vinculado.
          </p>
        </section>

        <section
          v-show="activeTab === 'lgpd'"
          class="grid gap-3 md:grid-cols-2"
        >
          <label class="crm-field">
            <span>Base legal</span>
            <select
              :value="deal.lgpd_basis || ''"
              :disabled="saving"
              @change="updateField('lgpd_basis', $event.target.value)"
            >
              <option value="">Selecione</option>
              <option value="consent">Consentimento</option>
              <option value="contract">Contrato</option>
              <option value="legal_obligation">Obrigacao legal</option>
              <option value="legitimate_interest">Interesse legitimo</option>
            </select>
          </label>
          <label class="crm-field">
            <span>Consentimento</span>
            <select
              :value="deal.consent_status || ''"
              :disabled="saving"
              @change="updateField('consent_status', $event.target.value)"
            >
              <option value="">Selecione</option>
              <option value="pending">Pendente</option>
              <option value="granted">Concedido</option>
              <option value="revoked">Revogado</option>
            </select>
          </label>
          <article class="crm-panel">
            <h2>Canal de consentimento</h2>
            <p>{{ deal.consent_channel || 'Não informado' }}</p>
          </article>
          <article class="crm-panel">
            <h2>Retencao de dados</h2>
            <p>{{ formatDate(deal.data_retention_until) }}</p>
          </article>
          <div
            class="rounded-lg border p-3 text-sm md:col-span-2"
            :class="
              deal.lgpd_ready
                ? 'border-teal-200 bg-teal-50 text-teal-700 dark:bg-teal-950/20'
                : 'border-amber-200 bg-amber-50 text-amber-700 dark:bg-amber-950/20'
            "
          >
            {{
              deal.lgpd_ready
                ? 'LGPD completa.'
                : 'LGPD incompleta: revise base legal, consentimento e retencao.'
            }}
          </div>
        </section>
      </main>
    </div>
  </div>
</template>

<style scoped>
.deal-details {
  width: 100%;
  min-width: 0;
}

.deal-details :deep(*) {
  min-width: 0;
}

.crm-record-strip {
  display: grid;
  grid-template-columns: minmax(16rem, 1fr) minmax(18rem, 1.4fr) auto;
  align-items: center;
  gap: 1rem;
  border-bottom: 1px solid rgb(var(--slate-5));
  background: rgb(var(--slate-1));
  padding: 1rem;
}

.crm-record-strip__identity,
.crm-record-strip__actions,
.crm-record-fact {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.crm-record-strip__actions {
  flex-wrap: wrap;
  justify-content: flex-end;
}

.crm-record-strip__facts {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 0.75rem;
}

.crm-record-avatar {
  display: grid;
  width: 3rem;
  height: 3rem;
  flex: none;
  place-content: center;
  border: 1px solid rgb(var(--slate-5));
  border-radius: 0.75rem;
  background: rgb(var(--brand-2));
  color: rgb(var(--brand-11));
  font-size: 0.9rem;
  font-weight: 800;
}

.crm-record-fact {
  border: 1px solid rgb(var(--slate-5));
  border-radius: 0.5rem;
  background: rgb(var(--slate-2));
  padding: 0.65rem;
}

.crm-record-fact__label {
  display: block;
  color: rgb(var(--slate-10));
  font-size: 0.68rem;
  font-weight: 700;
  text-transform: uppercase;
}

.crm-record-fact strong {
  display: block;
  overflow: hidden;
  color: rgb(var(--slate-12));
  font-size: 0.875rem;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.crm-stage-path {
  display: grid;
  grid-auto-columns: minmax(8rem, 1fr);
  grid-auto-flow: column;
  gap: 0.5rem;
  overflow-x: auto;
  border-bottom: 1px solid rgb(var(--slate-5));
  background: rgb(var(--slate-2));
  padding: 0.75rem 1rem;
}

.crm-stage-path__item {
  display: inline-flex;
  align-items: center;
  justify-content: flex-start;
  min-height: 2.5rem;
  border: 1px solid rgb(var(--slate-5));
  border-radius: 0.5rem;
  background: rgb(var(--slate-1));
  color: rgb(var(--slate-11));
  gap: 0.5rem;
  padding: 0 0.65rem;
  text-align: left;
}

.crm-stage-path__item--done {
  border-color: rgb(var(--teal-6));
  color: rgb(var(--teal-11));
}

.crm-stage-path__item--active {
  border-color: rgb(var(--brand-8));
  background: rgb(var(--brand-2));
  color: rgb(var(--brand-11));
  font-weight: 700;
}

.crm-stage-path__dot {
  display: grid;
  width: 1.25rem;
  height: 1.25rem;
  flex: none;
  place-content: center;
  border-radius: 999px;
  background: rgb(var(--slate-3));
}

.crm-field {
  display: grid;
  gap: 0.35rem;
  min-width: 0;
  border: 1px solid rgb(var(--slate-5));
  border-radius: 0.5rem;
  background: rgb(var(--slate-1));
  padding: 0.75rem;
}

.crm-field span {
  color: rgb(var(--slate-10));
  font-size: 0.68rem;
  font-weight: 700;
  text-transform: uppercase;
}

.crm-field input,
.crm-field select,
.crm-field textarea {
  min-width: 0;
  width: 100%;
  border: 1px solid rgb(var(--slate-5));
  border-radius: 0.45rem;
  background: rgb(var(--slate-2));
  color: rgb(var(--slate-12));
  font-size: 0.875rem;
  outline: none;
  padding: 0.5rem 0.625rem;
}

.crm-panel {
  min-width: 0;
  border: 1px solid rgb(var(--slate-5));
  border-radius: 0.5rem;
  background: rgb(var(--slate-1));
  padding: 0.875rem;
}

.crm-panel h2 {
  margin: 0 0 0.45rem;
  color: rgb(var(--slate-12));
  font-size: 0.875rem;
  font-weight: 700;
}

.crm-panel p {
  margin: 0;
  color: rgb(var(--slate-11));
  font-size: 0.875rem;
  line-height: 1.55;
}

.crm-dl {
  display: grid;
  gap: 0.5rem;
}

.crm-dl div {
  display: grid;
  gap: 0.1rem;
}

.crm-dl dt {
  color: rgb(var(--slate-10));
  font-size: 0.7rem;
  font-weight: 700;
  text-transform: uppercase;
}

.crm-dl dd {
  overflow-wrap: anywhere;
  margin: 0;
  color: rgb(var(--slate-12));
  font-size: 0.875rem;
}

.crm-empty {
  border: 1px dashed rgb(var(--slate-5));
  border-radius: 0.5rem;
  background: rgb(var(--slate-1));
  color: rgb(var(--slate-10));
  padding: 1.5rem;
  text-align: center;
}

.crm-primary-button,
.crm-secondary-button {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 0.4rem;
  min-height: 2.25rem;
  border-radius: 0.5rem;
  padding: 0 0.875rem;
  font-size: 0.875rem;
  font-weight: 700;
}

.crm-primary-button {
  background: rgb(var(--brand-9));
  color: white;
}

.crm-secondary-button {
  border: 1px solid rgb(var(--slate-5));
  background: rgb(var(--slate-1));
  color: rgb(var(--slate-11));
}

.crm-primary-button:disabled,
.crm-secondary-button:disabled {
  cursor: not-allowed;
  opacity: 0.55;
}

@media (max-width: 760px) {
  .crm-record-strip {
    grid-template-columns: 1fr;
  }

  .crm-record-strip__facts {
    grid-template-columns: 1fr;
  }

  .crm-record-strip__actions {
    justify-content: stretch;
  }

  .crm-primary-button,
  .crm-secondary-button {
    width: 100%;
  }
}
</style>
