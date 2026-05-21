<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text, no-alert, no-restricted-globals -->
<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import CrmAPI from 'dashboard/api/crm';

const cadences = ref([]);
const loading = ref(true);
const saving = ref(false);
const error = ref('');
const showModal = ref(false);
const editingId = ref(null);

const CHANNELS = [
  { value: 'whatsapp', label: 'WhatsApp', icon: 'i-lucide-message-circle' },
  { value: 'email', label: 'E-mail', icon: 'i-lucide-mail' },
  { value: 'sms', label: 'SMS', icon: 'i-lucide-smartphone' },
  { value: 'task', label: 'Tarefa', icon: 'i-lucide-list-checks' },
];

const STATUSES = [
  { value: 'draft', label: 'Rascunho', tone: 'draft' },
  { value: 'active', label: 'Ativa', tone: 'active' },
  { value: 'paused', label: 'Pausada', tone: 'paused' },
];

const ACTION_TYPES = [
  {
    value: 'send_message',
    label: 'Enviar mensagem',
    icon: 'i-lucide-send',
  },
  {
    value: 'create_activity',
    label: 'Criar atividade',
    icon: 'i-lucide-calendar-plus',
  },
  { value: 'wait', label: 'Aguardar', icon: 'i-lucide-clock-3' },
];

const CONDITION_MISS_BEHAVIORS = [
  { value: 'skip_step', label: 'Pular passo' },
  { value: 'pause_enrollment', label: 'Pausar inscricao' },
  { value: 'cancel_enrollment', label: 'Cancelar inscricao' },
];

const conditionPlaceholder =
  '[{"field":"score_total","operator":"gte","value":70}]';

const templateModels = [
  {
    key: 'lead_sem_resposta',
    name: 'Lead sem resposta',
    description: 'Sequencia curta para retomar contato sem parecer insistente.',
    icon: 'i-lucide-message-circle-warning',
    channel: 'whatsapp',
    steps: [
      {
        name: 'Mensagem de retomada',
        wait_hours: 0,
        action_type: 'send_message',
        template_body:
          'Oi, tudo bem? Passando para confirmar se você ainda precisa de ajuda com o seu atendimento.',
      },
      {
        name: 'Tarefa de ligação',
        wait_hours: 24,
        action_type: 'create_activity',
        template_body:
          'Ligar para o lead e registrar se ainda existe interesse.',
      },
      {
        name: 'Ultimo lembrete',
        wait_hours: 72,
        action_type: 'send_message',
        template_body:
          'Como não tivemos retorno, vou pausar seu atendimento por enquanto. Se precisar, é só responder esta mensagem.',
      },
    ],
  },
  {
    key: 'documentos_pendentes',
    name: 'Documentos pendentes',
    description: 'Cobra documentos sem perder o histórico do caso.',
    icon: 'i-lucide-files',
    channel: 'whatsapp',
    steps: [
      {
        name: 'Solicitar documentos',
        wait_hours: 0,
        action_type: 'send_message',
        template_body:
          'Para avancarmos, preciso que você envie os documentos combinados.',
      },
      {
        name: 'Lembrete de documentos',
        wait_hours: 48,
        action_type: 'send_message',
        template_body:
          'Passando para lembrar dos documentos pendentes. Assim que enviar, seguimos com a analise.',
      },
    ],
  },
  {
    key: 'consulta_agendada',
    name: 'Consulta agendada',
    description: 'Prepara o contato antes da reunião e reduz faltas.',
    icon: 'i-lucide-calendar-check',
    channel: 'whatsapp',
    steps: [
      {
        name: 'Confirmar consulta',
        wait_hours: 0,
        action_type: 'send_message',
        template_body:
          'Sua consulta está agendada. Se precisar remarcar, avise por aqui.',
      },
      {
        name: 'Lembrete da consulta',
        wait_hours: 24,
        action_type: 'send_message',
        template_body:
          'Lembrete: sua consulta está chegando. Separe documentos e dúvidas principais.',
      },
    ],
  },
  {
    key: 'reativacao_lead_frio',
    name: 'Reativação de lead frio',
    description: 'Reabre oportunidades antigas com uma abordagem leve.',
    icon: 'i-lucide-snowflake',
    channel: 'whatsapp',
    steps: [
      {
        name: 'Reativar interesse',
        wait_hours: 0,
        action_type: 'send_message',
        template_body:
          'Oi, estou retomando alguns atendimentos antigos. Você ainda quer seguir com esse assunto?',
      },
      {
        name: 'Criar tarefa de triagem',
        wait_hours: 48,
        action_type: 'create_activity',
        template_body:
          'Revisar o histórico do lead e decidir se vale nova triagem.',
      },
    ],
  },
  {
    key: 'pos_atendimento',
    name: 'Pos-atendimento',
    description: 'Acompanha satisfação e próximos passos após o contato.',
    icon: 'i-lucide-heart-handshake',
    channel: 'whatsapp',
    steps: [
      {
        name: 'Mensagem de acompanhamento',
        wait_hours: 24,
        action_type: 'send_message',
        template_body:
          'Passando para saber se ficou alguma duvida sobre o atendimento.',
      },
      {
        name: 'Checar próximo passo',
        wait_hours: 72,
        action_type: 'create_activity',
        template_body:
          'Conferir se o cliente precisa de novo retorno ou encaminhamento.',
      },
    ],
  },
  {
    key: 'cliente_base_remarketing',
    name: 'Cliente base / remarketing',
    description: 'Mantem relacionamento com contatos da base.',
    icon: 'i-lucide-megaphone',
    channel: 'whatsapp',
    steps: [
      {
        name: 'Mensagem de relacionamento',
        wait_hours: 0,
        action_type: 'send_message',
        template_body:
          'Oi, tudo bem? Estamos atualizando nossa base e queria saber se você precisa de apoio em algum novo assunto.',
      },
      {
        name: 'Registrar oportunidade',
        wait_hours: 48,
        action_type: 'create_activity',
        template_body:
          'Verificar se houve resposta e criar oportunidade quando fizer sentido.',
      },
    ],
  },
];

