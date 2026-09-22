<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { computed, onMounted, ref } from 'vue';

import CrmDocumentsAPI from 'dashboard/api/crmDocuments';
import { useAlert } from 'dashboard/composables';
import {
  DsButton,
  DsCheckbox,
  DsInput,
  DsSelect,
  DsSkeleton,
} from 'dashboard/design-system/components';

// Modelo de documentos por área e padrões de nome (marcadores). A prévia
// mostra na hora como fica o nome com dados de exemplo.
const settings = ref(null);
const preset = ref('');
const naming = ref({});
const captureOutgoing = ref(true);
const saving = ref(false);
const error = ref('');

const KINDS = [
  { key: 'file', title: 'Arquivo classificado' },
  { key: 'triage_file', title: 'Arquivo ainda na triagem' },
  { key: 'client_folder', title: 'Pasta do cliente' },
  { key: 'case_folder', title: 'Pasta de cada negócio' },
];

const SAMPLE = {
  data: '2026-09-22',
  data_hora: '2026-09-22 14h37',
  tipo: 'Comprovante de Endereço',
  descricao: 'Conta de luz',
  cliente: 'Maria da Silva',
  nome: 'Maria da Silva',
  codigo: '000123',
  nome_original: 'IMG-20260922-WA0012',
  origem: 'WhatsApp',
  ano: '2026',
  numero: '0042',
  titulo: 'Contrato de locação',
};

const presetOptions = computed(() =>
  (settings.value?.presets || []).map(item => ({
    value: item.slug,
    label: item.name,
  }))
);
const presetDescription = computed(
  () =>
    settings.value?.presets.find(item => item.slug === preset.value)
      ?.description
);

const preview = template =>
  String(template || '')
    .replace(/\{([a-z_]+)\}/g, (_, token) => SAMPLE[token] ?? `{${token}}`)
    .trim();

const tokenLabel = token => `{${token}}`;

const templateFor = kind =>
  naming.value[kind] ?? settings.value.effective_naming[kind];

const insertToken = (kind, token) => {
  naming.value = {
    ...naming.value,
    [kind]: `${templateFor(kind)} {${token}}`.trim(),
  };
};

const load = async () => {
  const { data } = await CrmDocumentsAPI.getSettings();
  settings.value = data;
  preset.value = data.preset;
  naming.value = { ...data.effective_naming };
  captureOutgoing.value = data.capture_outgoing;
};

const save = async () => {
  saving.value = true;
  error.value = '';
  try {
    const { data } = await CrmDocumentsAPI.updateSettings({
      preset: preset.value,
      naming: naming.value,
      capture_outgoing: captureOutgoing.value,
    });
    settings.value = data;
    naming.value = { ...data.effective_naming };
    useAlert('Configuração salva. Vale para os próximos documentos e pastas.');
  } catch (err) {
    error.value = err?.response?.data?.error || 'Não foi possível salvar.';
  } finally {
    saving.value = false;
  }
};

const restoreDefaults = () => {
  naming.value = { ...settings.value.default_naming };
};

onMounted(() =>
  load().catch(() => useAlert('Não foi possível carregar a configuração.'))
);
</script>

<template>
  <div v-if="!settings" class="flex flex-col gap-2">
    <DsSkeleton v-for="n in 4" :key="n" class="h-12" />
  </div>
  <div v-else class="flex max-w-3xl flex-col gap-6">
    <section class="flex flex-col gap-2">
      <DsSelect
        id="doc-preset"
        v-model="preset"
        label="Área de atuação (modelo de documentos)"
        :options="presetOptions"
      />
      <p class="m-0 text-ui-caption text-ui-text-muted">
        {{ presetDescription }}
      </p>
      <p
        v-if="preset !== settings.preset"
        class="m-0 rounded-ui-control bg-ui-warning-soft px-3 py-2 text-ui-caption text-ui-warning-foreground"
      >
        Trocar o modelo acrescenta os tipos de documento da nova área e troca a
        estrutura das próximas pastas. Pastas e documentos que já existem não
        mudam.
      </p>
    </section>

    <section class="flex flex-col gap-4">
      <h3 class="m-0 text-ui-body font-semibold text-ui-text">
        Como os arquivos e pastas são nomeados
      </h3>
      <div v-for="kind in KINDS" :key="kind.key" class="flex flex-col gap-1.5">
        <DsInput
          :id="`naming-${kind.key}`"
          :model-value="templateFor(kind.key)"
          :label="kind.title"
          @update:model-value="naming = { ...naming, [kind.key]: $event }"
        />
        <div class="flex flex-wrap gap-1">
          <button
            v-for="token in settings.naming_tokens[kind.key]"
            :key="token"
            type="button"
            class="rounded-ui-control border border-ui-border px-2 py-0.5 font-mono text-ui-caption text-ui-text-muted hover:bg-ui-hover hover:text-ui-text"
            @click="insertToken(kind.key, token)"
          >
            {{ tokenLabel(token) }}
          </button>
        </div>
        <p class="m-0 text-ui-caption text-ui-text-muted">
          Exemplo:
          <span class="font-mono text-ui-text">{{
            preview(templateFor(kind.key))
          }}</span>
        </p>
      </div>
    </section>

    <DsCheckbox
      id="doc-capture-outgoing"
      v-model="captureOutgoing"
      label="Guardar também o que a equipe envia pelas conversas"
      description="Contratos, propostas e procurações enviados ao cliente vão para a pasta de enviados."
    />

    <p
      v-if="error"
      class="m-0 rounded-ui-control bg-ui-danger-soft p-3 text-ui-body-sm text-ui-danger-foreground"
      role="alert"
    >
      {{ error }}
    </p>
    <div class="flex flex-wrap gap-2">
      <DsButton
        variant="primary"
        icon="i-lucide-save"
        label="Salvar configuração"
        :loading="saving"
        @click="save"
      />
      <DsButton
        variant="ghost"
        icon="i-lucide-rotate-ccw"
        label="Voltar aos nomes do modelo"
        @click="restoreDefaults"
      />
    </div>
  </div>
</template>
