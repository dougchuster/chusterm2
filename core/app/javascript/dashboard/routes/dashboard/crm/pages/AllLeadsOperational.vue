<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';

import CrmAPI from 'dashboard/api/crm';
import CRMDealDrawer from 'dashboard/components/crm/CRMDealDrawer.vue';
import CRMScoreBadge from 'dashboard/components/crm/CRMScoreBadge.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import {
  DsBadge,
  DsButton,
  DsDrawer,
  DsDropdown,
  DsInput,
  DsModal,
  DsPagination,
  DsSelect,
} from 'dashboard/design-system/components';
import { ListPageTemplate } from 'dashboard/design-system/templates';

const PER_PAGE = 50;
const STATUS_OPTIONS = [
  { value: '', label: 'Todos os status' },
  { value: 'open', label: 'Abertos' },
  { value: 'won', label: 'Ganhos' },
  { value: 'lost', label: 'Perdidos' },
  { value: 'archived', label: 'Arquivados' },
];
const SCORE_OPTIONS = [
  { value: '', label: 'Todos os scores' },
  { value: 'hot', label: 'Alta prioridade (80+)', min: 80 },
  { value: 'qualified', label: 'Qualificados (60–79)', min: 60, max: 79 },
  { value: 'medium', label: 'Médio potencial (40–59)', min: 40, max: 59 },
  { value: 'cold', label: 'Baixo potencial (até 39)', max: 39 },
];

const route = useRoute();
const router = useRouter();
const store = useStore();
const agents = useMapGetter('agents/getVerifiedAgents');

const pipelines = ref([]);
const stages = ref([]);
const deals = ref([]);
const activities = ref([]);
const selectedIds = ref([]);
const loading = ref(true);
const refreshing = ref(false);
const saving = ref(false);
const error = ref('');
const page = ref(Number(route.query.page || 1));
const total = ref(0);
const pipelineId = ref(route.query.pipeline_id || '');
const stageId = ref(route.query.stage_id || '');
const status = ref(route.query.status || 'open');
const score = ref(route.query.score || '');
const search = ref(route.query.search || '');
const bulkStageId = ref('');
const drawerDealId = ref(null);
const showDealDrawer = ref(false);
const showCreateDrawer = ref(false);
const discardTarget = ref(null);
const dispositionReason = ref('invalid');

// Os quatro motivos que o backend aceita. O Legacy descartava sempre como
// `no_lead` nesta tela, sem perguntar.
const dispositionOptions = [
  { value: 'invalid', label: 'Inválido' },
  { value: 'spam', label: 'Spam' },
  { value: 'duplicated', label: 'Duplicado' },
  { value: 'no_lead', label: 'Não é lead' },
];

const messageFrom = (exception, fallback) =>
  exception?.response?.data?.error ||
  exception?.response?.data?.message ||
  fallback;

const patchRow = (deal, changes) => {
  const index = deals.value.findIndex(item => item.id === deal.id);
  if (index === -1) return;
  deals.value[index] = { ...deals.value[index], ...changes };
};
const createForm = ref({
  title: '',
  contact_name: '',
  contact_phone_number: '',
  contact_email: '',
  crm_pipeline_stage_id: '',
});

const extractData = response => {
  const payload = response?.data ?? response;
  if (Array.isArray(payload)) return payload;
  return payload?.data ?? [];
};
const extractMeta = response => response?.data?.meta || response?.meta || {};
const option = (value, label) => ({ value, label });
const pipelineOptions = computed(() =>
  pipelines.value.map(item =>
    option(
      String(item.id),
      item.inbox?.name ? `${item.inbox.name} · ${item.name}` : item.name
    )
  )
);
const stageOptions = computed(() => [
  option('', 'Todas as etapas'),
  ...stages.value.map(item => option(String(item.id), item.name)),
]);
const createStageOptions = computed(() =>
  stages.value.map(item => option(String(item.id), item.name))
);
const ownerById = computed(() =>
  Object.fromEntries(
    agents.value.map(agent => [
      String(agent.id),
      agent.name || agent.email || 'Responsável',
    ])
  )
);
const activityByDeal = computed(() => {
  const result = {};
  activities.value.forEach(activity => {
    const key = String(activity.crm_deal_id || '');
    if (!key || result[key]) return;
    result[key] = activity;
  });
  return result;
});
const allSelected = computed(
  () =>
    deals.value.length > 0 &&
    deals.value.every(deal => selectedIds.value.includes(deal.id))
);
const selectedCount = computed(() => selectedIds.value.length);
const selectedPipeline = computed(() =>
  pipelines.value.find(item => String(item.id) === String(pipelineId.value))
);
const hasActiveFilters = computed(
  () =>
    Boolean(search.value) ||
    Boolean(stageId.value) ||
    status.value !== 'open' ||
    Boolean(score.value)
);

