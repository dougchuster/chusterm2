<script setup>
defineProps({
  item: {
    type: Object,
    required: true,
  },
});
</script>

<template>
  <tr class="base-table-row">
    <slot :item="item" />
  </tr>
</template>

<style scoped>
.base-table-row {
  transition: transform 0.18s ease;
}

.base-table-row:hover,
.base-table-row:focus-within {
  transform: translateY(-1px);
}

.base-table-row:hover :deep(.base-table-cell),
.base-table-row:focus-within :deep(.base-table-cell) {
  border-color: rgba(var(--shell-border-strong));
  background: linear-gradient(
    180deg,
    rgb(var(--slate-2) / 0.92) 0%,
    rgb(var(--slate-1) / 0.7) 100%
  );
  box-shadow: 0 18px 34px rgb(var(--slate-1) / 0.12);
}
</style>
