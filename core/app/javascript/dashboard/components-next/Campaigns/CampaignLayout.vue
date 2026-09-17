<script setup>
import { vOnClickOutside } from '@vueuse/components';
import Button from 'dashboard/components-next/button/Button.vue';

defineProps({
  headerTitle: {
    type: String,
    default: '',
  },
  buttonLabel: {
    type: String,
    default: '',
  },
});

const emit = defineEmits(['click', 'close']);

const handleButtonClick = () => {
  emit('click');
};
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-hidden bg-n-surface-1">
    <header
      class="sticky top-0 z-10 border-b border-ui-border-subtle/60 bg-n-surface-1 px-3 sm:px-6"
    >
      <div class="w-full max-w-5xl mx-auto">
        <div class="flex min-h-16 w-full items-center justify-between gap-3">
          <h1 class="m-0 truncate text-xl font-semibold text-n-slate-12">
            {{ headerTitle }}
          </h1>
          <div
            v-on-click-outside="[
              () => emit('close'),
              // This will prevent closing the modal when the editor Create link popup is open
              { ignore: ['dialog.ProseMirror-prompt-backdrop'] },
            ]"
            class="relative group/campaign-button"
          >
            <Button
              :label="buttonLabel"
              icon="i-lucide-plus"
              size="sm"
              class="group-hover/campaign-button:brightness-110"
              @click="handleButtonClick"
            />
            <slot name="action" />
          </div>
        </div>
      </div>
    </header>
    <main class="flex-1 overflow-y-auto px-3 sm:px-6">
      <div class="w-full max-w-5xl mx-auto py-4">
        <slot name="default" />
      </div>
    </main>
  </section>
</template>
