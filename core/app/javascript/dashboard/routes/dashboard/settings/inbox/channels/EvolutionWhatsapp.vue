<script>
/* global axios */
import { mapGetters } from 'vuex';
import { useVuelidate } from '@vuelidate/core';
import { useAlert } from 'dashboard/composables';
import { required } from '@vuelidate/validators';
import router from '../../../../index';
import {
  isEvolutionInboxPhone,
  normalizeToE164Phone,
} from 'shared/helpers/Validators';

const isHttpUrl = (value = '') =>
  value ? value.startsWith('http://') || value.startsWith('https://') : true;
import NextButton from 'dashboard/components-next/button/Button.vue';

export default {
  components: {
    NextButton,
  },
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    const gc = window.globalConfig || {};
    return {
      inboxName: '',
      phoneNumber: '',
      evolutionApiUrl: gc.EVOLUTION_API_URL || '',
      evolutionApiKey: gc.EVOLUTION_API_KEY || '',
      instanceName: '',
      evolutionRemoteInstances: [],
      evolutionRemoteLoading: false,
      evolutionRemoteError: '',
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
    phoneNumber: { required, isEvolutionInboxPhone },
    evolutionApiUrl: { required, isHttpUrl },
    evolutionApiKey: { required },
    instanceName: { required },
  },
  methods: {
    async loadRemoteEvolutionInstances() {
      this.v$.evolutionApiUrl.$touch();
      this.v$.evolutionApiKey.$touch();
      if (
        this.v$.evolutionApiUrl.$invalid ||
        this.v$.evolutionApiKey.$invalid
      ) {
        useAlert(
          this.$t(
            'INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.DISCOVER_INSTANCES.FIX_URL_KEY'
          )
        );
        return;
      }
      this.evolutionRemoteLoading = true;
      this.evolutionRemoteError = '';
      try {
        const { data } = await axios.post(
          `/api/v1/accounts/${this.accountId}/channels/evolution/preview_instances`,
          {
            api_url: this.evolutionApiUrl,
            api_key: this.evolutionApiKey,
          }
        );
        this.evolutionRemoteInstances = data.instances || [];
        if (this.evolutionRemoteInstances.length === 0) {
          this.evolutionRemoteError = this.$t(
            'INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.DISCOVER_INSTANCES.EMPTY'
          );
        }
      } catch (e) {
        this.evolutionRemoteInstances = [];
        this.evolutionRemoteError =
          e?.response?.data?.error ||
          this.$t(
            'INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.DISCOVER_INSTANCES.FETCH_ERROR'
          );
      } finally {
        this.evolutionRemoteLoading = false;
      }
    },
    async createChannel() {
      this.v$.$touch();
      if (this.v$.$invalid) {
        return;
      }

      try {
        const whatsappChannel = await this.$store.dispatch(
          'inboxes/createChannel',
          {
            name: this.inboxName?.trim(),
            channel: {
              type: 'whatsapp',
              phone_number: normalizeToE164Phone(this.phoneNumber),
              provider: 'evolution',
              provider_config: {
                api_url: this.evolutionApiUrl,
                api_key: this.evolutionApiKey,
                instance_name: this.instanceName,
              },
            },
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
      <label :class="{ error: v$.phoneNumber.$error }">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.PHONE.LABEL') }}
        <input
          v-model="phoneNumber"
          type="text"
          :placeholder="
            $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.PHONE.PLACEHOLDER')
          "
          @blur="v$.phoneNumber.$touch"
        />
        <span v-if="v$.phoneNumber.$error" class="message">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.PHONE.ERROR') }}
        </span>
        <span v-else class="text-xs text-n-slate-10 block mt-1">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.PHONE.HELP') }}
        </span>
      </label>
    </div>

    <div class="flex-shrink-0 flex-grow-0">
      <label :class="{ error: v$.evolutionApiUrl.$error }">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.API_URL.LABEL') }}
        <input
          v-model="evolutionApiUrl"
          type="url"
          :placeholder="
            $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.API_URL.PLACEHOLDER')
          "
          @blur="v$.evolutionApiUrl.$touch"
        />
        <span v-if="v$.evolutionApiUrl.$error" class="message">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.API_URL.ERROR') }}
        </span>
      </label>
    </div>

    <div class="flex-shrink-0 flex-grow-0">
      <label :class="{ error: v$.evolutionApiKey.$error }">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.API_KEY.LABEL') }}
        <input
          v-model="evolutionApiKey"
          type="text"
          :placeholder="
            $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.API_KEY.PLACEHOLDER')
          "
          @blur="v$.evolutionApiKey.$touch"
        />
        <span v-if="v$.evolutionApiKey.$error" class="message">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.API_KEY.ERROR') }}
        </span>
      </label>
    </div>

    <div class="flex-shrink-0 flex-grow-0">
      <label :class="{ error: v$.instanceName.$error }">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.INSTANCE_NAME.LABEL') }}
        <input
          v-model="instanceName"
          type="text"
          list="evolution-instances-datalist-wizard"
          :placeholder="
            $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.INSTANCE_NAME.PLACEHOLDER')
          "
          @blur="v$.instanceName.$touch"
        />
        <datalist id="evolution-instances-datalist-wizard">
          <option
            v-for="i in evolutionRemoteInstances"
            :key="i.name"
            :value="i.name"
          />
        </datalist>
        <span v-if="v$.instanceName.$error" class="message">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.INSTANCE_NAME.ERROR') }}
        </span>
        <span v-if="evolutionRemoteError" class="message block mt-1">
          {{ evolutionRemoteError }}
        </span>
        <div class="mt-2">
          <NextButton
            type="button"
            outline
            slate
            sm
            :is-loading="evolutionRemoteLoading"
            :label="
              $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.DISCOVER_INSTANCES.BUTTON')
            "
            @click="loadRemoteEvolutionInstances"
          />
        </div>
        <span class="text-xs text-n-slate-10 block mt-1">
          {{
            $t(
              'INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.DISCOVER_INSTANCES.PREVIEW_HELP'
            )
          }}
        </span>
      </label>
    </div>

    <div class="mt-4 p-4 rounded-lg bg-n-alpha-2 text-sm text-n-slate-11">
      <p class="font-medium text-n-slate-12 mb-2">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.INFO.TITLE') }}
      </p>
      <ul class="list-disc pl-4 space-y-1">
        <li>{{ $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.INFO.QR_CODE') }}</li>
        <li>{{ $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.INFO.UNOFFICIAL') }}</li>
        <li>{{ $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.INFO.BAILEYS') }}</li>
      </ul>
    </div>

    <div class="flex flex-row justify-end gap-2 py-2 px-0 w-full">
      <NextButton
        type="submit"
        :disabled="v$.$invalid || uiFlags.isCreating"
        :is-loading="uiFlags.isCreating"
      >
        {{ $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.SUBMIT_BUTTON') }}
      </NextButton>
    </div>
  </form>
</template>
