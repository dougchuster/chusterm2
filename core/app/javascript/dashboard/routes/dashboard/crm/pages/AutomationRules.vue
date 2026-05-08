<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text, no-alert, no-restricted-globals -->
<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import CrmAPI from 'dashboard/api/crm';

const rules = ref([]);
const pipelines = ref([]);
const loading = ref(true);
const saving = ref(false);
const error = ref('');
const showModal = ref(false);
const editingId = ref(null);

const filters = reactive({
  search: '',
  status: '',
  stage_id: '',
});

const ACTION_KINDS = [
  { value: 'ligacao', label: 'Ligação' },
  { value: 'solicitacao_documentos', label: 'Solicitação de documentos' },
  { value: 'follow_up', label: 'Follow-up' },
  { value: 'reuniao', label: 'Reunião' },
  { value: 'revisao_juridica', label: 'Revisão jurídica' },
  { value: 'analise_documental', label: 'Análise documental' },
  { value: 'retorno_cliente', label: 'Retorno ao cliente' },
  { value: 'envio_proposta', label: 'Envio de proposta' },
  { value: 'envio_contrato', label: 'Envio de contrato' },
  { value: 'arquivamento', label: 'Arquivamento' },
];

const PRIORITIES = [
  { value: 'baixa', label: 'Baixa' },
  { value: 'normal', label: 'Normal' },
  { value: 'alta', label: 'Alta' },
  { value: 'critica', label: 'Crítica' },
];

const CONDITION_FIELDS = [
  { value: 'legal_area', label: 'Setor jurídico' },
  { value: 'case_type', label: 'Tipo de caso' },
  { value: 'urgency_level', label: 'Urgencia' },
  { value: 'score_total', label: 'Score' },
  { value: 'relationship_status', label: 'Lead/Cliente' },
  { value: 'lifecycle_stage', label: 'Etapa do contato' },
  { value: 'has_phone', label: 'Tem telefone' },
  { value: 'campaign_opt_out', label: 'Opt-out de campanha' },
];

const CONDITION_OPERATORS = [
  { value: 'eq', label: 'igual a' },
  { value: 'not_eq', label: 'diferente de' },
  { value: 'present', label: 'preenchido' },
  { value: 'blank', label: 'vazio' },
  { value: 'gt', label: 'maior que' },
  { value: 'gte', label: 'maior ou igual' },
  { value: 'lt', label: 'menor que' },
  { value: 'lte', label: 'menor ou igual' },
];

const form = reactive({
  name: '',
  crm_pipeline_stage_id: '',
  action_config: {
    kind: 'follow_up',
    title: '',
    description: '',
    priority: 'normal',
    due_in_hours: 24,
    conditions: [],
  },
});

const extractData = response => {
  const payload = response?.data ?? response;
  if (Array.isArray(payload)) return payload;
  return payload?.data ?? [];
};

const allStages = computed(() =>
  pipelines.value.flatMap(pipeline =>
    (pipeline.stages || []).map(stage => ({
      id: stage.id,
      name: stage.name,
      pipelineName: pipeline.name,
    }))
  )
);

const stageMap = computed(() => {
  const map = {};
  allStages.value.forEach(stage => {
    map[stage.id] = `${stage.pipelineName} / ${stage.name}`;
  });
  return map;
});

const normalized = value =>
  String(value || '')
    .toLowerCase()
    .trim();

const filteredRules = computed(() => {
  const search = normalized(filters.search);
  return rules.value.filter(rule => {
    const stageLabel = stageMap.value[rule.crm_pipeline_stage_id] || '';
    const matchesSearch =
      !search ||
      [
        rule.name,
        rule.action_config?.title,
        rule.action_config?.description,
        stageLabel,
      ]
        .map(normalized)
        .some(value => value.includes(search));
    const matchesStatus =
      !filters.status ||
      (filters.status === 'active' ? rule.is_active : !rule.is_active);
    const matchesStage =
      !filters.stage_id ||
      String(rule.crm_pipeline_stage_id) === String(filters.stage_id);
    return matchesSearch && matchesStatus && matchesStage;
  });
});

