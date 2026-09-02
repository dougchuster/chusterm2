<script setup>
import { ref, computed, toRef } from 'vue';
import { useAlert } from 'dashboard/composables';
import { useFunctionGetter, useStore } from 'dashboard/composables/store';
import {
  COMPONENT_TYPES,
  MEDIA_FORMATS,
  findComponentByType,
} from 'dashboard/helper/templateHelper';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { useI18n } from 'vue-i18n';

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

const whatsAppTemplateMessages = useFunctionGetter(
  'inboxes/getFilteredWhatsAppTemplates',
  toRef(props, 'inboxId')
);

const filteredTemplateMessages = computed(() =>
  whatsAppTemplateMessages.value.filter(template =>
    template.name.toLowerCase().includes(query.value.toLowerCase())
  )
);

const getTemplateBody = template => {
  return findComponentByType(template, COMPONENT_TYPES.BODY)?.text || '';
};

const getTemplateHeader = template => {
  return findComponentByType(template, COMPONENT_TYPES.HEADER);
};

const getTemplateFooter = template => {
  return findComponentByType(template, COMPONENT_TYPES.FOOTER);
};

const getTemplateButtons = template => {
  return findComponentByType(template, COMPONENT_TYPES.BUTTONS);
};

const hasMediaContent = template => {
  const header = getTemplateHeader(template);
  return header && MEDIA_FORMATS.includes(header.format);
};

const refreshTemplates = async () => {
  isRefreshing.value = true;
  try {
    await store.dispatch('inboxes/syncTemplates', props.inboxId);
    useAlert(t('WHATSAPP_TEMPLATES.PICKER.REFRESH_SUCCESS'));
  } catch (error) {
    useAlert(t('WHATSAPP_TEMPLATES.PICKER.REFRESH_ERROR'));
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
          :placeholder="t('WHATSAPP_TEMPLATES.PICKER.SEARCH_PLACEHOLDER')"
          class="reset-base h-9 w-full bg-transparent !text-sm text-ds-fg-default !outline-0 placeholder:text-ds-fg-subtle"
        />
      </div>
      <button
        :disabled="isRefreshing"
        :aria-label="t('WHATSAPP_TEMPLATES.PICKER.REFRESH_BUTTON')"
        class="flex size-9 items-center justify-center rounded-lg border border-ds-border-subtle bg-ds-bg-surface text-ds-fg-muted transition-colors hover:bg-ds-bg-hover hover:text-ds-fg-default focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-border-focus disabled:cursor-not-allowed disabled:opacity-50"
        :title="t('WHATSAPP_TEMPLATES.PICKER.REFRESH_BUTTON')"
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
      <div v-for="(template, i) in filteredTemplateMessages" :key="template.id">
        <button
          class="block w-full cursor-pointer rounded-lg p-2.5 text-left text-ds-fg-default transition-colors hover:bg-ds-bg-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-border-focus"
          type="button"
          @click="emit('onSelect', template)"
        >
          <div>
            <div class="flex justify-between items-center mb-2.5">
              <p class="text-sm">
                {{ template.name }}
              </p>
              <span
                class="inline-block cursor-default rounded-lg bg-ds-bg-active px-2 py-1 text-xs leading-none text-ds-fg-muted"
              >
                {{
                  `${t('WHATSAPP_TEMPLATES.PICKER.LABELS.LANGUAGE')}: ${template.language}`
                }}
              </span>
            </div>
            <!-- Header -->
            <div v-if="getTemplateHeader(template)" class="mb-3">
              <p class="text-xs font-medium text-ds-fg-muted">
                {{ t('WHATSAPP_TEMPLATES.PICKER.HEADER') || 'HEADER' }}
              </p>
              <div
                v-if="getTemplateHeader(template).format === 'TEXT'"
                class="font-mono text-sm"
              >
                {{ getTemplateHeader(template).text }}
              </div>
              <div
                v-else-if="hasMediaContent(template)"
                class="text-sm italic text-ds-fg-muted"
              >
                {{
                  t('WHATSAPP_TEMPLATES.PICKER.MEDIA_CONTENT', {
                    format: getTemplateHeader(template).format,
                  }) ||
                  `${getTemplateHeader(template).format} ${t('WHATSAPP_TEMPLATES.PICKER.MEDIA_CONTENT_FALLBACK')}`
                }}
              </div>
            </div>

            <!-- Body -->
            <div>
              <p class="text-xs font-medium text-ds-fg-muted">
                {{ t('WHATSAPP_TEMPLATES.PICKER.BODY') || 'BODY' }}
              </p>
              <p class="font-mono text-sm">{{ getTemplateBody(template) }}</p>
            </div>

            <!-- Footer -->
            <div v-if="getTemplateFooter(template)" class="mt-3">
              <p class="text-xs font-medium text-ds-fg-muted">
                {{ t('WHATSAPP_TEMPLATES.PICKER.FOOTER') || 'FOOTER' }}
              </p>
              <p class="font-mono text-sm">
                {{ getTemplateFooter(template).text }}
              </p>
            </div>

            <!-- Buttons -->
            <div v-if="getTemplateButtons(template)" class="mt-3">
              <p class="text-xs font-medium text-ds-fg-muted">
                {{ t('WHATSAPP_TEMPLATES.PICKER.BUTTONS') || 'BUTTONS' }}
              </p>
              <div class="flex flex-wrap gap-1 mt-1">
                <span
                  v-for="button in getTemplateButtons(template).buttons"
                  :key="button.text"
                  class="rounded bg-ds-bg-active px-2 py-1 text-xs text-ds-fg-muted"
                >
                  {{ button.text }}
                </span>
              </div>
            </div>

            <div class="mt-3">
              <p class="text-xs font-medium text-ds-fg-muted">
                {{ t('WHATSAPP_TEMPLATES.PICKER.CATEGORY') || 'CATEGORY' }}
              </p>
              <p class="text-sm">{{ template.category }}</p>
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
        <div v-if="query && whatsAppTemplateMessages.length">
          <p>
            {{ t('WHATSAPP_TEMPLATES.PICKER.NO_TEMPLATES_FOUND') }}
            <strong>{{ query }}</strong>
          </p>
        </div>
        <div v-else-if="!whatsAppTemplateMessages.length" class="space-y-4">
          <p class="text-ds-fg-muted">
            {{ t('WHATSAPP_TEMPLATES.PICKER.NO_TEMPLATES_AVAILABLE') }}
          </p>
        </div>
      </div>
    </div>
  </div>
</template>