const scoreParams = () => {
  const selected = SCORE_OPTIONS.find(item => item.value === score.value);
  return selected
    ? { score_min: selected.min, score_max: selected.max }
    : {};
};
const dealParams = () => ({
  page: page.value,
  per_page: PER_PAGE,
  pipeline_id: pipelineId.value || undefined,
  stage_id: stageId.value || undefined,
  status: status.value || undefined,
  search: search.value.trim() || undefined,
  ...scoreParams(),
});
const syncQuery = () =>
  router.replace({
    query: {
      page: page.value > 1 ? page.value : undefined,
      pipeline_id: pipelineId.value || undefined,
      stage_id: stageId.value || undefined,
      status: status.value || undefined,
      score: score.value || undefined,
      search: search.value.trim() || undefined,
    },
  });

const loadPipelines = async () => {
  pipelines.value = extractData(await CrmAPI.getPipelines());
  if (!pipelineId.value && pipelines.value.length) {
    pipelineId.value = String(
      pipelines.value.find(item => item.is_default || item.isDefault)?.id ||
        pipelines.value[0].id
    );
  }
};
const loadStages = async () => {
  stages.value = pipelineId.value
    ? extractData(await CrmAPI.getPipelineStages(pipelineId.value))
    : [];
};
const loadDeals = async ({ silent = false } = {}) => {
  if (silent) refreshing.value = true;
  else loading.value = true;
  error.value = '';
  try {
    const [dealResponse, activityResponse] = await Promise.all([
      CrmAPI.getDeals(dealParams()),
      CrmAPI.getActivities({ status: 'pending' }),
    ]);
    deals.value = extractData(dealResponse);
    activities.value = extractData(activityResponse);
    const meta = extractMeta(dealResponse);
    total.value = Number(meta.total ?? deals.value.length);
    selectedIds.value = selectedIds.value.filter(id =>
      deals.value.some(deal => deal.id === id)
    );
    await syncQuery();
  } catch (exception) {
    error.value =
      exception?.response?.data?.error ||
      exception?.response?.data?.message ||
      'Não foi possível carregar os leads.';
  } finally {
    loading.value = false;
    refreshing.value = false;
  }
};
const loadAll = async () => {
  try {
    await loadPipelines();
    await loadStages();
    await loadDeals();
  } catch (exception) {
    error.value =
      exception?.response?.data?.error ||
      exception?.response?.data?.message ||
      'Não foi possível carregar o CRM.';
    loading.value = false;
  }
};
const applyFilters = async () => {
  page.value = 1;
  selectedIds.value = [];
  await loadDeals({ silent: true });
};
const clearFilters = async () => {
  search.value = '';
  stageId.value = '';
  status.value = 'open';
  score.value = '';
  await applyFilters();
};
const changePipeline = async () => {
  stageId.value = '';
  page.value = 1;
  selectedIds.value = [];
  await loadStages();
  await loadDeals({ silent: true });
};
const changePage = async nextPage => {
  page.value = nextPage;
  selectedIds.value = [];
  await loadDeals({ silent: true });
};
const toggleAll = event => {
  selectedIds.value = event.target.checked
    ? deals.value.map(deal => deal.id)
    : [];
};
const toggleDeal = (dealId, checked) => {
  selectedIds.value = checked
    ? [...new Set([...selectedIds.value, dealId])]
    : selectedIds.value.filter(id => id !== dealId);
};
const applyBulkMove = async () => {
  if (!selectedIds.value.length || !bulkStageId.value) return;
  saving.value = true;
  error.value = '';
  try {
    await CrmAPI.bulkActionDeals({
      deal_ids: selectedIds.value,
      bulk_action: 'move',
      stage_id: bulkStageId.value,
    });
    selectedIds.value = [];
    bulkStageId.value = '';
    await loadDeals({ silent: true });
  } catch (exception) {
    error.value =
      exception?.response?.data?.error ||
      exception?.response?.data?.message ||
      'Não foi possível mover os leads selecionados.';
  } finally {
    saving.value = false;
  }
};
// Otimismo com rollback (principio 2 do plano): a linha muda na hora, e o erro
// devolve a etapa anterior em vez de deixar a tela mentindo.
const moveToStage = async (deal, nextStageId) => {
  const target = Number(nextStageId);
  if (!deal?.id || !target || target === Number(deal.crm_pipeline_stage_id)) {
    return;
  }

  const previousStageId = deal.crm_pipeline_stage_id;
  patchRow(deal, { crm_pipeline_stage_id: target });
  error.value = '';
  try {
    const response = await CrmAPI.moveDeal(deal.id, target);
    patchRow(deal, response?.data || {});
  } catch (exception) {
    patchRow(deal, { crm_pipeline_stage_id: previousStageId });
    error.value = messageFrom(exception, 'Não foi possível mover o lead.');
  }
};

