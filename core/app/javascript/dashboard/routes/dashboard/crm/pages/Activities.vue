<script setup>
/**
 * F2.1 (a) do PLANO-KANBAN-CRM-2026.md — o par legacy/operational acabou.
 *
 * `ActivitiesLegacy.vue` foi apagado: o inventario da F0.2 registrou paridade
 * total de API entre os dois, o `crm_v2` esta ligado em todas as contas
 * (inclusive na de producao) e o Legacy era codigo morto em runtime. O
 * wrapper de feature flag some junto — nao ha mais dois caminhos a escolher.
 */
import ActivitiesOperational from './ActivitiesOperational.vue';
</script>

<template>
  <ActivitiesOperational />
</template>