const blankStep = position => ({
  name: `Passo ${position}`,
  position,
  channel: 'whatsapp',
  action_type: 'send_message',
  wait_hours: position === 1 ? 0 : 24,
  template_body: '',
  action_config: { conditions: [], condition_miss: 'skip_step' },
  condition_miss: 'skip_step',
  conditions_json: '[]',
  is_active: true,
});

const form = reactive({
  name: '',
  status: 'draft',
  channel: 'whatsapp',
  starts_at: '',
  steps: [blankStep(1)],
});

const filters = reactive({
  search: '',
  status: '',
  channel: '',
});

const extractData = response => {
  const payload = response?.data ?? response;
  if (Array.isArray(payload)) return payload;
  return payload?.data ?? [];
};

const activeCadences = computed(
  () => cadences.value.filter(cadence => cadence.status === 'active').length
);

const pausedCadences = computed(
  () => cadences.value.filter(cadence => cadence.status === 'paused').length
);

const totalSteps = computed(() =>
  cadences.value.reduce(
    (total, cadence) => total + (cadence.steps?.length || 0),
    0
  )
);

const stats = computed(() => [
  {
    label: 'Total',
    value: cadences.value.length,
    hint: 'Cadências criadas',
    icon: 'i-lucide-send',
    tone: 'blue',
  },
  {
    label: 'Ativas',
    value: activeCadences.value,
    hint: 'Em operação',
    icon: 'i-lucide-play-circle',
    tone: 'teal',
  },
  {
    label: 'Pausadas',
    value: pausedCadences.value,
    hint: 'Aguardando ajuste',
    icon: 'i-lucide-pause-circle',
    tone: 'amber',
  },
  {
    label: 'Passos',
    value: totalSteps.value,
    hint: 'Ações configuradas',
    icon: 'i-lucide-list-checks',
    tone: 'brand',
  },
]);

const filteredCadences = computed(() => {
  const search = filters.search.toLowerCase().trim();
  return cadences.value.filter(cadence => {
    const searchable = [
      cadence.name,
      cadence.channel,
      labelFor(CHANNELS, cadence.channel),
      cadence.status,
      labelFor(STATUSES, cadence.status),
      ...(cadence.steps || []).flatMap(step => [
        step.name,
        step.action_type,
        labelFor(ACTION_TYPES, step.action_type),
        step.template_body,
      ]),
    ];

    const matchesSearch =
      !search ||
      searchable
        .filter(Boolean)
        .some(value => String(value).toLowerCase().includes(search));
    const matchesStatus = !filters.status || cadence.status === filters.status;
    const matchesChannel =
      !filters.channel || cadence.channel === filters.channel;
    return matchesSearch && matchesStatus && matchesChannel;
  });
});

const isFormValid = computed(
  () =>
    form.name.trim() &&
    form.steps.length > 0 &&
    form.steps.every(
      step => step.name.trim() && step.channel && step.action_type
    )
);

const drawerTitle = computed(() =>
  editingId.value ? 'Editar cadencia' : 'Nova cadencia'
);

function labelFor(list, value) {
  return list.find(item => item.value === value)?.label || value || '-';
}

function iconFor(list, value, fallback = 'i-lucide-circle') {
  return list.find(item => item.value === value)?.icon || fallback;
}

function clearFilters() {
  filters.search = '';
  filters.status = '';
  filters.channel = '';
}

function statusTone(status) {
  return STATUSES.find(item => item.value === status)?.tone || 'draft';
}

function resetForm() {
  editingId.value = null;
  form.name = '';
  form.status = 'draft';
  form.channel = 'whatsapp';
  form.starts_at = '';
  form.steps = [blankStep(1)];
}

function normalizeTemplateStep(step, index, channel = 'whatsapp') {
  return {
    ...blankStep(index + 1),
    ...step,
    position: index + 1,
    channel: step.channel || channel,
    action_config: {
      conditions: step.conditions || [],
      condition_miss: step.condition_miss || 'skip_step',
    },
    condition_miss: step.condition_miss || 'skip_step',
    conditions_json: JSON.stringify(step.conditions || [], null, 2),
    is_active: step.is_active !== false,
  };
}

function openNew() {
  resetForm();
  showModal.value = true;
}

function openTemplate(template) {
  resetForm();
  form.name = template.name;
  form.channel = template.channel;
  form.steps = template.steps.map((step, index) =>
    normalizeTemplateStep(step, index, template.channel)
  );
  showModal.value = true;
}

function openEdit(cadence) {
  editingId.value = cadence.id;
  form.name = cadence.name || '';
  form.status = cadence.status || 'draft';
  form.channel = cadence.channel || 'whatsapp';
  form.starts_at = cadence.starts_at ? cadence.starts_at.slice(0, 16) : '';
  form.steps = (cadence.steps?.length ? cadence.steps : [blankStep(1)]).map(
    (step, index) => ({
      id: step.id,
      name: step.name || `Passo ${index + 1}`,
      position: step.position || index + 1,
      channel: step.channel || cadence.channel || 'whatsapp',
      action_type: step.action_type || 'send_message',
      wait_hours: step.wait_hours ?? (index === 0 ? 0 : 24),
      template_body: step.template_body || '',
      action_config: step.action_config || {},
      condition_miss: step.action_config?.condition_miss || 'skip_step',
      conditions_json: JSON.stringify(
        step.action_config?.conditions || [],
        null,
        2
      ),
      is_active: step.is_active !== false,
    })
  );
  showModal.value = true;
}

