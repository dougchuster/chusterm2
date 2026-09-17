<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { computed, ref, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { dynamicTime } from 'shared/helpers/timeHelper';
import ConversationAssignmentAPI from 'dashboard/api/inbox/conversation';

import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import ContactLabels from 'dashboard/components-next/Contacts/ContactLabels/ContactLabels.vue';
import CRMContactSummary from 'dashboard/components-next/Contacts/CRMContactSummary.vue';
import ContactsForm from 'dashboard/components-next/Contacts/ContactsForm/ContactsForm.vue';
import ConfirmContactDeleteDialog from 'dashboard/components-next/Contacts/ContactsForm/ConfirmContactDeleteDialog.vue';
import Policy from 'dashboard/components/policy.vue';

const props = defineProps({
  selectedContact: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['goToContactsList']);

const { t } = useI18n();
const store = useStore();

const CRM_TEXT = {
  title: 'CRM jurídico',
  description: 'Altere rapidamente se este contato e lead ou cliente.',
};
const ASSIGNMENT_TEXT = {
  title: 'Delegar resposta',
  description:
    'Defina quem deve responder o atendimento mais recente deste contato.',
  empty: 'Nenhum atendimento encontrado para este contato.',
  select: 'Selecione um responsável',
  unassigned: 'Sem responsável',
  currentConversation: 'Atendimento',
  assignToMe: 'Assumir atendimento',
  success: 'Responsável do atendimento atualizado.',
  error: 'Não foi possível delegar este atendimento.',
};
const CONVERSATION_STATUS_TEXT = {
  open: 'aberto',
  pending: 'pendente',
  resolved: 'resolvido',
  snoozed: 'adiado',
};

const confirmDeleteContactDialogRef = ref(null);

const avatarFile = ref(null);
const avatarUrl = ref('');

const contactsFormRef = ref(null);

const uiFlags = useMapGetter('contacts/getUIFlags');
const isUpdating = computed(() => uiFlags.value.isUpdating);
const agentList = useMapGetter('agents/getVerifiedAgents');
const currentUser = useMapGetter('getCurrentUser');
const contactConversations = useMapGetter(
  'contactConversations/getAllConversationsByContactId'
);

const isFormInvalid = computed(() => contactsFormRef.value?.isFormInvalid);

const contactData = ref({});
const selectedResponderId = ref('');
const isUpdatingResponder = ref(false);

const getInitialContactData = () => {
  if (!props.selectedContact) return {};
  return { ...props.selectedContact };
};

onMounted(() => {
  Object.assign(contactData.value, getInitialContactData());
  store.dispatch('agents/get');
  if (props.selectedContact?.id) {
    store.dispatch('contactConversations/get', props.selectedContact.id);
  }
});

const createdAt = computed(() => {
  return contactData.value?.createdAt
    ? dynamicTime(contactData.value.createdAt)
    : '';
});

const lastActivityAt = computed(() => {
  return contactData.value?.lastActivityAt
    ? dynamicTime(contactData.value.lastActivityAt)
    : '';
});

const avatarSrc = computed(() => {
  return avatarUrl.value ? avatarUrl.value : contactData.value?.thumbnail;
});

const conversations = computed(
  () => contactConversations.value(props.selectedContact?.id) || []
);

const activeConversation = computed(() => {
  const openConversation = conversations.value.find(conversation =>
    ['open', 'pending'].includes(conversation.status)
  );
  return openConversation || conversations.value[0] || null;
});

const assignedResponder = computed(
  () => activeConversation.value?.meta?.assignee || null
);

const assignedResponderLabel = computed(() => {
  if (!assignedResponder.value) return '';
  return `- ${assignedResponder.value.name || assignedResponder.value.email}`;
});

const responderOptions = computed(() => [
  { id: '', name: ASSIGNMENT_TEXT.unassigned },
  ...agentList.value.map(agent => ({
    id: String(agent.id),
    name: agent.name || agent.email,
  })),
]);

const responderSelectOptions = computed(() =>
  responderOptions.value.map(agent => ({
    value: agent.id,
    label: agent.name,
  }))
);

const activeConversationLabel = computed(() => {
  if (!activeConversation.value) return '';
  const status =
    CONVERSATION_STATUS_TEXT[activeConversation.value.status] ||
    activeConversation.value.status;
  return `#${activeConversation.value.id} - ${status}`;
});

watch(
  activeConversation,
  conversation => {
    selectedResponderId.value = conversation?.meta?.assignee?.id
      ? String(conversation.meta.assignee.id)
      : '';
  },
  { immediate: true }
);

const handleFormUpdate = updatedData => {
  Object.assign(contactData.value, updatedData);
};

const updateCrmContact = async data => {
  Object.assign(contactData.value, data);
  try {
    await store.dispatch('contacts/update', {
      id: props.selectedContact.id,
      ...data,
    });
    useAlert(t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.SUCCESS_MESSAGE'));
  } catch {
    useAlert(t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.ERROR_MESSAGE'));
  }
};

const assignResponder = async agentId => {
  if (!activeConversation.value) return;

  selectedResponderId.value = agentId;
  isUpdatingResponder.value = true;
  try {
    await ConversationAssignmentAPI.assignAgent({
      conversationId: activeConversation.value.id,
      agentId: agentId ? Number(agentId) : null,
    });
    await store.dispatch('contactConversations/get', props.selectedContact.id);
    useAlert(ASSIGNMENT_TEXT.success);
  } catch {
    useAlert(ASSIGNMENT_TEXT.error);
  } finally {
    isUpdatingResponder.value = false;
  }
};

const assignToCurrentUser = () => {
  if (!currentUser.value?.id) return;
  assignResponder(String(currentUser.value.id));
};

const updateContact = async () => {
  try {
    const { customAttributes, ...basicContactData } = contactData.value;
    await store.dispatch('contacts/update', basicContactData);
    await store.dispatch(
      'contacts/fetchContactableInbox',
      props.selectedContact.id
    );
    useAlert(t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.SUCCESS_MESSAGE'));
  } catch {
    useAlert(t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.ERROR_MESSAGE'));
  }
};

const openConfirmDeleteContactDialog = () => {
  confirmDeleteContactDialogRef.value?.dialogRef.open();
};

const handleAvatarUpload = async ({ file, url }) => {
  avatarFile.value = file;
  avatarUrl.value = url;

  try {
    await store.dispatch('contacts/update', {
      ...contactsFormRef.value?.state,
      avatar: file,
      isFormData: true,
    });
    useAlert(t('CONTACTS_LAYOUT.DETAILS.AVATAR.UPLOAD.SUCCESS_MESSAGE'));
  } catch {
    useAlert(t('CONTACTS_LAYOUT.DETAILS.AVATAR.UPLOAD.ERROR_MESSAGE'));
  }
};

const handleAvatarDelete = async () => {
  try {
    if (props.selectedContact && props.selectedContact.id) {
      await store.dispatch('contacts/deleteAvatar', props.selectedContact.id);
      useAlert(t('CONTACTS_LAYOUT.DETAILS.AVATAR.DELETE.SUCCESS_MESSAGE'));
    }
    avatarFile.value = null;
    avatarUrl.value = '';
    contactData.value.thumbnail = null;
  } catch (error) {
    useAlert(
      error.message
        ? error.message
        : t('CONTACTS_LAYOUT.DETAILS.AVATAR.DELETE.ERROR_MESSAGE')
    );
  }
};
</script>

<template>
  <div class="flex flex-col gap-5 pb-6">
    <section class="rounded-lg bg-ui-surface shadow-ui-raised p-4 sm:p-5">
      <div class="flex flex-col gap-4 sm:flex-row sm:items-start">
        <Avatar
          :src="avatarSrc || ''"
          :name="selectedContact?.name || ''"
          :size="72"
          allow-upload
          @upload="handleAvatarUpload"
          @delete="handleAvatarDelete"
        />
        <div class="min-w-0 flex-1">
          <h3 class="truncate text-lg font-semibold text-n-slate-12">
            {{ selectedContact?.name }}
          </h3>
          <div class="mt-2 flex flex-wrap items-center gap-x-3 gap-y-1.5">
            <span
              v-if="selectedContact?.identifier"
              class="inline-flex min-w-0 items-center gap-1 text-sm text-n-slate-11"
            >
              <span class="i-ph-user-gear size-4 shrink-0 text-n-slate-10" />
              <span class="truncate">{{ selectedContact?.identifier }}</span>
            </span>
            <span
              class="inline-flex min-w-0 items-center gap-1 text-sm text-n-slate-11"
            >
              <span class="i-ph-activity size-4 shrink-0 text-n-slate-10" />
              <span class="truncate">
                {{
                  $t('CONTACTS_LAYOUT.DETAILS.CREATED_AT', {
                    date: createdAt,
                  })
                }}
              </span>
            </span>
            <span class="text-sm text-n-slate-11">
              {{
                $t('CONTACTS_LAYOUT.DETAILS.LAST_ACTIVITY', {
                  date: lastActivityAt,
                })
              }}
            </span>
          </div>
          <div class="mt-4">
            <ContactLabels :contact-id="selectedContact?.id" />
          </div>
        </div>
      </div>
    </section>

    <section class="rounded-lg bg-ui-surface shadow-ui-raised p-4 sm:p-5">
      <div class="mb-4 flex flex-col gap-1">
        <h4 class="text-sm font-semibold text-n-slate-12">
          {{ CRM_TEXT.title }}
        </h4>
        <p class="text-xs text-n-slate-11">
          {{ CRM_TEXT.description }}
        </p>
      </div>
      <CRMContactSummary
        :contact="contactData"
        :is-updating="isUpdating"
        editable
        @update="updateCrmContact"
      />
    </section>

    <section class="rounded-lg bg-ui-surface shadow-ui-raised p-4 sm:p-5">
      <div class="mb-4 flex flex-col gap-1">
        <h4 class="text-sm font-semibold text-n-slate-12">
          {{ ASSIGNMENT_TEXT.title }}
        </h4>
        <p class="text-xs text-n-slate-11">
          {{ ASSIGNMENT_TEXT.description }}
        </p>
      </div>
      <div v-if="activeConversation" class="grid gap-3 md:grid-cols-[1fr_auto]">
        <div class="min-w-0">
          <label class="mb-1 block text-xs font-medium text-n-slate-11">
            {{ ASSIGNMENT_TEXT.currentConversation }}
          </label>
          <div
            class="mb-3 flex min-h-9 items-center rounded border border-ui-border-subtle bg-n-alpha-2 px-3 text-sm text-n-slate-11"
          >
            <span class="truncate">{{ activeConversationLabel }}</span>
            <span
              v-if="assignedResponder"
              class="ml-2 truncate text-n-slate-12"
            >
              {{ assignedResponderLabel }}
            </span>
          </div>
          <label class="mb-1 block text-xs font-medium text-n-slate-11">
            {{ ASSIGNMENT_TEXT.select }}
          </label>
          <Select
            v-model="selectedResponderId"
            :options="responderSelectOptions"
            :disabled="isUpdatingResponder"
            block
            @update:model-value="assignResponder"
          />
        </div>
        <div class="flex items-end">
          <Button
            :label="ASSIGNMENT_TEXT.assignToMe"
            icon="i-lucide-user-check"
            slate
            outline
            size="sm"
            :is-loading="isUpdatingResponder"
            @click="assignToCurrentUser"
          />
        </div>
      </div>
      <p v-else class="text-sm text-n-slate-11">
        {{ ASSIGNMENT_TEXT.empty }}
      </p>
    </section>

    <section class="rounded-lg bg-ui-surface shadow-ui-raised p-4 sm:p-5">
      <ContactsForm
        ref="contactsFormRef"
        :contact-data="contactData"
        is-details-view
        @update="handleFormUpdate"
      />
      <Button
        class="mt-4"
        :label="t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.UPDATE_BUTTON')"
        size="sm"
        :is-loading="isUpdating"
        :disabled="isUpdating || isFormInvalid"
        @click="updateContact"
      />
    </section>

    <Policy :permissions="['administrator']">
      <section class="rounded-lg bg-ui-surface shadow-ui-raised p-4 sm:p-5">
        <div class="flex flex-col items-start gap-4">
          <div class="flex flex-col gap-2">
            <h6 class="text-base font-medium text-n-slate-12">
              {{ t('CONTACTS_LAYOUT.DETAILS.DELETE_CONTACT') }}
            </h6>
            <span class="text-sm text-n-slate-11">
              {{ t('CONTACTS_LAYOUT.DETAILS.DELETE_CONTACT_DESCRIPTION') }}
            </span>
          </div>
          <Button
            :label="t('CONTACTS_LAYOUT.DETAILS.DELETE_CONTACT')"
            color="ruby"
            @click="openConfirmDeleteContactDialog"
          />
        </div>
      </section>
      <ConfirmContactDeleteDialog
        ref="confirmDeleteContactDialogRef"
        :selected-contact="selectedContact"
        @go-to-contacts-list="emit('goToContactsList')"
      />
    </Policy>
  </div>
</template>
