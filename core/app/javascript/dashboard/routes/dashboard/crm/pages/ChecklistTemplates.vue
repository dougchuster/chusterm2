<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text, no-alert, no-restricted-globals -->
<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import CrmAPI from 'dashboard/api/crm';

const templates = ref([]);
const loading = ref(true);
const saving = ref(false);
const error = ref('');
const showModal = ref(false);
const editingId = ref(null);

const filters = reactive({
  search: '',
  case_type: '',
  legal_area: '',
});

const ITEM_KINDS = [
  { value: 'document', label: 'Documento' },
  { value: 'task', label: 'Tarefa' },
  { value: 'validation', label: 'Conferência' },
];

const blankItem = () => ({
  key: '',
  title: '',
  kind: 'document',
  required: true,
});

const form = reactive({
  name: '',
  case_type: '',
  legal_area: '',
  position: 0,
  items: [blankItem()],
});

const extractData = response => {
  const payload = response?.data ?? response;
  if (Array.isArray(payload)) return payload;
  return payload?.data ?? [];
};

const normalized = value =>
  String(value || '')
    .toLowerCase()
    .trim();

const caseTypeOptions = computed(() => {
  const values = templates.value.map(item => item.case_type).filter(Boolean);
  return [...new Set(values)].sort();
});

const legalAreaOptions = computed(() => {
  const values = templates.value.map(item => item.legal_area).filter(Boolean);
  return [...new Set(values)].sort();
});

const filteredTemplates = computed(() => {
  const search = normalized(filters.search);
  return templates.value.filter(template => {
    const matchesSearch =
      !search ||
      [template.name, template.case_type, template.legal_area]
        .map(normalized)
        .some(value => value.includes(search));
    const matchesCase =
      !filters.case_type || template.case_type === filters.case_type;
    const matchesArea =
      !filters.legal_area || template.legal_area === filters.legal_area;
    return matchesSearch && matchesCase && matchesArea;
  });
});

const summary = computed(() => {
  const totalItems = templates.value.reduce(
    (sum, template) => sum + (template.items?.length || 0),
    0
  );
  const requiredItems = templates.value.reduce(
    (sum, template) =>
      sum + (template.items || []).filter(item => item.required).length,
    0
  );

  return [
    { label: 'Templates ativos', value: templates.value.length },
    { label: 'Áreas jurídicas', value: legalAreaOptions.value.length },
    { label: 'Itens cadastrados', value: totalItems },
    { label: 'Itens obrigatórios', value: requiredItems },
  ];
});

function labelFor(list, value) {
  return list.find(opt => opt.value === value)?.label || value;
}

function resetForm() {
  editingId.value = null;
  form.name = '';
  form.case_type = '';
  form.legal_area = '';
  form.position = 0;
  form.items = [blankItem()];
}

function openNew() {
  resetForm();
  showModal.value = true;
}

function openEdit(template) {
  editingId.value = template.id;
  form.name = template.name || '';
  form.case_type = template.case_type || '';
  form.legal_area = template.legal_area || '';
  form.position = template.position || 0;
  form.items = (template.items?.length ? template.items : [blankItem()]).map(
    item => ({
      key: item.key || '',
      title: item.title || '',
      kind: item.kind || 'document',
      required: item.required !== false,
    })
  );
  showModal.value = true;
}

function closeModal() {
  showModal.value = false;
  resetForm();
}

function addItem() {
  form.items.push(blankItem());
}

function removeItem(index) {
  if (form.items.length === 1) return;
  form.items.splice(index, 1);
}

async function loadTemplates() {
  loading.value = true;
  error.value = '';
  try {
    templates.value = extractData(await CrmAPI.getChecklistTemplates());
  } catch {
    error.value = 'Erro ao carregar templates de checklist';
  } finally {
    loading.value = false;
  }
}

async function saveTemplate() {
  if (!form.name.trim()) return;

  saving.value = true;
  error.value = '';

  const payload = {
    name: form.name.trim(),
    case_type: form.case_type.trim() || null,
    legal_area: form.legal_area.trim() || null,
    position: Number(form.position || 0),
    items: form.items
      .filter(item => item.title.trim())
      .map((item, index) => ({
        key: item.key.trim() || `item_${index + 1}`,
        title: item.title.trim(),
        kind: item.kind,
        required: item.required,
      })),
  };

  try {
    if (editingId.value) {
      await CrmAPI.updateChecklistTemplate(editingId.value, payload);
    } else {
      await CrmAPI.createChecklistTemplate(payload);
    }
    closeModal();
    await loadTemplates();
  } catch (err) {
    error.value = err?.response?.data?.error || 'Erro ao salvar checklist';
  } finally {
    saving.value = false;
  }
}

async function deleteTemplate(template) {
  if (!confirm(`Arquivar template "${template.name}"?`)) return;
  saving.value = true;
  error.value = '';
  try {
    await CrmAPI.deleteChecklistTemplate(template.id);
    await loadTemplates();
  } catch {
    error.value = 'Erro ao arquivar template';
  } finally {
    saving.value = false;
  }
}

