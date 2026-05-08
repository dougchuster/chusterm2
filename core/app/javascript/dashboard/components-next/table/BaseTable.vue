<script setup>
import { computed } from 'vue';

const props = defineProps({
  headers: {
    type: Array,
    default: () => [],
  },
  items: {
    type: Array,
    default: () => [],
  },
  noDataMessage: {
    type: String,
    default: '',
  },
  loading: {
    type: Boolean,
    default: false,
  },
});

const hasHeaderSlot = computed(() => !!props.headers.length);
const showHeaders = computed(
  () => hasHeaderSlot.value && props.items.length > 0
);
const columnCount = computed(() => props.headers.length || 1);
</script>

<template>
  <div class="base-table w-full">
    <div class="base-table__surface">
      <div class="base-table__scroller">
        <table class="base-table__table min-w-full table-auto">
          <thead v-if="showHeaders" class="base-table__head">
            <tr class="base-table__head-row">
              <th
                v-for="(header, index) in headers"
                :key="index"
                class="base-table__header py-3 ltr:pr-4 rtl:pl-4 text-start capitalize"
              >
                <slot :name="`header-${index}`" :header="header">
                  {{ header }}
                </slot>
              </th>
            </tr>
          </thead>
          <tbody class="base-table__body text-n-slate-11">
            <template v-if="items.length">
              <slot name="row" :items="items" />
            </template>
            <tr v-else-if="noDataMessage && !loading">
              <td
                :colspan="columnCount"
                class="base-table__empty py-16 text-center text-base text-n-slate-11"
              >
                <div class="base-table__empty-state mx-auto max-w-md">
                  <span class="base-table__empty-eyebrow">Operational space</span>
                  <p class="mb-0 mt-4 text-sm leading-7 text-n-slate-11 sm:text-base">
                    {{ noDataMessage }}
                  </p>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<style scoped>
.base-table__surface {
  position: relative;
  overflow: hidden;
  border: 1px solid rgba(var(--shell-border));
  border-radius: 1.4rem;
  background: linear-gradient(
    180deg,
    rgb(var(--slate-2) / 0.56) 0%,
    rgb(var(--slate-1) / 0.32) 100%
  );
  box-shadow:
    inset 0 1px 0 rgb(255 255 255 / 0.04),
    0 24px 60px rgba(var(--shell-shadow));
}

.base-table__surface::before {
  content: '';
  position: absolute;
  inset: 0;
  pointer-events: none;
  background:
    radial-gradient(circle at top right, rgba(var(--shell-glow-primary)) 0%, transparent 28%),
    linear-gradient(180deg, rgb(255 255 255 / 0.035), transparent 24%);
}

.base-table__scroller {
  position: relative;
  overflow-x: auto;
  padding: 0.4rem 0.75rem 0.85rem;
}

.base-table__table {
  border-collapse: separate;
  border-spacing: 0 0.55rem;
}

.base-table__head {
  position: relative;
  z-index: 1;
}

.base-table__head-row {
  transform: translateY(0.1rem);
}

.base-table__header {
  padding-top: 0.5rem;
  padding-bottom: 0.75rem;
  font-family: Inter, system-ui, sans-serif;
  font-size: 0.72rem;
  font-weight: 700;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: rgb(var(--slate-10));
  white-space: nowrap;
}

.base-table__body {
  position: relative;
  z-index: 1;
}

.base-table__empty {
  padding-left: 1rem;
  padding-right: 1rem;
}

.base-table__empty-state {
  border: 1px dashed rgba(var(--shell-border-strong));
  border-radius: 1.2rem;
  padding: 2rem 1.5rem;
  background: rgb(var(--slate-2) / 0.45);
}

.base-table__empty-eyebrow {
  display: inline-flex;
  align-items: center;
  border-radius: 9999px;
  border: 1px solid rgba(var(--shell-border));
  padding: 0.4rem 0.8rem;
  font-size: 0.72rem;
  font-weight: 700;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: rgb(var(--slate-10));
}
</style>
