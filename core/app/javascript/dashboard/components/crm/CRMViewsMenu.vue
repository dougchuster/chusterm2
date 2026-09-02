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
  <div class="flex min-w-56 flex-col gap-1 p-1">
    <p
      v-if="!views.length"
      data-testid="crm-view-empty"
      class="px-2 py-3 text-center text-ui-caption text-ui-text-muted"
    >
      {{ $t('CRM.VIEWS.EMPTY') }}
    </p>

    <template v-if="mine.length">
      <p class="px-2 pt-1 text-ui-caption font-medium text-ui-text-subtle">
        {{ $t('CRM.VIEWS.MINE') }}
      </p>
      <div
        v-for="view in mine"
        :key="view.id"
        class="flex items-center gap-1 rounded-ui-control hover:bg-ui-hover"
      >
        <button
          data-testid="crm-view-mine"
          type="button"
          role="menuitem"
          :aria-current="isActive(view) ? 'true' : undefined"
          class="min-h-9 min-w-0 flex-1 truncate px-2 text-left text-ui-body-sm text-ui-text focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ui-border-focus"
          :class="{ 'font-semibold': isActive(view) }"
          @click="emit('select', view)"
        >
          {{ view.name }}
        </button>
        <button
          data-testid="crm-view-share"
          type="button"
          class="rounded-ui-control p-1 text-ui-text-muted hover:text-ui-text focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ui-border-focus"
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
          class="rounded-ui-control p-1 text-ui-text-muted hover:text-ui-danger focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ui-border-focus"
          :aria-label="$t('CRM.VIEWS.DELETE', { name: view.name })"
          @click.stop="emit('delete', view)"
        >
          <Icon icon="i-lucide-trash-2" class="size-4" />
        </button>
      </div>
    </template>

    <template v-if="fromTeam.length">
      <p class="px-2 pt-2 text-ui-caption font-medium text-ui-text-subtle">
        {{ $t('CRM.VIEWS.TEAM') }}
      </p>
      <button
        v-for="view in fromTeam"
        :key="view.id"
        data-testid="crm-view-team"
        type="button"
        role="menuitem"
        :aria-current="isActive(view) ? 'true' : undefined"
        class="flex min-h-9 flex-col items-start rounded-ui-control px-2 py-1 text-left hover:bg-ui-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ui-border-focus"
        :class="{ 'font-semibold': isActive(view) }"
        @click="emit('select', view)"
      >
        <span class="w-full truncate text-ui-body-sm text-ui-text">
          {{ view.name }}
        </span>
        <span
          v-if="view.owner_name"
          class="w-full truncate text-ui-caption text-ui-text-muted"
        >
          {{ view.owner_name }}
        </span>
      </button>
    </template>

    <!--
      Sem filtro não há o que salvar: oferecer o botão seria oferecer uma visão
      vazia, que é o mesmo que nenhuma visão.
    -->
    <button
      v-if="hasActiveFilters"
      data-testid="crm-view-save"
      type="button"
      class="mt-1 flex min-h-9 items-center gap-2 rounded-ui-control border-t border-ui-border-subtle px-2 pt-2 text-left text-ui-body-sm text-ui-brand focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ui-border-focus"
      @click="emit('save')"
    >
      <Icon icon="i-lucide-bookmark-plus" class="size-4" />
      {{ $t('CRM.VIEWS.SAVE_CURRENT') }}
    </button>
  </div>
</template>
