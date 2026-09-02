<script>
import { mapGetters } from 'vuex';

export default {
  emits: ['assignTeam', 'close'],

  data() {
    return {
      query: '',
    };
  },
  computed: {
    ...mapGetters({ teams: 'teams/getTeams' }),
    filteredTeams() {
      return [
        { name: 'None', id: 0 },
        ...this.teams.filter(team =>
          team.name.toLowerCase().includes(this.query.toLowerCase())
        ),
      ];
    },
  },
  mounted() {
    this.$nextTick(() => this.$refs.searchInput?.focus());
  },
  methods: {
    assignTeam(key) {
      this.$emit('assignTeam', key);
    },
    teamDisplayName(team) {
      return team.id === 0 ? this.$t('BULK_ACTION.TEAMS.NONE') : team.name;
    },
    focusTeamOption(event) {
      const options = Array.from(
        this.$el.querySelectorAll('[data-team-option]')
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

      if (['ArrowDown', 'ArrowUp', 'Home', 'End'].includes(event.key)) {
        this.focusTeamOption(event);
      }
    },
    onClose() {
      this.$emit('close');
    },
  },
};
</script>

<template>
  <div
    v-on-clickaway="onClose"
    class="absolute top-12 z-20 flex w-[min(17rem,calc(100vw-1rem))] origin-top-right flex-col overflow-hidden rounded-xl bg-ds-bg-elevated/95 text-ds-fg-default shadow-[var(--ds-shadow-lg)] ring-1 ring-ds-border-subtle backdrop-blur-xl ltr:right-2 rtl:left-2"
    role="dialog"
    :aria-label="$t('BULK_ACTION.TEAMS.TEAM_SELECT_LABEL')"
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
        {{ $t('BULK_ACTION.TEAMS.TEAM_SELECT_LABEL') }}
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
      <ul
        class="m-0 list-none p-1.5"
        role="listbox"
        :aria-label="$t('BULK_ACTION.TEAMS.TEAM_SELECT_LABEL')"
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
        <template v-if="filteredTeams.length">
          <li v-for="team in filteredTeams" :key="team.id" role="none">
            <button
              type="button"
              role="option"
              data-team-option
              class="flex min-h-10 w-full items-center rounded-lg px-2.5 py-2 text-left text-sm text-ds-fg-default transition-colors hover:bg-ds-bg-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-ds-border-focus"
              :aria-selected="false"
              @click="assignTeam(team)"
            >
              <span class="min-w-0 truncate">
                {{ teamDisplayName(team) }}
              </span>
            </button>
          </li>
        </template>
        <li v-else class="p-3 text-center" role="none">
          <p class="m-0 text-sm text-ds-fg-muted">
            {{ $t('BULK_ACTION.TEAMS.NO_TEAMS_AVAILABLE') }}
          </p>
        </li>
      </ul>
    </div>
  </div>
</template>
