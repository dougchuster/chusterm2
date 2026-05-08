<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import validations, { getLabelTitleErrorMessage } from './validations';
import { getRandomColor } from 'dashboard/helper/labelColor';
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
    prefillTitle: {
      type: String,
      default: '',
    },
  },
  emits: ['close'],
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      color: '#000',
      description: '',
      title: '',
      category: '',
      slug: '',
      scope: 'both',
      showOnSidebar: true,
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
    labelTitleErrorMessage() {
      const errorMessage = getLabelTitleErrorMessage(this.v$);
      return this.$t(errorMessage);
    },
    normalizedSlug() {
      return this.slug ? this.slug.toLowerCase().trim() : undefined;
    },
  },
  mounted() {
    this.color = getRandomColor();
    this.title = this.prefillTitle.toLowerCase();
  },
  methods: {
    onClose() {
      this.$emit('close');
    },
    async addLabel() {
      try {
        await this.$store.dispatch('labels/create', {
          color: this.color,
          category: this.category || null,
          description: this.description,
          scope: this.scope,
          slug: this.normalizedSlug || null,
          title: this.title.toLowerCase(),
          show_on_sidebar: this.showOnSidebar,
        });
        useAlert(this.$t('LABEL_MGMT.ADD.API.SUCCESS_MESSAGE'));
        this.onClose();
      } catch (error) {
        const errorMessage =
          error.message || this.$t('LABEL_MGMT.ADD.API.ERROR_MESSAGE');
        useAlert(errorMessage);
      }
    },
    updateSlugSuggestion() {
      if (!this.category || !this.title || this.slug) return;

      this.slug = `${this.category}.${this.title}`
        .toLowerCase()
        .replace(/_/g, '.')
        .replace(/\s+/g, '_');
    },
  },
};
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header
      :header-title="$t('LABEL_MGMT.ADD.TITLE')"
      :header-content="$t('LABEL_MGMT.ADD.DESC')"
    />
    <form class="flex flex-wrap mx-0" @submit.prevent="addLabel">
      <woot-input
        v-model="title"
        :class="{ error: v$.title.$error }"
        class="w-full label-name--input"
        :label="$t('LABEL_MGMT.FORM.NAME.LABEL')"
        :placeholder="$t('LABEL_MGMT.FORM.NAME.PLACEHOLDER')"
        :error="labelTitleErrorMessage"
        data-testid="label-title"
        @input="v$.title.$touch"
        @blur="v$.title.$touch"
      />

      <woot-input
        v-model="description"
        :class="{ error: v$.description.$error }"
        class="w-full"
        :label="$t('LABEL_MGMT.FORM.DESCRIPTION.LABEL')"
        :placeholder="$t('LABEL_MGMT.FORM.DESCRIPTION.PLACEHOLDER')"
        data-testid="label-description"
        @input="v$.description.$touch"
        @blur="v$.description.$touch"
      />

      <div class="grid w-full grid-cols-1 gap-3 md:grid-cols-3">
        <label class="flex flex-col gap-1 text-sm text-n-slate-11">
          {{ formText.category }}
          <select
            v-model="category"
            class="h-10 px-3 rounded-md border border-n-weak bg-n-alpha-2 text-n-slate-12"
            @change="updateSlugSuggestion"
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
          data-testid="label-submit"
          :label="$t('LABEL_MGMT.FORM.CREATE')"
          :disabled="v$.title.$invalid || uiFlags.isCreating"
          :is-loading="uiFlags.isCreating"
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