function closeModal() {
  showModal.value = false;
  resetForm();
}

function addStep() {
  form.steps.push(blankStep(form.steps.length + 1));
}

function removeStep(index) {
  if (form.steps.length === 1) return;
  form.steps.splice(index, 1);
  form.steps.forEach((step, stepIndex) => {
    step.position = stepIndex + 1;
    step.name = step.name || `Passo ${stepIndex + 1}`;
  });
}

function duplicateStep(index) {
  const current = form.steps[index];
  form.steps.splice(index + 1, 0, {
    ...current,
    id: undefined,
    name: `${current.name} copia`,
    position: index + 2,
  });
  form.steps.forEach((step, stepIndex) => {
    step.position = stepIndex + 1;
  });
}

async function loadCadences() {
  loading.value = true;
  error.value = '';
  try {
    cadences.value = extractData(await CrmAPI.getCadences());
  } catch {
    error.value = 'Erro ao carregar cadencias';
  } finally {
    loading.value = false;
  }
}

async function saveCadence() {
  if (!isFormValid.value) return;
  saving.value = true;
  error.value = '';
  let stepsPayload = [];
  try {
    stepsPayload = form.steps.map((step, index) => ({
      id: step.id,
      name: step.name.trim(),
      position: index + 1,
      channel: step.channel,
      action_type: step.action_type,
      wait_hours: Number(step.wait_hours || 0),
      template_body: step.template_body?.trim() || null,
      action_config: actionConfigForStep(step),
      is_active: step.is_active,
    }));
  } catch (err) {
    error.value = err.message;
    saving.value = false;
    return;
  }

  const payload = {
    name: form.name.trim(),
    status: form.status,
    channel: form.channel,
    starts_at: form.starts_at || null,
    steps: stepsPayload,
  };

  try {
    if (editingId.value) {
      await CrmAPI.updateCadence(editingId.value, payload);
    } else {
      await CrmAPI.createCadence(payload);
    }
    closeModal();
    await loadCadences();
  } catch (err) {
    error.value = err?.response?.data?.error || 'Erro ao salvar cadencia';
  } finally {
    saving.value = false;
  }
}

function actionConfigForStep(step) {
  const actionConfig = {
    ...(step.action_config || {}),
    condition_miss: step.condition_miss || 'skip_step',
  };
  const rawConditions = step.conditions_json?.trim();
  const conditions = rawConditions ? JSON.parse(rawConditions) : [];
  if (!Array.isArray(conditions)) {
    throw new Error('Condicoes precisam ser uma lista JSON.');
  }
  actionConfig.conditions = conditions;
  return actionConfig;
}

async function toggleStatus(cadence) {
  const status = cadence.status === 'active' ? 'paused' : 'active';
  try {
    await CrmAPI.updateCadence(cadence.id, { status });
    await loadCadences();
  } catch {
    error.value = 'Erro ao atualizar status da cadencia';
  }
}

async function deleteCadence(cadence) {
  if (!confirm(`Arquivar cadencia "${cadence.name}"?`)) return;
  saving.value = true;
  error.value = '';
  try {
    await CrmAPI.deleteCadence(cadence.id);
    await loadCadences();
  } catch {
    error.value = 'Erro ao arquivar cadencia';
  } finally {
    saving.value = false;
  }
}

onMounted(loadCadences);
</script>