const summary = computed(() => {
  const active = rules.value.filter(rule => rule.is_active).length;
  const paused = rules.value.length - active;
  const fast = rules.value.filter(
    rule => Number(rule.action_config?.due_in_hours || 0) <= 12
  ).length;
  const critical = rules.value.filter(
    rule => rule.action_config?.priority === 'critica'
  ).length;

  return [
    { label: 'Regras criadas', value: rules.value.length },
    { label: 'Ativas', value: active },
    { label: 'Pausadas', value: paused },
    { label: 'Até 12h', value: fast },
    { label: 'Críticas', value: critical },
  ];
});

const isFormValid = computed(
  () =>
    form.name.trim() &&
    form.crm_pipeline_stage_id &&
    form.action_config.title.trim()
);

function labelFor(list, value) {
  return list.find(opt => opt.value === value)?.label || value;
}

function priorityClass(priority) {
  if (priority === 'critica') return 'danger';
  if (priority === 'alta') return 'warn';
  if (priority === 'baixa') return 'muted';
  return '';
}

function conditionLabel(condition) {
  const field = labelFor(CONDITION_FIELDS, condition.field);
  const operator = labelFor(CONDITION_OPERATORS, condition.operator);
  if (['present', 'blank'].includes(condition.operator)) {
    return `${field} ${operator}`;
  }
  return `${field} ${operator} ${condition.value || '-'}`;
}

function cleanConditions(conditions) {
  return (conditions || [])
    .filter(condition => condition.field && condition.operator)
    .map(condition => ({
      field: condition.field,
      operator: condition.operator,
      value: ['present', 'blank'].includes(condition.operator)
        ? null
        : condition.value,
    }));
}

function resetForm() {
  editingId.value = null;
  form.name = '';
  form.crm_pipeline_stage_id = '';
  form.action_config.kind = 'follow_up';
  form.action_config.title = '';
  form.action_config.description = '';
  form.action_config.priority = 'normal';
  form.action_config.due_in_hours = 24;
  form.action_config.conditions = [];
}

function openNew() {
  resetForm();
  showModal.value = true;
}

function openEdit(rule) {
  editingId.value = rule.id;
  form.name = rule.name || '';
  form.crm_pipeline_stage_id = rule.crm_pipeline_stage_id || '';
  form.action_config.kind = rule.action_config?.kind || 'follow_up';
  form.action_config.title = rule.action_config?.title || '';
  form.action_config.description = rule.action_config?.description || '';
  form.action_config.priority = rule.action_config?.priority || 'normal';
  form.action_config.due_in_hours = rule.action_config?.due_in_hours ?? 24;
  form.action_config.conditions = cleanConditions(
    rule.action_config?.conditions || []
  );
  showModal.value = true;
}

function closeModal() {
  showModal.value = false;
  resetForm();
}

function clearFilters() {
  filters.search = '';
  filters.status = '';
  filters.stage_id = '';
}

function addCondition() {
  form.action_config.conditions.push({
    field: 'legal_area',
    operator: 'eq',
    value: '',
  });
}

function removeCondition(index) {
  form.action_config.conditions.splice(index, 1);
}

async function loadData() {
  loading.value = true;
  error.value = '';
  try {
    const [rulesRes, pipelinesRes] = await Promise.all([
      CrmAPI.getAutomationRules(),
      CrmAPI.getPipelines(),
    ]);
    rules.value = extractData(rulesRes);
    pipelines.value = extractData(pipelinesRes);
  } catch {
    error.value = 'Erro ao carregar automações';
  } finally {
    loading.value = false;
  }
}

