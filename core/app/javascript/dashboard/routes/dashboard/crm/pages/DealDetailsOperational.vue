<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';

import CrmAPI from 'dashboard/api/crm';
import CRMDealDrawer from 'dashboard/components/crm/CRMDealDrawer.vue';
import CRMScoreBadge from 'dashboard/components/crm/CRMScoreBadge.vue';
import CRMDealAiInsightsCard from 'dashboard/components/crm/CRMDealAiInsightsCard.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import {
  DsBadge,
  DsButton,
  DsCard,
  DsDrawer,
  DsDropdown,
  DsInput,
  DsModal,
  DsSelect,
  DsTabs,
} from 'dashboard/design-system/components';
import { RecordPageTemplate } from 'dashboard/design-system/templates';
import { crmConversationUrl } from 'dashboard/helper/conversationIdentifier';

const route = useRoute();
const router = useRouter();
const store = useStore();
const agents = useMapGetter('agents/getVerifiedAgents');
const dealId = computed(() => Number(route.params.dealId));
const accountId = computed(() => Number(route.params.accountId));

const deal = ref(null);
const stages = ref([]);
const lossReasons = ref([]);
const auditEvents = ref([]);
const loading = ref(true);
const refreshing = ref(false);
const saving = ref(false);
const error = ref('');
const activeTab = ref('activities');
const showEditDrawer = ref(false);
const showActivityDrawer = ref(false);
const showLossModal = ref(false);
const showDiscardModal = ref(false);
const dispositionReason = ref('invalid');

// Os quatro motivos que o backend aceita (`normalized_disposition_reason` no
// DealsController). O Legacy oferecia so `invalid` aqui, `no_lead` na lista e
// `spam` no board — tres superficies, tres motivos fixos diferentes, sem que o
// atendente pudesse escolher. Portar a capacidade e deixar escolher.
const dispositionOptions = [
  { value: 'invalid', label: 'Inválido' },
  { value: 'spam', label: 'Spam' },
  { value: 'duplicated', label: 'Duplicado' },
  { value: 'no_lead', label: 'Não é lead' },
];
const lossReasonId = ref('');
const lossNote = ref('');
const newActivity = ref({
  kind: 'follow_up',
  title: '',
  description: '',
  priority: 'normal',
  due_at: '',
});

