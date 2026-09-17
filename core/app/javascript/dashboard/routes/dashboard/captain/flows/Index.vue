<script setup>
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import PageLayout from 'dashboard/components-next/captain/PageLayout.vue';

const store = useStore();
const router = useRouter();

const uiFlags = useMapGetter('captainFlows/getUIFlags');
const flows = useMapGetter('captainFlows/getRecords');

const isFetching = computed(() => uiFlags.value.fetchingList);
const isCreating = computed(() => uiFlags.value.creatingItem);
const isUpdating = computed(() => uiFlags.value.updatingItem);
const isDeleting = computed(() => uiFlags.value.deletingItem);

const showCreateModal = ref(false);
const newFlowName = ref('');
const newFlowDescription = ref('');

const statusBadgeClass = status => {
  if (status === 'published') return 'bg-n-teal-3 text-n-teal-11';
  return 'bg-n-slate-3 text-n-slate-11';
};

const statusLabel = status => {
  if (status === 'published') return 'Publicado';
  return 'Rascunho';
};

const openCreateModal = () => {
  newFlowName.value = '';
  newFlowDescription.value = '';
  showCreateModal.value = true;
};

const closeCreateModal = () => {
  showCreateModal.value = false;
};

const handleCreate = async () => {
  if (!newFlowName.value.trim()) return;
  await store.dispatch('captainFlows/create', {
    name: newFlowName.value.trim(),
    description: newFlowDescription.value.trim(),
  });
  showCreateModal.value = false;
};

const handlePublish = async id => {
  await store.dispatch('captainFlows/publish', id);
};

const handleEdit = flow => {
  router.push({ name: 'captain_flow_editor', params: { flowId: flow.id } });
};

const handleDelete = async id => {
  await store.dispatch('captainFlows/delete', id);
};

onMounted(() => {
  store.dispatch('captainFlows/get');
});
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
  <PageLayout
    header-title="Fluxos de Atendimento"
    :is-fetching="isFetching"
    :show-know-more="false"
    :show-pagination-footer="false"
    :show-assistant-switcher="false"
  >
    <template #body>
      <div class="flex flex-col gap-4">
        <div class="flex justify-end">
          <button
            class="inline-flex items-center gap-2 px-4 py-2 rounded-lg bg-n-brand text-white text-sm font-medium hover:brightness-110 transition-all disabled:opacity-60"
            :disabled="isCreating"
            @click="openCreateModal"
          >
            <span class="i-lucide-plus size-4" />
            Novo fluxo
          </button>
        </div>

        <div
          v-if="flows.length === 0"
          class="py-10 text-center text-n-slate-11 text-sm"
        >
          Nenhum fluxo criado ainda. Clique em "Novo fluxo" para começar.
        </div>

        <div v-else class="flex flex-col gap-3">
          <div
            v-for="flow in flows"
            :key="flow.id"
            class="flex items-start justify-between gap-4 p-4 rounded-lg border border-ui-border-subtle bg-n-surface-1"
          >
            <div class="flex flex-col gap-1 min-w-0">
              <div class="flex items-center gap-2">
                <span class="text-sm font-medium text-n-slate-12 truncate">
                  {{ flow.name }}
                </span>
                <span
                  class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium"
                  :class="statusBadgeClass(flow.status)"
                >
                  {{ statusLabel(flow.status) }}
                </span>
                <span
                  v-if="flow.version"
                  class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-n-slate-3 text-n-slate-11"
                >
                  v{{ flow.version }}
                </span>
              </div>
              <span
                v-if="flow.description"
                class="text-xs text-n-slate-11 line-clamp-2"
              >
                {{ flow.description }}
              </span>
            </div>

            <div class="flex items-center gap-2 flex-shrink-0">
              <button
                v-if="flow.status !== 'published'"
                class="inline-flex items-center gap-1 px-3 py-1.5 rounded-lg text-xs font-medium bg-n-teal-3 text-n-teal-11 hover:brightness-95 transition-all disabled:opacity-60"
                :disabled="isUpdating"
                @click="handlePublish(flow.id)"
              >
                <span class="i-lucide-send size-3.5" />
                Publicar
              </button>
              <button
                class="inline-flex items-center gap-1 px-3 py-1.5 rounded-lg text-xs font-medium bg-n-slate-3 text-n-slate-11 hover:bg-n-slate-4 transition-all"
                @click="handleEdit(flow)"
              >
                <span class="i-lucide-pencil size-3.5" />
                Editar
              </button>
              <button
                class="inline-flex items-center gap-1 px-3 py-1.5 rounded-lg text-xs font-medium bg-n-ruby-3 text-n-ruby-11 hover:brightness-95 transition-all disabled:opacity-60"
                :disabled="isDeleting"
                @click="handleDelete(flow.id)"
              >
                <span class="i-lucide-trash-2 size-3.5" />
                Excluir
              </button>
            </div>
          </div>
        </div>
      </div>
    </template>
  </PageLayout>

  <Teleport to="body">
    <div
      v-if="showCreateModal"
      class="fixed inset-0 z-50 flex items-center justify-center bg-black/40"
      @click.self="closeCreateModal"
    >
      <div
        class="w-full max-w-md rounded-xl bg-n-surface-1 border border-ui-border-subtle shadow-xl p-6 flex flex-col gap-4"
      >
        <div class="flex items-center justify-between">
          <h2 class="text-base font-semibold text-n-slate-12">Novo fluxo</h2>
          <button
            class="p-1 rounded text-n-slate-10 hover:text-n-slate-12 hover:bg-n-slate-3 transition-all"
            @click="closeCreateModal"
          >
            <span class="i-lucide-x size-4" />
          </button>
        </div>

        <div class="flex flex-col gap-3">
          <div class="flex flex-col gap-1">
            <label class="text-xs font-medium text-n-slate-11">Nome</label>
            <input
              v-model="newFlowName"
              type="text"
              placeholder="Nome do fluxo"
              class="w-full px-3 py-2 rounded-lg border border-ui-border-subtle bg-n-surface-1 text-sm text-n-slate-12 placeholder:text-n-slate-10 focus:outline-none focus:ring-2 focus:ring-n-brand/30 focus:border-n-brand transition-all"
            />
          </div>
          <div class="flex flex-col gap-1">
            <label class="text-xs font-medium text-n-slate-11">Descrição</label>
            <textarea
              v-model="newFlowDescription"
              rows="3"
              placeholder="Descrição opcional"
              class="w-full px-3 py-2 rounded-lg border border-ui-border-subtle bg-n-surface-1 text-sm text-n-slate-12 placeholder:text-n-slate-10 focus:outline-none focus:ring-2 focus:ring-n-brand/30 focus:border-n-brand transition-all resize-none"
            />
          </div>
        </div>

        <div class="flex justify-end gap-2">
          <button
            class="px-4 py-2 rounded-lg text-sm font-medium bg-n-slate-3 text-n-slate-11 hover:bg-n-slate-4 transition-all"
            @click="closeCreateModal"
          >
            Cancelar
          </button>
          <button
            class="px-4 py-2 rounded-lg text-sm font-medium bg-n-brand text-white hover:brightness-110 transition-all disabled:opacity-60"
            :disabled="!newFlowName.trim() || isCreating"
            @click="handleCreate"
          >
            Criar fluxo
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>
