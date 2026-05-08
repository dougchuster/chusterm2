<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import CampaignsAPI from 'dashboard/api/campaigns';
import ContactsAPI from 'dashboard/api/contacts';

import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';

const emit = defineEmits(['submit', 'cancel']);

const store = useStore();
const copy = {
  subjectLabel: 'Assunto',
  subjectPlaceholder: 'Ex: Atualização do atendimento',
  contentLabel: 'Conteudo',
  contentPlaceholder:
    'Escreva o email. Use {{contact.name}} para personalizar.',
  draftButton: 'Gerar rascunho com IA',
  inboxLabel: 'Caixa de email',
  inboxPlaceholder: 'Selecione uma caixa de email',
  audienceLabel: 'Publico',
  audiencePlaceholder: 'Etiquetas, listas ou segmentos',
  loadingAudience: 'Calculando audiencia...',
  missingEmail: 'Sem email',
  scheduleLabel: 'Agendar envio',
  reviewTitle: 'Revisão final',
  reviewSubject: 'Assunto',
  reviewSchedule: 'Agenda',
  reviewTotal: 'Total',
  cancel: 'Cancelar',
  reviewCampaign: 'Revisar campanha',
  confirmCampaign: 'Confirmar e criar',
};
const formState = {
  uiFlags: useMapGetter('campaigns/getUIFlags'),
  labels: useMapGetter('labels/getLabels'),
  segments: useMapGetter('customViews/getContactCustomViews'),
  inboxes: useMapGetter('inboxes/getEmailInboxes'),
};

const state = reactive({
  title: '',
  message: '',
  inboxId: null,
  scheduledAt: '',
  selectedAudience: [],
});

const audienceSummary = ref(null);
const audiencePreview = ref([]);
const sourceLists = ref([]);
const isAudienceLoading = ref(false);
const isReviewing = ref(false);

const isCreating = computed(() => formState.uiFlags.value.isCreating);
const isSubmitDisabled = computed(
  () =>
    !state.title.trim() ||
    !state.message.trim() ||
    !state.inboxId ||
    !state.scheduledAt ||
    !state.selectedAudience.length
);

const currentDateTime = computed(() => {
  const now = new Date();
  const localTime = new Date(now.getTime() - now.getTimezoneOffset() * 60000);
  return localTime.toISOString().slice(0, 16);
});

const inboxOptions = computed(() =>
  (formState.inboxes.value || []).map(inbox => ({
    value: inbox.id,
    label: inbox.name,
  }))
);

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

const audiencePayload = computed(() =>
  state.selectedAudience.map(value => {
    const [type, ...idParts] = String(value).split(':');
    return { id: idParts.join(':'), type };
  })
);

const audienceSummaryLabel = computed(() => {
  if (!audienceSummary.value) return '';
  return `Audiencia: ${audienceSummary.value.total} contatos, ${audienceSummary.value.with_email || 0} com email.`;
});

const formattedScheduledAt = computed(() => {
  if (!state.scheduledAt) return '-';
  return new Intl.DateTimeFormat('pt-BR', {
    dateStyle: 'short',
    timeStyle: 'short',
  }).format(new Date(state.scheduledAt));
});

const formatToUTCString = localDateTime =>
  localDateTime ? new Date(localDateTime).toISOString() : null;

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
  } catch {
    sourceLists.value = [];
  }
};

