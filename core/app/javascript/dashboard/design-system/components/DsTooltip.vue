<script setup>
import { computed, getCurrentInstance } from 'vue';

const props = defineProps({
  text: { type: String, required: true },
  placement: {
    type: String,
    default: 'top',
    validator: value => ['top', 'bottom', 'left', 'right'].includes(value),
  },
  disabled: { type: Boolean, default: false },
});

const { uid } = getCurrentInstance();
const tooltipId = `ds-tooltip-${uid}`;

const placementClasses = computed(
  () =>
    ({
      top: 'bottom-full left-1/2 mb-2 -translate-x-1/2',
      bottom: 'left-1/2 top-full mt-2 -translate-x-1/2',
      left: 'right-full top-1/2 mr-2 -translate-y-1/2',
      right: 'left-full top-1/2 ml-2 -translate-y-1/2',
    })[props.placement]
);
</script>

<template>
  <span class="group/tooltip relative inline-flex">
    <slot :tooltip-id="disabled ? undefined : tooltipId" />
    <span
      v-if="!disabled"
      :id="tooltipId"
      role="tooltip"
      class="pointer-events-none absolute z-ui-overlay hidden max-w-64 whitespace-nowrap rounded-ui-control bg-ui-text px-2 py-1 text-ui-caption text-ui-surface shadow-ui-raised group-hover/tooltip:block group-focus-within/tooltip:block"
      :class="placementClasses"
    >
      {{ text }}
    </span>
  </span>
</template>