const tabs = computed(() => [
  {
    value: 'activities',
    label: 'Atividades',
    icon: 'i-lucide-list-checks',
    count: activities.value.length,
  },
  {
    value: 'messages',
    label: 'Mensagens',
    icon: 'i-lucide-message-square',
    count: messages.value.length,
  },
  {
    value: 'files',
    label: 'Arquivos',
    icon: 'i-lucide-paperclip',
    count: attachments.value.length,
  },
  {
    value: 'history',
    label: 'Histórico',
    icon: 'i-lucide-history',
    count: auditEvents.value.length,
  },
]);
const activityKinds = [
  { value: 'follow_up', label: 'Follow-up' },
  { value: 'ligacao', label: 'Ligação' },
  { value: 'reuniao', label: 'Reunião' },
  { value: 'solicitacao_documentos', label: 'Solicitar documentos' },
  { value: 'analise_documental', label: 'Análise documental' },
  { value: 'envio_proposta', label: 'Enviar proposta' },
  { value: 'envio_contrato', label: 'Enviar contrato' },
  { value: 'retorno_cliente', label: 'Retorno ao cliente' },
];
const priorities = [
  { value: 'baixa', label: 'Baixa' },
  { value: 'normal', label: 'Normal' },
  { value: 'alta', label: 'Alta' },
  { value: 'critica', label: 'Crítica' },
];
const extractData = response => {
  const payload = response?.data ?? response;
  if (Array.isArray(payload)) return payload;
  return payload?.data ?? [];
};
const contact = computed(() => deal.value?.contact || {});
const activities = computed(() => deal.value?.activities || []);
const messages = computed(() => deal.value?.messages || []);
const attachments = computed(() => deal.value?.attachments || []);
const stageOptions = computed(() =>
  stages.value.map(stage => ({
    value: String(stage.id),
    label: stage.name,
  }))
);
const ownerOptions = computed(() => [
  { value: '', label: 'Sem responsável' },
  ...agents.value.map(agent => ({
    value: String(agent.id),
    label: agent.name || agent.email || 'Responsável',
  })),
]);
const lossReasonOptions = computed(() =>
  lossReasons.value.map(reason => ({
    value: String(reason.id),
    label: reason.name,
  }))
);
const currentStage = computed(
  () =>
    stages.value.find(
      stage => String(stage.id) === String(deal.value?.crm_pipeline_stage_id)
    )?.name ||
    deal.value?.stage?.name ||
    'Sem etapa'
);
const ownerName = computed(
  () =>
    agents.value.find(
      agent => String(agent.id) === String(deal.value?.owner_id)
    )?.name || 'Sem responsável'
);
const contactName = computed(
  () =>
    contact.value.name ||
    deal.value?.contact_name ||
    deal.value?.title ||
    'Contato sem nome'
);
const contactPhone = computed(
  () => contact.value.phone_number || deal.value?.contact_phone_number || ''
);
const contactEmail = computed(
  () => contact.value.email || deal.value?.contact_email || ''
);
const contactUrl = computed(() =>
  deal.value?.contact_id
    ? `/app/accounts/${accountId.value}/contacts/${deal.value.contact_id}`
    : ''
);
const conversationUrl = computed(() =>
  crmConversationUrl({ accountId: accountId.value, record: deal.value })
);
const statusLabel = computed(
  () =>
    ({
      open: 'Em aberto',
      won: 'Ganho',
      lost: 'Perdido',
      archived: 'Arquivado',
    })[deal.value?.status] || 'Sem status'
);
const statusVariant = computed(
  () =>
    ({
      open: 'info',
      won: 'success',
      lost: 'danger',
      archived: 'neutral',
    })[deal.value?.status] || 'neutral'
);
const operationalStatusLabel = computed(
  () =>
    ({
      active: 'Lead ativo',
      returning_client: 'Retorno de cliente',
      base_client: 'Cliente da base',
      converted_client: 'Cliente convertido',
      invalid: 'Inválido',
      spam: 'Spam',
      duplicated: 'Duplicado',
      no_lead: 'Não é lead',
      archived: 'Arquivado',
    })[deal.value?.operational_status] ||
    deal.value?.operational_status ||
    'Lead ativo'
);
const pendingActivities = computed(() =>
  activities.value.filter(activity => !activity.completed_at)
);
const nextActivity = computed(
  () =>
    [...pendingActivities.value].sort(
      (first, second) =>
        new Date(first.due_at || 8640000000000000) -
        new Date(second.due_at || 8640000000000000)
    )[0]
);
const formatDate = (value, includeTime = false) => {
  if (!value) return 'Não informado';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return 'Não informado';
  return new Intl.DateTimeFormat('pt-BR', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    ...(includeTime ? { hour: '2-digit', minute: '2-digit' } : {}),
  }).format(date);
};
const formatMoney = cents =>
  new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
  }).format(Number(cents || 0) / 100);
const fileUrl = attachment =>
  attachment.data_url ||
  attachment.file_url ||
  attachment.external_url ||
  attachment.url ||
  '';
const activityLabel = kind =>
  activityKinds.find(item => item.value === kind)?.label || kind || 'Atividade';
const auditLabel = event =>
  event.description ||
  event.action_label ||
  String(event.action || event.event_type || 'Registro atualizado').replace(
    /_/g,
    ' '
  );

