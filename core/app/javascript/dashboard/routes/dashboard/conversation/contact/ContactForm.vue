<script>
import { useAlert } from 'dashboard/composables';
import {
  DuplicateContactException,
  ExceptionWithMessage,
} from 'shared/helpers/CustomErrors';
import { required, email } from '@vuelidate/validators';
import { useVuelidate } from '@vuelidate/core';
import countries from 'shared/constants/countries.js';
import { isPhoneNumberValid } from 'shared/helpers/Validators';
import parsePhoneNumber from 'libphonenumber-js';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Avatar from 'next/avatar/Avatar.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';

export default {
  components: {
    NextButton,
    Avatar,
    ComboBox,
  },
  props: {
    contact: {
      type: Object,
      default: () => ({}),
    },
    inProgress: {
      type: Boolean,
      default: false,
    },
    onSubmit: {
      type: Function,
      default: () => {},
    },
  },
  emits: ['cancel', 'success'],
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      countries: countries,
      companyName: '',
      description: '',
      email: '',
      name: '',
      phoneNumber: '',
      activeDialCode: '',
      avatarFile: null,
      avatarUrl: '',
      country: {
        id: '',
        name: '',
      },
      city: '',
      socialProfileUserNames: {
        facebook: '',
        twitter: '',
        linkedin: '',
        github: '',
        telegram: '',
      },
      socialProfileKeys: [
        { key: 'facebook', prefixURL: 'https://facebook.com/' },
        { key: 'twitter', prefixURL: 'https://twitter.com/' },
        { key: 'linkedin', prefixURL: 'https://linkedin.com/' },
        { key: 'github', prefixURL: 'https://github.com/' },
        { key: 'telegram', prefixURL: 'https://t.me/' },
        { key: 'tiktok', prefixURL: 'https://tiktok.com/@' },
      ],
    };
  },
  validations: {
    name: {
      required,
    },
    description: {},
    email: {
      email,
    },
    companyName: {},
    phoneNumber: {},
    bio: {},
  },
  computed: {
    parsePhoneNumber() {
      return parsePhoneNumber(this.phoneNumber);
    },
    isPhoneNumberNotValid() {
      if (this.phoneNumber !== '') {
        return (
          !isPhoneNumberValid(this.phoneNumber, this.activeDialCode) ||
          (this.phoneNumber !== '' ? this.activeDialCode === '' : false)
        );
      }
      return false;
    },
    phoneNumberError() {
      if (this.activeDialCode === '') {
        return this.$t('CONTACT_FORM.FORM.PHONE_NUMBER.DIAL_CODE_ERROR');
      }
      if (!isPhoneNumberValid(this.phoneNumber, this.activeDialCode)) {
        return this.$t('CONTACT_FORM.FORM.PHONE_NUMBER.ERROR');
      }
      return '';
    },
    setPhoneNumber() {
      if (this.parsePhoneNumber && this.parsePhoneNumber.countryCallingCode) {
        return this.phoneNumber;
      }
      if (this.phoneNumber === '' && this.activeDialCode !== '') {
        return '';
      }
      return this.activeDialCode
        ? `${this.activeDialCode}${this.phoneNumber}`
        : '';
    },
  },
  watch: {
    contact() {
      this.setContactObject();
    },
  },
  mounted() {
    this.setContactObject();
    this.setDialCode();
  },
  methods: {
    onCancel() {
      this.$emit('cancel');
    },
    onSuccess() {
      this.$emit('success');
    },
    countryNameWithCode({ name, id }) {
      if (!id) return name;
      if (!name && !id) return '';
      return `${name} (${id})`;
    },
    onCountryChange(value) {
      const selected = this.countries.find(c => c.id === value);
      this.country = selected
        ? { id: selected.id, name: selected.name }
        : { id: '', name: '' };
    },
    setDialCode() {
      if (
        this.phoneNumber !== '' &&
        this.parsePhoneNumber &&
        this.parsePhoneNumber.countryCallingCode
      ) {
        const dialCode = this.parsePhoneNumber.countryCallingCode;
        this.activeDialCode = `+${dialCode}`;
      }
    },
    setContactObject() {
      const {
        email: emailAddress,
        phone_number: phoneNumber,
        name,
      } = this.contact;
      const additionalAttributes = this.contact.additional_attributes || {};

      this.name = name || '';
      this.email = emailAddress || '';
      this.phoneNumber = phoneNumber || '';
      this.companyName = additionalAttributes.company_name || '';
      this.country = {
        id: additionalAttributes.country_code || '',
        name:
          additionalAttributes.country ||
          this.$t('CONTACT_FORM.FORM.COUNTRY.SELECT_COUNTRY'),
      };
      this.city = additionalAttributes.city || '';
      this.description = additionalAttributes.description || '';
      this.avatarUrl = this.contact.thumbnail || '';
      const {
        social_profiles: socialProfiles = {},
        screen_name: twitterScreenName,
        social_telegram_user_name: telegramUserName,
      } = additionalAttributes;
      this.socialProfileUserNames = {
        twitter: socialProfiles.twitter || twitterScreenName || '',
        facebook: socialProfiles.facebook || '',
        linkedin: socialProfiles.linkedin || '',
        github: socialProfiles.github || '',
        telegram: socialProfiles.telegram || telegramUserName || '',
        instagram: socialProfiles.instagram || '',
        tiktok: socialProfiles.tiktok || '',
      };
    },
    getContactObject() {
      if (this.country === null) {
        this.country = {
          id: '',
          name: '',
        };
      }
      const contactObject = {
        id: this.contact.id,
        name: this.name,
        email: this.email,
        phone_number: this.setPhoneNumber,
        additional_attributes: {
          ...this.contact.additional_attributes,
          description: this.description,
          company_name: this.companyName,
          country_code: this.country.id,
          country:
            this.country.name ===
            this.$t('CONTACT_FORM.FORM.COUNTRY.SELECT_COUNTRY')
              ? ''
              : this.country.name,
          city: this.city,
          social_profiles: this.socialProfileUserNames,
        },
      };
      if (this.avatarFile) {
        contactObject.avatar = this.avatarFile;
        contactObject.isFormData = true;
      }
      return contactObject;
    },
    setPhoneCode(code) {
      if (this.phoneNumber !== '' && this.parsePhoneNumber) {
        const dialCode = this.parsePhoneNumber.countryCallingCode;
        if (dialCode === code) {
          return;
        }
        this.activeDialCode = `+${dialCode}`;
        const newPhoneNumber = this.phoneNumber.replace(
          `+${dialCode}`,
          `${code}`
        );
        this.phoneNumber = newPhoneNumber;
      } else {
        this.activeDialCode = code;
      }
    },
    async handleSubmit() {
      this.v$.$touch();
      if (this.v$.$invalid || this.isPhoneNumberNotValid) {
        return;
      }
      try {
        await this.onSubmit(this.getContactObject());
        this.onSuccess();
        useAlert(this.$t('CONTACT_FORM.SUCCESS_MESSAGE'));
      } catch (error) {
        if (error instanceof DuplicateContactException) {
          if (error.data.includes('email')) {
            useAlert(this.$t('CONTACT_FORM.FORM.EMAIL_ADDRESS.DUPLICATE'));
          } else if (error.data.includes('phone_number')) {
            useAlert(this.$t('CONTACT_FORM.FORM.PHONE_NUMBER.DUPLICATE'));
          }
        } else if (error instanceof ExceptionWithMessage) {
          useAlert(error.data);
        } else {
          useAlert(this.$t('CONTACT_FORM.ERROR_MESSAGE'));
        }
      }
    },
    handleImageUpload({ file, url }) {
      this.avatarFile = file;
      this.avatarUrl = url;
    },
    async handleAvatarDelete() {
      try {
        if (this.contact && this.contact.id) {
          await this.$store.dispatch('contacts/deleteAvatar', this.contact.id);
          useAlert(this.$t('CONTACT_FORM.DELETE_AVATAR.API.SUCCESS_MESSAGE'));
        }
        this.avatarFile = null;
        this.avatarUrl = '';
        this.activeDialCode = '';
      } catch (error) {
        useAlert(
          error.message
            ? error.message
            : this.$t('CONTACT_FORM.DELETE_AVATAR.API.ERROR_MESSAGE')
        );
      }
    },
  },
};
</script>