async function saveRule() {
  if (!isFormValid.value) return;
  saving.value = true;
  error.value = '';

  const payload = {
    name: form.name.trim(),
    trigger_event: 'stage_entered',
    action_type: 'create_activity',
    crm_pipeline_stage_id: form.crm_pipeline_stage_id,
    action_config: {
      kind: form.action_config.kind,
      title: form.action_config.title.trim(),
      description: form.action_config.description.trim() || null,
      priority: form.action_config.priority,
      due_in_hours: Number(form.action_config.due_in_hours),
      conditions: cleanConditions(form.action_config.conditions),
    },
  };

  try {
    if (editingId.value) {
      await CrmAPI.updateAutomationRule(editingId.value, payload);
    } else {
      await CrmAPI.createAutomationRule(payload);
    }
    closeModal();
    await loadData();
  } catch (err) {
    error.value = err?.response?.data?.message || 'Erro ao salvar automação';
  } finally {
    saving.value = false;
  }
}

async function toggleActive(rule) {
  try {
    await CrmAPI.updateAutomationRule(rule.id, { is_active: !rule.is_active });
    await loadData();
  } catch {
    error.value = 'Erro ao atualizar status da automação';
  }
}

async function deleteRule(rule) {
  if (!confirm(`Excluir automação "${rule.name}"?`)) return;
  saving.value = true;
  error.value = '';
  try {
    await CrmAPI.deleteAutomationRule(rule.id);
    await loadData();
  } catch {
    error.value = 'Erro ao excluir automação';
  } finally {
    saving.value = false;
  }
}

onMounted(loadData);
</script>