const loadStages = async () => {
  if (!deal.value?.crm_pipeline_id) {
    stages.value = [];
    return;
  }
  stages.value = extractData(
    await CrmAPI.getPipelineStages(deal.value.crm_pipeline_id)
  );
};
const loadDeal = async () => {
  const response = await CrmAPI.getDeal(dealId.value);
  deal.value = response.data;
  await loadStages();
};
const loadAudit = async () => {
  try {
    const response = await CrmAPI.getAuditEvents({
      target_type: 'CrmDeal',
      target_id: dealId.value,
    });
    auditEvents.value = extractData(response);
  } catch {
    auditEvents.value = [];
  }
};
const loadLossReasons = async () => {
  try {
    lossReasons.value = extractData(await CrmAPI.getLossReasons());
  } catch {
    lossReasons.value = [];
  }
};
const loadAll = async ({ silent = false } = {}) => {
  if (silent) refreshing.value = true;
  else loading.value = true;
  error.value = '';
  try {
    await Promise.all([loadDeal(), loadAudit(), loadLossReasons()]);
  } catch (exception) {
    error.value =
      exception?.response?.data?.message ||
      exception?.response?.data?.error ||
      'Não foi possível carregar a ficha do negócio.';
  } finally {
    loading.value = false;
    refreshing.value = false;
  }
};
const moveStage = async stageId => {
  if (!stageId) return;
  saving.value = true;
  try {
    const response = await CrmAPI.moveDeal(dealId.value, stageId);
    deal.value = { ...deal.value, ...response.data };
  } catch (exception) {
    error.value =
      exception?.response?.data?.message ||
      'Não foi possível alterar a etapa.';
  } finally {
    saving.value = false;
  }
};
const updateOwner = async ownerId => {
  saving.value = true;
  try {
    const response = await CrmAPI.updateDeal(dealId.value, {
      owner_id: ownerId || null,
    });
    deal.value = { ...deal.value, ...response.data };
  } catch (exception) {
    error.value =
      exception?.response?.data?.message ||
      'Não foi possível alterar o responsável.';
  } finally {
    saving.value = false;
  }
};
const recalculateScore = async () => {
  saving.value = true;
  try {
    await CrmAPI.recomputeScore(dealId.value);
    await loadDeal();
  } catch (exception) {
    error.value =
      exception?.response?.data?.message ||
      'Não foi possível recalcular o score.';
  } finally {
    saving.value = false;
  }
};
const markWon = async () => {
  saving.value = true;
  try {
    const response = await CrmAPI.markDealWon(dealId.value);
    deal.value = { ...deal.value, ...response.data };
    await loadAudit();
  } catch (exception) {
    error.value =
      exception?.response?.data?.message ||
      'Não foi possível marcar o negócio como ganho.';
  } finally {
    saving.value = false;
  }
};
const markLost = async () => {
  if (!lossReasonId.value) return;
  saving.value = true;
  try {
    const response = await CrmAPI.markDealLost(
      dealId.value,
      lossReasonId.value,
      lossNote.value
    );
    deal.value = { ...deal.value, ...response.data };
    showLossModal.value = false;
    await loadAudit();
  } catch (exception) {
    error.value =
      exception?.response?.data?.message ||
      'Não foi possível marcar o negócio como perdido.';
  } finally {
    saving.value = false;
  }
};
const reopen = async () => {
  saving.value = true;
  try {
    const response = await CrmAPI.reopenDeal(dealId.value);
    deal.value = { ...deal.value, ...response.data };
    await loadAudit();
  } catch (exception) {
    error.value =
      exception?.response?.data?.message ||
      'Não foi possível reabrir o negócio.';
  } finally {
    saving.value = false;
  }
};
// Descartar nao e o mesmo que perder: o negocio perdido teve disputa comercial
// e entra no funil de conversao; o descartado nunca foi um lead de verdade.
// Misturar os dois envenena a taxa de ganho do relatorio.
const discard = async () => {
  saving.value = true;
  error.value = '';
  try {
    const response = await CrmAPI.discardDeal(dealId.value, {
      reason: dispositionReason.value,
    });
    deal.value = { ...deal.value, ...response.data };
    showDiscardModal.value = false;
  } catch (exception) {
    error.value =
      exception?.response?.data?.message ||
      exception?.response?.data?.error ||
      'Não foi possível descartar o negócio.';
  } finally {
    saving.value = false;
  }
};