function clearFilters() {
  filters.search = '';
  filters.case_type = '';
  filters.legal_area = '';
}

const isFormValid = computed(
  () => form.name.trim() && form.items.some(item => item.title.trim())
);

onMounted(loadTemplates);
</script>

<template>
  <main class="crm-config-page">
    <header class="crm-page-header">
      <div>
        <p class="crm-eyebrow">Documentos e playbooks</p>
        <h1>Templates de checklist</h1>
        <p>
          Padronize documentos, conferências e tarefas por tipo de caso antes de
          mover o lead no funil.
        </p>
      </div>
      <button type="button" class="crm-primary-button" @click="openNew">
        <fluent-icon icon="add" size="16" />
        Novo template
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
      <select v-model="filters.case_type" class="crm-select">
        <option value="">Todos os tipos de caso</option>
        <option v-for="type in caseTypeOptions" :key="type" :value="type">
          {{ type }}
        </option>
      </select>
      <select v-model="filters.legal_area" class="crm-select">
        <option value="">Todas as áreas</option>
        <option v-for="area in legalAreaOptions" :key="area" :value="area">
          {{ area }}
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
      Carregando templates...
    </section>

    <section v-else-if="filteredTemplates.length === 0" class="crm-empty-state">
      <fluent-icon icon="clipboard-task-list-ltr" size="36" />
      <strong>Nenhum checklist encontrado</strong>
      <p>
        Crie templates para organizar documentos e etapas por área jurídica.
      </p>
      <button type="button" class="crm-primary-button" @click="openNew">
        Criar checklist
      </button>
    </section>

    <section v-else class="crm-template-list">
      <article
        v-for="template in filteredTemplates"
        :key="template.id"
        class="crm-template-card"
      >
        <div class="crm-template-icon">
          <fluent-icon icon="clipboard-task-list-ltr" size="20" />
        </div>
        <div class="crm-template-main">
          <div class="crm-template-title">
            <h2>{{ template.name }}</h2>
            <span>{{ template.items?.length || 0 }} itens</span>
          </div>
          <div class="crm-tag-row">
            <span v-if="template.case_type" class="crm-tag">
              {{ template.case_type }}
            </span>
            <span v-if="template.legal_area" class="crm-tag accent">
              {{ template.legal_area }}
            </span>
            <span class="crm-tag muted">
              {{ (template.items || []).filter(item => item.required).length }}
              obrigatórios
            </span>
          </div>
          <ol class="crm-item-preview">
            <li
              v-for="item in (template.items || []).slice(0, 3)"
              :key="item.key || item.title"
            >
              <span>{{ item.title }}</span>
              <small>{{ labelFor(ITEM_KINDS, item.kind) }}</small>
            </li>
          </ol>
        </div>
        <div class="crm-card-actions">
          <button type="button" @click="openEdit(template)">
            <fluent-icon icon="edit" size="14" />
            Editar
          </button>
          <button
            type="button"
            class="danger"
            @click="deleteTemplate(template)"
          >
            <fluent-icon icon="delete" size="14" />
            Arquivar
          </button>
        </div>
      </article>
    </section>

    <div v-if="showModal" class="crm-modal-backdrop" @click.self="closeModal">
      <section class="crm-modal">
        <header class="crm-modal-header">
          <div>
            <p class="crm-eyebrow">Checklist</p>
            <h2>{{ editingId ? 'Editar template' : 'Novo template' }}</h2>
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
              placeholder="Ex: Aposentadoria por tempo"
            />
          </label>
          <label>
            Tipo de caso
            <input
              v-model="form.case_type"
              type="text"
              class="crm-input"
              placeholder="Ex: Aposentadoria"
            />
          </label>
          <label>
            Área jurídica
            <input
              v-model="form.legal_area"
              type="text"
              class="crm-input"
              placeholder="Ex: Previdenciario"
            />
          </label>
          <label>
            Ordem
            <input
              v-model.number="form.position"
              type="number"
              class="crm-input"
              min="0"
            />
          </label>
        </div>

        <div class="crm-section-heading">
          <h3>Itens do checklist</h3>
          <button type="button" class="crm-secondary-button" @click="addItem">
            <fluent-icon icon="add" size="14" />
            Adicionar item
          </button>
        </div>

        <div class="crm-items-editor">
          <section
            v-for="(item, index) in form.items"
            :key="index"
            class="crm-item-editor"
          >
            <input
              v-model="item.title"
              type="text"
              class="crm-input item-title"
              placeholder="Documento, conferência ou tarefa"
            />
            <input
              v-model="item.key"
              type="text"
              class="crm-input"
              placeholder="chave_interna"
            />
            <select v-model="item.kind" class="crm-select">
              <option
                v-for="kind in ITEM_KINDS"
                :key="kind.value"
                :value="kind.value"
              >
                {{ kind.label }}
              </option>
            </select>
            <label class="crm-checkbox">
              <input v-model="item.required" type="checkbox" />
              Obrigatório
            </label>
            <button
              type="button"
              class="crm-icon-button danger"
              :disabled="form.items.length === 1"
              @click="removeItem(index)"
            >
              <fluent-icon icon="delete" size="15" />
            </button>
          </section>
        </div>

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
            @click="saveTemplate"
          >
            {{ saving ? 'Salvando...' : 'Salvar template' }}
          </button>
        </footer>
      </section>
    </div>
  </main>
