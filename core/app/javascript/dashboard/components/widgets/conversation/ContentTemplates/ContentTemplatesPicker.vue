<script setup>
import { ref, computed } from 'vue';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'dashboard/composables/store';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { useI18n } from 'vue-i18n';
import { TWILIO_CONTENT_TEMPLATE_TYPES } from 'shared/constants/messages';

const props = defineProps({
  inboxId: {
    type: Number,
    default: undefined,
  },
});

const emit = defineEmits(['onSelect']);

const { t } = useI18n();
const store = useStore();
const query = ref('');
const isRefreshing = ref(false);

const twilioTemplates = computed(() => {
  const inbox = store.getters['inboxes/getInbox'](props.inboxId);
  return inbox?.content_templates?.templates || [];
});

const filteredTemplateMessages = computed(() =>
  twilioTemplates.value.filter(
    template =>
      template.friendly_name
        .toLowerCase()
        .includes(query.value.toLowerCase()) && template.status === 'approved'
  )
);

const getTemplateType = template => {
  if (template.template_type === TWILIO_CONTENT_TEMPLATE_TYPES.MEDIA) {
    return t('CONTENT_TEMPLATES.PICKER.TYPES.MEDIA');
  }
  if (template.template_type === TWILIO_CONTENT_TEMPLATE_TYPES.QUICK_REPLY) {
    return t('CONTENT_TEMPLATES.PICKER.TYPES.QUICK_REPLY');
  }
  if (template.template_type === TWILIO_CONTENT_TEMPLATE_TYPES.CALL_TO_ACTION) {
    return t('CONTENT_TEMPLATES.PICKER.TYPES.CALL_TO_ACTION');
  }
  return t('CONTENT_TEMPLATES.PICKER.TYPES.TEXT');
};

const refreshTemplates = async () => {
  isRefreshing.value = true;
  try {
    await store.dispatch('inboxes/syncTemplates', props.inboxId);
    useAlert(t('CONTENT_TEMPLATES.PICKER.REFRESH_SUCCESS'));
  } catch (error) {
    useAlert(t('CONTENT_TEMPLATES.PICKER.REFRESH_ERROR'));
  } finally {
    isRefreshing.value = false;
  }
};
</script>

<template>
  <div class="w-full">
    <div class="mb-2.5 flex gap-2">
      <div
        class="flex flex-1 items-center gap-1 rounded-lg border border-ds-border-subtle bg-ds-bg-surface px-2.5 transition-colors hover:border-ds-border-strong focus-within:border-ds-border-focus focus-within:ring-2 focus-within:ring-ds-border-focus/30"
      >
        <span
          class="i-lucide-search size-4 text-ds-fg-subtle"
          aria-hidden="true"
        />
        <input
          v-model="query"
          type="search"
          :placeholder="t('CONTENT_TEMPLATES.PICKER.SEARCH_PLACEHOLDER')"
          class="reset-base h-9 w-full bg-transparent !text-sm text-ds-fg-default !outline-0 placeholder:text-ds-fg-subtle"
        />
      </div>
      <button
        :disabled="isRefreshing"
        :aria-label="t('CONTENT_TEMPLATES.PICKER.REFRESH_BUTTON')"
        class="flex size-9 items-center justify-center rounded-lg border border-ds-border-subtle bg-ds-bg-surface text-ds-fg-muted transition-colors hover:bg-ds-bg-hover hover:text-ds-fg-default focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-border-focus disabled:cursor-not-allowed disabled:opacity-50"
        :title="t('CONTENT_TEMPLATES.PICKER.REFRESH_BUTTON')"
        type="button"
        @click="refreshTemplates"
      >
        <Icon
          icon="i-lucide-refresh-ccw"
          class="size-4"
          :class="{ 'animate-spin': isRefreshing }"
        />
      </button>
    </div>
    <div
      class="max-h-[18.75rem] overflow-y-auto rounded-xl bg-ds-bg-sunken p-2.5 ring-1 ring-ds-border-subtle"
    >
      <div
        v-for="(template, i) in filteredTemplateMessages"
        :key="template.content_sid"
      >
        <button
          class="block w-full cursor-pointer rounded-lg p-2.5 text-left text-ds-fg-default transition-colors hover:bg-ds-bg-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-border-focus"
          type="button"
          @click="emit('onSelect', template)"
        >
          <div>
            <div class="flex justify-between items-center mb-2.5">
              <p class="text-sm">
                {{ template.friendly_name }}
              </p>
              <div class="flex gap-2">
                <span
                  class="inline-block cursor-default rounded-lg bg-ds-bg-active px-2 py-1 text-xs leading-none text-ds-fg-muted"
                >
                  {{ getTemplateType(template) }}
                </span>
                <span
                  class="inline-block cursor-default rounded-lg bg-ds-bg-active px-2 py-1 text-xs leading-none text-ds-fg-muted"
                >
                  {{
                    `${t('CONTENT_TEMPLATES.PICKER.LABELS.LANGUAGE')}: ${template.language}`
                  }}
                </span>
              </div>
            </div>

            <!-- Body -->
            <div>
              <p class="text-xs font-medium text-ds-fg-muted">
                {{ t('CONTENT_TEMPLATES.PICKER.BODY') }}
              </p>
              <p class="font-mono text-sm">
                {{ template.body || t('CONTENT_TEMPLATES.PICKER.NO_CONTENT') }}
              </p>
            </div>

            <div class="flex justify-between items-center mt-3">
              <div>
                <p class="text-xs font-medium text-ds-fg-muted">
                  {{ t('CONTENT_TEMPLATES.PICKER.LABELS.CATEGORY') }}
                </p>
                <p class="text-sm">{{ template.category || 'utility' }}</p>
              </div>
              <div class="text-xs text-ds-fg-muted">
                {{ new Date(template.created_at).toLocaleDateString() }}
              </div>
            </div>
          </div>
        </button>
        <hr
          v-if="i != filteredTemplateMessages.length - 1"
          :key="`hr-${i}`"
          class="mx-auto my-2.5 max-w-[95%] border-b border-solid border-ds-border-subtle"
        />
      </div>
      <div v-if="!filteredTemplateMessages.length" class="py-8 text-center">
        <div v-if="query && twilioTemplates.length">
          <p>
            {{ t('CONTENT_TEMPLATES.PICKER.NO_TEMPLATES_FOUND') }}
            <strong>{{ query }}</strong>
          </p>
        </div>
        <div v-else-if="!twilioTemplates.length" class="space-y-4">
          <p class="text-ds-fg-muted">
            {{ t('CONTENT_TEMPLATES.PICKER.NO_TEMPLATES_AVAILABLE') }}
          </p>
        </div>
      </div>
    </div>
  </div>
</template>
