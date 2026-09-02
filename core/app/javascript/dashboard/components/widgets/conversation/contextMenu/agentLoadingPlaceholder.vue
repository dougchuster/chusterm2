<script>
import Spinner from 'shared/components/Spinner.vue';

export default {
  components: {
    Spinner,
  },
};
</script>

<template>
  <div
    class="flex min-w-[12.5rem] flex-col items-center justify-center py-4 text-ds-fg-muted"
    role="status"
  >
    <Spinner />
    <p class="mb-0 mt-2">
      {{ $t('CONVERSATION.CARD_CONTEXT_MENU.AGENTS_LOADING') }}
    </p>
  </div>
</template>
