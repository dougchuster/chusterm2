<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script>
import { mapGetters } from 'vuex';
import { useVuelidate } from '@vuelidate/core';
import { useAlert } from 'dashboard/composables';
import { required } from '@vuelidate/validators';
import { useBranding } from 'shared/composables/useBranding';
import router from '../../../../index';
import NextButton from 'dashboard/components-next/button/Button.vue';

export default {
  components: {
    NextButton,
  },
  setup() {
    const { replaceInstallationName } = useBranding();
    return { v$: useVuelidate(), replaceInstallationName };
  },
  data() {
    return {
      inboxName: '',
      instanceName: '',
      evolutionConfigured: false,
      evolutionConfigLoading: false,
      labels: {
        notConfigured:
          'A Evolution API ainda não foi configurada. Acesse Configurações > Evolution API, salve a URL pública, chave global e URL de webhook, depois volte para criar a caixa.',
        automaticInstance:
          'A instância será criada automaticamente na Evolution API.',
        automaticWebhook:
          'O webhook será configurado automaticamente para o ChusteRM.',
        qrInsideChatwoot:
          'Após criar, escaneie o QR Code dentro do próprio ChusteRM.',
      },
    };
  },
  computed: {
    ...mapGetters({
      uiFlags: 'inboxes/getUIFlags',
      accountId: 'getCurrentAccountId',
    }),
  },
  validations: {
    inboxName: { required },
    instanceName: { required },
  },
  async mounted() {
    await this.loadEvolutionConfiguration();
  },
  methods: {
    async loadEvolutionConfiguration() {
      this.evolutionConfigLoading = true;
      try {
        const config = await this.$store.dispatch(
          'evolution/fetchConfiguration',
          this.accountId
        );
        this.evolutionConfigured = Boolean(config?.configured);
      } catch {
        this.evolutionConfigured = false;
      } finally {
        this.evolutionConfigLoading = false;
      }
    },
    async createChannel() {
      this.v$.$touch();
      if (this.v$.$invalid) return;

      if (!this.evolutionConfigured) {
        useAlert(
          'Configure a Evolution API em Configurações > Evolution API antes de criar a caixa.'
        );
        return;
      }

      try {
        const whatsappChannel = await this.$store.dispatch(
          'inboxes/createEvolutionChannel',
          {
            name: this.inboxName?.trim(),
            instance_name: this.instanceName?.trim(),
          }
        );

        router.replace({
          name: 'settings_inboxes_add_agents',
          params: {
            page: 'new',
            inbox_id: whatsappChannel.id,
          },
        });
      } catch (error) {
        useAlert(
          error.message || this.$t('INBOX_MGMT.ADD.WHATSAPP.API.ERROR_MESSAGE')
        );
      }
    },
  },
};
</script>

<template>
  <form class="flex flex-wrap flex-col mx-0" @submit.prevent="createChannel()">
    <div
      v-if="!evolutionConfigLoading && !evolutionConfigured"
      class="mb-4 p-4 rounded-lg bg-n-ruby-3 text-sm text-n-ruby-11"
    >
      {{ labels.notConfigured }}
    </div>

    <div class="flex-shrink-0 flex-grow-0">
      <label :class="{ error: v$.inboxName.$error }">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP.INBOX_NAME.LABEL') }}
        <input
          v-model="inboxName"
          type="text"
          :placeholder="$t('INBOX_MGMT.ADD.WHATSAPP.INBOX_NAME.PLACEHOLDER')"
          @blur="v$.inboxName.$touch"
        />
        <span v-if="v$.inboxName.$error" class="message">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.INBOX_NAME.ERROR') }}
        </span>
      </label>
    </div>

    <div class="flex-shrink-0 flex-grow-0">
      <label :class="{ error: v$.instanceName.$error }">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.INSTANCE_NAME.LABEL') }}
        <input
          v-model="instanceName"
          type="text"
          :placeholder="
            $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.INSTANCE_NAME.PLACEHOLDER')
          "
          @blur="v$.instanceName.$touch"
        />
        <span v-if="v$.instanceName.$error" class="message">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.INSTANCE_NAME.ERROR') }}
        </span>
      </label>
    </div>

    <div class="mt-4 p-4 rounded-lg bg-n-alpha-2 text-sm text-n-slate-11">
      <p class="font-medium text-n-slate-12 mb-2">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.INFO.TITLE') }}
      </p>
      <ul class="list-disc pl-4 space-y-1">
        <li>{{ labels.automaticInstance }}</li>
        <li>{{ replaceInstallationName(labels.automaticWebhook) }}</li>
        <li>{{ replaceInstallationName(labels.qrInsideChatwoot) }}</li>
      </ul>
    </div>

    <div class="flex flex-row justify-end gap-2 py-2 px-0 w-full">
      <NextButton
        type="submit"
        :disabled="v$.$invalid || uiFlags.isCreating || !evolutionConfigured"
        :is-loading="uiFlags.isCreating || evolutionConfigLoading"
      >
        {{ $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.SUBMIT_BUTTON') }}
      </NextButton>
    </div>
  </form>
</template>
