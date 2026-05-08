<script setup>
import { reactive, computed, watch, ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import CampaignsAPI from 'dashboard/api/campaigns';
import ContactsAPI from 'dashboard/api/contacts';

import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';
import WhatsAppTemplateParser from 'dashboard/components-next/whatsapp/WhatsAppTemplateParser.vue';

const emit = defineEmits(['submit', 'cancel']);

const { t } = useI18n();
const store = useStore();
const audienceText = {
  loading: 'Calculando audiencia...',
  previewTitle: 'Previa dos contatos',
};
const reviewText = {
  title: 'Revisão final',
  edit: 'Editar',
  campaignTitle: 'Título',
  template: 'Template',
  schedule: 'Agenda',
  audience: 'Publico',
  total: 'Total',
  message: 'Mensagem',
};

const formState = {
  uiFlags: useMapGetter('campaigns/getUIFlags'),
  labels: useMapGetter('labels/getLabels'),
  segments: useMapGetter('customViews/getContactCustomViews'),
  inboxes: useMapGetter('inboxes/getWhatsAppInboxes'),
  getFilteredWhatsAppTemplates: useMapGetter(
    'inboxes/getFilteredWhatsAppTemplates'
  ),
};

const initialState = {
  title: '',
  inboxId: null,
  templateId: null,
  scheduledAt: null,
  selectedAudience: [],
};

const state = reactive({ ...initialState });
const templateParserRef = ref(null);
const audienceSummary = ref(null);
const audiencePreview = ref([]);
const isAudienceLoading = ref(false);
const isReviewing = ref(false);
const sourceLists = ref([]);

const rules = {
  title: { required, minLength: minLength(1) },
  inboxId: { required },
  templateId: { required },
  scheduledAt: { required },
  selectedAudience: { required },
};

const v$ = useVuelidate(rules, state);

const isCreating = computed(() => formState.uiFlags.value.isCreating);
const audienceSummaryLabel = computed(() => {
  if (!audienceSummary.value) return '';
  return `Audiencia prevista: ${audienceSummary.value.total} contatos, ${audienceSummary.value.with_phone_number} com telefone.`;
});
const audiencePreviewCountLabel = computed(
  () => `${audiencePreview.value.length} exibidos`
);
const submitButtonLabel = computed(() =>
  isReviewing.value ? 'Confirmar e criar' : 'Revisar campanha'
);

const currentDateTime = computed(() => {
  // Added to disable the scheduled at field from being set to the current time
  const now = new Date();
  const localTime = new Date(now.getTime() - now.getTimezoneOffset() * 60000);
  return localTime.toISOString().slice(0, 16);
});

const mapToOptions = (items, valueKey, labelKey) =>
  items?.map(item => ({
    value: item[valueKey],
    label: item[labelKey],
  })) ?? [];

const audienceList = computed(() => [
  ...(formState.labels.value?.map(label => ({
    value: `Label:${label.id}`,
    label: `Etiqueta: ${label.display_title || label.title}`,
  })) || []),
  ...sourceLists.value.map(list => ({
    value: `SourceList:${list.name}`,
    label: `Lista: ${list.name}${list.total ? ` (${list.total})` : ''}`,
  })),
  ...(formState.segments.value?.map(segment => ({
    value: `ContactSegment:${segment.id}`,
    label: `Segmento: ${segment.name}`,
  })) || []),
]);

const selectedAudienceLabels = computed(() =>
  state.selectedAudience.map(value => {
    const option = audienceList.value.find(item => item.value === value);
    return option?.label || value;
  })
);

const inboxOptions = computed(() =>
  mapToOptions(formState.inboxes.value, 'id', 'name')
);

const templateOptions = computed(() => {
  if (!state.inboxId) return [];
  const templates = formState.getFilteredWhatsAppTemplates.value(state.inboxId);
  return templates.map(template => {
    // Create a more user-friendly label from template name
    const friendlyName = template.name
      .replace(/_/g, ' ')
      .replace(/\b\w/g, l => l.toUpperCase());

    return {
      value: template.id,
      label: `${friendlyName} (${template.language || 'en'})`,
      template: template,
    };
  });
});

const selectedTemplate = computed(() => {
  if (!state.templateId) return null;
  return templateOptions.value.find(option => option.value === state.templateId)
    ?.template;
});

const getErrorMessage = (field, errorKey) => {
  const baseKey = 'CAMPAIGN.WHATSAPP.CREATE.FORM';
  return v$.value[field].$error ? t(`${baseKey}.${errorKey}.ERROR`) : '';
};

const formErrors = computed(() => ({
  title: getErrorMessage('title', 'TITLE'),
  inbox: getErrorMessage('inboxId', 'INBOX'),
  template: getErrorMessage('templateId', 'TEMPLATE'),
  scheduledAt: getErrorMessage('scheduledAt', 'SCHEDULED_AT'),
  audience: getErrorMessage('selectedAudience', 'AUDIENCE'),
}));

const hasRequiredTemplateParams = computed(() => {
  return templateParserRef.value?.v$?.$invalid === false || true;
});

const isSubmitDisabled = computed(
  () => v$.value.$invalid || !hasRequiredTemplateParams.value
);

const formatToUTCString = localDateTime =>
  localDateTime ? new Date(localDateTime).toISOString() : null;

const resetState = () => {
  Object.assign(state, initialState);
  audienceSummary.value = null;
  audiencePreview.value = [];
  isReviewing.value = false;
  v$.value.$reset();
};

const handleCancel = () => emit('cancel');
const handleEditReview = () => {
  isReviewing.value = false;
};

const audiencePayload = computed(() =>
  state.selectedAudience.map(value => {
    const [type, ...idParts] = String(value).split(':');
    return { id: idParts.join(':'), type };
  })
);

const fetchSourceLists = async () => {
  try {
    const response = await ContactsAPI.getImports();
    const uniqueLists = new Map();
    response.data.forEach(importItem => {
      const name = importItem.metadata?.source_list;
      if (!name || uniqueLists.has(name)) return;
      uniqueLists.set(name, {
        name,
        total: importItem.total_records || importItem.processed_records || 0,
      });
    });
    sourceLists.value = [...uniqueLists.values()];
  } catch (error) {
    sourceLists.value = [];
  }
};

const fetchAudienceCount = async () => {
  if (!audiencePayload.value.length) {
    audienceSummary.value = null;
    audiencePreview.value = [];
    return;
  }

  isAudienceLoading.value = true;
  try {
    const response = await CampaignsAPI.audiencePreview(audiencePayload.value);
    audienceSummary.value = response.data.summary;
    audiencePreview.value = response.data.contacts || [];
  } finally {
    isAudienceLoading.value = false;
  }
};

const prepareCampaignDetails = () => {
  // Find the selected template to get its content
  const currentTemplate = selectedTemplate.value;
  const parserData = templateParserRef.value;

  // Extract template content - this should be the template message body
  const templateContent = parserData?.renderedTemplate || '';

  // Prepare template_params object with the same structure as used in contacts
  const templateParams = {
    name: currentTemplate?.name || '',
    namespace: currentTemplate?.namespace || '',
    category: currentTemplate?.category || 'UTILITY',
    language: currentTemplate?.language || 'en_US',
    processed_params: parserData?.processedParams || {},
  };

  return {
    title: state.title,
    message: templateContent,
    template_params: templateParams,
    inbox_id: state.inboxId,
    scheduled_at: formatToUTCString(state.scheduledAt),
    audience: audiencePayload.value,
  };
};

const formattedScheduledAt = computed(() => {
  if (!state.scheduledAt) return '-';

  return new Intl.DateTimeFormat('pt-BR', {
    dateStyle: 'short',
    timeStyle: 'short',
  }).format(new Date(state.scheduledAt));
});

const reviewTotalLabel = computed(
  () =>
    `${audienceSummary.value?.total || 0} contatos, ${
      audienceSummary.value?.without_phone_number || 0
    } sem telefone`
);

const handleSubmit = async () => {
  const isFormValid = await v$.value.$validate();
  if (!isFormValid) return;

  if (!isReviewing.value) {
    isReviewing.value = true;
    return;
  }

  emit('submit', prepareCampaignDetails());
  resetState();
  handleCancel();
};

// Reset template selection when inbox changes
watch(
  () => state.inboxId,
  () => {
    state.templateId = null;
  }
);

watch(() => [...state.selectedAudience], fetchAudienceCount);
watch(
  () => [
    state.title,
    state.inboxId,
    state.templateId,
    state.scheduledAt,
    state.selectedAudience.join(','),
  ],
  () => {
    if (isReviewing.value) isReviewing.value = false;
  }
);

onMounted(() => {
  store.dispatch('customViews/get', 'contact');
  fetchSourceLists();
});
</script>

<template>
  <form class="flex flex-col gap-4" @submit.prevent="handleSubmit">
    <Input
      v-model="state.title"
      :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.TITLE.LABEL')"
      :placeholder="t('CAMPAIGN.WHATSAPP.CREATE.FORM.TITLE.PLACEHOLDER')"
      :message="formErrors.title"
      :message-type="formErrors.title ? 'error' : 'info'"
    />

    <div class="flex flex-col gap-1">
      <label for="inbox" class="mb-0.5 text-sm font-medium text-n-slate-12">
        {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.INBOX.LABEL') }}
      </label>
      <ComboBox
        id="inbox"
        v-model="state.inboxId"
        :options="inboxOptions"
        :has-error="!!formErrors.inbox"
        :placeholder="t('CAMPAIGN.WHATSAPP.CREATE.FORM.INBOX.PLACEHOLDER')"
        :message="formErrors.inbox"
        class="[&>div>button]:bg-n-alpha-black2 [&>div>button:not(.focused)]:dark:outline-n-weak [&>div>button:not(.focused)]:hover:!outline-n-slate-6"
      />
    </div>

    <div class="flex flex-col gap-1">
      <label for="template" class="mb-0.5 text-sm font-medium text-n-slate-12">
        {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.LABEL') }}
      </label>
      <ComboBox
        id="template"
        v-model="state.templateId"
        :options="templateOptions"
        :has-error="!!formErrors.template"
        :placeholder="t('CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.PLACEHOLDER')"
        :message="formErrors.template"
        class="[&>div>button]:bg-n-alpha-black2 [&>div>button:not(.focused)]:dark:outline-n-weak [&>div>button:not(.focused)]:hover:!outline-n-slate-6"
      />
      <p class="mt-1 text-xs text-n-slate-11">
        {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.INFO') }}
      </p>
    </div>

    <!-- Template Parser -->
    <WhatsAppTemplateParser
      v-if="selectedTemplate"
      ref="templateParserRef"
      :template="selectedTemplate"
    />

    <div class="flex flex-col gap-1">
      <label for="audience" class="mb-0.5 text-sm font-medium text-n-slate-12">
        {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.AUDIENCE.LABEL') }}
      </label>
      <TagMultiSelectComboBox
        v-model="state.selectedAudience"
        :options="audienceList"
        :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.AUDIENCE.LABEL')"
        :placeholder="t('CAMPAIGN.WHATSAPP.CREATE.FORM.AUDIENCE.PLACEHOLDER')"
        :has-error="!!formErrors.audience"
        :message="formErrors.audience"
        class="[&>div>button]:bg-n-alpha-black2"
      />
      <p class="text-xs text-n-slate-11">
        <span v-if="isAudienceLoading">{{ audienceText.loading }}</span>
        <span v-else-if="audienceSummary">
          {{ audienceSummaryLabel }}
        </span>
      </p>
      <div
        v-if="audiencePreview.length"
        class="mt-2 rounded-lg border border-n-weak bg-n-alpha-2 p-3"
      >
        <div
          class="mb-2 flex items-center justify-between gap-3 text-xs font-medium text-n-slate-11"
        >
          <span>{{ audienceText.previewTitle }}</span>
          <span>{{ audiencePreviewCountLabel }}</span>
        </div>
        <div class="flex max-h-40 flex-col gap-2 overflow-y-auto">
          <div
            v-for="contact in audiencePreview"
            :key="contact.id"
            class="flex min-w-0 items-center justify-between gap-3 rounded-md bg-n-alpha-1 px-3 py-2 text-xs"
          >
            <div class="min-w-0">
              <p class="mb-0 truncate font-medium text-n-slate-12">
                {{ contact.name || contact.email || contact.phone_number }}
              </p>
              <p class="mb-0 truncate text-n-slate-11">
                {{ contact.phone_number || 'Sem telefone' }}
              </p>
            </div>
            <span
              class="shrink-0 rounded-md border border-n-weak px-2 py-1 text-n-slate-11"
            >
              {{ contact.source_list || contact.relationship_status || 'CRM' }}
            </span>
          </div>
        </div>
      </div>
    </div>

    <Input
      v-model="state.scheduledAt"
      :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.SCHEDULED_AT.LABEL')"
      type="datetime-local"
      :min="currentDateTime"
      :placeholder="t('CAMPAIGN.WHATSAPP.CREATE.FORM.SCHEDULED_AT.PLACEHOLDER')"
      :message="formErrors.scheduledAt"
      :message-type="formErrors.scheduledAt ? 'error' : 'info'"
    />

    <div
      v-if="isReviewing"
      class="rounded-lg border border-n-weak bg-n-alpha-2 p-3 text-sm"
    >
      <div class="mb-3 flex items-center justify-between gap-3">
        <span class="font-medium text-n-slate-12">{{ reviewText.title }}</span>
        <Button
          variant="link"
          color="slate"
          size="sm"
          type="button"
          :label="reviewText.edit"
          @click="handleEditReview"
        />
      </div>
      <dl class="grid gap-2 text-xs text-n-slate-11">
        <div class="grid grid-cols-[7rem_1fr] gap-2">
          <dt>{{ reviewText.campaignTitle }}</dt>
          <dd class="min-w-0 truncate text-n-slate-12">{{ state.title }}</dd>
        </div>
        <div class="grid grid-cols-[7rem_1fr] gap-2">
          <dt>{{ reviewText.template }}</dt>
          <dd class="min-w-0 truncate text-n-slate-12">
            {{ selectedTemplate?.name || '-' }}
          </dd>
        </div>
        <div class="grid grid-cols-[7rem_1fr] gap-2">
          <dt>{{ reviewText.schedule }}</dt>
          <dd class="text-n-slate-12">{{ formattedScheduledAt }}</dd>
        </div>
        <div class="grid grid-cols-[7rem_1fr] gap-2">
          <dt>{{ reviewText.audience }}</dt>
          <dd class="min-w-0 text-n-slate-12">
            {{ selectedAudienceLabels.join(', ') }}
          </dd>
        </div>
        <div class="grid grid-cols-[7rem_1fr] gap-2">
          <dt>{{ reviewText.total }}</dt>
          <dd class="text-n-slate-12">{{ reviewTotalLabel }}</dd>
        </div>
        <div class="grid grid-cols-[7rem_1fr] gap-2">
          <dt>{{ reviewText.message }}</dt>
          <dd class="min-w-0 whitespace-pre-wrap text-n-slate-12">
            {{ templateParserRef?.renderedTemplate || '' }}
          </dd>
        </div>
      </dl>
    </div>

    <div class="flex gap-3 justify-between items-center w-full">
      <Button
        variant="faded"
        color="slate"
        type="button"
        :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.BUTTONS.CANCEL')"
        class="w-full bg-n-alpha-2 text-n-blue-11 hover:bg-n-alpha-3"
        @click="handleCancel"
      />
      <Button
        :label="submitButtonLabel"
        class="w-full"
        type="submit"
        :is-loading="isCreating"
        :disabled="isCreating || isSubmitDisabled"
      />
    </div>
  </form>
</template>
