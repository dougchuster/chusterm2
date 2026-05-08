<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import validations, { getLabelTitleErrorMessage } from './validations';
import { useVuelidate } from '@vuelidate/core';

import NextButton from 'dashboard/components-next/button/Button.vue';

const CRM_CATEGORIES = [
  { value: '', label: 'Sem categoria' },
  { value: 'area', label: 'Setor jurídico' },
  { value: 'temperature', label: 'Temperatura' },
  { value: 'relationship', label: 'Relacionamento' },
  { value: 'status', label: 'Status' },
  { value: 'document', label: 'Documento' },
  { value: 'origin', label: 'Origem' },
  { value: 'risk', label: 'Risco' },
  { value: 'service', label: 'Atendimento' },
];

const CRM_SCOPES = [
  { value: 'both', label: 'Contato e conversa' },
  { value: 'contact', label: 'Apenas contato' },
  { value: 'conversation', label: 'Apenas conversa' },
];

export default {
  components: {
    NextButton,
  },
  props: {
    selectedResponse: {
      type: Object,
      default: () => {},
    },
  },
  emits: ['close'],
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      title: '',
      description: '',
      category: '',
      slug: '',
      scope: 'both',
      showOnSidebar: true,
      color: '',
      categories: CRM_CATEGORIES,
      scopes: CRM_SCOPES,
      formText: {
        category: 'Categoria',
        scope: 'Escopo',
      },
    };
  },
  validations,
  computed: {
    ...mapGetters({
      uiFlags: 'labels/getUIFlags',
    }),
    pageTitle() {
      return `${this.$t('LABEL_MGMT.EDIT.TITLE')} - ${
        this.selectedResponse.title
      }`;
    },
    labelTitleErrorMessage() {
      const errorMessage = getLabelTitleErrorMessage(this.v$);
      return this.$t(errorMessage);
    },
    normalizedSlug() {
      return this.slug ? this.slug.toLowerCase().trim() : undefined;
    },
  },
  mounted() {
    this.setFormValues();
  },
  methods: {
    onClose() {
      this.$emit('close');
    },
    setFormValues() {
      this.title = this.selectedResponse.title;
      this.description = this.selectedResponse.description;
      this.category = this.selectedResponse.category || '';
      this.slug = this.selectedResponse.slug || '';
      this.scope = this.selectedResponse.scope || 'both';
      this.showOnSidebar = this.selectedResponse.show_on_sidebar;
      this.color = this.selectedResponse.color;
    },
    editLabel() {
      this.$store
        .dispatch('labels/update', {
          id: this.selectedResponse.id,
          color: this.color,
          category: this.category || null,
          description: this.description,
          scope: this.scope,
          slug: this.normalizedSlug || null,
          title: this.title.toLowerCase(),
          show_on_sidebar: this.showOnSidebar,
        })
        .then(() => {
          useAlert(this.$t('LABEL_MGMT.EDIT.API.SUCCESS_MESSAGE'));
          setTimeout(() => this.onClose(), 10);
        })
        .catch(() => {
          useAlert(this.$t('LABEL_MGMT.EDIT.API.ERROR_MESSAGE'));
        });
    },
  },
};
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header :header-title="pageTitle" />
    <form class="flex flex-wrap mx-0" @submit.prevent="editLabel">
      <woot-input
        v-model="title"
        :class="{ error: v$.title.$error }"
        class="w-full label-name--input"
        :label="$t('LABEL_MGMT.FORM.NAME.LABEL')"
        :placeholder="$t('LABEL_MGMT.FORM.NAME.PLACEHOLDER')"
        :error="labelTitleErrorMessage"
        @input="v$.title.$touch"
        @blur="v$.title.$touch"
      />
      <woot-input
        v-model="description"
        :class="{ error: v$.description.$error }"
        class="w-full"
        :label="$t('LABEL_MGMT.FORM.DESCRIPTION.LABEL')"
        :placeholder="$t('LABEL_MGMT.FORM.DESCRIPTION.PLACEHOLDER')"
        @input="v$.description.$touch"
        @blur="v$.description.$touch"
      />

      <div class="grid w-full grid-cols-1 gap-3 md:grid-cols-3">
        <label class="flex flex-col gap-1 text-sm text-n-slate-11">
          {{ formText.category }}
          <select
            v-model="category"
            class="h-10 px-3 rounded-md border border-n-weak bg-n-alpha-2 text-n-slate-12"
          >
            <option
              v-for="option in categories"
              :key="option.value"
              :value="option.value"
            >
              {{ option.label }}
            </option>
          </select>
        </label>

        <woot-input
          v-model="slug"
          class="w-full"
          label="Slug CRM"
          placeholder="area.previdenciario"
        />

        <label class="flex flex-col gap-1 text-sm text-n-slate-11">
          {{ formText.scope }}
          <select
            v-model="scope"
            class="h-10 px-3 rounded-md border border-n-weak bg-n-alpha-2 text-n-slate-12"
          >
            <option
              v-for="option in scopes"
              :key="option.value"
              :value="option.value"
            >
              {{ option.label }}
            </option>
          </select>
        </label>
      </div>

      <div class="w-full">
        <label>
          {{ $t('LABEL_MGMT.FORM.COLOR.LABEL') }}
          <woot-color-picker v-model="color" />
        </label>
      </div>
      <div class="flex items-center w-full gap-2">
        <input v-model="showOnSidebar" type="checkbox" :value="true" />
        <label for="conversation_creation">
          {{ $t('LABEL_MGMT.FORM.SHOW_ON_SIDEBAR.LABEL') }}
        </label>
      </div>
      <div class="flex items-center justify-end w-full gap-2 px-0 py-2">
        <NextButton
          faded
          slate
          type="reset"
          :label="$t('LABEL_MGMT.FORM.CANCEL')"
          @click.prevent="onClose"
        />
        <NextButton
          type="submit"
          :label="$t('LABEL_MGMT.FORM.EDIT')"
          :disabled="v$.title.$invalid || uiFlags.isUpdating"
          :is-loading="uiFlags.isUpdating"
        />
      </div>
    </form>
  </div>
</template>

<style lang="scss" scoped>
// Label API supports only lowercase letters
.label-name--input {
  :deep() {
    input {
      @apply lowercase;
    }
  }
}
</style>