</template>

<style scoped>
.crm-config-page {
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
.crm-template-card,
.crm-modal {
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
.crm-empty-state p {
  max-width: 680px;
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
.crm-card-actions button {
  padding: 0 12px;
  color: rgb(var(--slate-11));
  border: 1px solid rgb(var(--slate-5));
  background: rgb(var(--slate-2));
}

.crm-icon-button {
  width: 36px;
  color: rgb(var(--slate-11));
  border: 1px solid rgb(var(--slate-5));
  background: rgb(var(--slate-2));
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
  grid-template-columns: repeat(4, minmax(0, 1fr));
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
    minmax(180px, 1fr) minmax(150px, 240px) minmax(150px, 240px)
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
.crm-select {
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
.crm-select {
  padding: 0 12px;
  border: 1px solid rgb(var(--slate-5));
  border-radius: 8px;
  background: rgb(var(--slate-2));
}

.crm-select {
  appearance: auto;
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

.crm-template-list {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 14px;
}

.crm-template-card {
  display: grid;
  grid-template-columns: 44px minmax(0, 1fr) auto;
  min-width: 0;
  gap: 14px;
  padding: 16px;
  border-radius: 8px;
}

.crm-template-icon {
  display: grid;
  width: 40px;
  height: 40px;
  color: rgb(var(--brand-9));
  place-items: center;
  border-radius: 8px;
  background: rgb(var(--brand-3));
}

.crm-template-title {
  display: flex;
  min-width: 0;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}

.crm-template-title h2 {
  overflow: hidden;
  margin: 0;
  font-size: 16px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.crm-template-title span {
  font-size: 12px;
  color: rgb(var(--slate-9));
}

.crm-tag-row {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin-top: 8px;
}

.crm-tag {
  padding: 3px 8px;
  font-size: 12px;
  font-weight: 700;
  color: rgb(var(--brand-10));
  border-radius: 999px;
  background: rgb(var(--brand-3));
}

.crm-tag.accent {
  color: rgb(var(--iris-11));
  background: rgb(var(--iris-3));
}

.crm-tag.muted {
  color: rgb(var(--slate-10));
  background: rgb(var(--slate-3));
}

.crm-item-preview {
  display: flex;
  flex-direction: column;
  gap: 6px;
  padding: 0;
  margin: 12px 0 0;
  list-style: none;
}

.crm-item-preview li {
  display: flex;
  justify-content: space-between;
  gap: 10px;
  padding: 8px 10px;
  border-radius: 8px;
  background: rgb(var(--slate-2));
}

.crm-item-preview small {
  flex-shrink: 0;
  color: rgb(var(--slate-9));
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
  width: min(960px, 100%);
  padding: 20px;
  border-radius: 8px;
  box-shadow: 0 24px 80px rgb(0 0 0 / 0.36);
}

.crm-modal-header,
.crm-modal-footer,
.crm-section-heading {
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
.crm-checkbox {
  display: flex;
  flex-direction: column;
  gap: 6px;
  font-size: 12px;
  font-weight: 700;
  color: rgb(var(--slate-10));
}

.crm-section-heading {
  margin-top: 22px;
}

.crm-section-heading h3 {
  margin: 0;
  font-size: 15px;
}

.crm-items-editor {
  display: flex;
  flex-direction: column;
  gap: 10px;
  margin-top: 10px;
}

.crm-item-editor {
  display: grid;
  grid-template-columns:
    minmax(180px, 1.3fr) minmax(140px, 0.8fr) minmax(140px, 0.7fr)
    120px 42px;
  gap: 8px;
  align-items: center;
  min-width: 0;
  padding: 10px;
  border: 1px solid rgb(var(--slate-5));
  border-radius: 8px;
  background: rgb(var(--slate-2));
}

.crm-item-editor .crm-input,
.crm-item-editor .crm-select {
  background: rgb(var(--slate-1));
}

.crm-checkbox {
  flex-direction: row;
  align-items: center;
  min-height: 40px;
}

.crm-modal-footer {
  margin-top: 20px;
}

.crm-item-editor > * {
  min-width: 0;
}

@media (max-width: 1180px) {
  .crm-summary-grid,
  .crm-template-list {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .crm-toolbar,
  .crm-item-editor {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 760px) {
  .crm-config-page {
    padding: 16px;
  }

  .crm-page-header,
  .crm-template-card {
    grid-template-columns: 1fr;
  }

  .crm-page-header {
    flex-direction: column;
  }

  .crm-summary-grid,
  .crm-template-list,
  .crm-toolbar,
  .crm-form-grid,
  .crm-item-editor {
    grid-template-columns: 1fr;
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