<template>
  <div class="crm-cadences-page">
    <header class="crm-cadences-hero">
      <div class="crm-cadences-hero__title">
        <span class="crm-cadences-hero__icon i-lucide-send size-5" />
        <div>
          <span class="crm-cadences-kicker">Nutricao e follow-up</span>
          <h1>Cadências do CRM</h1>
          <p>
            Modele sequências de contato para leads, documentos pendentes,
            consultas e reativação da base.
          </p>
        </div>
      </div>
      <button class="crm-primary-button" type="button" @click="openNew">
        <span class="i-lucide-plus size-4" />
        Nova cadencia
      </button>
    </header>

    <section class="crm-cadences-stats">
      <article
        v-for="stat in stats"
        :key="stat.label"
        class="crm-cadence-stat"
        :class="`crm-cadence-stat--${stat.tone}`"
      >
        <span class="crm-cadence-stat__icon-box" aria-hidden="true">
          <span class="crm-cadence-stat__icon" :class="stat.icon" />
        </span>
        <div>
          <small>{{ stat.label }}</small>
          <strong>{{ stat.value }}</strong>
          <span>{{ stat.hint }}</span>
        </div>
      </article>
    </section>

    <section class="crm-cadences-filters">
      <label class="crm-cadences-search">
        <span class="crm-cadences-search__icon" aria-hidden="true">
          <span class="i-lucide-search size-4" />
        </span>
        <input
          v-model="filters.search"
          type="search"
          placeholder="Buscar por cadencia, canal, status ou passo"
        />
      </label>

      <select v-model="filters.status" class="crm-native-select">
        <option value="">Todos os status</option>
        <option
          v-for="status in STATUSES"
          :key="status.value"
          :value="status.value"
        >
          {{ status.label }}
        </option>
      </select>

      <select v-model="filters.channel" class="crm-native-select">
        <option value="">Todos os canais</option>
        <option
          v-for="channel in CHANNELS"
          :key="channel.value"
          :value="channel.value"
        >
          {{ channel.label }}
        </option>
      </select>

      <button type="button" class="crm-secondary-button" @click="clearFilters">
        Limpar
      </button>
    </section>

    <section class="crm-template-strip">
      <div>
        <span class="crm-cadences-kicker">Modelos rapidos</span>
        <p>
          Comece com uma cadencia pronta e ajuste os passos antes de salvar.
        </p>
      </div>
      <div class="crm-template-strip__grid">
        <button
          v-for="template in templateModels"
          :key="template.key"
          type="button"
          class="crm-template-chip"
          @click="openTemplate(template)"
        >
          <span :class="[template.icon, 'size-4']" />
          {{ template.name }}
        </button>
      </div>
    </section>

    <div v-if="error" class="crm-alert">
      <span class="i-lucide-circle-alert size-4" />
      {{ error }}
    </div>

    <section class="crm-cadences-content">
      <div v-if="loading" class="crm-state">
        <span class="i-lucide-loader-circle size-5 animate-spin" />
        Carregando cadencias...
      </div>

      <div v-else-if="filteredCadences.length === 0" class="crm-empty-state">
        <span class="i-lucide-send size-10" />
        <h2>Nenhuma cadencia encontrada</h2>
        <p>
          Crie uma sequência manual ou escolha um modelo rapido para automatizar
          follow-ups com mais consistencia.
        </p>
        <div class="crm-empty-state__actions">
          <button class="crm-primary-button" type="button" @click="openNew">
            <span class="i-lucide-plus size-4" />
            Criar cadencia
          </button>
        </div>
      </div>

      <div v-else class="crm-cadence-grid">
        <article
          v-for="cadence in filteredCadences"
          :key="cadence.id"
          class="crm-cadence-card"
          :class="`crm-cadence-card--${statusTone(cadence.status)}`"
        >
          <header class="crm-cadence-card__header">
            <div class="crm-cadence-card__identity">
              <span
                class="crm-cadence-card__channel"
                :class="iconFor(CHANNELS, cadence.channel, 'i-lucide-send')"
              />
              <div>
                <h2>{{ cadence.name }}</h2>
                <div class="crm-cadence-card__chips">
                  <span
                    class="crm-status-chip"
                    :class="`crm-status-chip--${statusTone(cadence.status)}`"
                  >
                    {{ labelFor(STATUSES, cadence.status) }}
                  </span>
                  <span class="crm-meta-chip">
                    {{ labelFor(CHANNELS, cadence.channel) }}
                  </span>
                  <span class="crm-meta-chip">
                    {{ cadence.steps?.length || 0 }} passos
                  </span>
                </div>
              </div>
            </div>

            <div class="crm-cadence-card__actions">
              <button
                type="button"
                class="crm-icon-button"
                :title="cadence.status === 'active' ? 'Pausar' : 'Ativar'"
                @click="toggleStatus(cadence)"
              >
                <span
                  :class="
                    cadence.status === 'active'
                      ? 'i-lucide-pause size-4'
                      : 'i-lucide-play size-4'
                  "
                />
              </button>
              <button
                type="button"
                class="crm-icon-button"
                title="Editar"
                @click="openEdit(cadence)"
              >
                <span class="i-lucide-pencil size-4" />
              </button>
              <button
                type="button"
                class="crm-icon-button crm-icon-button--danger"
                title="Arquivar"
                @click="deleteCadence(cadence)"
              >
                <span class="i-lucide-archive size-4" />
              </button>
            </div>
          </header>

          <ol class="crm-cadence-timeline">
            <li
              v-for="step in cadence.steps"
              :key="step.id"
              class="crm-cadence-step"
              :class="{
                'crm-cadence-step--inactive': step.is_active === false,
              }"
            >
              <span class="crm-cadence-step__number">{{ step.position }}</span>
              <div class="crm-cadence-step__body">
                <div class="crm-cadence-step__title">
                  <span
                    :class="[
                      iconFor(
                        ACTION_TYPES,
                        step.action_type,
                        'i-lucide-circle'
                      ),
                      'size-4',
                    ]"
                  />
                  <strong>{{ step.name }}</strong>
                </div>
                <p>
                  {{ labelFor(ACTION_TYPES, step.action_type) }} depois de
                  {{ step.wait_hours }}h
                  <span v-if="step.action_config?.conditions?.length">
                    - {{ step.action_config.conditions.length }} cond.
                  </span>
                </p>
              </div>
            </li>
          </ol>
        </article>
      </div>
    </section>

    <div v-if="showModal" class="crm-drawer-backdrop" @click.self="closeModal">
      <aside class="crm-drawer">
        <header class="crm-drawer__header">
          <div>
            <span class="crm-cadences-kicker">
              {{ editingId ? 'Edição' : 'Criação guiada' }}
            </span>
            <h2>{{ drawerTitle }}</h2>
            <p>Configure dados, canal padrão e passos da sequência.</p>
          </div>
          <button class="crm-icon-button" type="button" @click="closeModal">
            <span class="i-lucide-x size-4" />
          </button>
        </header>

        <div class="crm-drawer__body">
          <section class="crm-form-section">
            <div class="crm-form-section__header">
              <span class="i-lucide-settings-2 size-4" />
              <div>
                <h3>Dados da cadencia</h3>
                <p>Defina como a sequência aparece e quando pode iniciar.</p>
              </div>
            </div>

            <div class="crm-form-grid">
              <label class="crm-field crm-field--wide">
                <span>Nome *</span>
                <input
                  v-model="form.name"
                  type="text"
                  placeholder="Ex: Follow-up proposta"
                />
              </label>

              <label class="crm-field">
                <span>Status</span>
                <select v-model="form.status">
                  <option
                    v-for="status in STATUSES"
                    :key="status.value"
                    :value="status.value"
                  >
                    {{ status.label }}
                  </option>
                </select>
              </label>

              <label class="crm-field">
                <span>Canal padrão</span>
                <select v-model="form.channel">
                  <option
                    v-for="channel in CHANNELS"
                    :key="channel.value"
                    :value="channel.value"
                  >
                    {{ channel.label }}
                  </option>
                </select>
              </label>

              <label class="crm-field">
                <span>Inicio</span>
                <input v-model="form.starts_at" type="datetime-local" />
              </label>
            </div>
          </section>

          <section class="crm-form-section">
            <div
              class="crm-form-section__header crm-form-section__header--split"
            >
              <div class="crm-form-section__title">
                <span class="i-lucide-list-plus size-4" />
                <div>
                  <h3>Passos</h3>
                  <p>Combine espera, mensagem, tarefas e condicoes.</p>
                </div>
              </div>
              <button
                class="crm-secondary-button"
                type="button"
                @click="addStep"
              >
                <span class="i-lucide-plus size-4" />
                Adicionar passo
              </button>
            </div>

            <div class="crm-step-editor-list">
              <section
                v-for="(step, index) in form.steps"
                :key="index"
                class="crm-step-editor"
              >
                <header class="crm-step-editor__header">
                  <span class="crm-step-editor__number">{{ index + 1 }}</span>
                  <div>
                    <strong>Passo {{ index + 1 }}</strong>
                    <small>
                      {{ labelFor(ACTION_TYPES, step.action_type) }} -
                      {{ step.wait_hours || 0 }}h
                    </small>
                  </div>
                  <div class="crm-step-editor__actions">
                    <button
                      class="crm-icon-button"
                      type="button"
                      title="Duplicar passo"
                      @click="duplicateStep(index)"
                    >
                      <span class="i-lucide-copy size-4" />
                    </button>
                    <button
                      class="crm-icon-button crm-icon-button--danger"
                      type="button"
                      :disabled="form.steps.length === 1"
                      title="Remover passo"
                      @click="removeStep(index)"
                    >
                      <span class="i-lucide-trash-2 size-4" />
                    </button>
                  </div>
                </header>

                <div class="crm-form-grid">
                  <label class="crm-field crm-field--wide">
                    <span>Nome *</span>
                    <input v-model="step.name" type="text" />
                  </label>
                  <label class="crm-field">
                    <span>Canal</span>
                    <select v-model="step.channel">
                      <option
                        v-for="channel in CHANNELS"
                        :key="channel.value"
                        :value="channel.value"
                      >
                        {{ channel.label }}
                      </option>
                    </select>
                  </label>
                  <label class="crm-field">
                    <span>Acao</span>
                    <select v-model="step.action_type">
                      <option
                        v-for="action in ACTION_TYPES"
                        :key="action.value"
                        :value="action.value"
                      >
                        {{ action.label }}
                      </option>
                    </select>
                  </label>
                  <label class="crm-field">
                    <span>Espera em horas</span>
                    <input
                      v-model.number="step.wait_hours"
                      type="number"
                      min="0"
                    />
                  </label>
                  <label class="crm-toggle-field">
                    <input v-model="step.is_active" type="checkbox" />
                    <span>Passo ativo</span>
                  </label>
                </div>

                <label class="crm-field crm-field--wide">
                  <span>Mensagem ou instrucao</span>
                  <textarea
                    v-model="step.template_body"
                    rows="3"
                    placeholder="Texto base do contato ou instrucao interna para a atividade."
                  />
                </label>

                <div class="crm-form-grid">
                  <label class="crm-field">
                    <span>Se condicao falhar</span>
                    <select v-model="step.condition_miss">
                      <option
                        v-for="behavior in CONDITION_MISS_BEHAVIORS"
                        :key="behavior.value"
                        :value="behavior.value"
                      >
                        {{ behavior.label }}
                      </option>
                    </select>
                  </label>
                  <label class="crm-field crm-field--wide">
                    <span>Condicoes JSON</span>
                    <textarea
                      v-model="step.conditions_json"
                      rows="3"
                      class="crm-code-input"
                      :placeholder="conditionPlaceholder"
                    />
                  </label>
                </div>
              </section>
            </div>
          </section>
        </div>

        <footer class="crm-drawer__footer">
          <button
            class="crm-secondary-button"
            type="button"
            @click="closeModal"
          >
            Cancelar
          </button>
          <button
            :disabled="saving || !isFormValid"
            class="crm-primary-button"
            type="button"
            @click="saveCadence"
          >
            {{ saving ? 'Salvando...' : 'Salvar cadencia' }}
          </button>
        </footer>
      </aside>
    </div>
  </div>