<template>
  <form
    class="w-full bg-ds-bg-elevated px-4 pb-8 pt-6 text-ds-fg-default sm:px-6 [&_.error_input]:border-ds-state-danger [&_.error_textarea]:border-ds-state-danger [&_.message]:mt-1 [&_.message]:block [&_.message]:text-xs [&_.message]:text-ds-state-danger [&_input]:rounded-lg [&_input]:border-ds-border-subtle [&_input]:bg-ds-bg-sunken [&_input]:text-ds-fg-default [&_input]:outline-none [&_input]:transition-shadow [&_input]:placeholder:text-ds-fg-subtle [&_input]:focus:border-ds-border-focus [&_input]:focus:ring-2 [&_input]:focus:ring-ds-border-focus/30 [&_label]:mb-1.5 [&_label]:block [&_label]:text-sm [&_label]:font-medium [&_label]:text-ds-fg-muted [&_textarea]:min-h-24 [&_textarea]:rounded-lg [&_textarea]:border-ds-border-subtle [&_textarea]:bg-ds-bg-sunken [&_textarea]:text-ds-fg-default [&_textarea]:outline-none [&_textarea]:transition-shadow [&_textarea]:placeholder:text-ds-fg-subtle [&_textarea]:focus:border-ds-border-focus [&_textarea]:focus:ring-2 [&_textarea]:focus:ring-ds-border-focus/30"
    @submit.prevent="handleSubmit"
  >
    <div class="mb-5 flex w-full flex-col items-start gap-1">
      <span class="mb-0.5 text-sm font-medium text-ds-fg-default">
        {{ $t('CONTACT_FORM.FORM.AVATAR.LABEL') }}
      </span>
      <Avatar
        :src="avatarUrl"
        :size="72"
        :name="contact.name"
        allow-upload
        rounded-full
        @upload="handleImageUpload"
        @delete="handleAvatarDelete"
      />
    </div>
    <div>
      <div class="w-full">
        <label :class="{ error: v$.name.$error }">
          {{ $t('CONTACT_FORM.FORM.NAME.LABEL') }}
          <input
            v-model="name"
            type="text"
            autocomplete="name"
            aria-required="true"
            :aria-invalid="v$.name.$error"
            :placeholder="$t('CONTACT_FORM.FORM.NAME.PLACEHOLDER')"
            @input="v$.name.$touch"
          />
        </label>

        <label :class="{ error: v$.email.$error }">
          {{ $t('CONTACT_FORM.FORM.EMAIL_ADDRESS.LABEL') }}
          <input
            v-model="email"
            type="email"
            autocomplete="email"
            :aria-invalid="v$.email.$error"
            :aria-describedby="
              v$.email.$error ? 'contact-email-error' : undefined
            "
            :placeholder="$t('CONTACT_FORM.FORM.EMAIL_ADDRESS.PLACEHOLDER')"
            @input="v$.email.$touch"
          />
          <span v-if="v$.email.$error" id="contact-email-error" class="message">
            {{ $t('CONTACT_FORM.FORM.EMAIL_ADDRESS.ERROR') }}
          </span>
        </label>
      </div>
    </div>
    <div class="w-full">
      <label :class="{ error: v$.description.$error }">
        {{ $t('CONTACT_FORM.FORM.BIO.LABEL') }}
        <textarea
          v-model="description"
          :placeholder="$t('CONTACT_FORM.FORM.BIO.PLACEHOLDER')"
          @input="v$.description.$touch"
        />
      </label>
    </div>
    <div>
      <div class="w-full">
        <label
          :class="{
            error: isPhoneNumberNotValid,
          }"
        >
          {{ $t('CONTACT_FORM.FORM.PHONE_NUMBER.LABEL') }}
          <woot-phone-input
            v-model="phoneNumber"
            :value="phoneNumber"
            :error="isPhoneNumberNotValid"
            :aria-invalid="isPhoneNumberNotValid"
            :aria-describedby="
              isPhoneNumberNotValid ? 'contact-phone-error' : undefined
            "
            :placeholder="$t('CONTACT_FORM.FORM.PHONE_NUMBER.PLACEHOLDER')"
            @blur="v$.phoneNumber.$touch"
            @set-code="setPhoneCode"
          />
          <span
            v-if="isPhoneNumberNotValid"
            id="contact-phone-error"
            class="message"
          >
            {{ phoneNumberError }}
          </span>
        </label>
        <div
          v-if="isPhoneNumberNotValid || !phoneNumber"
          role="note"
          class="relative mx-0 mb-2.5 mt-0 rounded-lg bg-ds-state-warning-soft p-2 text-sm text-ds-state-warning ring-1 ring-inset ring-ds-state-warning/20"
        >
          {{ $t('CONTACT_FORM.FORM.PHONE_NUMBER.HELP') }}
        </div>
      </div>
    </div>
    <woot-input
      v-model="companyName"
      class="w-full"
      :label="$t('CONTACT_FORM.FORM.COMPANY_NAME.LABEL')"
      :placeholder="$t('CONTACT_FORM.FORM.COMPANY_NAME.PLACEHOLDER')"
    />
    <div class="w-full mb-4">
      <label for="contact-country">
        {{ $t('CONTACT_FORM.FORM.COUNTRY.LABEL') }}
      </label>
      <ComboBox
        id="contact-country"
        :aria-label="$t('CONTACT_FORM.FORM.COUNTRY.LABEL')"
        :model-value="country.id"
        :options="
          countries.map(c => ({
            value: c.id,
            label: countryNameWithCode(c),
          }))
        "
        class="[&>div>button]:bg-ds-bg-sunken [&>div>button]:text-ds-fg-default [&>div>button]:ring-ds-border-subtle"
        :placeholder="$t('CONTACT_FORM.FORM.COUNTRY.PLACEHOLDER')"
        :search-placeholder="$t('CONTACT_FORM.FORM.COUNTRY.SELECT_PLACEHOLDER')"
        @update:model-value="onCountryChange"
      />
    </div>
    <woot-input
      v-model="city"
      class="w-full"
      :label="$t('CONTACT_FORM.FORM.CITY.LABEL')"
      :placeholder="$t('CONTACT_FORM.FORM.CITY.PLACEHOLDER')"
    />

    <div class="w-full">
      <label>{{ $t('CONTACTS_PAGE.LIST.TABLE_HEADER.SOCIAL_PROFILES') }}</label>
      <div
        v-for="socialProfile in socialProfileKeys"
        :key="socialProfile.key"
        class="mb-4 flex w-full items-stretch"
      >
        <span
          class="flex h-10 max-w-[45%] items-center truncate bg-ds-bg-sunken px-2 text-sm text-ds-fg-muted ring-1 ring-inset ring-ds-border-subtle ltr:rounded-l-lg rtl:rounded-r-lg"
        >
          {{ socialProfile.prefixURL }}
        </span>
        <input
          v-model="socialProfileUserNames[socialProfile.key]"
          :aria-label="socialProfile.key"
          class="mb-0 min-w-0 flex-1 ltr:rounded-l-none rtl:rounded-r-none"
          type="text"
          autocomplete="off"
        />
      </div>
    </div>
    <div class="flex flex-row justify-start w-full gap-2 px-0 py-2">
      <NextButton
        type="submit"
        :label="$t('CONTACT_FORM.FORM.SUBMIT')"
        :is-loading="inProgress"
      />
      <NextButton
        color="tertiary"
        variant="faded"
        type="reset"
        :label="$t('CONTACT_FORM.FORM.CANCEL')"
        @click.prevent="onCancel"
      />
    </div>
  </form>
</template>