<template>
  <main class="crm-automation-page">
    <header class="crm-page-header">
      <div>
        <p class="crm-eyebrow">Motor operacional</p>
        <h1>Automações do CRM</h1>
        <p>
          Crie tarefas automaticamente quando o lead entrar em uma etapa do
          pipeline.
        </p>
      </div>
      <button type="button" class="crm-primary-button" @click="openNew">
        <fluent-icon icon="add" size="16" />
        Nova automação
      </button>
    </header>

    <section class="crm-summary-grid">
      <article v-for="item in summary" :key="item.label" class="crm-stat-card">
        <span>{{ item.label }}</span>
        <strong>{{ item.value }}</strong>
      </article>
    </section>

    <section class="crm-toolbar">
      <label class="crm-search-field">
        <fluent-icon icon="search" size="16" />
        <input v-model="filters.search" type="search" placeholder="Buscar" />
      </label>
      <select v-model="filters.status" class="crm-select">
        <option value="">Todas as regras</option>
        <option value="active">Ativas</option>
        <option value="paused">Pausadas</option>
      </select>
      <select v-model="filters.stage_id" class="crm-select">
        <option value="">Todas as etapas</option>
        <option v-for="stage in allStages" :key="stage.id" :value="stage.id">
          {{ stage.pipelineName }} / {{ stage.name }}
        </option>
      </select>
      <button type="button" class="crm-secondary-button" @click="clearFilters">
        Limpar
      </button>
    </section>

    <div v-if="error" class="crm-alert">
      {{ error }}
    </div>

    <section v-if="loading" class="crm-empty-state">
      Carregando automações...
    </section>

    <section v-else-if="filteredRules.length === 0" class="crm-empty-state">
      <fluent-icon icon="flash" size="38" />
      <strong>Nenhuma automação encontrada</strong>
      <p>Configure regras para transformar movimentações do funil em ações.</p>
      <button type="button" class="crm-primary-button" @click="openNew">
        Criar automação
      </button>
    </section>

    <section v-else class="crm-rule-list">
      <article
        v-for="rule in filteredRules"
        :key="rule.id"
        class="crm-rule-card"
      >
        <div class="crm-rule-icon">
          <fluent-icon icon="flash" size="20" />
        </div>
        <div class="crm-rule-main">
          <div class="crm-rule-title">
            <h2>{{ rule.name }}</h2>
            <span :class="rule.is_active ? 'active' : 'paused'">
              {{ rule.is_active ? 'Ativa' : 'Pausada' }}
            </span>
          </div>
          <p class="crm-trigger">
            Quando entrar em
            <strong>
              {{
                stageMap[rule.crm_pipeline_stage_id] || 'etapa não vinculada'
              }}
            </strong>
          </p>
          <div class="crm-flow-row">
            <span class="crm-chip">
              {{ labelFor(ACTION_KINDS, rule.action_config?.kind) }}
            </span>
            <span
              class="crm-chip"
              :class="priorityClass(rule.action_config?.priority)"
            >
              {{ labelFor(PRIORITIES, rule.action_config?.priority) }}
            </span>
            <span class="crm-chip muted">
              Prazo: {{ rule.action_config?.due_in_hours ?? 24 }}h
            </span>
            <span
              v-if="rule.action_config?.conditions?.length"
              class="crm-chip muted"
            >
              {{ rule.action_config.conditions.length }} condicao(oes)
            </span>
          </div>
          <ul
            v-if="rule.action_config?.conditions?.length"
            class="crm-condition-summary"
          >
            <li
              v-for="(condition, index) in rule.action_config.conditions"
              :key="`${rule.id}-condition-${index}`"
            >
              {{ conditionLabel(condition) }}
            </li>
          </ul>
          <p class="crm-action-title">
            {{ rule.action_config?.title || 'Atividade sem título' }}
          </p>
          <p v-if="rule.action_config?.description" class="crm-description">
            {{ rule.action_config.description }}
          </p>
        </div>
        <div class="crm-card-actions">
          <button type="button" @click="toggleActive(rule)">
            <fluent-icon :icon="rule.is_active ? 'pause' : 'play'" size="14" />
            {{ rule.is_active ? 'Pausar' : 'Ativar' }}
          </button>
          <button type="button" @click="openEdit(rule)">
            <fluent-icon icon="edit" size="14" />
            Editar
          </button>
          <button type="button" class="danger" @click="deleteRule(rule)">
            <fluent-icon icon="delete" size="14" />
            Excluir
          </button>
        </div>
      </article>
    </section>

    <div v-if="showModal" class="crm-modal-backdrop" @click.self="closeModal">
      <section class="crm-modal">
        <header class="crm-modal-header">
          <div>
            <p class="crm-eyebrow">Regra de etapa</p>
            <h2>{{ editingId ? 'Editar automação' : 'Nova automação' }}</h2>
          </div>
          <button type="button" class="crm-icon-button" @click="closeModal">
            <fluent-icon icon="dismiss" size="16" />
          </button>
        </header>

        <div class="crm-form-grid">
          <label>
            Nome *
            <input
              v-model="form.name"
              type="text"
              class="crm-input"
              placeholder="Ex: Follow-up de proposta"
            />
          </label>
          <label>
            Etapa do pipeline *
            <select v-model="form.crm_pipeline_stage_id" class="crm-select">
              <option value="" disabled>Selecione uma etapa</option>
              <optgroup
                v-for="pipeline in pipelines"
                :key="pipeline.id"
                :label="pipeline.name"
              >
                <option
                  v-for="stage in pipeline.stages || []"
                  :key="stage.id"
                  :value="stage.id"
                >
                  {{ stage.name }}
                </option>
              </optgroup>
            </select>
          </label>
        </div>

        <section class="crm-action-box">
          <h3>Atividade gerada pela automação</h3>
          <div class="crm-form-grid">
            <label>
              Tipo
              <select v-model="form.action_config.kind" class="crm-select">
                <option
                  v-for="opt in ACTION_KINDS"
                  :key="opt.value"
                  :value="opt.value"
                >
                  {{ opt.label }}
                </option>
              </select>
            </label>
            <label>
              Prioridade
              <select v-model="form.action_config.priority" class="crm-select">
                <option
                  v-for="opt in PRIORITIES"
                  :key="opt.value"
                  :value="opt.value"
                >
                  {{ opt.label }}
                </option>
              </select>
            </label>
            <label>
              Título *
              <input
                v-model="form.action_config.title"
                type="text"
                class="crm-input"
                placeholder="Ex: Retomar proposta enviada"
              />
            </label>
            <label>
              Prazo em horas
              <input
                v-model.number="form.action_config.due_in_hours"
                type="number"
                min="1"
                class="crm-input"
              />
            </label>
          </div>
          <label class="crm-full-field">
            Descrição
            <textarea
              v-model="form.action_config.description"
              rows="3"
              class="crm-textarea"
              placeholder="Instrução para o responsável executar a atividade"
            />
          </label>
        </section>

        <section class="crm-action-box">
          <div class="crm-action-box__header">
            <div>
              <h3>Condicoes visuais</h3>
              <p>
                Execute a automacao somente quando o lead cumprir estes
                criterios.
              </p>
            </div>
            <button
              type="button"
              class="crm-secondary-button"
              @click="addCondition"
            >
              <fluent-icon icon="add" size="14" />
              Adicionar condicao
            </button>
          </div>

          <div
            v-if="form.action_config.conditions.length"
            class="crm-condition-builder"
          >
            <div
              v-for="(condition, index) in form.action_config.conditions"
              :key="`condition-${index}`"
              class="crm-condition-row"
            >
              <select v-model="condition.field" class="crm-select">
                <option
                  v-for="field in CONDITION_FIELDS"
                  :key="field.value"
                  :value="field.value"
                >
                  {{ field.label }}
                </option>
              </select>
              <select v-model="condition.operator" class="crm-select">
                <option
                  v-for="operator in CONDITION_OPERATORS"
                  :key="operator.value"
                  :value="operator.value"
                >
                  {{ operator.label }}
                </option>
              </select>
              <input
                v-model="condition.value"
                type="text"
                class="crm-input"
                :disabled="['present', 'blank'].includes(condition.operator)"
                placeholder="Valor"
              />
              <button
                type="button"
                class="crm-icon-button danger"
                @click="removeCondition(index)"
              >
                <fluent-icon icon="delete" size="14" />
              </button>
            </div>
          </div>
          <p v-else class="crm-helper-text">
            Sem condicoes: a regra roda sempre que o lead entrar na etapa.
          </p>
        </section>

        <footer class="crm-modal-footer">
          <button
            type="button"
            class="crm-secondary-button"
            @click="closeModal"
          >
            Cancelar
          </button>
          <button
            type="button"
            class="crm-primary-button"
            :disabled="saving || !isFormValid"
            @click="saveRule"
          >
            {{ saving ? 'Salvando...' : 'Salvar automação' }}
          </button>
        </footer>
      </section>
    </div>
  </main>
