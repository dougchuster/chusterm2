<script>
import { ref } from 'vue';
import { mapGetters } from 'vuex';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useConversationLabels } from 'dashboard/composables/useConversationLabels';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';
import Spinner from 'shared/components/Spinner.vue';
import LabelDropdown from 'shared/components/ui/label/LabelDropdown.vue';
import AddLabel from 'shared/components/ui/dropdown/AddLabel.vue';

export default {
  components: {
    Spinner,
    LabelDropdown,
    AddLabel,
  },
  setup() {
    const { isAdmin } = useAdmin();

    const {
      savedLabels,
      activeLabels,
      accountLabels,
      addLabelToConversation,
      removeLabelFromConversation,
    } = useConversationLabels();

    const showSearchDropdownLabel = ref(false);

    const toggleLabels = () => {
      showSearchDropdownLabel.value = !showSearchDropdownLabel.value;
    };

    const closeDropdownLabel = () => {
      showSearchDropdownLabel.value = false;
    };

    const keyboardEvents = {
      KeyL: {
        action: e => {
          e.preventDefault();
          toggleLabels();
        },
      },
      Escape: {
        action: () => {
          if (showSearchDropdownLabel.value) {
            toggleLabels();
          }
        },
        allowOnFocusedInput: true,
      },
    };
    useKeyboardEvents(keyboardEvents);
    return {
      isAdmin,
      savedLabels,
      activeLabels,
      accountLabels,
      addLabelToConversation,
      removeLabelFromConversation,
      showSearchDropdownLabel,
      closeDropdownLabel,
      toggleLabels,
    };
  },
  data() {
    return {
      selectedLabels: [],
    };
  },

  computed: {
    ...mapGetters({
      conversationUiFlags: 'conversationLabels/getUIFlags',
    }),
  },
};
</script>

<template>
  <div class="sidebar-labels-wrap mb-0">
    <div
      v-if="!conversationUiFlags.isFetching"
      class="contact-conversation--list w-full"
    >
      <div
        v-on-clickaway="closeDropdownLabel"
        class="label-wrap relative flex flex-wrap leading-6"
        @keyup.esc="closeDropdownLabel"
      >
        <AddLabel @add="toggleLabels" />
        <woot-label
          v-for="label in activeLabels"
          :key="label.id"
          :title="label.display_title || label.title"
          :description="label.description"
          show-close
          :color="label.color"
          variant="smooth"
          class="max-w-[calc(100%-0.5rem)]"
          @remove="() => removeLabelFromConversation(label.title)"
        />

        <div
          :class="{
            'block visible': showSearchDropdownLabel,
            'hidden invisible': !showSearchDropdownLabel,
          }"
          class="absolute top-6 z-[9999] box-border w-full rounded-xl border border-ds-border-subtle bg-ds-bg-elevated/95 p-2 shadow-lg backdrop-blur-xl"
        >
          <LabelDropdown
            v-if="showSearchDropdownLabel"
            :account-labels="accountLabels"
            :selected-labels="savedLabels"
            :allow-creation="isAdmin"
            context-scope="conversation"
            @add="addLabelToConversation"
            @remove="removeLabelFromConversation"
          />
        </div>
      </div>
    </div>
    <Spinner v-else />
  </div>
</template>
