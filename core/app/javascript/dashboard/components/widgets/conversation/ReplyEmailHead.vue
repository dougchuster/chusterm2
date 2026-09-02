<script>
import { validEmailsByComma } from './helpers/emailHeadHelper';
import { useVuelidate } from '@vuelidate/core';
import ButtonV4 from 'dashboard/components-next/button/Button.vue';

export default {
  components: {
    ButtonV4,
  },
  props: {
    ccEmails: {
      type: String,
      default: '',
    },
    bccEmails: {
      type: String,
      default: '',
    },
    toEmails: {
      type: String,
      default: '',
    },
  },
  emits: ['update:bccEmails', 'update:ccEmails', 'update:toEmails'],
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      showBcc: false,
      ccEmailsVal: '',
      bccEmailsVal: '',
      toEmailsVal: '',
    };
  },
  watch: {
    bccEmails(newVal) {
      if (newVal !== this.bccEmailsVal) {
        this.bccEmailsVal = newVal;
      }
    },
    ccEmails(newVal) {
      if (newVal !== this.ccEmailsVal) {
        this.ccEmailsVal = newVal;
      }
    },
    toEmails(newVal) {
      if (newVal !== this.toEmailsVal) {
        this.toEmailsVal = newVal;
      }
    },
  },
  mounted() {
    this.ccEmailsVal = this.ccEmails;
    this.bccEmailsVal = this.bccEmails;
    this.toEmailsVal = this.toEmails;
  },
  validations: {
    ccEmailsVal: {
      hasValidEmails(value) {
        return validEmailsByComma(value);
      },
    },
    bccEmailsVal: {
      hasValidEmails(value) {
        return validEmailsByComma(value);
      },
    },
    toEmailsVal: {
      hasValidEmails(value) {
        return validEmailsByComma(value);
      },
    },
  },
  methods: {
    handleAddBcc() {
      this.showBcc = true;
    },
    onBlur() {
      this.v$.$touch();
      this.$emit('update:bccEmails', this.bccEmailsVal);
      this.$emit('update:ccEmails', this.ccEmailsVal);
      this.$emit('update:toEmails', this.toEmailsVal);
    },
  },
};
</script>

<template>
  <div>
    <div v-if="toEmails">
      <div
        class="input-group small my-1 flex items-center gap-2 border-b border-solid border-ds-border-subtle"
        :class="{ 'border-ds-state-danger': v$.toEmailsVal.$error }"
      >
        <label
          class="input-group-label border-transparent bg-transparent pl-0 text-xs font-semibold text-ds-fg-muted"
          :class="{ 'text-ds-state-danger': v$.toEmailsVal.$error }"
        >
          {{ $t('CONVERSATION.REPLYBOX.EMAIL_HEAD.TO') }}
        </label>
        <div class="m-0 min-w-0 flex-1 rounded-none whitespace-nowrap">
          <woot-input
            v-model="v$.toEmailsVal.$model"
            type="text"
            class="[&>input]:!mb-0 [&>input]:h-8 [&>input]:border-0 [&>input]:border-transparent [&>input]:!bg-transparent [&>input]:!text-sm [&>input]:text-ds-fg-default [&>input]:!outline-none"
            :class="{ error: v$.toEmailsVal.$error }"
            :placeholder="$t('CONVERSATION.REPLYBOX.EMAIL_HEAD.CC.PLACEHOLDER')"
            @blur="onBlur"
          />
        </div>
      </div>
    </div>
    <div class="input-group-wrap">
      <div
        class="input-group small my-1 flex items-center gap-2 border-b border-solid border-ds-border-subtle"
        :class="{ 'border-ds-state-danger': v$.ccEmailsVal.$error }"
      >
        <label
          class="input-group-label border-transparent bg-transparent pl-0 text-xs font-semibold text-ds-fg-muted"
          :class="{ 'text-ds-state-danger': v$.ccEmailsVal.$error }"
        >
          {{ $t('CONVERSATION.REPLYBOX.EMAIL_HEAD.CC.LABEL') }}
        </label>
        <div class="m-0 min-w-0 flex-1 rounded-none whitespace-nowrap">
          <woot-input
            v-model="v$.ccEmailsVal.$model"
            class="[&>input]:!mb-0 [&>input]:h-8 [&>input]:border-0 [&>input]:border-transparent [&>input]:!bg-transparent [&>input]:!text-sm [&>input]:text-ds-fg-default [&>input]:!outline-none"
            type="text"
            :class="{ error: v$.ccEmailsVal.$error }"
            :placeholder="$t('CONVERSATION.REPLYBOX.EMAIL_HEAD.CC.PLACEHOLDER')"
            @blur="onBlur"
          />
        </div>
        <ButtonV4
          v-if="!showBcc"
          :label="$t('CONVERSATION.REPLYBOX.EMAIL_HEAD.ADD_BCC')"
          ghost
          xs
          primary
          @click="handleAddBcc"
        />
      </div>
      <span v-if="v$.ccEmailsVal.$error" class="text-sm text-ds-state-danger">
        {{ $t('CONVERSATION.REPLYBOX.EMAIL_HEAD.CC.ERROR') }}
      </span>
    </div>
    <div v-if="showBcc" class="input-group-wrap">
      <div
        class="input-group small my-1 flex items-center gap-2 border-b border-solid border-ds-border-subtle"
        :class="{ 'border-ds-state-danger': v$.bccEmailsVal.$error }"
      >
        <label
          class="input-group-label border-transparent bg-transparent pl-0 text-xs font-semibold text-ds-fg-muted"
          :class="{ 'text-ds-state-danger': v$.bccEmailsVal.$error }"
        >
          {{ $t('CONVERSATION.REPLYBOX.EMAIL_HEAD.BCC.LABEL') }}
        </label>
        <div class="m-0 min-w-0 flex-1 rounded-none whitespace-nowrap">
          <woot-input
            v-model="v$.bccEmailsVal.$model"
            type="text"
            class="[&>input]:!mb-0 [&>input]:h-8 [&>input]:border-0 [&>input]:border-transparent [&>input]:!bg-transparent [&>input]:!text-sm [&>input]:text-ds-fg-default [&>input]:!outline-none"
            :class="{ error: v$.bccEmailsVal.$error }"
            :placeholder="
              $t('CONVERSATION.REPLYBOX.EMAIL_HEAD.BCC.PLACEHOLDER')
            "
            @blur="onBlur"
          />
        </div>
      </div>
      <span v-if="v$.bccEmailsVal.$error" class="text-sm text-ds-state-danger">
        {{ $t('CONVERSATION.REPLYBOX.EMAIL_HEAD.BCC.ERROR') }}
      </span>
    </div>
  </div>
</template>
