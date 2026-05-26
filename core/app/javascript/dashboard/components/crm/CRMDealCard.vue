<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text, vue/no-static-inline-styles -->
<script setup>
import { computed, ref, watch } from 'vue';
import CRMScoreBadge from './CRMScoreBadge.vue';
import CRMLegalAreaBadge from './CRMLegalAreaBadge.vue';

const props = defineProps({
  deal: {
    type: Object,
    required: true,
  },
  accountId: {
    type: Number,
    required: true,
  },
  scoreRefreshing: {
    type: Boolean,
    default: false,
  },
  selected: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits([
  'recompute-score',
  'openDrawer',
  'delete-deal',
  'updateTitle',
  'toggleSelect',
  'discardDeal',
  'markBaseClient',
]);

const isEditingTitle = ref(false);
const titleDraft = ref('');
const pointerStart = ref(null);

const score = computed(() =>
  Number(props.deal.score_total ?? props.deal.score ?? 0)
);

const classification = computed(() => props.deal.score_classification ?? '');

const contactUrl = computed(() => {
  const cid = props.deal.contact_id ?? props.deal.chatwootContactId;
  if (!cid) return '';
  return `/app/accounts/${props.accountId}/contacts/${cid}`;
});

const dealDetailsUrl = computed(() =>
  props.deal.id
    ? `/app/accounts/${props.accountId}/crm/deals/${props.deal.id}`
    : ''
);

const displayName = computed(
  () => props.deal.title || props.deal.contact_name || 'Lead sem nome'
);

const dealRef = computed(() => {
  const title = props.deal.title || '';
  const name = props.deal.contact_name || '';
  if (!name || title === name) return '';
  return name;
});

const contactPhone = computed(() => props.deal.contact_phone_number || '');

const operationalStatus = computed(() => props.deal.operational_status || '');

const operationalLabel = computed(() => {
  const labels = {
    active: 'Lead ativo',
    returning_client: 'Retorno',
    base_client: 'Cliente Base',
    converted_client: 'Cliente Convertido',
    invalid: 'Inválido',
    spam: 'Spam',
    duplicated: 'Duplicado',
    no_lead: 'Não é lead',
    archived: 'Arquivado',
  };
  return labels[operationalStatus.value] || '';
});

const urgencyClass = computed(() => {
  const u = (
    props.deal.urgency_level ||
    props.deal.urgencyLevel ||
    ''
  ).toLowerCase();
  if (u === 'critica') return 'bg-n-ruby-3 text-n-ruby-11 font-semibold';
  if (u === 'alta') return 'bg-n-amber-3 text-n-amber-11';
  if (u === 'media') return 'bg-n-yellow-3 text-n-yellow-11';
  return 'bg-n-slate-3 text-n-slate-10';
});

const urgencyLabel = computed(() => {
  const u = (
    props.deal.urgency_level ||
    props.deal.urgencyLevel ||
    ''
  ).toLowerCase();
  const labels = {
    critica: '🔴 Crítica',
    alta: '🟠 Alta',
    media: '🟡 Média',
    baixa: '🟢 Baixa',
  };
  return labels[u] || u || '';
});

const hasNextAction = computed(
  () => !!(props.deal.next_best_action || props.deal.nextBestAction)
);

const nextAction = computed(
  () => props.deal.next_best_action || props.deal.nextBestAction || ''
);

const hasConversation = computed(
  () => !!(props.deal.conversation_id || props.deal.conversation?.id)
);

const unreadCount = computed(() =>
  Number(
    props.deal.unread_count ||
      props.deal.conversation_unread_count ||
      props.deal.unread_messages_count ||
      0
  )
);

const aiMode = computed(
  () => props.deal.ai_mode || props.deal.captain_ai_mode || ''
);

const aiHumanControlled = computed(() =>
  ['paused', 'human_only'].includes(aiMode.value)
);

const aiBadgeLabel = computed(() => {
  if (!aiMode.value) return '';
  return aiHumanControlled.value ? 'Humano' : 'IA';
});

watch(
  () => props.deal.title,
  value => {
    if (!isEditingTitle.value) titleDraft.value = value || '';
  },
  { immediate: true }
);

function startTitleEdit() {
  titleDraft.value = props.deal.title || props.deal.contact_name || '';
  isEditingTitle.value = true;
}

function cancelTitleEdit() {
  titleDraft.value = props.deal.title || '';
  isEditingTitle.value = false;
}

function saveTitleEdit() {
  const nextTitle = titleDraft.value.trim();
  if (!nextTitle) {
    cancelTitleEdit();
    return;
  }

  isEditingTitle.value = false;
  if (nextTitle !== props.deal.title) {
    emit('updateTitle', { deal: props.deal, title: nextTitle });
  }
}

function rememberPointerStart(event) {
  pointerStart.value = { x: event.clientX, y: event.clientY };
}

function shouldIgnoreOpen(event) {
  if (!event || !pointerStart.value) return false;
  const dx = Math.abs(event.clientX - pointerStart.value.x);
  const dy = Math.abs(event.clientY - pointerStart.value.y);
  return dx + dy > 8;
}

function openAttendance(event) {
  if (shouldIgnoreOpen(event)) return;
  emit('openDrawer', props.deal);
}
</script>

<template>
  <article
    class="group flex min-w-0 cursor-grab flex-col gap-2 rounded-xl border border-n-weak bg-n-slate-2 p-3 shadow-sm transition-all duration-150 hover:border-n-slate-6 hover:shadow-md active:cursor-grabbing"
    :class="selected ? 'ring-2 ring-n-brand/30' : ''"
    tabindex="0"
    role="button"
    title="Abrir atendimento no Kanban"
    @pointerdown="rememberPointerStart"
    @click="openAttendance"
    @keydown.enter.prevent="emit('openDrawer', deal)"
    @keydown.space.prevent="emit('openDrawer', deal)"
  >
    <!-- Header: nome do contato + score badge -->
    <div class="flex items-start justify-between gap-2">
      <label
        class="grid flex-shrink-0 place-content-center w-4 h-5"
        title="Selecionar lead"
      >
        <input
          type="checkbox"
          :checked="selected"
          class="size-3.5 cursor-pointer accent-n-brand"
          @click.stop
          @change.stop="emit('toggleSelect', deal)"
        />
      </label>
      <input
        v-if="isEditingTitle"
        v-model="titleDraft"
        class="flex-1 min-w-0 h-7 px-2 text-xs font-semibold text-n-slate-12 border border-n-brand rounded-md bg-n-slate-1 outline-none"
        type="text"
        autofocus
        @click.stop
        @dblclick.stop
        @keydown.enter.prevent="saveTitleEdit"
        @keydown.esc.prevent="cancelTitleEdit"
        @blur="saveTitleEdit"
      />
      <button
        v-else
        type="button"
        class="flex-1 min-w-0 m-0 p-0 text-left text-xs font-semibold text-n-slate-12 leading-snug line-clamp-2 bg-transparent border-0 cursor-text"
        title="Clique para renomear"
        @click.stop="startTitleEdit"
      >
        {{ displayName }}
      </button>
      <CRMScoreBadge
        :score="score"
        :classification="classification"
        size="sm"
      />
    </div>

    <div
      v-if="hasConversation || aiBadgeLabel || unreadCount"
      class="flex flex-wrap items-center gap-1"
    >
      <span
        v-if="hasConversation"
        class="inline-flex items-center gap-1 rounded-full bg-n-teal-3 px-1.5 py-0.5 text-[0.68rem] font-semibold text-n-teal-11"
        title="Conversa vinculada"
      >
        <span class="i-lucide-message-square size-3" />
        Chat
      </span>
      <span
        v-if="aiBadgeLabel"
        class="inline-flex items-center gap-1 rounded-full px-1.5 py-0.5 text-[0.68rem] font-semibold"
        :class="
          aiHumanControlled
            ? 'bg-n-ruby-3 text-n-ruby-11'
            : 'bg-n-brand/10 text-n-brand'
        "
        title="Controle da IA"
      >
        <span class="i-lucide-bot size-3" />
        {{ aiBadgeLabel }}
      </span>
      <span
        v-if="unreadCount"
        class="inline-flex items-center gap-1 rounded-full bg-n-ruby-3 px-1.5 py-0.5 text-[0.68rem] font-semibold text-n-ruby-11"
        title="Mensagens nao lidas"
      >
        <span class="i-lucide-circle-dot size-3" />
        {{ unreadCount > 9 ? '9+' : unreadCount }}
      </span>
    </div>

    <!-- Referência do atendimento (somente se diferente do nome) -->
    <p v-if="dealRef" class="m-0 truncate text-xs text-n-slate-10">
      {{ dealRef }}
    </p>
    <p v-if="contactPhone" class="m-0 truncate text-xs text-n-slate-10">
      <span
        class="i-lucide-phone inline-block size-3 mr-0.5 align-[-0.06rem]"
      />
      {{ contactPhone }}
    </p>
    <p v-if="deal.source" class="m-0 truncate text-xs text-n-slate-10">
      <span
        class="i-lucide-map-pin inline-block size-3 mr-0.5 align-[-0.06rem]"
      />
      {{
        deal.source_detail
          ? `${deal.source} · ${deal.source_detail}`
          : deal.source
      }}
    </p>

    <!-- Tags: área jurídica + urgência -->
    <div
      v-if="deal.legal_area || deal.urgency_level"
      class="flex flex-wrap gap-1"
    >
      <CRMLegalAreaBadge
        v-if="deal.legal_area"
        :area="deal.legal_area"
        compact
      />
      <span
        v-if="deal.urgency_level"
        class="inline-flex items-center rounded-full text-[0.6875rem] font-medium px-1.5 py-0.5"
        :class="urgencyClass"
      >
        {{ urgencyLabel }}
      </span>
      <span
        v-if="operationalLabel"
        class="inline-flex items-center rounded-full text-[0.6875rem] font-semibold px-1.5 py-0.5"
        :class="{
          'bg-n-teal-3 text-n-teal-11':
            operationalStatus === 'base_client' ||
            operationalStatus === 'converted_client',
          'bg-n-brand/10 text-n-brand':
            operationalStatus === 'returning_client',
          'bg-n-ruby-3 text-n-ruby-11': [
            'invalid',
            'spam',
            'duplicated',
            'no_lead',
          ].includes(operationalStatus),
          'bg-n-slate-3 text-n-slate-10': ![
            'base_client',
            'converted_client',
            'returning_client',
            'invalid',
            'spam',
            'duplicated',
            'no_lead',
          ].includes(operationalStatus),
        }"
      >
        {{ operationalLabel }}
      </span>
    </div>

    <!-- Próxima ação (compacta) -->
    <p
      v-if="hasNextAction"
      class="m-0 line-clamp-2 overflow-hidden rounded-r-md bg-n-brand/5 py-1 px-2 text-[0.6875rem] text-n-slate-11 leading-relaxed border-l-2 border-n-brand"
      :title="nextAction"
    >
      <span
        class="i-lucide-lightbulb inline-block size-3 mr-1 align-[-0.06rem] text-n-brand"
      />
      {{ nextAction }}
    </p>

    <!-- Footer: botões de ação -->
    <div
      class="flex items-center justify-between gap-2 pt-1 mt-0.5 border-t border-n-slate-4/60"
    >
      <div class="flex items-center gap-1">
        <button
          type="button"
          class="relative grid size-7 place-content-center rounded-md border border-n-teal-6 bg-n-teal-2 text-n-teal-10 transition-colors duration-150 hover:bg-n-teal-3 disabled:opacity-50"
          title="Atender no Kanban"
          @click.stop="emit('openDrawer', deal)"
        >
          <span class="i-lucide-message-square-text size-3" />
          <span
            v-if="unreadCount"
            class="absolute -right-1 -top-1 grid min-w-4 place-content-center rounded-full bg-n-ruby-9 px-1 text-[0.58rem] font-bold leading-4 text-white"
          >
            {{ unreadCount > 9 ? '9+' : unreadCount }}
          </span>
        </button>

        <button
          type="button"
          class="grid size-7 place-content-center rounded-md border border-n-weak bg-n-slate-1 text-n-slate-10 transition-colors duration-150 hover:bg-n-slate-3 hover:text-n-slate-12 disabled:opacity-50"
          title="Recalcular score"
          :disabled="scoreRefreshing"
          @click.stop="emit('recompute-score', deal)"
        >
          <span class="i-lucide-sparkles size-3" />
        </button>

        <a
          v-if="dealDetailsUrl"
          type="button"
          class="grid size-7 place-content-center rounded-md border border-n-weak bg-n-slate-1 text-n-slate-10 transition-colors duration-150 hover:bg-n-slate-3 hover:text-n-slate-12"
          :href="dealDetailsUrl"
          title="Abrir ficha 360"
          @click.stop
        >
          <span class="i-lucide-external-link size-3" />
        </a>

        <a
          v-if="contactUrl"
          class="grid size-7 place-content-center rounded-md border border-n-weak bg-n-slate-1 text-n-slate-10 transition-colors duration-150 hover:bg-n-slate-3 hover:text-n-slate-12"
          :href="contactUrl"
          title="Ver contato"
          @click.stop
        >
          <span class="i-lucide-user size-3" />
        </a>

        <button
          type="button"
          class="grid size-7 place-content-center rounded-md border border-n-ruby-6 bg-n-ruby-2/0 text-n-ruby-9 transition-colors duration-150 hover:bg-n-ruby-2"
          title="Marcar como spam"
          @click.stop="emit('discardDeal', { deal, reason: 'spam' })"
        >
          <span class="i-lucide-ban size-3" />
        </button>

        <button
          type="button"
          class="grid size-7 place-content-center rounded-md border border-n-weak bg-n-slate-1 text-n-slate-10 transition-colors duration-150 hover:bg-n-slate-3 hover:text-n-slate-12"
          title="Marcar Cliente Base"
          @click.stop="emit('markBaseClient', deal)"
        >
          <span class="i-lucide-archive size-3" />
        </button>

        <button
          type="button"
          class="grid size-7 place-content-center rounded-md border border-n-ruby-6 bg-n-ruby-2/0 text-n-ruby-9 transition-colors duration-150 hover:bg-n-ruby-2"
          title="Excluir definitivamente"
          @click.stop="emit('delete-deal', deal)"
        >
          <span class="i-lucide-trash-2 size-3" />
        </button>
      </div>
    </div>
  </article>
</template>
