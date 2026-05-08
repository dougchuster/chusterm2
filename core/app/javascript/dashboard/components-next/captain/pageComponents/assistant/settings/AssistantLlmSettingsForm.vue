<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { computed, onMounted, reactive, watch } from 'vue';
import { useCaptainConfigStore } from 'dashboard/store/captain/preferences';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';

const props = defineProps({
  assistant: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['submit']);

const captainConfigStore = useCaptainConfigStore();

const state = reactive({
  llmProvider: '',
  llmMainModel: '',
  llmFallbackModel: '',
  llmClassifierModel: '',
  llmSummarizerModel: '',
  llmMaxTokens: 4096,
  llmTimeoutSeconds: 30,
  llmCostLimitCentsPerConversation: '',
});

const providerOptions = computed(() => {
  const configured = Object.entries(captainConfigStore.getProviders || {}).map(
    ([id, provider]) => ({
      value: id,
      label: provider.display_name || id,
    })
  );

  const list = configured.length
    ? configured
    : [
        { value: 'openai', label: 'OpenAI' },
        { value: 'openrouter', label: 'OpenRouter' },
        { value: 'anthropic', label: 'Anthropic' },
        { value: 'gemini', label: 'Gemini' },
      ];

  return [{ value: '', label: 'Usar padrão da conta' }, ...list];
});

const baseModelOptions = computed(() => {
  const optionsById = new Map();
  Object.values(captainConfigStore.getFeatures || {}).forEach(feature => {
    (feature.models || []).forEach(model => {
      optionsById.set(model.id, {
        id: model.id,
        label: model.display_name || model.id,
        provider: model.provider,
        comingSoon: model.coming_soon,
      });
    });
  });

  Object.entries(captainConfigStore.getModels || {}).forEach(([id, model]) => {
    if (!optionsById.has(id)) {
      optionsById.set(id, {
        id,
        label: model.display_name || id,
        provider: model.provider,
        comingSoon: model.coming_soon,
      });
    }
  });

  return [...optionsById.values()].sort((a, b) =>
    `${a.provider || ''}-${a.label}`.localeCompare(
      `${b.provider || ''}-${b.label}`
    )
  );
});

const buildModelOptions = emptyLabel => [
  { value: '', label: emptyLabel },
  ...baseModelOptions.value.map(model => ({
    value: model.id,
    label: `${model.label} (${model.provider || 'custom'})`,
    disabled: model.comingSoon,
  })),
];

const mainModelOptions = computed(() =>
  buildModelOptions('Usar padrão da conta')
);
const fallbackModelOptions = computed(() =>
  buildModelOptions('Sem fallback próprio')
);
const classifierModelOptions = computed(() =>
  buildModelOptions('Usar padrão da conta')
);
const summarizerModelOptions = computed(() =>
  buildModelOptions('Usar padrão da conta')
);

const updateStateFromAssistant = assistant => {
  const { config = {} } = assistant || {};
  state.llmProvider = config.llm_provider || '';
  state.llmMainModel = config.llm_main_model || '';
  state.llmFallbackModel = config.llm_fallback_model || '';
  state.llmClassifierModel = config.llm_classifier_model || '';
  state.llmSummarizerModel = config.llm_summarizer_model || '';
  state.llmMaxTokens = config.llm_max_tokens || 4096;
  state.llmTimeoutSeconds = config.llm_timeout_seconds || 30;
  state.llmCostLimitCentsPerConversation =
    config.llm_cost_limit_cents_per_conversation ?? '';
};

const handleUpdate = () => {
  emit('submit', {
    config: {
      ...props.assistant.config,
      llm_provider: state.llmProvider || null,
      llm_main_model: state.llmMainModel || null,
      llm_fallback_model: state.llmFallbackModel || null,
      llm_classifier_model: state.llmClassifierModel || null,
      llm_summarizer_model: state.llmSummarizerModel || null,
      llm_max_tokens: state.llmMaxTokens || 4096,
      llm_timeout_seconds: state.llmTimeoutSeconds || 30,
      llm_cost_limit_cents_per_conversation:
        state.llmCostLimitCentsPerConversation === ''
          ? null
          : state.llmCostLimitCentsPerConversation,
    },
  });
};

onMounted(() => {
  if (!Object.keys(captainConfigStore.getFeatures || {}).length) {
    captainConfigStore.fetch();
  }
});

watch(
  () => props.assistant,
  assistant => updateStateFromAssistant(assistant),
  { immediate: true }
);
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
  <div class="flex flex-col gap-6">
    <label class="flex flex-col gap-1 text-sm font-medium text-n-slate-12">
      Provedor
      <Select v-model="state.llmProvider" :options="providerOptions" block />
    </label>

    <label class="flex flex-col gap-1 text-sm font-medium text-n-slate-12">
      Modelo principal
      <Select v-model="state.llmMainModel" :options="mainModelOptions" block />
    </label>

    <div class="grid grid-cols-1 gap-4 md:grid-cols-2">
      <label class="flex flex-col gap-1 text-sm font-medium text-n-slate-12">
        Fallback
        <Select
          v-model="state.llmFallbackModel"
          :options="fallbackModelOptions"
          block
        />
      </label>

      <label class="flex flex-col gap-1 text-sm font-medium text-n-slate-12">
        Classificador
        <Select
          v-model="state.llmClassifierModel"
          :options="classifierModelOptions"
          block
        />
      </label>
    </div>

    <label class="flex flex-col gap-1 text-sm font-medium text-n-slate-12">
      Resumo e memória
      <Select
        v-model="state.llmSummarizerModel"
        :options="summarizerModelOptions"
        block
      />
    </label>

    <div class="grid grid-cols-1 gap-4 md:grid-cols-3">
      <Input
        v-model="state.llmMaxTokens"
        type="number"
        min="256"
        max="32000"
        label="Max tokens"
      />
      <Input
        v-model="state.llmTimeoutSeconds"
        type="number"
        min="5"
        max="120"
        label="Timeout (s)"
      />
      <Input
        v-model="state.llmCostLimitCentsPerConversation"
        type="number"
        min="0"
        label="Limite por conversa (centavos)"
      />
    </div>

    <div>
      <Button label="Atualizar LLM do agente" @click="handleUpdate" />
    </div>
  </div>
</template>