// Descartar nao e o mesmo que perder: o descartado nunca foi um lead de
// verdade e nao pode entrar na taxa de conversao.
const discard = async () => {
  const deal = discardTarget.value;
  if (!deal?.id) return;

  saving.value = true;
  error.value = '';
  try {
    const response = await CrmAPI.discardDeal(deal.id, {
      reason: dispositionReason.value,
    });
    patchRow(deal, response?.data || {});
    discardTarget.value = null;
  } catch (exception) {
    error.value = messageFrom(exception, 'Não foi possível descartar o lead.');
  } finally {
    saving.value = false;
  }
};

// Regra de produto 10: cliente antigo nao e lead novo.
const markBaseClient = async deal => {
  if (!deal?.id) return;

  saving.value = true;
  error.value = '';
  try {
    const response = await CrmAPI.markDealBaseClient(deal.id);
    patchRow(deal, response?.data || {});
  } catch (exception) {
    error.value = messageFrom(
      exception,
      'Não foi possível marcar como cliente da base.'
    );
  } finally {
    saving.value = false;
  }
};

// O recalculo e assincrono no servidor (RecomputeLeadScoreJob); a lista se
// atualiza sozinha no proximo refresh, sem prender o atendente esperando.
const recomputeScore = async deal => {
  if (!deal?.id) return;

  error.value = '';
  try {
    await CrmAPI.recomputeScore(deal.id);
  } catch (exception) {
    error.value = messageFrom(exception, 'Não foi possível recalcular o score.');
  }
};

const openCreate = () => {
  createForm.value = {
    title: '',
    contact_name: '',
    contact_phone_number: '',
    contact_email: '',
    crm_pipeline_stage_id: String(stages.value[0]?.id || ''),
  };
  showCreateDrawer.value = true;
};
const createLead = async () => {
  if (!createForm.value.title.trim() || !pipelineId.value) return;
  saving.value = true;
  error.value = '';
  try {
    const response = await CrmAPI.createDeal({
      title: createForm.value.title.trim(),
      contact_name: createForm.value.contact_name.trim() || undefined,
      contact_phone_number:
        createForm.value.contact_phone_number.trim() || undefined,
      contact_email: createForm.value.contact_email.trim() || undefined,
      crm_pipeline_id: pipelineId.value,
      inbox_id: selectedPipeline.value?.inbox_id || undefined,
      crm_pipeline_stage_id:
        createForm.value.crm_pipeline_stage_id || stages.value[0]?.id,
      operational_status: 'active',
    });
    showCreateDrawer.value = false;
    const created = response?.data;
    if (created?.id) {
      await router.push({
        name: 'crm_deal_details',
        params: { accountId: route.params.accountId, dealId: created.id },
      });
    } else {
      await loadDeals({ silent: true });
    }
  } catch (exception) {
    error.value =
      exception?.response?.data?.error ||
      exception?.response?.data?.message ||
      'Não foi possível criar o lead.';
  } finally {
    saving.value = false;
  }
};
const openDeal = deal => {
  drawerDealId.value = deal.id;
  showDealDrawer.value = true;
};
const onDealSaved = updated => {
  const index = deals.value.findIndex(item => item.id === updated?.id);
  if (index >= 0) deals.value[index] = { ...deals.value[index], ...updated };
};
const onDealDeleted = dealId => {
  deals.value = deals.value.filter(item => item.id !== dealId);
  total.value = Math.max(0, total.value - 1);
  showDealDrawer.value = false;
};
const dealUrl = deal =>
  `/app/accounts/${route.params.accountId}/crm/deals/${deal.id}`;