</template>

<style scoped>
.crm-automation-page {
  display: flex;
  flex-direction: column;
  gap: 20px;
  width: 100%;
  min-width: 0;
  min-height: 100%;
  overflow-x: hidden;
  padding: 28px;
  color: rgb(var(--slate-12));
}

.crm-page-header,
.crm-toolbar,
.crm-rule-card,
.crm-modal,
.crm-action-box {
  border: 1px solid rgb(var(--slate-5));
  background: rgb(var(--slate-1));
}

.crm-page-header {
  display: flex;
  min-width: 0;
  align-items: flex-start;
  justify-content: space-between;
  gap: 20px;
  padding: 20px;
  border-radius: 8px;
}

.crm-page-header > * {
  min-width: 0;
}

.crm-page-header h1,
.crm-modal-header h2 {
  margin: 0;
  font-size: 24px;
  font-weight: 700;
}

.crm-page-header p,
.crm-empty-state p,
.crm-description {
  max-width: 720px;
  margin: 6px 0 0;
  color: rgb(var(--slate-10));
}

.crm-eyebrow {
  margin: 0 0 4px;
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0;
  text-transform: uppercase;
  color: rgb(var(--brand-9));
}

.crm-primary-button,
.crm-secondary-button,
.crm-icon-button,
.crm-card-actions button {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  min-height: 36px;
  border-radius: 8px;
  font-size: 13px;
  font-weight: 700;
  transition: 0.16s ease;
}

