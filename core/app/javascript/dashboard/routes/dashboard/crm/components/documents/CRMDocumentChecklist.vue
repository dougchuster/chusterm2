<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { computed, ref, watch } from 'vue';

import CrmDocumentsAPI from 'dashboard/api/crmDocuments';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { useAlert } from 'dashboard/composables';
import { DsSelect } from 'dashboard/design-system/components';

// "X de Y" do negócio (PROJETO-COFRE-DOCUMENTOS.md §8.6): o que falta sem
// reler a conversa. `refreshKey` muda quando os documentos mudam.
const props = defineProps({
  dealId: { type: Number, required: true },
  refreshKey: { type: Number, default: 0 },
});

const checklist = ref(null);
const open = ref(false);

const STATUS = {
  approved: {
    icon: 'i-lucide-circle-check',
    tone: 'text-ui-success-foreground',
    label: 'Aprovado',
  },
  received: {
    icon: 'i-lucide-circle-check',
    tone: 'text-ui-success-foreground',
    label: 'Recebido',
  },
  manual: {
    icon: 'i-lucide-hand',
    tone: 'text-ui-success-foreground',
    label: 'Entregue em papel',
  },
  rejected: {
    icon: 'i-lucide-circle-x',
    tone: 'text-ui-danger-foreground',
    label: 'Rejeitado',
  },
  missing: {
    icon: 'i-lucide-circle-dashed',
    tone: 'text-ui-text-muted',
    label: 'Falta',
  },
};

const percent = computed(() =>
  checklist.value?.total
    ? Math.round((checklist.value.done / checklist.value.total) * 100)
    : 0
);
const missing = computed(() =>
  (checklist.value?.items || []).filter(item =>
    ['missing', 'rejected'].includes(item.status)
  )
);
const templateOptions = computed(() => [
  { value: '', label: 'Sem checklist' },
  ...(checklist.value?.templates || []).map(t => ({
    value: t.id,
    label: t.name,
  })),
]);

const load = async () => {
  try {
    const { data } = await CrmDocumentsAPI.getChecklist(props.dealId);
    checklist.value = data;
  } catch {
    checklist.value = null;
  }
};

const save = async payload => {
  try {
    const { data } = await CrmDocumentsAPI.updateChecklist(
      props.dealId,
      payload
    );
    checklist.value = data;
  } catch (err) {
    useAlert(
      err?.response?.data?.error || 'Não foi possível atualizar o checklist.'
    );
  }
};

const itemLabel = item =>
  item.required ? `${item.title} · obrigatório` : item.title;

const chooseTemplate = value =>
  save({ template_id: value ? Number(value) : null });
const toggleManual = item =>
  save({ mark: { key: item.key, done: item.status !== 'manual' } });

watch(() => [props.dealId, props.refreshKey], load, { immediate: true });
</script>

<template>
  <div>
    <section
      v-if="checklist"
      class="border-b border-ui-border-subtle px-3 py-2.5"
      aria-label="Checklist de documentos"
    >
      <div class="flex flex-wrap items-center gap-x-3 gap-y-2">
        <button
          v-if="checklist.total"
          type="button"
          class="flex min-w-0 flex-1 items-center gap-3 text-left"
          :aria-expanded="open"
          @click="open = !open"
        >
          <span class="text-ui-body-sm font-medium text-ui-text"
            >Documentos do caso</span
          >
          <span
            class="h-2 min-w-24 flex-1 overflow-hidden rounded-full bg-ui-sunken"
            role="progressbar"
            :aria-valuenow="checklist.done"
            aria-valuemin="0"
            :aria-valuemax="checklist.total"
          >
            <span
              class="block h-full rounded-full bg-ui-success transition-all"
              :style="{ width: `${percent}%` }"
            />
          </span>
          <span
            class="shrink-0 font-mono text-ui-body-sm tabular-nums text-ui-text"
          >
            {{ checklist.done }} de {{ checklist.total }}
          </span>
          <Icon
            :icon="open ? 'i-lucide-chevron-up' : 'i-lucide-chevron-down'"
            class="size-4 shrink-0 text-ui-text-muted"
          />
        </button>
        <span v-else class="flex-1 text-ui-body-sm text-ui-text-muted">
          Escolha um checklist para ver o que falta.
        </span>
        <div class="w-full sm:w-64">
          <DsSelect
            id="crm-doc-checklist-template"
            :model-value="checklist.template_id || ''"
            label="Checklist"
            hide-label
            :options="templateOptions"
            @update:model-value="chooseTemplate"
          />
        </div>
      </div>
      <p
        v-if="checklist.total && !open && missing.length"
        class="m-0 mt-1.5 text-ui-caption text-ui-text-muted"
      >
        Faltam: {{ missing.map(item => item.title).join(', ') }}
      </p>
      <ul v-if="open" class="m-0 mt-2 flex list-none flex-col gap-1 p-0">
        <li
          v-for="item in checklist.items"
          :key="item.key"
          class="flex items-center gap-2 text-ui-body-sm"
        >
          <Icon
            :icon="STATUS[item.status].icon"
            class="size-4 shrink-0"
            :class="STATUS[item.status].tone"
          />
          <span class="min-w-0 flex-1 text-ui-text">{{ itemLabel(item) }}</span>
          <span class="text-ui-caption" :class="STATUS[item.status].tone">{{
            STATUS[item.status].label
          }}</span>
          <button
            v-if="['missing', 'manual'].includes(item.status)"
            type="button"
            class="text-ui-caption text-ui-text-muted underline-offset-2 hover:text-ui-text hover:underline"
            @click="toggleManual(item)"
          >
            {{ item.status === 'manual' ? 'Desfazer' : 'Entregue em papel' }}
          </button>
        </li>
      </ul>
    </section>
  </div>
</template>
