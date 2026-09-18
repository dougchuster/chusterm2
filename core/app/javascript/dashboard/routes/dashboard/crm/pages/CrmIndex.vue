<script setup>
/**
 * F2.1 (d) do PLANO-KANBAN-CRM-2026.md — o ultimo par legacy/operational caiu.
 *
 * `CrmIndexLegacy.vue` foi apagado depois de a F2.1-a levar o
 * `CRMConversationPanel` para o board Operational: sem isso, apagar o Legacy
 * tiraria do produto a unica tela onde o atendente responde no WhatsApp sem sair
 * do Kanban — item n. 2 do goal.
 *
 * Das 10 lacunas que o inventario da F0.2 listou, tres eram reais (descartar,
 * cliente da base, recalcular score) e foram portadas antes. `getActivities`
 * nao era lacuna: o board ja le `next_activity_due_at` do proprio negocio.
 */
import CrmIndexOperational from './CrmIndexOperational.vue';
</script>

<template>
  <CrmIndexOperational />
</template>