.crm-primary-button {
  padding: 0 14px;
  color: white;
  background: rgb(var(--brand-9));
}

.crm-primary-button:disabled {
  cursor: not-allowed;
  opacity: 0.45;
}

.crm-secondary-button,
.crm-card-actions button,
.crm-icon-button {
  color: rgb(var(--slate-11));
  border: 1px solid rgb(var(--slate-5));
  background: rgb(var(--slate-2));
}

.crm-secondary-button,
.crm-card-actions button {
  padding: 0 12px;
}

.crm-icon-button {
  width: 36px;
}

.crm-primary-button:hover,
.crm-secondary-button:hover,
.crm-icon-button:hover,
.crm-card-actions button:hover {
  opacity: 0.86;
}

.danger {
  color: rgb(var(--ruby-11)) !important;
}

.crm-summary-grid {
  display: grid;
  grid-template-columns: repeat(5, minmax(0, 1fr));
  gap: 12px;
}

.crm-stat-card {
  padding: 14px;
  border: 1px solid rgb(var(--slate-5));
  border-radius: 8px;
  background: rgb(var(--slate-1));
}

.crm-stat-card span {
  display: block;
  font-size: 12px;
  color: rgb(var(--slate-10));
}

.crm-stat-card strong {
  display: block;
  margin-top: 6px;
  font-size: 24px;
}

.crm-toolbar {
  display: grid;
  grid-template-columns:
    minmax(180px, 1fr) minmax(140px, 180px) minmax(180px, 280px)
    auto;
  gap: 10px;
  min-width: 0;
  padding: 12px;
  border-radius: 8px;
}

.crm-toolbar > * {
  min-width: 0;
}

.crm-search-field {
  display: flex;
  align-items: center;
  gap: 8px;
  min-height: 40px;
  padding: 0 12px;
  border: 1px solid rgb(var(--slate-5));
  border-radius: 8px;
  background: rgb(var(--slate-2));
}

.crm-search-field input,
.crm-input,
.crm-select,
.crm-textarea {
  width: 100%;
  min-width: 0;
  min-height: 40px;
  color: rgb(var(--slate-12));
  outline: none;
}

.crm-search-field input {
  min-height: auto;
  background: transparent;
}

.crm-input,
.crm-select,
.crm-textarea {
  padding: 0 12px;
  border: 1px solid rgb(var(--slate-5));
  border-radius: 8px;
  background: rgb(var(--slate-2));
}

.crm-select {
  appearance: auto;
}

.crm-textarea {
  min-height: 86px;
  padding-top: 10px;
  resize: vertical;
}

.crm-alert {
  padding: 12px 14px;
  color: rgb(var(--ruby-11));
  border: 1px solid rgb(var(--ruby-6));
  border-radius: 8px;
  background: rgb(var(--ruby-2));
}

.crm-empty-state {
  display: flex;
  flex: 1;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 10px;
  min-height: 280px;
  padding: 32px;
  text-align: center;
  color: rgb(var(--slate-10));
}

