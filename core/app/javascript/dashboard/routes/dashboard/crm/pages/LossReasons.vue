<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { ref, onMounted } from 'vue';
import CrmAPI from '../../../../api/crm';

const lossReasons = ref([]);
const loading = ref(false);
const newReason = ref('');

async function loadReasons() {
  loading.value = true;
  try {
    const { data } = await CrmAPI.getLossReasons();
    lossReasons.value = data || [];
  } finally {
    loading.value = false;
  }
}

async function addReason() {
  if (!newReason.value.trim()) return;
  await CrmAPI.createLossReason({ name: newReason.value.trim() });
  newReason.value = '';
  await loadReasons();
}

onMounted(loadReasons);
</script>

<template>
  <main class="crm-loss-reasons">
    <header class="crm-loss-reasons__header">
      <div>
        <p>Configuração CRM</p>
        <h1>Motivos de Perda</h1>
        <span>Padronize os motivos usados para fechar leads perdidos.</span>
      </div>
    </header>

    <section class="crm-loss-reasons__form">
      <input
        v-model="newReason"
        type="text"
        placeholder="Novo motivo de perda..."
        @keyup.enter="addReason"
      />
      <button @click="addReason">Adicionar</button>
    </section>

    <div v-if="loading" class="crm-loss-reasons__state">Carregando...</div>
    <ul v-else class="crm-loss-reasons__list">
      <li v-for="reason in lossReasons" :key="reason.id">
        <span>{{ reason.name }}</span>
        <small v-if="reason.legal_area">{{ reason.legal_area }}</small>
      </li>
    </ul>
  </main>
</template>

<style scoped>
.crm-loss-reasons {
  display: flex;
  width: 100%;
  min-width: 0;
  min-height: 100%;
  flex-direction: column;
  gap: 1rem;
  overflow-x: hidden;
  padding: clamp(1rem, 2vw, 1.5rem);
  color: rgb(var(--slate-12));
}

.crm-loss-reasons__header,
.crm-loss-reasons__form,
.crm-loss-reasons__list li,
.crm-loss-reasons__state {
  border: 1px solid rgb(var(--slate-4));
  border-radius: 8px;
  background: rgb(var(--slate-1));
}

.crm-loss-reasons__header {
  padding: 1rem;
}

.crm-loss-reasons__header p {
  margin: 0 0 0.25rem;
  color: rgb(var(--brand-9));
  font-size: 0.75rem;
  font-weight: 800;
  text-transform: uppercase;
}

.crm-loss-reasons__header h1 {
  margin: 0;
  font-size: 1.5rem;
  font-weight: 800;
}

.crm-loss-reasons__header span {
  display: block;
  margin-top: 0.25rem;
  color: rgb(var(--slate-10));
  font-size: 0.875rem;
}

.crm-loss-reasons__form {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  gap: 0.75rem;
  padding: 1rem;
}

.crm-loss-reasons__form input {
  min-width: 0;
  height: 2.5rem;
  border: 1px solid rgb(var(--slate-5));
  border-radius: 8px;
  padding: 0 0.75rem;
  color: rgb(var(--slate-12));
  background: rgb(var(--slate-2));
  outline: none;
}

.crm-loss-reasons__form button {
  min-height: 2.5rem;
  border-radius: 8px;
  padding: 0 1rem;
  color: white;
  font-size: 0.875rem;
  font-weight: 800;
  background: rgb(var(--brand-9));
}

.crm-loss-reasons__state {
  padding: 2rem;
  color: rgb(var(--slate-10));
  text-align: center;
}

.crm-loss-reasons__list {
  display: grid;
  gap: 0.5rem;
  padding: 0;
  margin: 0;
  list-style: none;
}

.crm-loss-reasons__list li {
  display: flex;
  min-width: 0;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  padding: 0.85rem 1rem;
  font-size: 0.875rem;
}

.crm-loss-reasons__list span {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.crm-loss-reasons__list small {
  flex-shrink: 0;
  color: rgb(var(--slate-9));
}

@media (max-width: 640px) {
  .crm-loss-reasons__form {
    grid-template-columns: 1fr;
  }
}
</style>