const fetchAudiencePreview = async () => {
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

const generateDraft = () => {
  const title = state.title || 'Atualização do seu atendimento jurídico';
  state.title = title;
  state.message = [
    'Ola {{contact.name}},',
    '',
    'Estamos passando para atualizar o andamento do seu atendimento e confirmar se você precisa de algum apoio adicional.',
    '',
    'Responda este email para falar com a nossa equipe.',
  ].join('\n');
};

const prepareCampaignDetails = () => ({
  title: state.title,
  message: state.message,
  inbox_id: state.inboxId,
  scheduled_at: formatToUTCString(state.scheduledAt),
  audience: audiencePayload.value,
  template_params: {
    channel: 'email',
    editor: 'simple',
  },
});

const handleSubmit = () => {
  if (isSubmitDisabled.value) return;
  if (!isReviewing.value) {
    isReviewing.value = true;
    return;
  }

  emit('submit', prepareCampaignDetails());
  emit('cancel');
};

watch(() => [...state.selectedAudience], fetchAudiencePreview);
watch(
  () => [state.title, state.message, state.inboxId, state.scheduledAt],
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
      :label="copy.subjectLabel"
      :placeholder="copy.subjectPlaceholder"
    />
    <TextArea
      v-model="state.message"
      :label="copy.contentLabel"
      :placeholder="copy.contentPlaceholder"
      rows="8"
    />
    <Button
      variant="faded"
      color="slate"
      type="button"
      :label="copy.draftButton"
      @click="generateDraft"
    />

    <div class="flex flex-col gap-1">
      <label
        for="email-inbox"
        class="mb-0.5 text-sm font-medium text-n-slate-12"
      >
        {{ copy.inboxLabel }}
      </label>
      <ComboBox
        id="email-inbox"
        v-model="state.inboxId"
        :options="inboxOptions"
        :placeholder="copy.inboxPlaceholder"
        class="[&>div>button]:bg-n-alpha-black2"
      />
    </div>

    <div class="flex flex-col gap-1">
      <label
        for="email-audience"
        class="mb-0.5 text-sm font-medium text-n-slate-12"
      >
        {{ copy.audienceLabel }}
      </label>
      <TagMultiSelectComboBox
        v-model="state.selectedAudience"
        :options="audienceList"
        :label="copy.audienceLabel"
        :placeholder="copy.audiencePlaceholder"
        class="[&>div>button]:bg-n-alpha-black2"
      />
      <p class="text-xs text-n-slate-11">
        <span v-if="isAudienceLoading">{{ copy.loadingAudience }}</span>
        <span v-else-if="audienceSummary">{{ audienceSummaryLabel }}</span>
      </p>
      <div
        v-if="audiencePreview.length"
        class="mt-2 flex max-h-40 flex-col gap-2 overflow-y-auto rounded-lg border border-n-weak bg-n-alpha-2 p-3"
      >
        <div
          v-for="contact in audiencePreview"
          :key="contact.id"
          class="flex min-w-0 justify-between gap-3 rounded-md bg-n-alpha-1 px-3 py-2 text-xs"
        >
          <span class="min-w-0 truncate text-n-slate-12">
            {{ contact.name || contact.email }}
          </span>
          <span class="shrink-0 text-n-slate-11">
            {{ contact.email || copy.missingEmail }}
          </span>
        </div>
      </div>
    </div>

    <Input
      v-model="state.scheduledAt"
      :label="copy.scheduleLabel"
      type="datetime-local"
      :min="currentDateTime"
    />

    <div
      v-if="isReviewing"
      class="rounded-lg border border-n-weak bg-n-alpha-2 p-3 text-sm"
    >
      <strong class="text-n-slate-12">{{ copy.reviewTitle }}</strong>
      <dl class="mt-3 grid gap-2 text-xs text-n-slate-11">
        <div class="grid grid-cols-[6rem_1fr] gap-2">
          <dt>{{ copy.reviewSubject }}</dt>
          <dd class="min-w-0 truncate text-n-slate-12">{{ state.title }}</dd>
        </div>
        <div class="grid grid-cols-[6rem_1fr] gap-2">
          <dt>{{ copy.reviewSchedule }}</dt>
          <dd class="text-n-slate-12">{{ formattedScheduledAt }}</dd>
        </div>
        <div class="grid grid-cols-[6rem_1fr] gap-2">
          <dt>{{ copy.reviewTotal }}</dt>
          <dd class="text-n-slate-12">{{ audienceSummaryLabel }}</dd>
        </div>
      </dl>
    </div>

    <div class="flex items-center justify-between gap-3">
      <Button
        variant="faded"
        color="slate"
        type="button"
        :label="copy.cancel"
        class="w-full bg-n-alpha-2 text-n-blue-11 hover:bg-n-alpha-3"
        @click="emit('cancel')"
      />
      <Button
        class="w-full"
        type="submit"
        :label="isReviewing ? copy.confirmCampaign : copy.reviewCampaign"
        :is-loading="isCreating"
        :disabled="isCreating || isSubmitDisabled"
      />
    </div>
  </form>
</template>
