<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { computed, ref } from 'vue';

import Icon from 'dashboard/components-next/icon/Icon.vue';
import {
  DsCheckbox,
  DsInput,
  DsSelect,
  DsTextarea,
} from 'dashboard/design-system/components';
import {
  CHOICE_TYPES,
  FIELD_TYPES,
  MAPS_TO,
  conditionValues,
} from './formBuilder';

// Uma linha do construtor: um campo do formulário (kind="field") ou um
// documento pedido (kind="item"). Resumo fechado; detalhes ao abrir.
const props = defineProps({
  kind: {
    type: String,
    required: true,
    validator: value => ['field', 'item'].includes(value),
  },
  entry: { type: Object, required: true },
  index: { type: Number, required: true },
  total: { type: Number, required: true },
  conditionFields: { type: Array, default: () => [] },
  documentTypes: { type: Array, default: () => [] },
  startOpen: { type: Boolean, default: false },
});

const emit = defineEmits(['update', 'move', 'remove']);

const open = ref(props.startOpen);
const id = suffix => `${props.kind}-${props.index}-${suffix}`;

const set = (key, value) => emit('update', { ...props.entry, [key]: value });

const typeLabel = computed(
  () => FIELD_TYPES.find(type => type.value === props.entry.type)?.label
);
const docTypeLabel = computed(
  () =>
    props.documentTypes.find(type => type.slug === props.entry.doc_type)?.label
);
const docTypeOptions = computed(() => [
  { value: '', label: 'Sem tipo (a equipe classifica)' },
  ...props.documentTypes.map(type => ({ value: type.slug, label: type.label })),
]);
const conditionOptions = computed(() => [
  { value: '', label: 'Sempre mostrar' },
  ...props.conditionFields.map(field => ({
    value: field.key,
    label: `Quando "${field.label}" for…`,
  })),
]);
const conditionSource = computed(() =>
  props.conditionFields.find(field => field.key === props.entry.show_if?.field)
);
const optionsText = computed(() => (props.entry.options || []).join('\n'));

const setOptions = text =>
  set(
    'options',
    text
      .split('\n')
      .map(option => option.trim())
      .filter(Boolean)
  );

const setConditionField = fieldKey =>
  set(
    'show_if',
    fieldKey
      ? {
          field: fieldKey,
          equals:
            conditionValues(
              props.conditionFields.find(f => f.key === fieldKey)
            )[0] || '',
        }
      : undefined
  );
</script>

<template>
  <li class="rounded-ui-control border border-ui-border bg-ui-surface">
    <div class="flex items-center gap-2 px-3 py-2">
      <button
        type="button"
        class="flex min-w-0 flex-1 items-center gap-2 text-left"
        :aria-expanded="open"
        @click="open = !open"
      >
        <Icon
          :icon="open ? 'i-lucide-chevron-down' : 'i-lucide-chevron-right'"
          class="size-4 shrink-0 text-ui-text-muted"
        />
        <span class="min-w-0 flex-1">
          <span class="block truncate text-ui-body-sm font-medium text-ui-text">
            {{ entry.label || 'Sem nome'
            }}<span v-if="entry.required" class="text-ui-danger-foreground">
              *</span
            >
          </span>
          <span class="block truncate text-ui-caption text-ui-text-muted">
            {{ kind === 'field' ? typeLabel : docTypeLabel || 'Sem tipo' }}
            <template v-if="entry.maps_to"> · ligado ao cadastro</template>
            <template v-if="entry.show_if"> · condicional</template>
            <template v-if="kind === 'item' && entry.multiple">
              · vários arquivos</template
            >
          </span>
        </span>
      </button>
      <button
        type="button"
        class="grid size-8 place-items-center rounded-ui-control hover:bg-ui-hover disabled:opacity-40"
        :disabled="index === 0"
        :aria-label="`Subir ${entry.label}`"
        @click="emit('move', -1)"
      >
        <Icon icon="i-lucide-arrow-up" class="size-4" />
      </button>
      <button
        type="button"
        class="grid size-8 place-items-center rounded-ui-control hover:bg-ui-hover disabled:opacity-40"
        :disabled="index === total - 1"
        :aria-label="`Descer ${entry.label}`"
        @click="emit('move', 1)"
      >
        <Icon icon="i-lucide-arrow-down" class="size-4" />
      </button>
      <button
        type="button"
        class="grid size-8 place-items-center rounded-ui-control text-ui-danger-foreground hover:bg-ui-hover"
        :aria-label="`Remover ${entry.label}`"
        @click="emit('remove')"
      >
        <Icon icon="i-lucide-trash-2" class="size-4" />
      </button>
    </div>

    <div
      v-if="open"
      class="grid gap-3 border-t border-ui-border-subtle p-3 sm:grid-cols-2"
    >
      <DsInput
        :id="id('label')"
        :model-value="entry.label"
        :label="kind === 'field' ? 'Pergunta' : 'Documento pedido'"
        class="sm:col-span-2"
        @update:model-value="set('label', $event)"
      />
      <template v-if="kind === 'field'">
        <DsSelect
          :id="id('type')"
          :model-value="entry.type"
          label="Tipo de resposta"
          :options="FIELD_TYPES"
          @update:model-value="set('type', $event)"
        />
        <DsSelect
          :id="id('maps')"
          :model-value="entry.maps_to || ''"
          label="Guardar no cadastro do contato"
          :options="MAPS_TO"
          @update:model-value="set('maps_to', $event || undefined)"
        />
        <DsTextarea
          v-if="CHOICE_TYPES.includes(entry.type)"
          :id="id('options')"
          :model-value="optionsText"
          label="Opções (uma por linha)"
          class="sm:col-span-2"
          @update:model-value="setOptions"
        />
        <DsInput
          :id="id('placeholder')"
          :model-value="entry.placeholder || ''"
          label="Exemplo dentro do campo (opcional)"
          @update:model-value="set('placeholder', $event || undefined)"
        />
      </template>
      <template v-else>
        <DsSelect
          :id="id('doctype')"
          :model-value="entry.doc_type || ''"
          label="Tipo no cofre"
          :options="docTypeOptions"
          @update:model-value="set('doc_type', $event || undefined)"
        />
        <DsCheckbox
          :id="id('multiple')"
          :model-value="Boolean(entry.multiple)"
          label="Aceita vários arquivos"
          description="Ex.: frente e verso, várias páginas."
          @update:model-value="set('multiple', $event)"
        />
      </template>
      <DsInput
        :id="id('help')"
        :model-value="entry.help || ''"
        label="Explicação para o cliente (opcional)"
        @update:model-value="set('help', $event || undefined)"
      />
      <DsCheckbox
        :id="id('required')"
        :model-value="Boolean(entry.required)"
        label="Obrigatório"
        @update:model-value="set('required', $event)"
      />
      <DsSelect
        :id="id('condition')"
        :model-value="entry.show_if?.field || ''"
        label="Mostrar"
        :options="conditionOptions"
        @update:model-value="setConditionField"
      />
      <DsSelect
        v-if="conditionSource"
        :id="id('condition-value')"
        :model-value="entry.show_if?.equals || ''"
        label="…igual a"
        :options="
          conditionValues(conditionSource).map(value => ({
            value,
            label: value === 'true' ? 'marcado' : value,
          }))
        "
        @update:model-value="
          set('show_if', { field: entry.show_if.field, equals: $event })
        "
      />
    </div>
  </li>
</template>
