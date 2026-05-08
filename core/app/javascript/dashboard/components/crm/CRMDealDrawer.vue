<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text, vue/prefer-separate-static-class, vue/html-closing-bracket-newline -->
<script setup>
import { reactive, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import CrmAPI from '../../api/crm';
import CRMActivityList from './CRMActivityList.vue';
import CRMLegalAreaBadge from './CRMLegalAreaBadge.vue';
import CRMNextActionBox from './CRMNextActionBox.vue';
import CRMScoreAudit from './CRMScoreAudit.vue';
import CRMScoreBadge from './CRMScoreBadge.vue';
import CRMTimeline from './CRMTimeline.vue';

const props = defineProps({
  dealId: { type: [Number, String], required: true },
});

const emit = defineEmits(['saved', 'dealDeleted']);
const show = defineModel('show', { type: Boolean, default: false });
const router = useRouter();
const route = useRoute();

const loading = ref(false);
const saving = ref(false);
const deleting = ref(false);
const error = ref('');
const deal = ref(null);
const activeTab = ref('dados');
const valueEstimate = ref('');

const form = reactive({
  title: '',
  legal_area: '',
  case_type: '',
  urgency_level: '',
  operational_status: 'active',
  source: '',
  source_detail: '',
  value_estimate_cents: 0,
  probability_pct: 0,
  conflict_check_status: '',
  documents_status: '',
  lgpd_basis: '',
  consent_status: '',
  consent_channel: '',
  consent_collected_at: '',
  data_retention_until: '',
  summary: '',
  next_best_action: '',
});

const areaOptions = [
  ['trabalhista', 'Trabalhista'],
  ['previdenciario', 'Previdenciário'],
  ['civel', 'Cível'],
  ['familia', 'Família'],
  ['consumidor', 'Consumidor'],
  ['empresarial', 'Empresarial'],
  ['tributario', 'Tributário'],
  ['imobiliario', 'Imobiliário'],
  ['criminal', 'Criminal'],
  ['outro', 'Outro'],
];

const urgencyOptions = [
  ['baixa', '🟢 Baixa'],
  ['media', '🟡 Média'],
  ['alta', '🟠 Alta'],
  ['critica', '🔴 Crítica'],
];

const operationalStatusOptions = [
  ['active', 'Lead ativo'],
  ['returning_client', 'Retorno de Cliente'],
  ['base_client', 'Cliente Base'],
  ['converted_client', 'Cliente Convertido'],
  ['invalid', 'Inválido'],
  ['spam', 'Spam'],
  ['duplicated', 'Duplicado'],
  ['no_lead', 'Não é lead'],
  ['archived', 'Arquivado'],
];

const sourceOptions = [
  ['', 'Sem origem'],
  ['whatsapp', 'WhatsApp'],
  ['jusbrasil', 'JusBrasil'],
  ['instagram', 'Instagram'],
  ['facebook', 'Facebook'],
  ['google_ads', 'Google Ads'],
  ['indicacao', 'Indicação'],
  ['site', 'Site'],
  ['lista_importada', 'Lista importada'],
  ['cliente_base', 'Cliente Base'],
  ['outros', 'Outros'],
];

const documentOptions = [
  ['pending', 'Pendente'],
  ['solicitado', 'Solicitado'],
  ['parcial', 'Parcial'],
  ['completo', 'Completo'],
];

const conflictOptions = [
  ['pending', 'Pendente'],
  ['ok', 'Sem conflito'],
  ['review', 'Em revisão'],
  ['blocked', 'Bloqueado'],
];

const consentOptions = [
  ['pending', 'Pendente'],
  ['granted', 'Autorizado'],
  ['denied', 'Negado'],
];

const lgpdOptions = [
  ['consentimento', 'Consentimento'],
  ['execucao_de_contrato', 'Execucao de contrato'],
  ['procedimentos_preliminares', 'Procedimentos preliminares'],
  ['exercicio_regular_de_direitos', 'Exercicio regular de direitos'],
  ['obrigacao_legal', 'Obrigacao legal'],
  ['legitimo_interesse', 'Legitimo interesse'],
];

const consentChannelOptions = [
  ['chat', 'Chat'],
  ['whatsapp', 'WhatsApp'],
  ['email', 'Email'],
  ['telefone', 'Telefone'],
  ['presencial', 'Presencial'],
  ['contrato', 'Contrato'],
];

const onScheduleAction = () => {
  // Move foco para a aba de atividades para criar tarefa
  activeTab.value = 'atividades';
};

function toDateInput(value) {
  if (!value) return '';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '';
  return date.toISOString().slice(0, 10);
}

function toDateTimeInput(value) {
  if (!value) return '';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '';
  date.setMinutes(date.getMinutes() - date.getTimezoneOffset());
  return date.toISOString().slice(0, 16);
}

function assignForm(payload) {
  deal.value = payload;
  Object.assign(form, {
    title: payload.title || '',
    legal_area: payload.legal_area || '',
    case_type: payload.case_type || '',
    urgency_level: payload.urgency_level || '',
    operational_status: payload.operational_status || 'active',
    source: payload.source || '',
    source_detail: payload.source_detail || '',
    value_estimate_cents: Number(payload.value_estimate_cents || 0),
    probability_pct: Number(payload.probability_pct || 0),
    conflict_check_status: payload.conflict_check_status || 'pending',
    documents_status: payload.documents_status || 'pending',
    lgpd_basis: payload.lgpd_basis || '',
    consent_status: payload.consent_status || 'pending',
    consent_channel: payload.consent_channel || '',
    consent_collected_at: toDateTimeInput(payload.consent_collected_at),
    data_retention_until: toDateInput(payload.data_retention_until),
    summary: payload.summary || '',
    next_best_action: payload.next_best_action || '',
  });
  valueEstimate.value = (Number(payload.value_estimate_cents || 0) / 100)
    .toFixed(2)
    .replace('.', ',');
}

async function loadDeal() {
  if (!props.dealId || !show.value) return;
  loading.value = true;
  error.value = '';
  try {
    const { data } = await CrmAPI.getDeal(props.dealId);
    assignForm(data);
  } catch {
    error.value = 'Não foi possível carregar a oportunidade.';
  } finally {
    loading.value = false;
  }
}

function centsFromInput(value) {
  const normalized = String(value || '0')
    .replace(/\./g, '')
    .replace(',', '.');
  const amount = Number(normalized);
  if (Number.isNaN(amount)) return 0;
  return Math.max(0, Math.round(amount * 100));
}

async function saveDeal() {
  if (!props.dealId) return;
  saving.value = true;
  error.value = '';
  try {
    const payload = {
      ...form,
      value_estimate_cents: centsFromInput(valueEstimate.value),
      probability_pct: Number(form.probability_pct || 0),
    };
    const { data } = await CrmAPI.updateDeal(props.dealId, payload);
    assignForm(data);
    emit('saved', data);
  } catch {
    error.value = 'Não foi possível salvar as alterações.';
  } finally {
    saving.value = false;
  }
}

async function deleteDeal() {
  if (!props.dealId || !deal.value) return;
  // eslint-disable-next-line no-alert
  const confirmed = window.confirm(
    `Tem certeza que deseja excluir "${deal.value.title || 'este atendimento'}"?\nEssa ação não pode ser desfeita.`
  );
  if (!confirmed) return;
  deleting.value = true;
  error.value = '';
  try {
    await CrmAPI.deleteDeal(props.dealId);
    emit('dealDeleted', props.dealId);
    closeDrawer();
  } catch {
    error.value = 'Não foi possível deletar a oportunidade.';
  } finally {
    deleting.value = false;
  }
}

function closeDrawer() {
  show.value = false;
}

function goToDetails() {
  if (!props.dealId) return;
  router.push({
    name: 'crm_deal_details',
    params: { accountId: route.params.accountId, dealId: props.dealId },
  });
  show.value = false;
}

watch(
  () => [props.dealId, show.value],
  () => loadDeal(),
  { immediate: true }
);
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
  <woot-modal
    v-model:show="show"
    modal-type="right-aligned"
    :on-close="closeDrawer"
  >
    <div
      class="flex h-full min-h-screen flex-col bg-n-background text-n-slate-12"
    >
      <header class="border-b border-n-weak px-5 py-4">
        <div class="flex items-start justify-between gap-4">
          <div class="min-w-0">
            <p class="m-0 text-xs font-semibold uppercase text-n-slate-10">
              Oportunidade jurídica
            </p>
            <h3 class="m-0 mt-1 truncate text-lg font-semibold">
              {{ deal?.title || 'Carregando...' }}
            </h3>
          </div>
          <div class="flex items-center gap-2">
            <button
              v-if="deal"
              type="button"
              class="inline-flex h-8 items-center gap-1.5 rounded-lg border border-n-weak px-3 text-xs font-medium text-n-slate-12 hover:bg-n-slate-2"
              @click="goToDetails"
            >
              <span
                class="i-lucide-external-link"
                style="width: 0.875rem; height: 0.875rem"
              />
              Detalhes
            </button>
            <CRMScoreBadge
              v-if="deal"
              :score="deal.score_total || 0"
              :classification="deal.score_classification"
              size="md"
            />
            <button
              v-if="deal"
              type="button"
              class="inline-flex h-8 items-center gap-1.5 rounded-lg border border-red-300 px-3 text-xs font-medium text-red-600 hover:bg-red-50 disabled:opacity-60"
              :disabled="deleting"
              @click="deleteDeal"
            >
              <span
                class="i-lucide-trash-2"
                style="width: 0.875rem; height: 0.875rem"
              />
              {{ deleting ? 'Deletando...' : 'Deletar' }}
            </button>
          </div>
        </div>

        <div class="mt-3 flex flex-wrap items-center gap-2 text-xs">
          <CRMLegalAreaBadge v-if="deal?.legal_area" :area="deal.legal_area" />
          <span class="rounded-full bg-n-slate-2 px-2 py-1 text-n-slate-11">
            {{ deal?.stage?.name || 'Sem etapa' }}
          </span>
          <span class="rounded-full bg-n-slate-2 px-2 py-1 text-n-slate-11">
            {{ deal?.status || 'open' }}
          </span>
        </div>
      </header>

      <div class="flex border-b border-n-weak px-5">
        <button
          v-for="tab in [
            ['dados', 'Dados'],
            ['score', 'Score'],
            ['atividades', 'Atividades'],
            ['historico', 'Histórico'],
          ]"
          :key="tab[0]"
          type="button"
          class="border-b-2 px-3 py-3 text-sm font-medium"
          :class="[
            activeTab === tab[0]
              ? 'border-n-brand text-n-brand'
              : 'border-transparent text-n-slate-11 hover:text-n-slate-12',
          ]"
          @click="activeTab = tab[0]"
        >
          {{ tab[1] }}
        </button>
      </div>

      <!-- Próxima ação em destaque -->
      <div v-if="deal?.next_best_action" class="px-5 pt-3">
        <CRMNextActionBox
          :action="deal.next_best_action"
          :urgency-level="deal.urgency_level"
          @schedule="onScheduleAction"
        />
      </div>

      <main class="min-h-0 flex-1 overflow-y-auto px-5 py-4">
        <div v-if="loading" class="text-sm text-n-slate-11">Carregando...</div>
        <div
          v-else-if="error"
          class="mb-3 rounded-lg bg-red-50 p-3 text-sm text-red-600"
        >
          {{ error }}
        </div>

        <form
          v-if="activeTab === 'dados' && !loading"
          class="space-y-4"
          @submit.prevent="saveDeal"
        >
          <label class="block">
            <span class="mb-1 block text-xs font-medium text-n-slate-11"
              >Título</span
            >
            <input
              v-model="form.title"
              class="h-10 w-full rounded-lg border border-n-weak bg-n-slate-1 px-3 text-sm outline-none focus:border-n-brand"
              type="text"
              required
            />
          </label>

          <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <label class="block">
              <span class="mb-1 block text-xs font-medium text-n-slate-11"
                >Setor jurídico</span
              >
              <select
                v-model="form.legal_area"
                class="h-10 w-full rounded-lg border border-n-weak bg-n-slate-1 px-3 text-sm outline-none focus:border-n-brand"
              >
                <option value="">Não informado</option>
                <option
                  v-for="[value, label] in areaOptions"
                  :key="value"
                  :value="value"
                >
                  {{ label }}
                </option>
              </select>
            </label>

            <label class="block">
              <span class="mb-1 block text-xs font-medium text-n-slate-11"
                >Urgencia</span
              >
              <select
                v-model="form.urgency_level"
                class="h-10 w-full rounded-lg border border-n-weak bg-n-slate-1 px-3 text-sm outline-none focus:border-n-brand"
              >
                <option value="">Não informado</option>
                <option
                  v-for="[value, label] in urgencyOptions"
                  :key="value"
                  :value="value"
                >
                  {{ label }}
                </option>
              </select>
            </label>
          </div>

          <div class="grid grid-cols-1 gap-3 sm:grid-cols-3">
            <label class="block">
              <span class="mb-1 block text-xs font-medium text-n-slate-11"
                >Status CRM</span
              >
              <select
                v-model="form.operational_status"
                class="h-10 w-full rounded-lg border border-n-weak bg-n-slate-1 px-3 text-sm outline-none focus:border-n-brand"
              >
                <option
                  v-for="[value, label] in operationalStatusOptions"
                  :key="value"
                  :value="value"
                >
                  {{ label }}
                </option>
              </select>
            </label>

            <label class="block">
              <span class="mb-1 block text-xs font-medium text-n-slate-11"
                >Origem do lead</span
              >
              <select
                v-model="form.source"
                class="h-10 w-full rounded-lg border border-n-weak bg-n-slate-1 px-3 text-sm outline-none focus:border-n-brand"
              >
                <option
                  v-for="[value, label] in sourceOptions"
                  :key="value"
                  :value="value"
                >
                  {{ label }}
                </option>
              </select>
            </label>

            <label class="block">
              <span class="mb-1 block text-xs font-medium text-n-slate-11"
                >Detalhe da origem</span
              >
              <input
                v-model="form.source_detail"
                class="h-10 w-full rounded-lg border border-n-weak bg-n-slate-1 px-3 text-sm outline-none focus:border-n-brand"
                placeholder="Campanha, anúncio, planilha"
                type="text"
              />
            </label>
          </div>

          <div class="grid grid-cols-1 gap-3 sm:grid-cols-3">
            <label class="block">
              <span class="mb-1 block text-xs font-medium text-n-slate-11"
                >Canal do consentimento</span
              >
              <select
                v-model="form.consent_channel"
                class="h-10 w-full rounded-lg border border-n-weak bg-n-slate-1 px-3 text-sm outline-none focus:border-n-brand"
              >
                <option value="">Não informado</option>
                <option
                  v-for="[value, label] in consentChannelOptions"
                  :key="value"
                  :value="value"
                >
                  {{ label }}
                </option>
              </select>
            </label>

            <label class="block">
              <span class="mb-1 block text-xs font-medium text-n-slate-11"
                >Consentimento em</span
              >
              <input
                v-model="form.consent_collected_at"
                class="h-10 w-full rounded-lg border border-n-weak bg-n-slate-1 px-3 text-sm outline-none focus:border-n-brand"
                type="datetime-local"
              />
            </label>

            <label class="block">
              <span class="mb-1 block text-xs font-medium text-n-slate-11"
                >Retenção até</span
              >
              <input
                v-model="form.data_retention_until"
                class="h-10 w-full rounded-lg border border-n-weak bg-n-slate-1 px-3 text-sm outline-none focus:border-n-brand"
                type="date"
              />
            </label>
          </div>

          <label class="block">
            <span class="mb-1 block text-xs font-medium text-n-slate-11"
              >Tipo de caso</span
            >
            <input
              v-model="form.case_type"
              class="h-10 w-full rounded-lg border border-n-weak bg-n-slate-1 px-3 text-sm outline-none focus:border-n-brand"
              type="text"
            />
          </label>

          <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <label class="block">
              <span class="mb-1 block text-xs font-medium text-n-slate-11"
                >Valor estimado</span
              >
              <input
                v-model="valueEstimate"
                class="h-10 w-full rounded-lg border border-n-weak bg-n-slate-1 px-3 text-sm outline-none focus:border-n-brand"
                inputmode="decimal"
                type="text"
              />
            </label>

            <label class="block">
              <span class="mb-1 block text-xs font-medium text-n-slate-11"
                >Probabilidade</span
              >
              <input
                v-model="form.probability_pct"
                class="h-10 w-full rounded-lg border border-n-weak bg-n-slate-1 px-3 text-sm outline-none focus:border-n-brand"
                max="100"
                min="0"
                type="number"
              />
            </label>
          </div>

          <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <label class="block">
              <span class="mb-1 block text-xs font-medium text-n-slate-11"
                >Documentos</span
              >
              <select
                v-model="form.documents_status"
                class="h-10 w-full rounded-lg border border-n-weak bg-n-slate-1 px-3 text-sm outline-none focus:border-n-brand"
              >
                <option
                  v-for="[value, label] in documentOptions"
                  :key="value"
                  :value="value"
                >
                  {{ label }}
                </option>
              </select>
            </label>

            <label class="block">
              <span class="mb-1 block text-xs font-medium text-n-slate-11"
                >Conflito</span
              >
              <select
                v-model="form.conflict_check_status"
                class="h-10 w-full rounded-lg border border-n-weak bg-n-slate-1 px-3 text-sm outline-none focus:border-n-brand"
              >
                <option
                  v-for="[value, label] in conflictOptions"
                  :key="value"
                  :value="value"
                >
                  {{ label }}
                </option>
              </select>
            </label>
          </div>

          <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <label class="block">
              <span class="mb-1 block text-xs font-medium text-n-slate-11"
                >Base LGPD</span
              >
              <select
                v-model="form.lgpd_basis"
                class="h-10 w-full rounded-lg border border-n-weak bg-n-slate-1 px-3 text-sm outline-none focus:border-n-brand"
              >
                <option value="">Não informado</option>
                <option
                  v-for="[value, label] in lgpdOptions"
                  :key="value"
                  :value="value"
                >
                  {{ label }}
                </option>
              </select>
            </label>

            <label class="block">
              <span class="mb-1 block text-xs font-medium text-n-slate-11"
                >Consentimento</span
              >
              <select
                v-model="form.consent_status"
                class="h-10 w-full rounded-lg border border-n-weak bg-n-slate-1 px-3 text-sm outline-none focus:border-n-brand"
              >
                <option
                  v-for="[value, label] in consentOptions"
                  :key="value"
                  :value="value"
                >
                  {{ label }}
                </option>
              </select>
            </label>
          </div>

          <label class="block">
            <span class="mb-1 block text-xs font-medium text-n-slate-11"
              >Resumo</span
            >
            <textarea
              v-model="form.summary"
              class="min-h-24 w-full rounded-lg border border-n-weak bg-n-slate-1 px-3 py-2 text-sm outline-none focus:border-n-brand"
            />
          </label>

          <label class="block">
            <span class="mb-1 block text-xs font-medium text-n-slate-11"
              >Próxima melhor ação</span
            >
            <textarea
              v-model="form.next_best_action"
              class="min-h-20 w-full rounded-lg border border-n-weak bg-n-slate-1 px-3 py-2 text-sm outline-none focus:border-n-brand"
            />
          </label>

          <footer
            class="sticky bottom-0 -mx-5 border-t border-n-weak bg-n-background px-5 py-3"
          >
            <button
              type="submit"
              class="inline-flex h-10 w-full items-center justify-center rounded-lg bg-n-brand px-4 text-sm font-semibold text-white hover:brightness-110 disabled:opacity-60"
              :disabled="saving"
            >
              {{ saving ? 'Salvando...' : 'Salvar oportunidade' }}
            </button>
          </footer>
        </form>

        <CRMScoreAudit
          v-else-if="activeTab === 'score' && deal"
          :score="deal.latest_score"
        />
        <CRMActivityList
          v-else-if="activeTab === 'atividades' && deal"
          :deal-id="deal.id"
        />
        <CRMTimeline
          v-else-if="activeTab === 'historico' && deal"
          :deal-id="deal.id"
        />
      </main>
    </div>
  </woot-modal>
</template>
