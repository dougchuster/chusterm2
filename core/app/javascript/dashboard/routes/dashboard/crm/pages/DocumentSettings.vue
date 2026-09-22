<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { ref } from 'vue';

import Icon from 'dashboard/components-next/icon/Icon.vue';
import { DsTabs } from 'dashboard/design-system/components';
import CRMDocumentTypesSettings from '../components/documents/settings/CRMDocumentTypesSettings.vue';
import CRMFolderTemplatesSettings from '../components/documents/settings/CRMFolderTemplatesSettings.vue';
import CRMFormsManager from '../components/documents/settings/CRMFormsManager.vue';
import CRMNamingSettings from '../components/documents/settings/CRMNamingSettings.vue';

// Configuração do cofre de documentos, tudo pela tela: formulários de envio,
// área de atuação e nomes, tipos de documento e estrutura de pastas.
const tab = ref('forms');
const tabs = [
  { value: 'forms', label: 'Formulários', icon: 'i-lucide-clipboard-list' },
  {
    value: 'naming',
    label: 'Área e nomes',
    icon: 'i-lucide-text-cursor-input',
  },
  { value: 'types', label: 'Tipos de documento', icon: 'i-lucide-tags' },
  { value: 'folders', label: 'Pastas', icon: 'i-lucide-folder-tree' },
];
</script>

<template>
  <div class="flex h-full min-h-0 flex-col gap-4 overflow-y-auto p-4 md:p-6 [&>*]:shrink-0">
    <header class="flex items-center gap-3">
      <Icon
        icon="i-lucide-settings-2"
        class="hidden size-6 text-ui-text-muted sm:block"
      />
      <div class="min-w-0">
        <h1 class="m-0 text-ui-title text-ui-text">Configurar documentos</h1>
        <p class="m-0 text-ui-body-sm text-ui-text-muted">
          Formulários que o cliente preenche, nomes dos arquivos, tipos de
          documento e pastas.
        </p>
      </div>
    </header>
    <DsTabs v-model="tab" :tabs="tabs" label="Configuração do cofre" />
    <div class="rounded-ui-card border border-ui-border bg-ui-surface p-4">
      <CRMFormsManager v-if="tab === 'forms'" />
      <CRMNamingSettings v-else-if="tab === 'naming'" />
      <CRMDocumentTypesSettings v-else-if="tab === 'types'" />
      <CRMFolderTemplatesSettings v-else />
    </div>
  </div>
</template>
