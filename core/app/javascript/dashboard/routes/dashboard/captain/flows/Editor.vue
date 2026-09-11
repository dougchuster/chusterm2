<script setup>
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import PageLayout from 'dashboard/components-next/captain/PageLayout.vue';

const route = useRoute();
const router = useRouter();
const store = useStore();

const flowId = computed(() => Number(route.params.flowId));

const uiFlags = useMapGetter('captainFlows/getUIFlags');
const getRecord = useMapGetter('captainFlows/getRecord');

const isFetching = computed(() => uiFlags.value.fetchingItem);
const isUpdating = computed(() => uiFlags.value.updatingItem);

const currentFlow = computed(() => getRecord.value(flowId.value));

const nodes = ref([]);
const edges = ref([]);

const NODE_TYPES = [
  { value: 'start', label: 'Início' },
  { value: 'message', label: 'Mensagem' },
  { value: 'question', label: 'Pergunta' },
  { value: 'condition', label: 'Condição' },
  { value: 'score', label: 'Score' },
  { value: 'crm_action', label: 'Ação CRM' },
  { value: 'handoff', label: 'Transferência' },
  { value: 'end', label: 'Fim' },
];

const nodeBadgeClass = type => {
  const map = {
    start: 'bg-n-teal-3 text-n-teal-11',
    message:
      'bg-n-blue-3 text-n-blue-11 dark:bg-n-slate-4 dark:text-n-slate-11',
    question:
      'bg-n-amber-3 text-n-amber-11 dark:bg-n-slate-4 dark:text-n-slate-11',
    condition:
      'bg-n-amber-3 text-n-amber-11 dark:bg-n-slate-4 dark:text-n-slate-11',
    score:
      'bg-n-violet-3 text-n-violet-11 dark:bg-n-slate-4 dark:text-n-slate-11',
    crm_action:
      'bg-n-blue-3 text-n-blue-11 dark:bg-n-slate-4 dark:text-n-slate-11',
    handoff: 'bg-n-ruby-3 text-n-ruby-11',
    end: 'bg-n-slate-3 text-n-slate-11',
  };
  return map[type] || 'bg-n-slate-3 text-n-slate-11';
};

const nodeTypeLabel = type => {
  const found = NODE_TYPES.find(n => n.value === type);
  return found ? found.label : type;
};

const statusBadgeClass = status => {
  if (status === 'published') return 'bg-n-teal-3 text-n-teal-11';
  return 'bg-n-slate-3 text-n-slate-11';
};

const statusLabel = status => {
  if (status === 'published') return 'Publicado';
  return 'Rascunho';
};

const addNode = () => {
  nodes.value.push({
    node_id: `node_${Date.now()}`,
    node_type: 'message',
    position_x: 0,
    position_y: 0,
    config: { label: '' },
  });
};

const removeNode = index => {
  nodes.value.splice(index, 1);
};

const addEdge = () => {
  edges.value.push({
    edge_id: `edge_${Date.now()}`,
    source_node_id: '',
    target_node_id: '',
    label: '',
    condition: {},
  });
};

const removeEdge = index => {
  edges.value.splice(index, 1);
};

const handleSaveGraph = async () => {
  await store.dispatch('captainFlows/saveGraph', {
    id: flowId.value,
    nodes: nodes.value,
    edges: edges.value,
  });
};

const handlePublish = async () => {
  await store.dispatch('captainFlows/publish', flowId.value);
};

const handleBack = () => {
  router.push({ name: 'captain_flow_list' });
};

