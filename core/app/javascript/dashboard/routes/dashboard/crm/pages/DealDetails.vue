<script setup>
/**
 * F2.1 (b) do PLANO-KANBAN-CRM-2026.md — o par legacy/operational acabou.
 *
 * `DealDetailsLegacy.vue` foi apagado. O inventario da F0.2 listou duas
 * lacunas aqui, `deleteDeal` e `discardDeal`; so `discardDeal` era lacuna de
 * verdade — o `CRMDealDrawer`, que a pagina Operational ja renderiza, exclui o
 * negocio. O descarte foi portado antes de apagar.
 */
import DealDetailsOperational from './DealDetailsOperational.vue';
</script>

<template>
  <DealDetailsOperational />
</template>
