<script>
import { mapGetters } from 'vuex';
import Avatar from 'next/avatar/Avatar.vue';
import Spinner from 'shared/components/Spinner.vue';

export default {
  components: {
    Avatar,
    Spinner,
  },
  props: {
    selectedInboxes: {
      type: Array,
      default: () => [],
    },
    conversationCount: {
      type: Number,
      default: 0,
    },
  },
  emits: ['select', 'close'],
  data() {
    return {
      query: '',
      selectedAgent: null,
      goBackToAgentList: false,
    };
  },
  computed: {
    ...mapGetters({
      uiFlags: 'bulkActions/getUIFlags',
      assignableAgentsUiFlags: 'inboxAssignableAgents/getUIFlags',
    }),
    filteredAgents() {
      if (this.query) {
        return this.assignableAgents.filter(agent =>
          agent.name.toLowerCase().includes(this.query.toLowerCase())
        );
      }
      return [
        {
          confirmed: true,
          name: 'None',
          id: null,
          role: 'agent',
          account_id: 0,
          email: 'None',
        },
        ...this.assignableAgents,
      ];
    },
    assignableAgents() {
      return this.$store.getters['inboxAssignableAgents/getAssignableAgents'](
        this.selectedInboxes.join(',')
      );
    },
    conversationLabel() {
      return this.conversationCount > 1 ? 'conversations' : 'conversation';
    },
  },
  watch: {
    'assignableAgentsUiFlags.isFetching'(isFetching) {
      if (!isFetching) {
        this.focusSearch();
      }
    },
  },
  mounted() {
    this.$store.dispatch('inboxAssignableAgents/fetch', this.selectedInboxes);
    this.focusSearch();
  },
  methods: {
    submit() {
      this.$emit('select', this.selectedAgent);
    },
    goBack() {
      this.goBackToAgentList = true;
      this.selectedAgent = null;
      this.focusSearch();
    },
    assignAgent(agent) {
      this.selectedAgent = agent;
      this.$nextTick(() => this.$refs.goBackButton?.focus());
    },
    agentDisplayName(agent) {
      return agent.id === null ? this.$t('BULK_ACTION.TEAMS.NONE') : agent.name;
    },
    focusSearch() {
      this.$nextTick(() => this.$refs.searchInput?.focus());
    },
    focusAgentOption(event) {
      const options = Array.from(
        this.$el.querySelectorAll('[data-agent-option]')
      );
      if (!options.length) return;

      const activeIndex = options.indexOf(document.activeElement);
      let nextIndex;

      if (event.key === 'Home') {
        nextIndex = 0;
      } else if (event.key === 'End') {
        nextIndex = options.length - 1;
      } else if (event.key === 'ArrowDown') {
        nextIndex = activeIndex < 0 ? 0 : (activeIndex + 1) % options.length;
      } else {
        nextIndex =
          activeIndex < 0
            ? options.length - 1
            : (activeIndex - 1 + options.length) % options.length;
      }

      event.preventDefault();
      options[nextIndex].focus();
    },
    onPanelKeydown(event) {
      if (event.key === 'Escape') {
        event.preventDefault();
        event.stopPropagation();
        this.onClose();
        return;
      }

      if (
        !this.selectedAgent &&
        ['ArrowDown', 'ArrowUp', 'Home', 'End'].includes(event.key)
      ) {
        this.focusAgentOption(event);
      }
    },
    onClose() {
      this.$emit('close');
    },
    onCloseAgentList() {
      if (this.selectedAgent === null && !this.goBackToAgentList) {
        this.onClose();
      }
      this.goBackToAgentList = false;
    },
  },
};
</script>