onMounted(async () => {
  const result = await store.dispatch('captainFlows/show', flowId.value);
  if (result) {
    nodes.value = result.nodes
      ? result.nodes.map(n => ({ ...n, config: n.config || { label: '' } }))
      : [];
    edges.value = result.edges ? result.edges.map(e => ({ ...e })) : [];
  }
});
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
  <PageLayout
    :header-title="currentFlow?.name || 'Editor de Fluxo'"
    :is-fetching="isFetching"
    :show-know-more="false"
    :show-pagination-footer="false"
    :show-assistant-switcher="false"
  >
    <template #body>
      <div class="flex flex-col gap-6">
        <div class="flex items-center justify-between gap-4 flex-wrap">
          <div class="flex items-center gap-3">
            <button
              class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium bg-n-slate-3 text-n-slate-11 hover:bg-n-slate-4 transition-all"
              @click="handleBack"
            >
              <span class="i-lucide-arrow-left size-3.5" />
              Voltar
            </button>
            <div v-if="currentFlow?.status" class="flex items-center gap-2">
              <span
                class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium"
                :class="statusBadgeClass(currentFlow.status)"
              >
                {{ statusLabel(currentFlow.status) }}
              </span>
              <span
                v-if="currentFlow?.version"
                class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-n-slate-3 text-n-slate-11"
              >
                v{{ currentFlow.version }}
              </span>
            </div>
          </div>

          <div class="flex items-center gap-2">
            <button
              class="inline-flex items-center gap-1.5 px-4 py-2 rounded-lg text-sm font-medium bg-n-slate-3 text-n-slate-11 hover:bg-n-slate-4 transition-all disabled:opacity-60"
              :disabled="isUpdating"
              @click="handleSaveGraph"
            >
              <span class="i-lucide-save size-4" />
              Salvar grafo
            </button>
            <button
              class="inline-flex items-center gap-1.5 px-4 py-2 rounded-lg text-sm font-medium bg-n-teal-3 text-n-teal-11 hover:brightness-95 transition-all disabled:opacity-60"
              :disabled="isUpdating"
              @click="handlePublish"
            >
              <span class="i-lucide-send size-4" />
              Publicar
            </button>
          </div>
        </div>

        <div class="flex flex-col gap-4">
          <div class="flex items-center justify-between">
            <h3 class="text-sm font-semibold text-n-slate-12">Nós</h3>
            <button
              class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium bg-n-brand text-white hover:brightness-110 transition-all"
              @click="addNode"
            >
              <span class="i-lucide-plus size-3.5" />
              Adicionar nó
            </button>
          </div>

          <div
            v-if="nodes.length === 0"
            class="py-6 text-center text-n-slate-11 text-sm rounded-lg border border-dashed border-n-weak"
          >
            Nenhum nó adicionado. Clique em "Adicionar nó" para começar.
          </div>

          <div v-else class="flex flex-col gap-3">
            <div
              v-for="(node, index) in nodes"
              :key="node.node_id"
              class="flex flex-col gap-3 p-4 rounded-lg border border-n-weak bg-n-surface-1"
            >
              <div class="flex items-center justify-between gap-2">
                <span
                  class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium"
                  :class="nodeBadgeClass(node.node_type)"
                >
                  {{ nodeTypeLabel(node.node_type) }}
                </span>
                <button
                  class="p-1 rounded text-n-slate-10 hover:text-n-ruby-11 hover:bg-n-ruby-3 transition-all"
                  @click="removeNode(index)"
                >
                  <span class="i-lucide-trash-2 size-3.5" />
                </button>
              </div>

              <div class="grid grid-cols-2 gap-3">
                <div class="flex flex-col gap-1">
                  <label class="text-xs font-medium text-n-slate-11"
                    >ID do nó</label
                  >
                  <input
                    v-model="node.node_id"
                    type="text"
                    placeholder="node_id"
                    class="w-full px-3 py-2 rounded-lg border border-n-weak bg-n-surface-1 text-sm text-n-slate-12 placeholder:text-n-slate-10 focus:outline-none focus:ring-2 focus:ring-n-brand/30 focus:border-n-brand transition-all"
                  />
                </div>

                <div class="flex flex-col gap-1">
                  <label class="text-xs font-medium text-n-slate-11"
                    >Tipo do nó</label
                  >
                  <select
                    v-model="node.node_type"
                    class="w-full px-3 py-2 rounded-lg border border-n-weak bg-n-surface-1 text-sm text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand/30 focus:border-n-brand transition-all"
                  >
                    <option
                      v-for="nt in NODE_TYPES"
                      :key="nt.value"
                      :value="nt.value"
                    >
                      {{ nt.label }}
                    </option>
                  </select>
                </div>
              </div>

              <div class="flex flex-col gap-1">
                <label class="text-xs font-medium text-n-slate-11">Label</label>
                <textarea
                  v-model="node.config.label"
                  rows="2"
                  placeholder="Texto exibido neste nó"
                  class="w-full px-3 py-2 rounded-lg border border-n-weak bg-n-surface-1 text-sm text-n-slate-12 placeholder:text-n-slate-10 focus:outline-none focus:ring-2 focus:ring-n-brand/30 focus:border-n-brand transition-all resize-none"
                />
              </div>
            </div>
          </div>
        </div>

        <div class="flex flex-col gap-4">
          <div class="flex items-center justify-between">
            <h3 class="text-sm font-semibold text-n-slate-12">Arestas</h3>
            <button
              class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium bg-n-brand text-white hover:brightness-110 transition-all"
              @click="addEdge"
            >
              <span class="i-lucide-plus size-3.5" />
              Adicionar aresta
            </button>
          </div>

          <div
            v-if="edges.length === 0"
            class="py-6 text-center text-n-slate-11 text-sm rounded-lg border border-dashed border-n-weak"
          >
            Nenhuma aresta adicionada.
          </div>

          <div v-else class="flex flex-col gap-3">
            <div
              v-for="(edge, index) in edges"
              :key="edge.edge_id"
              class="flex flex-col gap-3 p-4 rounded-lg border border-n-weak bg-n-surface-1"
            >
              <div class="flex items-center justify-between">
                <span class="text-xs font-medium text-n-slate-11"
                  >Aresta {{ index + 1 }}</span
                >
                <button
                  class="p-1 rounded text-n-slate-10 hover:text-n-ruby-11 hover:bg-n-ruby-3 transition-all"
                  @click="removeEdge(index)"
                >
                  <span class="i-lucide-trash-2 size-3.5" />
                </button>
              </div>

              <div class="grid grid-cols-3 gap-3">
                <div class="flex flex-col gap-1">
                  <label class="text-xs font-medium text-n-slate-11"
                    >Nó de origem</label
                  >
                  <input
                    v-model="edge.source_node_id"
                    type="text"
                    placeholder="source_node_id"
                    class="w-full px-3 py-2 rounded-lg border border-n-weak bg-n-surface-1 text-sm text-n-slate-12 placeholder:text-n-slate-10 focus:outline-none focus:ring-2 focus:ring-n-brand/30 focus:border-n-brand transition-all"
                  />
                </div>
                <div class="flex flex-col gap-1">
                  <label class="text-xs font-medium text-n-slate-11"
                    >Nó de destino</label
                  >
                  <input
                    v-model="edge.target_node_id"
                    type="text"
                    placeholder="target_node_id"
                    class="w-full px-3 py-2 rounded-lg border border-n-weak bg-n-surface-1 text-sm text-n-slate-12 placeholder:text-n-slate-10 focus:outline-none focus:ring-2 focus:ring-n-brand/30 focus:border-n-brand transition-all"
                  />
                </div>
                <div class="flex flex-col gap-1">
                  <label class="text-xs font-medium text-n-slate-11"
                    >Label</label
                  >
                  <input
                    v-model="edge.label"
                    type="text"
                    placeholder="Label da aresta"
                    class="w-full px-3 py-2 rounded-lg border border-n-weak bg-n-surface-1 text-sm text-n-slate-12 placeholder:text-n-slate-10 focus:outline-none focus:ring-2 focus:ring-n-brand/30 focus:border-n-brand transition-all"
                  />
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </template>
  </PageLayout>
</template>
