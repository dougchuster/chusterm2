<script setup>
/**
 * Menu de visões salvas — F2.7 do PLANO-KANBAN-CRM-2026.md.
 *
 * A separação entre "minhas" e "da equipe" não é estética: uma visão da equipe
 * eu **uso**, não edito. O menu deixa isso óbvio antes do clique — não oferece
 * apagar nem compartilhar o que não é meu, em vez de deixar o servidor recusar
 * com 404 depois.
 *
 * Saber de quem é a visão da equipe é o que faz o atendente confiar nela: uma
 * visão sem dono é um filtro anônimo que ninguém sabe se ainda vale.
 */
import { computed } from 'vue';

import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  views: { type: Array, default: () => [] },
  activeViewId: { type: [Number, String], default: null },
  hasActiveFilters: { type: Boolean, default: false },
});

const emit = defineEmits(['select', 'save', 'delete', 'share']);

const mine = computed(() => props.views.filter(view => view.is_mine));
const fromTeam = computed(() => props.views.filter(view => !view.is_mine));

const isActive = view => String(view.id) === String(props.activeViewId);
</script>

<template>
  <div class="flex min-w-60 flex-col gap-1 p-1.5">
    <p
      v-if="!views.length"
      data-testid="crm-view-empty"
      class="px-2.5 py-3 text-center text-ui-caption text-ui-text-muted"
    >
      {{ $t('CRM.VIEWS.EMPTY') }}
    </p>

    <template v-if="mine.length">
      <p class="px-2 pt-1 text-ui-caption font-semibold uppercase tracking-wider text-ui-text-subtle">
        {{ $t('CRM.VIEWS.MINE') }}
      </p>
      <div
        v-for="view in mine"
        :key="view.id"
        class="group flex items-center gap-1.5 rounded-ui-control transition-colors hover:bg-ui-hover"
      >
        <button
          data-testid="crm-view-mine"
          type="button"
          role="menuitem"
          :aria-current="isActive(view) ? 'true' : undefined"
          class="min-h-9 min-w-0 flex-1 truncate px-2.5 text-left text-ui-body-sm text-ui-text transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ui-border-focus"
          :class="{ 'font-semibold text-ui-brand': isActive(view) }"
          @click="emit('select', view)"
        >
          {{ view.name }}
        </button>
        <button
          data-testid="crm-view-share"
          type="button"
          class="rounded-ui-control p-1 text-ui-text-muted transition-colors hover:text-ui-text focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ui-border-focus"
          :aria-label="
            view.is_shared
              ? $t('CRM.VIEWS.UNSHARE', { name: view.name })
              : $t('CRM.VIEWS.SHARE', { name: view.name })
          "
          @click.stop="emit('share', view)"
        >
          <Icon
            :icon="view.is_shared ? 'i-lucide-users' : 'i-lucide-user'"
            class="size-4"
          />
        </button>
        <button
          data-testid="crm-view-delete"
          type="button"
          class="rounded-ui-control p-1 text-ui-text-muted transition-colors hover:text-ui-danger focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ui-border-focus"
          :aria-label="$t('CRM.VIEWS.DELETE', { name: view.name })"
          @click.stop="emit('delete', view)"
        >
          <Icon icon="i-lucide-trash-2" class="size-4" />
        </button>
      </div>
    </template>

    <template v-if="fromTeam.length">
      <p class="px-2 pt-2 text-ui-caption font-semibold uppercase tracking-wider text-ui-text-subtle">
        {{ $t('CRM.VIEWS.TEAM') }}
      </p>
      <button
        v-for="view in fromTeam"
        :key="view.id"
        data-testid="crm-view-team"
        type="button"
        role="menuitem"
        :aria-current="isActive(view) ? 'true' : undefined"
        class="flex min-h-9 flex-col items-start rounded-ui-control px-2.5 py-1.5 text-left transition-colors hover:bg-ui-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ui-border-focus"
        :class="{ 'font-semibold text-ui-brand': isActive(view) }"
        @click="emit('select', view)"
      >
        <span class="truncate text-ui-body-sm text-ui-text">
          {{ view.name }}
        </span>
        <span class="truncate text-ui-caption text-ui-text-muted">
          {{ $t('CRM.VIEWS.AUTHOR', { author: view.owner_name || view.author_name }) }}
        </span>
      </button>
    </template>

    <div v-if="hasActiveFilters" class="mt-1 border-t border-ui-border-subtle pt-1">
      <button
        data-testid="crm-view-save"
        type="button"
        role="menuitem"
        class="flex min-h-9 w-full items-center gap-2 rounded-ui-control px-2.5 text-left text-ui-body-sm font-medium text-ui-brand transition-colors hover:bg-ui-hover"
        @click="emit('save')"
      >
        <Icon icon="i-lucide-bookmark-plus" class="size-4" />
        {{ $t('CRM.VIEWS.SAVE_CURRENT') }}
      </button>
    </div>
  </div>
</template>
