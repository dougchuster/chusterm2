<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { dynamicTime } from 'shared/helpers/timeHelper';
import { useAdmin } from 'dashboard/composables/useAdmin';
import ContactInfoRow from './ContactInfoRow.vue';
import Avatar from 'next/avatar/Avatar.vue';
import SocialIcons from './SocialIcons.vue';
import EditContact from './EditContact.vue';
import ContactMergeModal from 'dashboard/modules/contact/ContactMergeModal.vue';
import ComposeConversation from 'dashboard/components-next/NewConversation/ComposeConversation.vue';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import NextButton from 'dashboard/components-next/button/Button.vue';
import VoiceCallButton from 'dashboard/components-next/Contacts/VoiceCallButton.vue';

import {
  isAConversationRoute,
  isAInboxViewRoute,
  getConversationDashboardRoute,
} from '../../../../helper/routeHelpers';
import { emitter } from 'shared/helpers/mitt';

export default {
  components: {
    NextButton,
    ContactInfoRow,
    EditContact,
    Avatar,
    ComposeConversation,
    SocialIcons,
    ContactMergeModal,
    VoiceCallButton,
  },
  props: {
    contact: {
      type: Object,
      default: () => ({}),
    },
    showAvatar: {
      type: Boolean,
      default: true,
    },
  },
  emits: ['panelClose'],
  setup() {
    const { isAdmin } = useAdmin();
    return {
      isAdmin,
    };
  },
  data() {
    return {
      showEditModal: false,
      showDeleteModal: false,
    };
  },
  computed: {
    ...mapGetters({ uiFlags: 'contacts/getUIFlags' }),
    contactProfileLink() {
      return `/app/accounts/${this.$route.params.accountId}/contacts/${this.contact.id}`;
    },
    additionalAttributes() {
      return this.contact.additional_attributes || {};
    },
    location() {
      const {
        country = '',
        city = '',
        country_code: countryCode,
      } = this.additionalAttributes;
      const cityAndCountry = [city, country].filter(item => !!item).join(', ');

      if (!cityAndCountry) {
        return '';
      }
      return this.findCountryFlag(countryCode, cityAndCountry);
    },
    socialProfiles() {
      const {
        social_profiles: socialProfiles,
        screen_name: twitterScreenName,
        social_telegram_user_name: telegramUsername,
      } = this.additionalAttributes;

      const telegram = socialProfiles?.telegram || telegramUsername || '';
      const twitter = socialProfiles?.twitter || twitterScreenName || '';

      return {
        ...(socialProfiles || {}),
        twitter,
        telegram,
      };
    },
    // Delete Modal
    confirmDeleteMessage() {
      return ` ${this.contact.name}?`;
    },
  },
  watch: {
    'contact.id': {
      handler(id) {
        this.$store.dispatch('contacts/fetchContactableInbox', id);
      },
      immediate: true,
    },
  },
  methods: {
    dynamicTime,
    toggleEditModal() {
      this.showEditModal = !this.showEditModal;
    },
    openComposeConversationModal(toggleFn) {
      toggleFn();
      // Flag to prevent triggering drag n drop,
      // When compose modal is active
      emitter.emit(BUS_EVENTS.NEW_CONVERSATION_MODAL, true);
    },
    closeComposeConversationModal() {
      // Flag to enable drag n drop,
      // When compose modal is closed
      emitter.emit(BUS_EVENTS.NEW_CONVERSATION_MODAL, false);
    },
    toggleDeleteModal() {
      this.showDeleteModal = !this.showDeleteModal;
    },
    confirmDeletion() {
      this.deleteContact(this.contact);
      this.closeDelete();
    },
    closeDelete() {
      this.showDeleteModal = false;
      this.showEditModal = false;
    },
    findCountryFlag(countryCode, cityAndCountry) {
      try {
        if (!countryCode) {
          return `${cityAndCountry} 🌎`;
        }

        const code = countryCode?.toLowerCase();
        return `${cityAndCountry} <span class="fi fi-${code} size-3.5"></span>`;
      } catch (error) {
        return '';
      }
    },
    async deleteContact({ id }) {
      try {
        await this.$store.dispatch('contacts/delete', id);
        this.$emit('panelClose');
        useAlert(this.$t('DELETE_CONTACT.API.SUCCESS_MESSAGE'));

        if (isAConversationRoute(this.$route.name)) {
          this.$router.push({
            name: getConversationDashboardRoute(this.$route.name),
          });
        } else if (isAInboxViewRoute(this.$route.name)) {
          this.$router.push({
            name: 'inbox_view',
          });
        } else if (this.$route.name !== 'contacts_dashboard') {
          this.$router.push({
            name: 'contacts_dashboard',
          });
        }
      } catch (error) {
        useAlert(
          error.message
            ? error.message
            : this.$t('DELETE_CONTACT.API.ERROR_MESSAGE')
        );
      }
    },
    openMergeModal() {
      this.$refs.mergeModal?.open();
    },
  },
};
</script>

