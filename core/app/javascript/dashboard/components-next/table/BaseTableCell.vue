<script setup>
defineProps({
  align: {
    type: String,
    default: 'start',
    validator: value => ['start', 'center', 'end'].includes(value),
  },
});
</script>

<template>
  <td
    class="base-table-cell py-4 ltr:pr-4 rtl:pl-4 text-body-main"
    :class="{
      'text-start': align === 'start',
      'text-center': align === 'center',
      'text-end': align === 'end',
    }"
  >
    <slot />
  </td>
</template>

<style scoped>
.base-table-cell {
  vertical-align: top;
  border-top: 1px solid rgba(var(--shell-border));
  border-bottom: 1px solid rgba(var(--shell-border));
  background: linear-gradient(
    180deg,
    rgb(var(--slate-2) / 0.78) 0%,
    rgb(var(--slate-1) / 0.58) 100%
  );
  font-size: 0.92rem;
  line-height: 1.6;
  transition:
    background 0.18s ease,
    border-color 0.18s ease,
    box-shadow 0.18s ease;
}

.base-table-cell:first-child {
  padding-left: 1rem;
  border-left: 1px solid rgba(var(--shell-border));
  border-radius: 1rem 0 0 1rem;
}

.base-table-cell:last-child {
  padding-right: 1rem;
  border-right: 1px solid rgba(var(--shell-border));
  border-radius: 0 1rem 1rem 0;
}
</style>
