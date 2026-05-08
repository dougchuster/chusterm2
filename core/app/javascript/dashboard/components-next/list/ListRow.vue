<script setup>
import { computed } from 'vue';

const props = defineProps({
  interactive: { type: Boolean, default: false },
  density: {
    type: String,
    default: 'comfortable',
    validator: v => ['compact', 'comfortable', 'spacious'].includes(v),
  },
  as: { type: String, default: 'div' },
});

const emit = defineEmits(['click']);

const DENSITY_CLASSES = {
  compact: 'py-2 px-3 gap-3',
  comfortable: 'py-3 px-4 gap-4',
  spacious: 'py-4 px-6 gap-4',
};

const densityClass = computed(() => DENSITY_CLASSES[props.density]);
const interactiveClass = computed(() =>
  props.interactive
    ? 'cursor-pointer transition-colors hover:bg-ds-bg-hover focus-visible:outline focus-visible:outline-2 focus-visible:-outline-offset-2 focus-visible:outline-ds-border-focus'
    : ''
);

const handleKeydown = e => {
  if (!props.interactive) return;
  if (e.key === 'Enter' || e.key === ' ') {
    e.preventDefault();
    emit('click', e);
  }
};
</script>

<template>
  <component
    :is="as"
    class="flex items-center w-full"
    :class="[densityClass, interactiveClass]"
    :role="interactive ? 'button' : undefined"
    :tabindex="interactive ? 0 : undefined"
    @click="interactive && emit('click', $event)"
    @keydown="handleKeydown"
  >
    <slot name="leading" />
    <div class="flex-1 min-w-0 flex flex-col gap-0.5">
      <slot>
        <div class="flex items-baseline gap-2 min-w-0">
          <span
            v-if="$slots.title"
            class="text-sm font-medium text-ds-fg-default truncate"
          >
            <slot name="title" />
          </span>
          <span v-if="$slots.meta" class="text-xs text-ds-fg-muted truncate">
            <slot name="meta" />
          </span>
        </div>
        <span
          v-if="$slots.description"
          class="text-xs text-ds-fg-muted truncate"
        >
          <slot name="description" />
        </span>
      </slot>
    </div>
    <slot name="trailing" />
  </component>
</template>