</template>

<style scoped>
.crm-cadences-page {
  display: flex;
  width: 100%;
  min-width: 0;
  height: 100%;
  flex-direction: column;
  gap: 1rem;
  overflow: auto;
  padding: 1.5rem;
  color: rgb(var(--slate-12));
  background: radial-gradient(
      circle at top right,
      rgb(var(--blue-3) / 0.34),
      transparent 24rem
    ),
    radial-gradient(
      circle at 6% 28%,
      rgb(var(--teal-3) / 0.18),
      transparent 22rem
    ),
    rgb(var(--slate-2));
}

.crm-cadences-page * {
  min-width: 0;
}

.crm-cadences-hero,
.crm-cadence-stat,
.crm-cadences-filters,
.crm-template-strip,
.crm-cadence-card,
.crm-empty-state,
.crm-state,
.crm-form-section,
.crm-step-editor,
.crm-drawer {
  border: 1px solid rgb(var(--slate-4));
  border-radius: 8px;
  background: rgb(var(--slate-1));
  box-shadow: 0 16px 45px rgb(15 23 42 / 0.05);
}

.crm-cadences-hero {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  padding: 1rem;
}

.crm-cadences-hero__title,
.crm-form-section__header,
.crm-form-section__title,
.crm-cadence-card__identity,
.crm-cadence-card__chips,
.crm-cadence-card__actions,
.crm-step-editor__header,
.crm-step-editor__actions {
  display: flex;
  min-width: 0;
}