const markBaseClient = async () => {
  saving.value = true;
  try {
    const response = await CrmAPI.markDealBaseClient(dealId.value);
    deal.value = { ...deal.value, ...response.data };
  } catch (exception) {
    error.value =
      exception?.response?.data?.message ||
      'Não foi possível marcar como cliente da base.';
  } finally {
    saving.value = false;
  }
};
const createActivity = async () => {
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
    showActivityDrawer.value = false;
    await loadDeal();
  } catch (exception) {
    error.value =
      exception?.response?.data?.message ||
      'Não foi possível criar a atividade.';
  } finally {
    saving.value = false;
  }
};
const completeActivity = async activity => {
  saving.value = true;
  try {
    await CrmAPI.completeActivity(activity.id, 'Concluída pela ficha do CRM');
    await loadDeal();
  } catch (exception) {
    error.value =
      exception?.response?.data?.message ||
      'Não foi possível concluir a atividade.';
  } finally {
    saving.value = false;
  }
};
const onDealSaved = updated => {
  deal.value = { ...deal.value, ...updated };
  loadStages();
};
const onDealDeleted = () =>
  router.push(`/app/accounts/${accountId.value}/crm`);

onMounted(async () => {
  store.dispatch('agents/get');
  await loadAll();
});
</script>

<template>
  <RecordPageTemplate
    :title="deal?.title || 'Ficha do negócio'"
    :breadcrumbs="[
      { label: 'CRM' },
      { label: 'Pipeline' },
      { label: deal?.title || `Negócio #${dealId}` },
    ]"
    :loading="loading"
    :empty="!deal"
    empty-title="Este negócio não está disponível."
    empty-action-label="Voltar ao pipeline"
    @empty-action="router.push(`/app/accounts/${accountId}/crm`)"
  >
    <template #actions>
      <DsButton
        icon="i-lucide-refresh-cw"
        variant="secondary"
        :loading="refreshing"
        aria-label="Atualizar ficha"
        @click="loadAll({ silent: true })"
      />
      <DsButton
        v-if="conversationUrl"
        label="Abrir conversa"
        icon="i-lucide-message-circle"
        variant="secondary"
        @click="router.push(conversationUrl)"
      />
      <DsButton
        label="Editar"
        icon="i-lucide-pencil"
        variant="primary"
        @click="showEditDrawer = true"
      />
      <DsDropdown aria-label="Mais ações do negócio">
        <button
          v-if="deal?.status === 'open'"
          type="button"
          role="menuitem"
          class="flex min-h-10 w-full items-center gap-2 rounded-ui-control px-3 text-left text-ui-body-sm text-ui-text hover:bg-ui-hover"
          @click="markWon"
        >
          <Icon icon="i-lucide-circle-check" class="size-4 text-ui-success" />
          Marcar como ganho
        </button>
        <button
          v-if="deal?.status === 'open'"
          type="button"
          role="menuitem"
          class="flex min-h-10 w-full items-center gap-2 rounded-ui-control px-3 text-left text-ui-body-sm text-ui-text hover:bg-ui-hover"
          @click="showLossModal = true"
        >
          <Icon icon="i-lucide-circle-x" class="size-4 text-ui-danger" />
          Marcar como perdido
        </button>
        <button
          v-if="deal?.status !== 'open'"
          type="button"
          role="menuitem"
          class="flex min-h-10 w-full items-center gap-2 rounded-ui-control px-3 text-left text-ui-body-sm text-ui-text hover:bg-ui-hover"
          @click="reopen"
        >
          <Icon icon="i-lucide-rotate-ccw" class="size-4" />
          Reabrir negócio
        </button>
        <button
          type="button"
          role="menuitem"
          class="flex min-h-10 w-full items-center gap-2 rounded-ui-control px-3 text-left text-ui-body-sm text-ui-text hover:bg-ui-hover"
          @click="markBaseClient"
        >
          <Icon icon="i-lucide-contact-round" class="size-4" />
          Marcar como cliente da base
        </button>
        <button
          v-if="deal?.status === 'open'"
          type="button"
          role="menuitem"
          class="flex min-h-10 w-full items-center gap-2 rounded-ui-control px-3 text-left text-ui-body-sm text-ui-danger hover:bg-ui-hover"
          @click="showDiscardModal = true"
        >
          <Icon icon="i-lucide-ban" class="size-4" />
          Descartar negócio
        </button>
      </DsDropdown>
    </template>

    <template #summary>
      <div
        v-if="error"
        role="alert"
        class="mb-4 flex items-start gap-2 rounded-ui-control border border-ui-danger/30 bg-ui-danger-soft p-3 text-ui-body-sm text-ui-danger-foreground"
      >
        <Icon icon="i-lucide-circle-alert" class="mt-0.5 size-4 shrink-0" />
        <span class="flex-1">{{ error }}</span>
        <DsButton
          icon="i-lucide-x"
          variant="ghost"
          size="sm"
          aria-label="Fechar aviso"
          @click="error = ''"
        />
      </div>
      <DsCard padding="md">
        <div class="flex flex-wrap items-start gap-4">
          <div class="min-w-56 flex-1">
            <div class="flex flex-wrap items-center gap-2">
              <DsBadge :label="statusLabel" :variant="statusVariant" />
              <DsBadge
                :label="operationalStatusLabel"
                variant="neutral"
              />
            </div>
            <p class="mb-0 mt-3 text-ui-body-sm text-ui-text-muted">
              {{ contactName }}
              <span v-if="contactPhone"> · {{ contactPhone }}</span>
            </p>
          </div>
          <div class="flex flex-wrap gap-6">
            <div>
              <span class="block text-ui-caption text-ui-text-muted">Score</span>
              <div class="mt-1 flex items-center gap-2">
                <CRMScoreBadge
                  :score="Number(deal?.score_total || 0)"
                  :classification="deal?.score_classification || ''"
                  show-label
                  size="sm"
                />
                <DsButton
                  icon="i-lucide-sparkles"
                  variant="ghost"
                  size="sm"
                  :loading="saving"
                  aria-label="Recalcular score"
                  @click="recalculateScore"
                />
              </div>
            </div>
            <div>
              <span class="block text-ui-caption text-ui-text-muted">
                Valor estimado
              </span>
              <strong class="mt-1 block text-ui-body font-semibold">
                {{ formatMoney(deal?.value_estimate_cents) }}
              </strong>
            </div>
            <div>
              <span class="block text-ui-caption text-ui-text-muted">
                Próxima ação
              </span>
              <strong class="mt-1 block text-ui-body font-semibold">
                {{ nextActivity?.title || 'Não definida' }}
              </strong>
              <span class="text-ui-caption text-ui-text-muted">
                {{ formatDate(nextActivity?.due_at, true) }}
              </span>
            </div>
          </div>
        </div>
      </DsCard>
    </template>

    <DsCard padding="none" class="overflow-hidden">
      <div class="border-b border-ui-border-subtle p-3">
        <DsTabs
          v-model="activeTab"
          :tabs="tabs"
          label="Conteúdo da ficha"
        />
      </div>

      <div v-if="activeTab === 'activities'" class="divide-y divide-ui-border-subtle">
        <div class="flex items-center justify-between gap-3 p-4">
          <div>
            <h2 class="m-0 text-ui-body font-semibold">Atividades</h2>
            <p class="mb-0 mt-1 text-ui-caption text-ui-text-muted">
              {{ pendingActivities.length }} pendente(s)
            </p>
          </div>
          <DsButton
            label="Nova atividade"
            icon="i-lucide-plus"
            variant="secondary"
            size="sm"
            @click="showActivityDrawer = true"
          />
        </div>
        <div
          v-if="!activities.length"
          class="p-8 text-center text-ui-body-sm text-ui-text-muted"
        >
          Nenhuma atividade registrada.
        </div>
        <article
          v-for="activity in activities"
          :key="activity.id"
          class="flex items-start gap-3 p-4"
        >
          <button
            type="button"
            :disabled="Boolean(activity.completed_at) || saving"
            :aria-label="
              activity.completed_at
                ? `${activity.title} concluída`
                : `Concluir ${activity.title}`
            "
            class="mt-0.5 flex size-8 shrink-0 items-center justify-center rounded-ui-control border border-ui-border text-ui-text-muted hover:bg-ui-hover disabled:opacity-60"
            @click="completeActivity(activity)"
          >
            <Icon
              :icon="
                activity.completed_at
                  ? 'i-lucide-circle-check'
                  : 'i-lucide-circle'
              "
              class="size-4"
            />
          </button>
          <div class="min-w-0 flex-1">
            <h3
              class="m-0 text-ui-body-sm font-medium"
              :class="{ 'line-through text-ui-text-muted': activity.completed_at }"
            >
              {{ activity.title }}
            </h3>
            <p
              v-if="activity.description"
              class="mb-0 mt-1 text-ui-body-sm text-ui-text-muted"
            >
              {{ activity.description }}
            </p>
            <div class="mt-2 flex flex-wrap gap-2 text-ui-caption text-ui-text-muted">
              <span>{{ activityLabel(activity.kind) }}</span>
              <span>·</span>
              <span>{{ formatDate(activity.due_at, true) }}</span>
            </div>
          </div>
          <DsBadge
            :label="activity.priority || 'normal'"
            :variant="activity.priority === 'critica' ? 'danger' : 'neutral'"
          />
        </article>
      </div>

      <div v-else-if="activeTab === 'messages'" class="divide-y divide-ui-border-subtle">
        <div
          v-if="!messages.length"
          class="p-8 text-center text-ui-body-sm text-ui-text-muted"
        >
          Nenhuma mensagem vinculada.
        </div>
        <article
          v-for="message in messages"
          :key="message.id"
          class="flex gap-3 p-4"
        >
          <span
            class="flex size-8 shrink-0 items-center justify-center rounded-full bg-ui-sunken text-ui-text-muted"
          >
            <Icon
              :icon="
                message.message_type === 1
                  ? 'i-lucide-arrow-up-right'
                  : 'i-lucide-arrow-down-left'
              "
              class="size-4"
            />
          </span>
          <div class="min-w-0 flex-1">
            <div class="flex flex-wrap items-center justify-between gap-2">
              <strong class="text-ui-body-sm">
                {{ message.sender?.name || (message.message_type === 1 ? 'Equipe' : contactName) }}
              </strong>
              <span class="text-ui-caption text-ui-text-muted">
                {{ formatDate(message.created_at, true) }}
              </span>
            </div>
            <p class="mb-0 mt-1 whitespace-pre-wrap text-ui-body-sm text-ui-text">
              {{ message.content || 'Mensagem sem texto' }}
            </p>
          </div>
        </article>
      </div>

      <div v-else-if="activeTab === 'files'" class="grid gap-3 p-4 sm:grid-cols-2">
        <p
          v-if="!attachments.length"
          class="col-span-full m-0 p-4 text-center text-ui-body-sm text-ui-text-muted"
        >
          Nenhum arquivo vinculado.
        </p>
        <a
          v-for="attachment in attachments"
          :key="attachment.id"
          :href="fileUrl(attachment)"
          target="_blank"
          rel="noopener noreferrer"
          class="flex min-w-0 items-center gap-3 rounded-ui-control border border-ui-border p-3 text-ui-text hover:bg-ui-hover"
        >
          <Icon icon="i-lucide-file-text" class="size-5 shrink-0" />
          <span class="min-w-0 flex-1">
            <strong class="block truncate text-ui-body-sm">
              {{ attachment.file_name || attachment.filename || `Arquivo ${attachment.id}` }}
            </strong>
            <span class="text-ui-caption text-ui-text-muted">
              {{ attachment.file_type || attachment.content_type || 'Documento' }}
            </span>
          </span>
          <Icon icon="i-lucide-arrow-up-right" class="size-4 shrink-0" />
        </a>
      </div>

      <div v-else class="divide-y divide-ui-border-subtle">
        <p
          v-if="!auditEvents.length"
          class="m-0 p-8 text-center text-ui-body-sm text-ui-text-muted"
        >
          Nenhuma alteração registrada.
        </p>
        <article
          v-for="event in auditEvents"
          :key="event.id"
          class="flex gap-3 p-4"
        >
          <span
            class="mt-1 size-2 shrink-0 rounded-full bg-ui-brand"
            aria-hidden="true"
          />
          <div class="min-w-0 flex-1">
            <p class="m-0 text-ui-body-sm text-ui-text">
              {{ auditLabel(event) }}
            </p>
            <p class="mb-0 mt-1 text-ui-caption text-ui-text-muted">
              {{ event.user?.name || event.actor_name || 'Sistema' }}
              · {{ formatDate(event.created_at, true) }}
            </p>
          </div>
        </article>
      </div>
    </DsCard>

    <template #context>
      <div class="grid gap-4">
        <CRMDealAiInsightsCard
          v-if="deal"
          :deal="deal"
          @recompute="onDealSaved"
          @deal-updated="onDealSaved"
        />

        <DsCard padding="md">
          <h2 class="m-0 text-ui-body font-semibold">Controle do negócio</h2>
          <div class="mt-4 grid gap-4">
            <DsSelect
              :model-value="String(deal?.crm_pipeline_stage_id || '')"
              label="Etapa"
              :options="stageOptions"
              :disabled="saving"
              @change="moveStage($event.target.value)"
            />
            <DsSelect
              :model-value="String(deal?.owner_id || '')"
              label="Responsável"
              :options="ownerOptions"
              :disabled="saving"
              @change="updateOwner($event.target.value)"
            />
          </div>
          <dl class="mb-0 mt-4 grid gap-3 border-t border-ui-border-subtle pt-4">
            <div class="flex items-start justify-between gap-3">
              <dt class="text-ui-caption text-ui-text-muted">Pipeline</dt>
              <dd class="m-0 text-right text-ui-body-sm">
                {{ deal?.pipeline?.name || 'Não informado' }}
              </dd>
            </div>
            <div class="flex items-start justify-between gap-3">
              <dt class="text-ui-caption text-ui-text-muted">Etapa atual</dt>
              <dd class="m-0 text-right text-ui-body-sm">{{ currentStage }}</dd>
            </div>
            <div class="flex items-start justify-between gap-3">
              <dt class="text-ui-caption text-ui-text-muted">Responsável</dt>
              <dd class="m-0 text-right text-ui-body-sm">{{ ownerName }}</dd>
            </div>
            <div class="flex items-start justify-between gap-3">
              <dt class="text-ui-caption text-ui-text-muted">Origem</dt>
              <dd class="m-0 text-right text-ui-body-sm">
                {{ deal?.source || 'Não informada' }}
              </dd>
            </div>
            <div class="flex items-start justify-between gap-3">
              <dt class="text-ui-caption text-ui-text-muted">Área jurídica</dt>
              <dd class="m-0 text-right text-ui-body-sm">
                {{ deal?.legal_area || 'Não informada' }}
              </dd>
            </div>
          </dl>
        </DsCard>

        <DsCard padding="md">
          <h2 class="m-0 text-ui-body font-semibold">Contato</h2>
          <div class="mt-4">
            <strong class="block text-ui-body-sm">{{ contactName }}</strong>
            <a
              v-if="contactPhone"
              :href="`tel:${contactPhone}`"
              class="mt-2 block text-ui-body-sm text-ui-brand-foreground hover:underline"
            >
              {{ contactPhone }}
            </a>
            <a
              v-if="contactEmail"
              :href="`mailto:${contactEmail}`"
              class="mt-1 block truncate text-ui-body-sm text-ui-brand-foreground hover:underline"
            >
              {{ contactEmail }}
            </a>
          </div>
          <DsButton
            v-if="contactUrl"
            label="Abrir perfil"
            icon="i-lucide-user-round"
            variant="secondary"
            class="mt-4 w-full"
            @click="router.push(contactUrl)"
          />
        </DsCard>
      </div>
    </template>
  </RecordPageTemplate>

  <DsDrawer
    id="new-activity-drawer"
    :open="showActivityDrawer"
    title="Nova atividade"
    description="Defina a próxima ação para este negócio."
    :loading="saving"
    @close="showActivityDrawer = false"
  >
    <form class="grid gap-4" @submit.prevent="createActivity">
      <DsInput
        v-model="newActivity.title"
        label="Título"
        placeholder="Ex.: Retornar com análise dos documentos"
        required
      />
      <DsSelect
        v-model="newActivity.kind"
        label="Tipo"
        :options="activityKinds"
      />
      <DsSelect
        v-model="newActivity.priority"
        label="Prioridade"
        :options="priorities"
      />
      <DsInput
        v-model="newActivity.due_at"
        label="Prazo"
        type="datetime-local"
      />
      <label class="grid gap-1 text-ui-label font-medium text-ui-text">
        Descrição
        <textarea
          v-model="newActivity.description"
          rows="4"
          class="min-h-24 resize-y rounded-ui-control border border-ui-border bg-ui-surface p-3 text-ui-body text-ui-text outline-none focus:border-ui-border-focus focus:ring-2 focus:ring-ui-border-focus/20"
        />
      </label>
    </form>
    <template #footer>
      <div class="flex justify-end gap-2">
        <DsButton
          label="Cancelar"
          variant="ghost"
          :disabled="saving"
          @click="showActivityDrawer = false"
        />
        <DsButton
          label="Criar atividade"
          variant="primary"
          :loading="saving"
          :disabled="!newActivity.title.trim()"
          @click="createActivity"
        />
      </div>
    </template>
  </DsDrawer>

  <DsModal
    id="mark-lost-modal"
    :open="showLossModal"
    title="Marcar como perdido"
    description="Registre o motivo para manter o histórico comercial confiável."
    confirm-label="Marcar como perdido"
    dangerous
    :loading="saving"
    :disabled="!lossReasonId"
    @close="showLossModal = false"
    @confirm="markLost"
  >
    <div class="grid gap-4">
      <DsSelect
        v-model="lossReasonId"
        label="Motivo da perda"
        placeholder="Escolha um motivo"
        :options="lossReasonOptions"
      />
      <label class="grid gap-1 text-ui-label font-medium text-ui-text">
        Observação
        <textarea
          v-model="lossNote"
          rows="3"
          class="min-h-20 resize-y rounded-ui-control border border-ui-border bg-ui-surface p-3 text-ui-body text-ui-text outline-none focus:border-ui-border-focus focus:ring-2 focus:ring-ui-border-focus/20"
        />
      </label>
    </div>
  </DsModal>

  <DsModal
    id="discard-deal-modal"
    :open="showDiscardModal"
    title="Descartar negócio"
    description="Descartar tira o negócio do funil sem contá-lo como perda comercial. Use quando nunca houve um lead de verdade."
    confirm-label="Descartar"
    dangerous
    :loading="saving"
    @close="showDiscardModal = false"
    @confirm="discard"
  >
    <DsSelect
      v-model="dispositionReason"
      label="Motivo do descarte"
      :options="dispositionOptions"
    />
  </DsModal>

  <CRMDealDrawer
    v-if="deal"
    v-model:show="showEditDrawer"
    :deal-id="dealId"
    :loss-reasons="lossReasons"
    @saved="onDealSaved"
    @deal-deleted="onDealDeleted"
  />
</template>
