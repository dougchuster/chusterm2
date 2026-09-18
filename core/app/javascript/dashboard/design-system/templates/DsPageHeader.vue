<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import DsSkeleton from '../components/DsSkeleton.vue';

defineProps({
  title: { type: String, required: true },
  breadcrumbs: { type: Array, default: () => [] },
  description: { type: String, default: '' },
  loading: { type: Boolean, default: false },
});

const BREADCRUMB_NAV_LABEL = 'Navegação estrutural';
</script>

<template>
  <header
    class="flex min-h-16 shrink-0 flex-col justify-center gap-3 border-b border-ui-border-subtle bg-ui-surface px-4 py-3 sm:px-6 lg:flex-row lg:items-center lg:justify-between"
  >
    <div class="min-w-0">
      <DsSkeleton v-if="loading" class="h-5 w-48" />
      <template v-else>
        <nav
          v-if="breadcrumbs.length"
          :aria-label="BREADCRUMB_NAV_LABEL"
          class="mb-1 flex min-w-0 items-center gap-1 text-ui-caption text-ui-text-muted"
        >
          <template
            v-for="(breadcrumb, index) in breadcrumbs"
            :key="`${breadcrumb.label}-${index}`"
          >
            <span v-if="index" aria-hidden="true" class="text-ui-text-subtle">
              /
            </span>
            <a
              v-if="breadcrumb.href && index < breadcrumbs.length - 1"
              :href="breadcrumb.href"
              class="truncate rounded-ui-control hover:text-ui-text focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ui-border-focus"
            >
              {{ breadcrumb.label }}
            </a>
            <span
              v-else
              class="truncate"
              :aria-current="
                index === breadcrumbs.length - 1 ? 'page' : undefined
              "
            >
              {{ breadcrumb.label }}
            </span>
          </template>
        </nav>
        <h1 class="m-0 truncate text-ui-title font-semibold text-ui-text">
          {{ title }}
        </h1>
        <p
          v-if="description"
          class="mt-1 max-w-3xl text-ui-body-sm text-ui-text-muted"
        >
          {{ description }}
        </p>
      </template>
    </div>

    <div
      v-if="$slots.actions"
      class="flex shrink-0 flex-wrap items-center gap-2 lg:justify-end"
    >
      <slot name="actions" />
    </div>
  </header>
</template>