.crm-cadences-hero__title {
  align-items: center;
  gap: 0.85rem;
}

.crm-cadences-hero__icon {
  display: grid;
  width: 3rem;
  height: 3rem;
  flex: 0 0 auto;
  place-items: center;
  border: 1px solid rgb(var(--blue-5));
  border-radius: 8px;
  color: rgb(var(--blue-11));
  background: linear-gradient(135deg, rgb(var(--blue-2)), rgb(var(--teal-2)));
}

.crm-cadences-kicker {
  display: block;
  margin-bottom: 0.2rem;
  color: rgb(var(--brand-10));
  font-size: 0.72rem;
  font-weight: 900;
  letter-spacing: 0;
  text-transform: uppercase;
}

.crm-cadences-hero h1,
.crm-drawer h2 {
  margin: 0;
  color: rgb(var(--slate-12));
  font-size: 1.35rem;
  font-weight: 900;
  line-height: 1.15;
}

.crm-cadences-hero p,
.crm-template-strip p,
.crm-form-section__header p,
.crm-drawer__header p,
.crm-empty-state p {
  margin: 0;
  color: rgb(var(--slate-10));
  font-size: 0.83rem;
  line-height: 1.45;
}

.crm-primary-button,
.crm-secondary-button,
.crm-icon-button,
.crm-template-chip {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border-radius: 8px;
  font-weight: 850;
  transition:
    border-color 160ms ease,
    background 160ms ease,
    color 160ms ease,
    transform 160ms ease;
}

.crm-primary-button {
  gap: 0.45rem;
  min-height: 2.5rem;
  border: 1px solid rgb(var(--blue-7));
  padding: 0 0.9rem;
  color: white;
  background: linear-gradient(135deg, rgb(var(--blue-7)), rgb(var(--brand-9)));
  box-shadow: 0 10px 24px rgb(var(--blue-9) / 0.2);
}

.crm-primary-button:hover:not(:disabled) {
  transform: translateY(-1px);
  background: linear-gradient(135deg, rgb(var(--blue-8)), rgb(var(--brand-10)));
}

.crm-secondary-button,
.crm-template-chip {
  gap: 0.4rem;
  min-height: 2.4rem;
  border: 1px solid rgb(var(--slate-5));
  padding: 0 0.8rem;
  color: rgb(var(--slate-11));
  background: rgb(var(--slate-1));
}

.crm-secondary-button:hover,
.crm-template-chip:hover {
  border-color: rgb(var(--blue-6));
  color: rgb(var(--blue-11));
  background: rgb(var(--blue-2));
}

.crm-primary-button:disabled,
.crm-secondary-button:disabled,
.crm-icon-button:disabled {
  cursor: not-allowed;
  opacity: 0.55;
}

.crm-cadences-stats {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 0.75rem;
}

.crm-cadence-stat {
  position: relative;
  display: flex;
  gap: 0.75rem;
  overflow: hidden;
  padding: 0.9rem;
}

.crm-cadence-stat::before {
  position: absolute;
  inset-block: 0;
  left: 0;
  width: 0.24rem;
  background: rgb(var(--blue-8));
  content: '';
}

.crm-cadence-stat__icon-box {
  display: grid;
  width: 2.1rem;
  height: 2.1rem;
  flex: 0 0 auto;
  place-items: center;
  border-radius: 8px;
  color: rgb(var(--blue-11));
  background: rgb(var(--blue-2));
}

.crm-cadence-stat__icon {
  width: 1rem;
  height: 1rem;
}

.crm-cadence-stat small {
  display: block;
  color: rgb(var(--slate-10));
  font-size: 0.72rem;
  font-weight: 900;
  text-transform: uppercase;
}

.crm-cadence-stat strong {
  display: block;
  color: rgb(var(--slate-12));
  font-size: 1.35rem;
  font-weight: 900;
  line-height: 1.1;
}

.crm-cadence-stat
  span:not(.crm-cadence-stat__icon-box):not(.crm-cadence-stat__icon) {
  color: rgb(var(--slate-10));
  font-size: 0.75rem;
}

.crm-cadence-stat--teal {
  border-color: rgb(var(--teal-5));
  background: linear-gradient(135deg, rgb(var(--teal-1)), rgb(var(--slate-1)));
}

.crm-cadence-stat--teal::before {
  background: rgb(var(--teal-8));
}

.crm-cadence-stat--teal .crm-cadence-stat__icon-box {
  color: rgb(var(--teal-11));
  background: rgb(var(--teal-2));
}

.crm-cadence-stat--amber {
  border-color: rgb(var(--amber-5));
  background: linear-gradient(135deg, rgb(var(--amber-1)), rgb(var(--slate-1)));
}

.crm-cadence-stat--amber::before {
  background: rgb(var(--amber-8));
}

.crm-cadence-stat--amber .crm-cadence-stat__icon-box {
  color: rgb(var(--amber-11));
  background: rgb(var(--amber-2));
}

