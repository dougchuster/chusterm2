<script setup>
import { reactive, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';
import { useMapGetter } from 'dashboard/composables/store';

import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';

const props = defineProps({
  assistantId: {
    type: Number,
    required: true,
  },
});

const emit = defineEmits(['submit', 'cancel']);

const { t } = useI18n();

const formState = {
  uiFlags: useMapGetter('captainInboxes/getUIFlags'),
  inboxes: useMapGetter('inboxes/getInboxes'),
  captainInboxes: useMapGetter('captainInboxes/getRecords'),
};

const initialState = {
  inboxId: null,
  enabled: true,
  autoReplyEnabled: true,
  aiMode: 'auto',
  handoffStrategy: 'human_request_or_score',
};

const state = reactive({ ...initialState });

const validationRules = {
  inboxId: { required },
};

const inboxList = computed(() => {
  const captainInboxIds = formState.captainInboxes.value.map(inbox => inbox.id);

  return formState.inboxes.value
    .filter(inbox => !captainInboxIds.includes(inbox.id))
    .map(inbox => ({
      value: inbox.id,
      label: inbox.name,
    }));
});

const v$ = useVuelidate(validationRules, state);

const isLoading = computed(() => formState.uiFlags.value.creatingItem);

const aiModeOptions = computed(() => [
  { value: 'auto', label: t('CAPTAIN.INBOXES.FORM.AI_MODE.AUTO') },
  {
    value: 'supervised',
    label: t('CAPTAIN.INBOXES.FORM.AI_MODE.SUPERVISED'),
  },
  { value: 'paused', label: t('CAPTAIN.INBOXES.FORM.AI_MODE.PAUSED') },
  {
    value: 'human_only',
    label: t('CAPTAIN.INBOXES.FORM.AI_MODE.HUMAN_ONLY'),
  },
]);

const handoffStrategyOptions = computed(() => [
  {
    value: 'human_request_or_score',
    label: t('CAPTAIN.INBOXES.FORM.HANDOFF.HUMAN_REQUEST_OR_SCORE'),
  },
  {
    value: 'human_request',
    label: t('CAPTAIN.INBOXES.FORM.HANDOFF.HUMAN_REQUEST'),
  },
  {
    value: 'score_threshold',
    label: t('CAPTAIN.INBOXES.FORM.HANDOFF.SCORE_THRESHOLD'),
  },
  {
    value: 'manual_only',
    label: t('CAPTAIN.INBOXES.FORM.HANDOFF.MANUAL_ONLY'),
  },
]);

const getErrorMessage = (field, errorKey) => {
  return v$.value[field].$error
    ? t(`CAPTAIN.INBOXES.FORM.${errorKey}.ERROR`)
    : '';
};

const formErrors = computed(() => ({
  inboxId: getErrorMessage('inboxId', 'INBOX'),
}));

const handleCancel = () => emit('cancel');

const prepareInboxPayload = () => ({
  inboxId: state.inboxId,
  assistantId: props.assistantId,
  enabled: state.enabled,
  autoReplyEnabled: state.autoReplyEnabled,
  aiMode: state.aiMode,
  handoffStrategy: state.handoffStrategy,
});

const handleSubmit = async () => {
  const isFormValid = await v$.value.$validate();
  if (!isFormValid) {
    return;
  }

  emit('submit', prepareInboxPayload());
};
</script>

<template>
  <form class="flex flex-col gap-4" @submit.prevent="handleSubmit">
    <div class="flex flex-col gap-1">
      <label for="inbox" class="mb-0.5 text-sm font-medium text-n-slate-12">
        {{ t('CAPTAIN.INBOXES.FORM.INBOX.LABEL') }}
      </label>
      <ComboBox
        id="inbox"
        v-model="state.inboxId"
        :options="inboxList"
        :has-error="!!formErrors.inboxId"
        :placeholder="t('CAPTAIN.INBOXES.FORM.INBOX.PLACEHOLDER')"
        class="[&>div>button]:bg-n-alpha-black2 [&>div>button:not(.focused)]:dark:outline-n-weak [&>div>button:not(.focused)]:hover:!outline-n-slate-6"
        :message="formErrors.inboxId"
      />
    </div>

    <div class="grid grid-cols-1 gap-4 md:grid-cols-2">
      <div class="flex flex-col gap-1">
        <label class="mb-0.5 text-sm font-medium text-n-slate-12">
          {{ t('CAPTAIN.INBOXES.FORM.AI_MODE.LABEL') }}
        </label>
        <Select
          v-model="state.aiMode"
          :options="aiModeOptions"
          class="[&>select]:w-full"
        />
      </div>

      <div class="flex flex-col gap-1">
        <label class="mb-0.5 text-sm font-medium text-n-slate-12">
          {{ t('CAPTAIN.INBOXES.FORM.HANDOFF.LABEL') }}
        </label>
        <Select
          v-model="state.handoffStrategy"
          :options="handoffStrategyOptions"
          class="[&>select]:w-full"
        />
      </div>
    </div>

    <div class="flex flex-col gap-3 rounded-lg bg-n-alpha-2 p-3">
      <label class="flex items-center justify-between gap-3">
        <span class="flex flex-col gap-0.5">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('CAPTAIN.INBOXES.FORM.ENABLED.LABEL') }}
          </span>
          <span class="text-xs text-n-slate-11">
            {{ t('CAPTAIN.INBOXES.FORM.ENABLED.HELP') }}
          </span>
        </span>
        <Switch v-model="state.enabled" />
      </label>

      <label class="flex items-center justify-between gap-3">
        <span class="flex flex-col gap-0.5">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('CAPTAIN.INBOXES.FORM.AUTO_REPLY.LABEL') }}
          </span>
          <span class="text-xs text-n-slate-11">
            {{ t('CAPTAIN.INBOXES.FORM.AUTO_REPLY.HELP') }}
          </span>
        </span>
        <Switch v-model="state.autoReplyEnabled" />
      </label>
    </div>

    <div class="flex items-center justify-between w-full gap-3">
      <Button
        type="button"
        variant="faded"
        color="slate"
        :label="t('CAPTAIN.FORM.CANCEL')"
        class="w-full bg-n-alpha-2 text-n-blue-11 hover:bg-n-alpha-3"
        @click="handleCancel"
      />
      <Button
        type="submit"
        :label="t('CAPTAIN.FORM.CREATE')"
        class="w-full"
        :is-loading="isLoading"
        :disabled="isLoading"
      />
    </div>
  </form>
</template>
