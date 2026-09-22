<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { DsBadge, DsDropdown } from 'dashboard/design-system/components';

defineProps({
  documents: { type: Array, default: () => [] },
});

const emit = defineEmits(['open', 'download', 'edit', 'archive']);

const STATUS = {
  received: { label: 'Recebido', variant: 'neutral' },
  approved: { label: 'Aprovado', variant: 'success' },
  rejected: { label: 'Rejeitado', variant: 'danger' },
  obsolete: { label: 'Obsoleto', variant: 'neutral' },
};

const SOURCE = {
  whatsapp: 'WhatsApp',
  email: 'E-mail',
  instagram: 'Instagram',
  upload: 'Enviado pela equipe',
  portal: 'Portal do cliente',
  system: 'Sistema',
};

const fileIcon = contentType => {
  if (contentType?.startsWith('image/')) return 'i-lucide-file-image';
  if (contentType?.startsWith('audio/')) return 'i-lucide-file-audio';
  if (contentType?.startsWith('video/')) return 'i-lucide-file-video';
  if (contentType === 'application/pdf') return 'i-lucide-file-text';
  return 'i-lucide-file';
};

const formatSize = bytes => {
  if (!bytes) return '';
  if (bytes < 1024 * 1024) return `${Math.max(1, Math.round(bytes / 1024))} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1).replace('.', ',')} MB`;
};

const formatDate = value =>
  value
    ? new Date(value).toLocaleDateString('pt-BR', {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
      })
    : '';

const expiringSoon = document => {
  if (!document.expires_on) return false;
  const days = (new Date(document.expires_on) - new Date()) / 86400000;
  return days <= 30;
};

const itemClass =
  'flex min-h-10 w-full items-center gap-2 rounded-ui-control px-3 text-left text-ui-body-sm text-ui-text hover:bg-ui-hover';
</script>

<template>
  <ul class="m-0 flex list-none flex-col p-0" aria-label="Documentos da pasta">
    <li
      v-for="document in documents"
      :key="document.id"
      class="group flex items-center gap-3 border-b border-ui-border-subtle px-3 py-2.5 last:border-b-0 hover:bg-ui-hover/60"
    >
      <Icon
        :icon="fileIcon(document.content_type)"
        class="size-5 shrink-0 text-ui-text-muted"
      />
      <button
        type="button"
        class="min-w-0 flex-1 text-left outline-none focus-visible:ring-2 focus-visible:ring-ui-brand rounded-ui-control"
        :title="document.path"
        @click="emit('open', document)"
      >
        <span
          class="line-clamp-2 font-mono text-ui-body-sm text-ui-text [overflow-wrap:anywhere]"
        >
          {{ document.file_name }}
        </span>
        <span
          class="mt-0.5 flex flex-wrap items-center gap-x-2 gap-y-1 text-ui-caption text-ui-text-muted"
        >
          <span
            v-if="document.in_triage"
            class="font-medium text-ui-warning-foreground"
            >A classificar</span
          >
          <span v-else>{{ document.doc_type_label || document.doc_type }}</span>
          <span aria-hidden="true">·</span>
          <span>{{ formatDate(document.created_at) }}</span>
          <span v-if="document.byte_size" aria-hidden="true">·</span>
          <span v-if="document.byte_size" class="tabular-nums">{{
            formatSize(document.byte_size)
          }}</span>
          <span aria-hidden="true">·</span>
          <span>{{ SOURCE[document.source] || document.source }}</span>
        </span>
      </button>
      <DsBadge
        v-if="expiringSoon(document)"
        variant="warning"
        icon="i-lucide-clock-alert"
        :label="`Vence ${formatDate(document.expires_on)}`"
        class="hidden sm:inline-flex"
      />
      <DsBadge
        :variant="STATUS[document.status]?.variant || 'neutral'"
        :label="STATUS[document.status]?.label || document.status"
        class="hidden sm:inline-flex"
      />
      <DsDropdown :aria-label="`Ações de ${document.file_name}`">
        <button
          type="button"
          role="menuitem"
          :class="itemClass"
          @click="emit('open', document)"
        >
          <Icon icon="i-lucide-eye" class="size-4" /> Visualizar
        </button>
        <button
          type="button"
          role="menuitem"
          :class="itemClass"
          @click="emit('download', document)"
        >
          <Icon icon="i-lucide-download" class="size-4" /> Baixar
        </button>
        <button
          type="button"
          role="menuitem"
          :class="itemClass"
          @click="emit('edit', 'classify', document)"
        >
          <Icon icon="i-lucide-tag" class="size-4" />
          {{ document.in_triage ? 'Classificar' : 'Alterar tipo' }}
        </button>
        <button
          type="button"
          role="menuitem"
          :class="itemClass"
          @click="emit('edit', 'move', document)"
        >
          <Icon icon="i-lucide-folder-input" class="size-4" /> Mover para…
        </button>
        <button
          type="button"
          role="menuitem"
          :class="itemClass"
          @click="emit('edit', 'rename', document)"
        >
          <Icon icon="i-lucide-pencil" class="size-4" /> Renomear
        </button>
        <button
          type="button"
          role="menuitem"
          :class="itemClass"
          @click="emit('archive', document)"
        >
          <Icon icon="i-lucide-archive" class="size-4 text-ui-danger" />
          Arquivar
        </button>
      </DsDropdown>
    </li>
  </ul>
</template>