<template>
  <div
    class="relative w-full items-center bg-ds-bg-surface px-4 pb-4 pt-3 text-ds-fg-default"
  >
    <div class="flex w-full flex-col gap-3 text-left rtl:text-right">
      <div class="flex flex-row justify-between">
        <Avatar
          v-if="showAvatar"
          :src="contact.thumbnail"
          :name="contact.name"
          :status="contact.availability_status"
          :size="48"
          hide-offline-status
          rounded-full
        />
      </div>

      <div class="flex w-full min-w-0 flex-col items-start gap-2">
        <div v-if="showAvatar" class="flex w-full min-w-0 items-center gap-2">
          <h3
            class="my-0 min-w-0 max-w-full flex-shrink break-words font-manrope text-base font-semibold capitalize text-ds-fg-default"
          >
            {{ contact.name }}
          </h3>
          <div class="flex flex-row items-center gap-1">
            <span
              v-if="contact.created_at"
              v-tooltip.left="
                `${$t('CONTACT_PANEL.CREATED_AT_LABEL')} ${dynamicTime(
                  contact.created_at
                )}`
              "
              class="i-lucide-info size-4 text-ds-fg-subtle"
              aria-hidden="true"
            />
            <a
              :href="contactProfileLink"
              target="_blank"
              rel="noopener nofollow noreferrer"
              class="inline-flex size-9 items-center justify-center rounded-lg text-ds-fg-subtle transition-colors hover:bg-ds-bg-hover hover:text-ds-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-border-focus"
              :title="`${$t('CONTACT_PANEL.VIEW_PROFILE')} — ${$t('CONVERSATION.HEADER.OPEN_IN_NEW_TAB')}`"
              :aria-label="`${$t('CONTACT_PANEL.VIEW_PROFILE')} — ${$t('CONVERSATION.HEADER.OPEN_IN_NEW_TAB')}`"
            >
              <span class="i-lucide-external-link size-4" aria-hidden="true" />
            </a>
          </div>
        </div>

        <div v-if="contact.id" class="grid w-full grid-cols-2 gap-2">
          <router-link
            :to="contactProfileLink"
            class="inline-flex min-h-10 min-w-0 items-center justify-center gap-1.5 rounded-xl bg-ds-bg-sunken px-2.5 text-xs font-semibold text-ds-fg-default no-underline transition-colors hover:bg-ds-bg-hover hover:text-ds-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-border-focus"
          >
            <span
              class="i-lucide-user-round-search size-4"
              aria-hidden="true"
            />
            {{ $t('CONTACT_PANEL.VIEW_PROFILE') }}
          </router-link>
          <button
            type="button"
            class="inline-flex min-h-10 min-w-0 items-center justify-center gap-1.5 rounded-xl bg-ds-bg-sunken px-2.5 text-xs font-semibold text-ds-fg-default transition-colors hover:bg-ds-bg-hover hover:text-ds-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-border-focus"
            @click="toggleEditModal"
          >
            <span class="i-lucide-pencil size-4" aria-hidden="true" />
            {{ $t('EDIT_CONTACT.BUTTON_LABEL') }}
          </button>
        </div>

        <p
          v-if="additionalAttributes.description"
          class="mb-0.5 break-words text-sm leading-5 text-ds-fg-muted"
        >
          {{ additionalAttributes.description }}
        </p>
        <div class="flex w-full flex-col items-start gap-2">
          <ContactInfoRow
            :href="contact.email ? `mailto:${contact.email}` : ''"
            :value="contact.email"
            icon="mail"
            emoji="✉️"
            :title="$t('CONTACT_PANEL.EMAIL_ADDRESS')"
            show-copy
          />
          <ContactInfoRow
            :href="contact.phone_number ? `tel:${contact.phone_number}` : ''"
            :value="contact.phone_number"
            icon="call"
            emoji="📞"
            :title="$t('CONTACT_PANEL.PHONE_NUMBER')"
            show-copy
          />
          <ContactInfoRow
            v-if="contact.identifier"
            :value="contact.identifier"
            icon="contact-identify"
            emoji="🪪"
            :title="$t('CONTACT_PANEL.IDENTIFIER')"
          />
          <ContactInfoRow
            :value="additionalAttributes.company_name"
            icon="building-bank"
            emoji="🏢"
            :title="$t('CONTACT_PANEL.COMPANY')"
          />
          <ContactInfoRow
            v-if="location || additionalAttributes.location"
            :value="location || additionalAttributes.location"
            icon="map"
            emoji="🌍"
            :title="$t('CONTACT_PANEL.LOCATION')"
          />
          <SocialIcons :social-profiles="socialProfiles" />
        </div>
      </div>
      <div
        v-if="contact.id"
        class="mt-0.5 flex w-full items-center gap-1.5 rounded-xl bg-ds-bg-sunken p-1.5"
        role="group"
        :aria-label="$t('CONTACT_PANEL.CONTACT_ACTIONS')"
      >
        <ComposeConversation
          :contact-id="String(contact.id)"
          is-modal
          @close="closeComposeConversationModal"
        >
          <template #trigger="{ toggle }">
            <NextButton
              v-tooltip.top-end="$t('CONTACT_PANEL.NEW_MESSAGE')"
              :aria-label="$t('CONTACT_PANEL.NEW_MESSAGE')"
              icon="i-lucide-message-circle"
              color="primary"
              variant="ghost"
              size="md"
              @click="openComposeConversationModal(toggle)"
            />
          </template>
        </ComposeConversation>
        <VoiceCallButton
          :phone="contact.phone_number"
          :contact-id="contact.id"
          :aria-label="$t('CONTACT_PANEL.CALL')"
          icon="i-lucide-phone"
          size="md"
          :tooltip-label="$t('CONTACT_PANEL.CALL')"
          color="primary"
          variant="ghost"
        />
        <NextButton
          v-tooltip.top-end="$t('CONTACT_PANEL.MERGE_CONTACT')"
          :aria-label="$t('CONTACT_PANEL.MERGE_CONTACT')"
          icon="i-lucide-merge"
          color="primary"
          variant="ghost"
          size="md"
          :disabled="uiFlags.isMerging"
          @click="openMergeModal"
        />
        <NextButton
          v-if="isAdmin"
          v-tooltip.top-end="$t('DELETE_CONTACT.BUTTON_LABEL')"
          :aria-label="$t('DELETE_CONTACT.BUTTON_LABEL')"
          icon="i-lucide-trash-2"
          color="ruby"
          variant="ghost"
          size="md"
          :disabled="uiFlags.isDeleting"
          @click="toggleDeleteModal"
        />
      </div>
      <EditContact
        v-if="showEditModal"
        :show="showEditModal"
        :contact="contact"
        @cancel="toggleEditModal"
      />
      <ContactMergeModal ref="mergeModal" :primary-contact="contact" />
    </div>
    <woot-delete-modal
      v-if="showDeleteModal"
      v-model:show="showDeleteModal"
      :on-close="closeDelete"
      :on-confirm="confirmDeletion"
      :title="$t('DELETE_CONTACT.CONFIRM.TITLE')"
      :message="$t('DELETE_CONTACT.CONFIRM.MESSAGE')"
      :message-value="confirmDeleteMessage"
      :confirm-text="$t('DELETE_CONTACT.CONFIRM.YES')"
      :reject-text="$t('DELETE_CONTACT.CONFIRM.NO')"
    />
  </div>
</template>
