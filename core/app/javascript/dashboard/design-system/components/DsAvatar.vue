<script setup>
import { computed, ref, watch } from 'vue';

import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  src: { type: String, default: '' },
  name: { type: String, required: true },
  size: {
    type: String,
    default: 'md',
    validator: value => ['sm', 'md', 'lg'].includes(value),
  },
  status: {
    type: String,
    default: '',
    validator: value => ['', 'online', 'away', 'offline'].includes(value),
  },
  disabled: { type: Boolean, default: false },
  loading: { type: Boolean, default: false },
});

const imageValid = ref(true);

const initials = computed(() =>
  props.name
    .trim()
    .split(/\s+/)
    .slice(0, 2)
    .map(part => part.charAt(0).toUpperCase())
    .join('')
);

const sizeClasses = computed(
  () =>
    ({
      sm: 'size-6 text-ui-caption',
      md: 'size-8 text-ui-body-sm',
      lg: 'size-10 text-ui-body',
    })[props.size]
);

const statusClasses = computed(
  () =>
    ({
      online: 'bg-ui-success',
      away: 'bg-ui-warning',
      offline: 'bg-ui-text-subtle',
    })[props.status]
);

watch(
  () => props.src,
  () => {
    imageValid.value = true;
  }
);
</script>

<template>
  <span
    class="relative inline-flex shrink-0"
    :class="{ 'opacity-60': disabled }"
    :aria-busy="loading || undefined"
  >
    <span
      role="img"
      :aria-label="name"
      class="flex items-center justify-center overflow-hidden rounded-full bg-ui-brand-soft font-medium text-ui-brand"
      :class="[sizeClasses, { 'animate-pulse': loading }]"
    >
      <img
        v-if="src && imageValid && !loading"
        :src="src"
        :alt="name"
        class="size-full object-cover"
        @error="imageValid = false"
      />
      <span v-else-if="!loading && initials">{{ initials }}</span>
      <Icon
        v-else-if="!loading"
        icon="i-lucide-user"
        class="size-1/2"
        aria-hidden="true"
      />
    </span>
    <span
      v-if="status && !loading"
      class="absolute bottom-0 right-0 size-2 rounded-full ring-2 ring-ui-surface"
      :class="statusClasses"
      aria-hidden="true"
    />
  </span>
</template>
