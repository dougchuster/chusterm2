<script>
import Hotkey from 'dashboard/components/base/Hotkey.vue';

export default {
  components: {
    Hotkey,
  },
  data() {
    return {
      modifierKey: 'Ctrl',
      keyShortcuts: [
        {
          key: 'K',
          description: this.$t('CONVERSATION.EMPTY_STATE.CMD_BAR'),
        },
        {
          key: '/',
          description: this.$t('CONVERSATION.EMPTY_STATE.KEYBOARD_SHORTCUTS'),
        },
      ],
    };
  },
};
</script>

<template>
  <div class="mt-9 flex flex-col gap-2">
    <div
      v-for="keyShortcut in keyShortcuts"
      :key="keyShortcut.key"
      class="flex items-center gap-2"
    >
      <div class="flex items-center gap-2">
        <Hotkey
          custom-class="h-7 min-w-8 px-1.5 text-sm font-semibold text-ds-fg-muted ring-1 ring-ds-border-subtle bg-ds-bg-elevated"
        >
          {{ modifierKey }}
        </Hotkey>
        <Hotkey
          custom-class="h-7 min-w-8 px-1.5 text-xs font-semibold text-ds-fg-muted ring-1 ring-ds-border-subtle bg-ds-bg-elevated"
        >
          {{ keyShortcut.key }}
        </Hotkey>
      </div>
      <span class="text-center text-sm font-medium text-ds-fg-muted">
        {{ keyShortcut.description }}
      </span>
    </div>
  </div>
</template>