.crm-rule-list {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.crm-rule-card {
  display: grid;
  grid-template-columns: 44px minmax(0, 1fr) auto;
  min-width: 0;
  gap: 14px;
  padding: 16px;
  border-radius: 8px;
}

.crm-rule-icon {
  display: grid;
  width: 40px;
  height: 40px;
  color: rgb(var(--brand-9));
  place-items: center;
  border-radius: 8px;
  background: rgb(var(--brand-3));
}

.crm-rule-title {
  display: flex;
  min-width: 0;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.crm-rule-title h2 {
  overflow: hidden;
  margin: 0;
  font-size: 16px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.crm-rule-title span,
.crm-chip {
  display: inline-flex;
  align-items: center;
  min-height: 24px;
  padding: 0 8px;
  border-radius: 999px;
  font-size: 12px;
  font-weight: 700;
}

.crm-rule-title span.active {
  color: rgb(var(--teal-11));
  background: rgb(var(--teal-3));
}

.crm-rule-title span.paused {
  color: rgb(var(--slate-10));
  background: rgb(var(--slate-3));
}

.crm-trigger {
  margin: 8px 0 0;
  color: rgb(var(--slate-10));
}

.crm-trigger strong {
  color: rgb(var(--slate-12));
}

.crm-flow-row {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin-top: 10px;
}

.crm-chip {
  color: rgb(var(--brand-10));
  background: rgb(var(--brand-3));
}

.crm-chip.warn {
  color: rgb(var(--amber-11));
  background: rgb(var(--amber-3));
}

.crm-chip.danger {
  color: rgb(var(--ruby-11)) !important;
  background: rgb(var(--ruby-3));
}

.crm-chip.muted {
  color: rgb(var(--slate-10));
  background: rgb(var(--slate-3));
}

.crm-action-title {
  margin: 10px 0 0;
  font-weight: 700;
}

.crm-card-actions {
  display: flex;
  flex-direction: column;
  min-width: 0;
  gap: 8px;
}

.crm-modal-backdrop {
  position: fixed;
  inset: 0;
  z-index: 50;
  display: flex;
  align-items: flex-start;
  justify-content: center;
  padding: 32px 16px;
  overflow: auto;
  background: rgb(0 0 0 / 0.48);
}

.crm-modal {
  width: min(860px, 100%);
  padding: 20px;
  border-radius: 8px;
  box-shadow: 0 24px 80px rgb(0 0 0 / 0.36);
}

.crm-modal-header,
.crm-modal-footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.crm-form-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
  margin-top: 18px;
}

.crm-form-grid label,
.crm-full-field {
  display: flex;
  flex-direction: column;
  gap: 6px;
  font-size: 12px;
  font-weight: 700;
  color: rgb(var(--slate-10));
}

.crm-action-box {
  padding: 14px;
  margin-top: 18px;
  border-radius: 8px;
}

.crm-action-box h3 {
  margin: 0;
  font-size: 15px;
}

.crm-action-box__header {
  display: flex;
  min-width: 0;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
}

.crm-action-box__header p,
.crm-helper-text {
  margin: 6px 0 0;
  color: rgb(var(--slate-10));
  font-size: 13px;
  line-height: 1.45;
}

.crm-full-field {
  margin-top: 12px;
}

.crm-condition-builder,
.crm-condition-summary {
  display: grid;
  gap: 8px;
  margin-top: 12px;
}

.crm-condition-row {
  display: grid;
  grid-template-columns: minmax(0, 1fr) minmax(0, 0.8fr) minmax(0, 1fr) auto;
  gap: 8px;
  align-items: center;
}

.crm-condition-summary {
  margin-bottom: 0;
  padding-left: 18px;
  color: rgb(var(--slate-10));
  font-size: 12px;
}

.crm-modal-footer {
  margin-top: 20px;
}

@media (max-width: 1180px) {
  .crm-summary-grid {
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }

  .crm-toolbar {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 760px) {
  .crm-automation-page {
    padding: 16px;
  }

  .crm-page-header {
    flex-direction: column;
  }

  .crm-summary-grid,
  .crm-toolbar,
  .crm-rule-card,
  .crm-form-grid,
  .crm-condition-row {
    grid-template-columns: 1fr;
  }

  .crm-action-box__header {
    flex-direction: column;
  }

  .crm-card-actions {
    flex-direction: row;
    flex-wrap: wrap;
  }

  .crm-card-actions button,
  .crm-primary-button,
  .crm-secondary-button {
    width: 100%;
  }
}
</style>