<template>
  <div
    v-on-clickaway="onCloseAgentList"
    class="absolute top-12 z-20 flex w-[min(17rem,calc(100vw-1rem))] origin-top-right flex-col overflow-hidden rounded-xl bg-ds-bg-elevated/95 text-ds-fg-default shadow-[var(--ds-shadow-lg)] ring-1 ring-ds-border-subtle backdrop-blur-xl ltr:right-2 rtl:left-2"
    role="dialog"
    :aria-label="$t('BULK_ACTION.AGENT_SELECT_LABEL')"
    @keydown="onPanelKeydown"
  >
    <span
      class="absolute -top-1.5 z-10 size-3 rotate-45 border-l border-t border-ds-border-subtle bg-ds-bg-elevated ltr:right-[var(--triangle-position)] rtl:left-[var(--triangle-position)]"
      aria-hidden="true"
    />
    <div
      class="flex min-h-11 items-center justify-between border-b border-ds-border-subtle px-3 py-2"
    >
      <span class="text-sm font-semibold text-ds-fg-default">
        {{ $t('BULK_ACTION.AGENT_SELECT_LABEL') }}
      </span>
      <button
        type="button"
        class="inline-flex size-8 items-center justify-center rounded-lg text-ds-fg-muted transition-colors hover:bg-ds-bg-hover hover:text-ds-fg-default focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-border-focus"
        :aria-label="$t('GENERAL.CLOSE')"
        @click="onClose"
      >
        <span class="i-lucide-x size-4" aria-hidden="true" />
      </button>
    </div>
    <div class="max-h-72 overflow-y-auto">
      <div
        v-if="assignableAgentsUiFlags.isFetching"
        class="flex min-h-32 flex-col items-center justify-center gap-2 p-5 text-ds-fg-muted"
        role="status"
        aria-live="polite"
      >
        <Spinner />
        <p class="m-0 text-sm">
          {{ $t('BULK_ACTION.AGENT_LIST_LOADING') }}
        </p>
      </div>
      <div v-else>
        <ul
          v-if="!selectedAgent"
          class="m-0 list-none p-1.5"
          role="listbox"
          :aria-label="$t('BULK_ACTION.AGENT_SELECT_LABEL')"
        >
          <li
            class="sticky top-0 z-20 bg-ds-bg-elevated/95 p-1 backdrop-blur-sm"
            role="none"
          >
            <div class="relative flex items-center">
              <span
                class="i-lucide-search pointer-events-none absolute size-4 text-ds-fg-subtle ltr:left-3 rtl:right-3"
                aria-hidden="true"
              />
              <input
                ref="searchInput"
                v-model="query"
                type="search"
                :placeholder="$t('BULK_ACTION.SEARCH_INPUT_PLACEHOLDER')"
                :aria-label="$t('BULK_ACTION.SEARCH_INPUT_PLACEHOLDER')"
                class="reset-base mb-0 h-9 w-full rounded-lg border border-ds-border-subtle bg-ds-bg-sunken py-2 text-sm text-ds-fg-default outline-none placeholder:text-ds-fg-subtle focus:border-ds-border-focus focus:ring-2 focus:ring-ds-border-focus/30 ltr:pl-9 ltr:pr-3 rtl:pl-3 rtl:pr-9"
              />
            </div>
          </li>
          <li
            v-for="agent in filteredAgents"
            :key="agent.id ?? 'unassigned'"
            role="none"
          >
            <button
              type="button"
              role="option"
              data-agent-option
              class="flex min-h-10 w-full items-center gap-2 rounded-lg px-2.5 py-2 text-left text-ds-fg-default transition-colors hover:bg-ds-bg-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-ds-border-focus"
              :aria-selected="false"
              @click="assignAgent(agent)"
            >
              <Avatar
                :name="agentDisplayName(agent)"
                :src="agent.thumbnail"
                :status="agent.availability_status"
                :size="22"
                hide-offline-status
                rounded-full
              />
              <span class="my-0 min-w-0 truncate text-sm">
                {{ agentDisplayName(agent) }}
              </span>
            </button>
          </li>
        </ul>
        <div v-else class="flex min-h-40 flex-col gap-4 p-3" aria-live="polite">
          <p
            v-if="selectedAgent.id"
            class="m-0 flex-1 text-sm text-ds-fg-muted"
          >
            {{
              $t('BULK_ACTION.ASSIGN_CONFIRMATION_LABEL', {
                conversationCount,
                conversationLabel,
              })
            }}
            <strong class="font-semibold text-ds-fg-default">
              {{ selectedAgent.name }}
            </strong>
          </p>
          <p v-else class="m-0 flex-1 text-sm text-ds-fg-muted">
            {{
              $t('BULK_ACTION.UNASSIGN_CONFIRMATION_LABEL', {
                conversationCount,
                conversationLabel,
              })
            }}
          </p>
          <div class="grid w-full grid-cols-2 gap-2">
            <button
              ref="goBackButton"
              type="button"
              class="inline-flex h-9 items-center justify-center rounded-lg border border-ds-border-subtle bg-ds-bg-surface px-3 text-sm font-medium text-ds-fg-default transition-colors hover:bg-ds-bg-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-border-focus"
              @click="goBack"
            >
              {{ $t('BULK_ACTION.GO_BACK_LABEL') }}
            </button>
            <button
              type="button"
              class="inline-flex h-9 items-center justify-center gap-2 rounded-lg bg-ds-accent px-3 text-sm font-semibold text-ds-fg-on-accent transition-colors hover:bg-ds-accent-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-border-focus disabled:cursor-not-allowed disabled:opacity-50"
              :disabled="uiFlags.isUpdating"
              @click="submit"
            >
              <Spinner v-if="uiFlags.isUpdating" class="size-4" />
              <span>{{ $t('BULK_ACTION.YES') }}</span>
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
