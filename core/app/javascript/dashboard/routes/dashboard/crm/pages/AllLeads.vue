<script setup>
/**
 * F2.1 (c) do PLANO-KANBAN-CRM-2026.md — o par legacy/operational acabou.
 *
 * `AllLeadsLegacy.vue` foi apagado. O inventario da F0.2 listou 7 lacunas; pelo
 * metodo corrigido na etapa (b) — que conta tambem o que a pagina alcanca pelos
 * componentes que renderiza — eram 4. `deleteDeal`, `markDealWon` e
 * `updateDeal` ja vinham do `CRMDealDrawer`. As quatro reais (mover de etapa,
 * descartar, cliente da base, recalcular score) foram portadas antes de apagar.
 */
import AllLeadsOperational from './AllLeadsOperational.vue';
</script>

<template>
  <AllLeadsOperational />
</template>