.crm-cadence-stat--brand {
  border-color: rgb(var(--brand-5));
  background: linear-gradient(135deg, rgb(var(--brand-1)), rgb(var(--slate-1)));
}

.crm-cadence-stat--brand::before {
  background: rgb(var(--brand-8));
}

.crm-cadence-stat--brand .crm-cadence-stat__icon-box {
  color: rgb(var(--brand-11));
  background: rgb(var(--brand-2));
}

.crm-cadences-filters {
  display: grid;
  grid-template-columns: minmax(18rem, 1fr) 13rem 13rem auto;
  gap: 0.65rem;
  padding: 0.8rem;
}

.crm-cadences-search {
  position: relative;
  display: block;
  height: 2.5rem;
  overflow: hidden;
  border: 1px solid rgb(var(--blue-6));
  border-radius: 8px;
  color: rgb(var(--blue-10));
  background: rgb(var(--slate-1));
}

.crm-cadences-search__icon {
  position: absolute;
  inset-block: 0;
  left: 0;
  z-index: 1;
  display: grid;
  width: 2.75rem;
  place-items: center;
  border-right: 1px solid rgb(var(--slate-4));
  background: rgb(var(--blue-2));
  pointer-events: none;
}

.crm-cadences-search__icon > span {
  width: 1rem;
  height: 1rem;
}

.crm-cadences-search input {
  display: block;
  width: 100%;
  height: 100%;
  border: 0;
  padding: 0 0.85rem 0 3.35rem;
  color: rgb(var(--slate-12));
  background: transparent;
  outline: none;
}

.crm-cadences-search input::placeholder {
  color: rgb(var(--slate-10));
}

.crm-cadences-search:focus-within {
  border-color: rgb(var(--blue-7));
  box-shadow: 0 0 0 3px rgb(var(--blue-4) / 0.26);
}

.crm-native-select,
.crm-field input,
.crm-field select,
.crm-field textarea {
  width: 100%;
  min-height: 2.5rem;
  border: 1px solid rgb(var(--slate-5));
  border-radius: 8px;
  padding: 0 0.75rem;
  color: rgb(var(--slate-12));
  background: rgb(var(--slate-1));
  outline: none;
}

.crm-field textarea {
  min-height: 5.5rem;
  resize: vertical;
  padding: 0.75rem;
}

.crm-code-input {
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  font-size: 0.76rem;
}

.crm-native-select:focus,
.crm-field input:focus,
.crm-field select:focus,
.crm-field textarea:focus {
  border-color: rgb(var(--blue-7));
  box-shadow: 0 0 0 3px rgb(var(--blue-4) / 0.22);
}

.crm-template-strip {
  display: grid;
  grid-template-columns: minmax(14rem, 0.7fr) minmax(0, 1.3fr);
  gap: 1rem;
  padding: 1rem;
}

.crm-template-strip__grid {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.crm-alert {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  border: 1px solid rgb(var(--ruby-7));
  border-radius: 8px;
  padding: 0.85rem 1rem;
  color: rgb(var(--ruby-11));
  background: rgb(var(--ruby-2));
}

.crm-cadences-content {
  min-height: 0;
}

.crm-state,
.crm-empty-state {
  display: grid;
  min-height: 18rem;
  place-items: center;
  gap: 0.65rem;
  padding: 2rem;
  text-align: center;
}

.crm-empty-state > span {
  color: rgb(var(--brand-8));
}

.crm-empty-state h2 {
  margin: 0;
  color: rgb(var(--slate-12));
  font-size: 1.1rem;
  font-weight: 900;
}

.crm-empty-state__actions {
  display: flex;
  gap: 0.5rem;
}

.crm-cadence-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 1rem;
}

.crm-cadence-card {
  position: relative;
  overflow: hidden;
  padding: 1rem;
}

.crm-cadence-card::before {
  position: absolute;
  inset-block: 0;
  left: 0;
  width: 0.25rem;
  background: rgb(var(--slate-7));
  content: '';
}

.crm-cadence-card--active::before {
  background: linear-gradient(180deg, rgb(var(--teal-6)), rgb(var(--teal-9)));
}

.crm-cadence-card--paused::before {
  background: linear-gradient(180deg, rgb(var(--amber-5)), rgb(var(--amber-9)));
}

.crm-cadence-card--draft::before {
  background: linear-gradient(180deg, rgb(var(--blue-5)), rgb(var(--brand-8)));
}

.crm-cadence-card__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
  margin-bottom: 1rem;
}

.crm-cadence-card__identity {
  align-items: flex-start;
  gap: 0.75rem;
}

.crm-cadence-card__channel {
  display: grid;
  width: 2.4rem;
  height: 2.4rem;
  flex: 0 0 auto;
  place-items: center;
  border: 1px solid rgb(var(--blue-5));
  border-radius: 8px;
  color: rgb(var(--blue-11));
  background: linear-gradient(135deg, rgb(var(--blue-2)), rgb(var(--teal-2)));
}