const formatDate = value =>
  value
    ? new Intl.DateTimeFormat('pt-BR', {
        day: '2-digit',
        month: 'short',
      }).format(new Date(value))
    : 'Sem prazo';
const statusVariant = value =>
  ({ open: 'info', won: 'success', lost: 'danger', archived: 'neutral' })[
    value
  ] || 'neutral';
const statusLabel = value =>
  STATUS_OPTIONS.find(item => item.value === value)?.label || 'Sem status';

onMounted(async () => {
  store.dispatch('agents/get');
  await loadAll();
});
</script>

<template>
  <ListPageTemplate
    title="Leads"
    :breadcrumbs="[{ label: 'CRM' }, { label: 'Leads' }]"
    :loading="loading"
    :empty="!deals.length"
    empty-title="Nenhum lead encontrado para os filtros atuais."
    empty-action-label="Criar lead"
    @empty-action="openCreate"
  >
    <template #actions>
      <DsButton
        icon="i-lucide-refresh-cw"
        variant="secondary"
        :loading="refreshing"
        aria-label="Atualizar leads"
        @click="loadDeals({ silent: true })"
      />
      <DsButton
        label="Novo lead"
        icon="i-lucide-plus"
        variant="primary"
        @click="openCreate"
      />
    </template>

    <template #toolbar>
      <DsInput
        v-model="search"
        label="Buscar leads"
        hide-label
        placeholder="Buscar por nome, telefone ou assunto"
        class="min-w-64 flex-1"
        @enter="applyFilters"
      >
        <template #prefix>
          <Icon icon="i-lucide-search" class="size-4" />
        </template>
      </DsInput>
      <DsSelect
        v-model="pipelineId"
        label="Pipeline"
        hide-label
        :options="pipelineOptions"
        class="min-w-44"
        @change="changePipeline"
      />
      <DsSelect
        v-model="stageId"
        label="Etapa"
        hide-label
        :options="stageOptions"
        class="min-w-40"
        @change="applyFilters"
      />
      <DsSelect
        v-model="status"
        label="Status"
        hide-label
        :options="STATUS_OPTIONS"
        class="min-w-36"
        @change="applyFilters"
      />
      <DsSelect
        v-model="score"
        label="Score"
        hide-label
        :options="SCORE_OPTIONS"
        class="min-w-44"
        @change="applyFilters"
      />
      <DsButton
        label="Buscar"
        icon="i-lucide-search"
        variant="secondary"
        @click="applyFilters"
      />
      <DsButton
        v-if="hasActiveFilters"
        label="Limpar"
        variant="ghost"
        @click="clearFilters"
      />
    </template>

    <template v-if="selectedCount" #selection>
      <p class="m-0 mr-auto text-ui-body-sm font-medium text-ui-text">
        {{ selectedCount }} lead(s) selecionado(s)
      </p>
      <DsSelect
        v-model="bulkStageId"
        label="Mover selecionados para"
        hide-label
        placeholder="Escolha uma etapa"
        :options="createStageOptions"
        class="min-w-52"
      />
      <DsButton
        label="Mover"
        variant="primary"
        :disabled="!bulkStageId"
        :loading="saving"
        @click="applyBulkMove"
      />
      <DsButton
        label="Cancelar"
        variant="ghost"
        @click="selectedIds = []"
      />
    </template>

    <div
      v-if="error"
      role="alert"
      class="m-3 flex items-start gap-2 rounded-ui-control border border-ui-danger/30 bg-ui-danger-soft p-3 text-ui-body-sm text-ui-danger-foreground"
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

    <table class="w-full min-w-[58rem] border-collapse text-left">
      <thead class="sticky top-0 z-10 bg-ui-sunken">
        <tr class="border-b border-ui-border text-ui-label text-ui-text-muted">
          <th class="w-12 px-3 py-2">
            <input
              type="checkbox"
              :checked="allSelected"
              aria-label="Selecionar todos os leads desta página"
              class="size-4 rounded border-ui-border accent-ui-brand"
              @change="toggleAll"
            />
          </th>
          <th class="px-3 py-2 font-medium">Lead</th>
          <th class="px-3 py-2 font-medium">Etapa</th>
          <th class="px-3 py-2 font-medium">Score</th>
          <th class="hidden px-3 py-2 font-medium lg:table-cell">
            Responsável
          </th>
          <th class="hidden px-3 py-2 font-medium xl:table-cell">
            Próxima ação
          </th>
          <th class="w-28 px-3 py-2 text-right font-medium">Ações</th>
        </tr>
      </thead>
      <tbody class="divide-y divide-ui-border-subtle">
        <tr
          v-for="deal in deals"
          :key="deal.id"
          class="group bg-ui-surface hover:bg-ui-hover"
        >
          <td class="px-3 py-2">
            <input
              type="checkbox"
              :checked="selectedIds.includes(deal.id)"
              :aria-label="`Selecionar ${deal.title || `lead ${deal.id}`}`"
              class="size-4 rounded border-ui-border accent-ui-brand"
              @change="toggleDeal(deal.id, $event.target.checked)"
            />
          </td>
          <td class="max-w-sm px-3 py-2">
            <a
              :href="dealUrl(deal)"
              class="block truncate text-ui-body-sm font-medium text-ui-text hover:text-ui-brand-foreground hover:underline"
            >
              {{ deal.title || `Lead #${deal.id}` }}
            </a>
            <div class="mt-1 flex min-w-0 items-center gap-2">
              <span class="truncate text-ui-caption text-ui-text-muted">
                {{ deal.contact_name || deal.contact_phone_number || 'Sem contato' }}
              </span>
              <DsBadge
                :label="statusLabel(deal.status)"
                :variant="statusVariant(deal.status)"
              />
            </div>
          </td>
          <td class="px-3 py-2 text-ui-body-sm text-ui-text">
            <DsSelect
              :model-value="String(deal.crm_pipeline_stage_id || '')"
              :options="stageOptions.filter(item => item.value)"
              :aria-label="`Etapa de ${deal.title || `lead ${deal.id}`}`"
              size="sm"
              @update:model-value="moveToStage(deal, $event)"
            />
          </td>
          <td class="px-3 py-2">
            <CRMScoreBadge
              :score="Number(deal.score_total || 0)"
              :classification="deal.score_classification || ''"
              size="sm"
              show-label
            />
          </td>
          <td
            class="hidden max-w-48 truncate px-3 py-2 text-ui-body-sm text-ui-text-muted lg:table-cell"
          >
            {{ ownerById[String(deal.owner_id)] || 'Sem responsável' }}
          </td>
          <td class="hidden px-3 py-2 xl:table-cell">
            <div class="text-ui-body-sm text-ui-text">
              {{
                activityByDeal[String(deal.id)]?.title ||
                activityByDeal[String(deal.id)]?.content ||
                'Nenhuma tarefa'
              }}
            </div>
            <div class="text-ui-caption text-ui-text-muted">
              {{ formatDate(activityByDeal[String(deal.id)]?.due_at) }}
            </div>
          </td>
          <td class="px-3 py-2">
            <div class="flex justify-end gap-1">
              <DsButton
                icon="i-lucide-pencil"
                variant="ghost"
                size="sm"
                :aria-label="`Editar ${deal.title || `lead ${deal.id}`}`"
                @click="openDeal(deal)"
              />
              <DsButton
                icon="i-lucide-arrow-up-right"
                variant="ghost"
                size="sm"
                :aria-label="`Abrir ficha de ${deal.title || `lead ${deal.id}`}`"
                @click="router.push(dealUrl(deal))"
              />
              <DsDropdown :aria-label="`Mais ações para ${deal.title || `lead ${deal.id}`}`">
                <a
                  :href="deal.contact_id ? `/app/accounts/${route.params.accountId}/contacts/${deal.contact_id}` : undefined"
                  role="menuitem"
                  :aria-disabled="!deal.contact_id || undefined"
                  class="flex min-h-10 items-center gap-2 rounded-ui-control px-3 text-ui-body-sm text-ui-text hover:bg-ui-hover aria-disabled:pointer-events-none aria-disabled:opacity-50"
                >
                  <Icon icon="i-lucide-user-round" class="size-4" />
                  Abrir contato
                </a>
                <button
                  type="button"
                  role="menuitem"
                  class="flex min-h-10 w-full items-center gap-2 rounded-ui-control px-3 text-left text-ui-body-sm text-ui-text hover:bg-ui-hover"
                  @click="recomputeScore(deal)"
                >
                  <Icon icon="i-lucide-refresh-cw" class="size-4" />
                  Recalcular score
                </button>
                <button
                  type="button"
                  role="menuitem"
                  class="flex min-h-10 w-full items-center gap-2 rounded-ui-control px-3 text-left text-ui-body-sm text-ui-text hover:bg-ui-hover"
                  @click="markBaseClient(deal)"
                >
                  <Icon icon="i-lucide-contact-round" class="size-4" />
                  Marcar como cliente da base
                </button>
                <button
                  v-if="deal.status === 'open'"
                  type="button"
                  role="menuitem"
                  class="flex min-h-10 w-full items-center gap-2 rounded-ui-control px-3 text-left text-ui-body-sm text-ui-danger hover:bg-ui-hover"
                  @click="discardTarget = deal"
                >
                  <Icon icon="i-lucide-ban" class="size-4" />
                  Descartar lead
                </button>
              </DsDropdown>
            </div>
          </td>
        </tr>
      </tbody>
    </table>

    <template #pagination>
      <DsPagination
        :current-page="page"
        :total-items="total"
        :items-per-page="PER_PAGE"
        :loading="refreshing"
        @update:current-page="changePage"
      />
    </template>
  </ListPageTemplate>

  <DsDrawer
    id="create-lead-drawer"
    :open="showCreateDrawer"
    title="Novo lead"
    description="Cadastre o assunto e o contato principal."
    :loading="saving"
    @close="showCreateDrawer = false"
  >
    <form class="grid gap-4" @submit.prevent="createLead">
      <DsInput
        v-model="createForm.title"
        label="Assunto"
        placeholder="Ex.: Aposentadoria por invalidez"
        required
      />
      <DsInput
        v-model="createForm.contact_name"
        label="Nome do contato"
        autocomplete="name"
      />
      <DsInput
        v-model="createForm.contact_phone_number"
        label="Telefone"
        type="tel"
        autocomplete="tel"
      />
      <DsInput
        v-model="createForm.contact_email"
        label="E-mail"
        type="email"
        autocomplete="email"
      />
      <DsSelect
        v-model="createForm.crm_pipeline_stage_id"
        label="Etapa inicial"
        :options="createStageOptions"
      />
    </form>
    <template #footer>
      <div class="flex justify-end gap-2">
        <DsButton
          label="Cancelar"
          variant="ghost"
          :disabled="saving"
          @click="showCreateDrawer = false"
        />
        <DsButton
          label="Criar lead"
          variant="primary"
          :loading="saving"
          :disabled="!createForm.title.trim()"
          @click="createLead"
        />
      </div>
    </template>
  </DsDrawer>

  <DsModal
    id="discard-lead-modal"
    :open="!!discardTarget"
    title="Descartar lead"
    description="Descartar tira o lead do funil sem contá-lo como perda comercial. Use quando nunca houve um lead de verdade."
    confirm-label="Descartar"
    dangerous
    :loading="saving"
    @close="discardTarget = null"
    @confirm="discard"
  >
    <DsSelect
      v-model="dispositionReason"
      label="Motivo do descarte"
      :options="dispositionOptions"
    />
  </DsModal>

  <CRMDealDrawer
    v-if="drawerDealId"
    v-model:show="showDealDrawer"
    :deal-id="drawerDealId"
    @saved="onDealSaved"
    @deal-deleted="onDealDeleted"
  />
</template>
