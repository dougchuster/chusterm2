<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { useBranding } from 'shared/composables/useBranding';
import SettingsLayout from '../SettingsLayout.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

export default {
  components: {
    SettingsLayout,
    NextButton,
  },
  setup() {
    const { replaceInstallationName } = useBranding();
    return { replaceInstallationName };
  },
  data() {
    return {
      baseUrl: '',
      globalApiKey: '',
      webhookBaseUrl: '',
      healthStatus: 'unknown',
      lastHealthError: '',
      labels: {
        title: 'Evolution API',
        description:
          'Configure a conexão global usada para criar e gerenciar instâncias WhatsApp via Baileys sem abrir o painel da Evolution.',
        baseUrl: 'URL da Evolution API',
        baseUrlPlaceholder: 'https://evolution-api.seudominio.com',
        globalApiKey: 'Chave global da Evolution API',
        globalApiKeyPlaceholder: 'Informe a chave para salvar ou rotacionar',
        keyPresent:
          'Uma chave já está cadastrada. Preencha este campo apenas para substituir.',
        webhookBaseUrl: 'URL pública do ChusteRM para webhooks',
        webhookBaseUrlPlaceholder: 'https://crm.seudominio.com',
        status: 'Status:',
      },
    };
  },
  computed: {
    ...mapGetters({
      accountId: 'getCurrentAccountId',
      configuration: 'evolution/configuration',
      uiFlags: 'evolution/uiFlags',
    }),
  },
  async mounted() {
    await this.loadConfiguration();
  },
  methods: {
    async loadConfiguration() {
      const config = await this.$store.dispatch(
        'evolution/fetchConfiguration',
        this.accountId
      );
      this.baseUrl = config.base_url || '';
      this.webhookBaseUrl = config.webhook_base_url || '';
      this.healthStatus = config.health_status || 'unknown';
      this.lastHealthError = config.last_health_error || '';
    },
    payload() {
      const data = {
        accountId: this.accountId,
        base_url: this.baseUrl,
        webhook_base_url: this.webhookBaseUrl,
      };
      if (this.globalApiKey) data.global_api_key = this.globalApiKey;
      return data;
    },
    async validateConfiguration() {
      try {
        const data = await this.$store.dispatch(
          'evolution/validateConfiguration',
          this.payload()
        );
        this.healthStatus = data.health_status || 'ok';
        this.lastHealthError = '';
        useAlert('Conexão com a Evolution API validada.');
      } catch (e) {
        this.healthStatus = 'error';
        this.lastHealthError = e?.response?.data?.error || e.message;
        useAlert(this.lastHealthError);
      }
    },
    async saveConfiguration() {
      try {
        const config = await this.$store.dispatch(
          'evolution/saveConfiguration',
          this.payload()
        );
        this.globalApiKey = '';
        this.healthStatus = config.health_status || 'ok';
        this.lastHealthError = config.last_health_error || '';
        useAlert('Configuração da Evolution API salva.');
      } catch (e) {
        useAlert(e?.response?.data?.error || e.message);
      }
    },
  },
};
</script>

<template>
  <SettingsLayout :no-records-found="false">
    <div class="max-w-3xl">
      <h2 class="text-xl font-semibold text-n-slate-12 mb-2">
        {{ labels.title }}
      </h2>
      <p class="text-sm text-n-slate-10 mb-6">
        {{ labels.description }}
      </p>

      <form class="grid gap-4" @submit.prevent="saveConfiguration">
        <label>
          {{ labels.baseUrl }}
          <input
            v-model="baseUrl"
            type="url"
            :placeholder="labels.baseUrlPlaceholder"
          />
        </label>

        <label>
          {{ labels.globalApiKey }}
          <input
            v-model="globalApiKey"
            type="password"
            autocomplete="new-password"
            :placeholder="labels.globalApiKeyPlaceholder"
          />
          <span
            v-if="configuration?.global_api_key_present"
            class="text-xs text-n-slate-10"
          >
            {{ labels.keyPresent }}
          </span>
        </label>

        <label>
          {{ replaceInstallationName(labels.webhookBaseUrl) }}
          <input
            v-model="webhookBaseUrl"
            type="url"
            :placeholder="labels.webhookBaseUrlPlaceholder"
          />
        </label>

        <div class="rounded-lg bg-n-alpha-2 p-3 text-sm">
          <strong>{{ labels.status }}</strong> {{ healthStatus }}
          <p v-if="lastHealthError" class="text-n-ruby-10 mt-1">
            {{ lastHealthError }}
          </p>
        </div>

        <div class="flex flex-wrap justify-end gap-2">
          <NextButton
            type="button"
            outline
            slate
            :is-loading="uiFlags.isValidating"
            label="Testar conexão"
            @click="validateConfiguration"
          />
          <NextButton
            type="submit"
            :is-loading="uiFlags.isSaving"
            label="Salvar configuração"
          />
        </div>
      </form>
    </div>
  </SettingsLayout>
</template>
