<script setup>
import { computed } from 'vue';

import { DsButton, DsDrawer, DsInput, DsSelect } from 'dashboard/design-system/components';

/**
 * Formulário de negócio novo, extraído de `CrmIndexOperational.vue` quando a
 * página passou do teto de 800 linhas.
 *
 * O formulário continua vivendo na página (`v-model`): quem abre o drawer é
 * quem sabe de que coluna veio o clique e qual etapa pré-selecionar.
 */
const props = defineProps({
  modelValue: { type: Object, required: true },
  open: { type: Boolean, default: false },
  saving: { type: Boolean, default: false },
  stageOptions: { type: Array, default: () => [] },
});

const emit = defineEmits(['update:modelValue', 'close', 'submit']);

// Campo a campo, sempre devolvendo um objeto novo — o pai nunca vê o seu
// formulário mudar por baixo.
const field = name =>
  computed({
    get: () => props.modelValue[name],
    set: value => emit('update:modelValue', { ...props.modelValue, [name]: value }),
  });

const title = field('title');
const contactName = field('contact_name');
const contactPhoneNumber = field('contact_phone_number');
const stageId = field('crm_pipeline_stage_id');

const canSubmit = computed(() => Boolean(String(props.modelValue.title || '').trim()));
</script>

<template>
  <DsDrawer
    id="create-deal-drawer"
    :open="open"
    :title="$t('CRM.CREATE_DEAL.TITLE')"
    :description="$t('CRM.CREATE_DEAL.DESCRIPTION')"
    :loading="saving"
    @close="emit('close')"
  >
    <form class="grid gap-4" @submit.prevent="emit('submit')">
      <DsInput
        v-model="title"
        :label="$t('CRM.CREATE_DEAL.SUBJECT')"
        :placeholder="$t('CRM.CREATE_DEAL.SUBJECT_PLACEHOLDER')"
        required
      />
      <DsInput
        v-model="contactName"
        :label="$t('CRM.CREATE_DEAL.CONTACT_NAME')"
        autocomplete="name"
      />
      <DsInput
        v-model="contactPhoneNumber"
        :label="$t('CRM.CREATE_DEAL.PHONE')"
        type="tel"
        autocomplete="tel"
      />
      <DsSelect
        v-model="stageId"
        :label="$t('CRM.CREATE_DEAL.INITIAL_STAGE')"
        :options="stageOptions"
      />
    </form>
    <template #footer>
      <div class="flex justify-end gap-2">
        <DsButton
          :label="$t('CRM.CREATE_DEAL.CANCEL')"
          variant="ghost"
          :disabled="saving"
          @click="emit('close')"
        />
        <DsButton
          :label="$t('CRM.CREATE_DEAL.SUBMIT')"
          variant="primary"
          :loading="saving"
          :disabled="!canSubmit"
          @click="emit('submit')"
        />
      </div>
    </template>
  </DsDrawer>
</template>