.crm-cadence-card h2 {
  overflow: hidden;
  margin: 0;
  color: rgb(var(--slate-12));
  font-size: 1rem;
  font-weight: 900;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.crm-cadence-card__chips {
  flex-wrap: wrap;
  gap: 0.35rem;
  margin-top: 0.45rem;
}

.crm-status-chip,
.crm-meta-chip {
  border-radius: 999px;
  padding: 0.16rem 0.52rem;
  font-size: 0.7rem;
  font-weight: 850;
}

.crm-status-chip--active {
  color: rgb(var(--teal-11));
  background: rgb(var(--teal-2));
}

.crm-status-chip--paused {
  color: rgb(var(--amber-11));
  background: rgb(var(--amber-2));
}

.crm-status-chip--draft,
.crm-meta-chip {
  color: rgb(var(--blue-11));
  background: rgb(var(--blue-2));
}

.crm-cadence-card__actions {
  flex: 0 0 auto;
  gap: 0.3rem;
}

.crm-icon-button {
  width: 2rem;
  height: 2rem;
  border: 1px solid rgb(var(--slate-5));
  color: rgb(var(--slate-10));
  background: rgb(var(--slate-1));
}

.crm-icon-button:hover:not(:disabled) {
  border-color: rgb(var(--blue-5));
  color: rgb(var(--blue-11));
  background: rgb(var(--blue-2));
}

.crm-icon-button--danger:hover:not(:disabled) {
  border-color: rgb(var(--ruby-5));
  color: rgb(var(--ruby-11));
  background: rgb(var(--ruby-2));
}

.crm-cadence-timeline {
  display: grid;
  gap: 0.55rem;
  margin: 0;
  padding: 0;
  list-style: none;
}

.crm-cadence-step {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr);
  gap: 0.65rem;
  border: 1px solid rgb(var(--slate-4));
  border-radius: 8px;
  padding: 0.65rem;
  background: rgb(var(--slate-2));
}

.crm-cadence-step--inactive {
  opacity: 0.62;
}

.crm-cadence-step__number,
.crm-step-editor__number {
  display: grid;
  width: 1.7rem;
  height: 1.7rem;
  place-items: center;
  border-radius: 999px;
  color: rgb(var(--brand-11));
  font-size: 0.72rem;
  font-weight: 900;
  background: rgb(var(--brand-2));
}

.crm-cadence-step__title {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  color: rgb(var(--slate-12));
}

.crm-cadence-step__title span {
  flex: 0 0 auto;
  color: rgb(var(--brand-10));
}

.crm-cadence-step p {
  margin: 0.2rem 0 0;
  color: rgb(var(--slate-10));
  font-size: 0.76rem;
}

.crm-drawer-backdrop {
  position: fixed;
  inset: 0;
  z-index: 50;
  display: flex;
  justify-content: flex-end;
  background: rgb(15 23 42 / 0.42);
}

.crm-drawer {
  display: flex;
  width: min(58rem, 100vw);
  height: 100%;
  flex-direction: column;
  border-radius: 0;
  border-block: 0;
  border-right: 0;
}

.crm-drawer__header,
.crm-drawer__footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  padding: 1rem;
}

.crm-drawer__header {
  border-bottom: 1px solid rgb(var(--slate-4));
}

.crm-drawer__footer {
  border-top: 1px solid rgb(var(--slate-4));
}

.crm-drawer__body {
  display: grid;
  gap: 1rem;
  overflow-y: auto;
  padding: 1rem;
}

.crm-form-section {
  padding: 1rem;
}

.crm-form-section__header {
  align-items: center;
  gap: 0.65rem;
  margin-bottom: 0.85rem;
}

.crm-form-section__header > span {
  display: grid;
  width: 2rem;
  height: 2rem;
  flex: 0 0 auto;
  place-items: center;
  border-radius: 8px;
  color: rgb(var(--blue-11));
  background: rgb(var(--blue-2));
}

.crm-form-section__header h3 {
  margin: 0;
  color: rgb(var(--slate-12));
  font-size: 0.95rem;
  font-weight: 900;
}

.crm-form-section__header--split {
  justify-content: space-between;
}

.crm-form-section__title {
  align-items: center;
  gap: 0.65rem;
}

.crm-form-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 0.75rem;
}

.crm-field {
  display: grid;
  gap: 0.35rem;
}

.crm-field--wide {
  grid-column: span 2;
}

.crm-field > span,
.crm-toggle-field span {
  color: rgb(var(--slate-10));
  font-size: 0.76rem;
  font-weight: 900;
}

.crm-toggle-field {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  min-height: 2.5rem;
  border: 1px solid rgb(var(--slate-5));
  border-radius: 8px;
  padding: 0 0.75rem;
  background: rgb(var(--slate-1));
}

.crm-step-editor-list {
  display: grid;
  gap: 0.85rem;
}

.crm-step-editor {
  padding: 0.9rem;
  background: rgb(var(--slate-2));
}

.crm-step-editor__header {
  align-items: center;
  gap: 0.65rem;
  margin-bottom: 0.85rem;
}

.crm-step-editor__header strong {
  display: block;
  color: rgb(var(--slate-12));
}

.crm-step-editor__header small {
  color: rgb(var(--slate-10));
  font-size: 0.75rem;
}

.crm-step-editor__actions {
  margin-left: auto;
  gap: 0.3rem;
}

@media (max-width: 1280px) {
  .crm-cadence-grid,
  .crm-template-strip {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 960px) {
  .crm-cadences-page {
    padding: 1rem;
  }

  .crm-cadences-hero,
  .crm-cadence-card__header,
  .crm-form-section__header--split,
  .crm-drawer__footer {
    align-items: stretch;
    flex-direction: column;
  }

  .crm-cadences-stats {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .crm-cadences-filters,
  .crm-form-grid {
    grid-template-columns: 1fr;
  }

  .crm-field--wide {
    grid-column: auto;
  }

  .crm-primary-button,
  .crm-secondary-button {
    width: 100%;
  }
}

@media (max-width: 560px) {
  .crm-cadences-stats {
    grid-template-columns: 1fr;
  }

  .crm-cadences-hero__title {
    align-items: flex-start;
    flex-direction: column;
  }
}
</style>
