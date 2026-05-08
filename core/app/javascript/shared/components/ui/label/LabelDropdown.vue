<script>
import LabelDropdownItem from './LabelDropdownItem.vue';
import Hotkey from 'dashboard/components/base/Hotkey.vue';
import AddLabelModal from 'dashboard/routes/dashboard/settings/labels/AddLabel.vue';
import { picoSearch } from '@scmmishra/pico-search';
import { sanitizeLabel } from 'shared/helpers/sanitizeData';
import NextButton from 'dashboard/components-next/button/Button.vue';

export default {
  components: {
    LabelDropdownItem,
    AddLabelModal,
    Hotkey,
    NextButton,
  },

  props: {
    accountLabels: {
      type: Array,
      default: () => [],
    },
    selectedLabels: {
      type: Array,
      default: () => [],
    },
    allowCreation: {
      type: Boolean,
      default: false,
    },
    contextScope: {
      type: String,
      default: 'all',
      validator: value =>
        ['all', 'contact', 'conversation'].includes(value),
    },
  },
  emits: ['update', 'add', 'remove'],

  data() {
    return {
      search: '',
      createModalVisible: false,
    };
  },

  computed: {
    categoryLabels() {
      return {
        area: 'Area juridica',
        temperature: 'Temperatura',
        relationship: 'Relacionamento',
        status: 'Status',
        document: 'Documentos',
        origin: 'Origem',
        risk: 'Risco',
        service: 'Atendimento',
        uncategorized: 'Outras etiquetas',
      };
    },

    createLabelPlaceholder() {
      const label = this.$t('CONTACT_PANEL.LABELS.LABEL_SELECT.CREATE_LABEL');
      return this.search ? `${label}:` : label;
    },

    scopedAccountLabels() {
      if (this.contextScope === 'all') return this.accountLabels;

      return this.accountLabels.filter(label => {
        const scope = label.scope || 'both';
        return scope === 'both' || scope === this.contextScope;
      });
    },

    filteredActiveLabels() {
      if (!this.search) return this.scopedAccountLabels;

      return picoSearch(this.scopedAccountLabels, this.search, [
        'title',
        'slug',
        'category',
        'description',
      ]);
    },

    groupedLabels() {
      const groups = this.filteredActiveLabels.reduce((acc, label) => {
        const category = label.category || 'uncategorized';
        if (!acc[category]) {
          acc[category] = {
            key: category,
            title: this.categoryLabels[category] || category,
            labels: [],
          };
        }

        acc[category].labels.push(label);
        return acc;
      }, {});

      return Object.values(groups).sort((a, b) => {
        if (a.key === 'uncategorized') return 1;
        if (b.key === 'uncategorized') return -1;
        return a.title.localeCompare(b.title);
      });
    },

    noResult() {
      return this.filteredActiveLabels.length === 0;
    },

    hasExactMatchInResults() {
      return this.filteredActiveLabels.some(
        label => label.title === this.search
      );
    },

    shouldShowCreate() {
      return this.allowCreation && this.filteredActiveLabels.length < 3;
    },

    parsedSearch() {
      return sanitizeLabel(this.search);
    },
  },

  mounted() {
    this.focusInput();
  },

  methods: {
    focusInput() {
      this.$refs.searchbar.focus();
    },

    updateLabels(label) {
      this.$emit('update', label);
    },

    onAdd(label) {
      this.$emit('add', label);
    },

    onRemove(label) {
      this.$emit('remove', label);
    },

    onAddRemove(label) {
      if (this.selectedLabels.includes(label.title)) {
        this.onRemove(label.title);
      } else {
        this.onAdd(label);
      }
    },

    showCreateModal() {
      this.createModalVisible = true;
    },

    hideCreateModal() {
      this.createModalVisible = false;
    },
  },
};
</script>

<template>
  <div class="flex flex-col w-full max-h-[12.5rem]">
    <div class="flex items-center justify-center mb-1">
      <h4
        class="flex-grow m-0 overflow-hidden text-sm text-n-slate-12 whitespace-nowrap text-ellipsis"
      >
        {{ $t('CONTACT_PANEL.LABELS.LABEL_SELECT.TITLE') }}
      </h4>
      <Hotkey
        custom-class="border border-solid text-n-slate-12 bg-n-slate-2 text-xxs border-n-strong flex-shrink-0"
      >
        {{ 'L' }}
      </Hotkey>
    </div>
    <div class="flex-auto flex-grow-0 flex-shrink-0 mb-2 max-h-8">
      <input
        ref="searchbar"
        v-model="search"
        type="text"
        class="search-input"
        autofocus="true"
        :placeholder="$t('CONTACT_PANEL.LABELS.LABEL_SELECT.PLACEHOLDER')"
      />
    </div>
    <div
      class="flex items-start justify-start flex-auto flex-grow flex-shrink overflow-auto"
    >
      <div class="w-full my-1">
        <woot-dropdown-menu>
          <template v-for="group in groupedLabels" :key="group.key">
            <div
              class="px-2.5 pt-2 pb-1 text-[0.625rem] font-semibold uppercase tracking-normal text-n-slate-10"
            >
              {{ group.title }}
            </div>
            <LabelDropdownItem
              v-for="label in group.labels"
              :key="label.title"
              :title="label.title"
              :display-title="label.display_title"
              :color="label.color"
              :selected="selectedLabels.includes(label.title)"
              @select-label="onAddRemove(label)"
            />
          </template>
        </woot-dropdown-menu>
        <div
          v-if="noResult"
          class="flex justify-center py-4 px-2.5 font-medium text-xs text-n-slate-11"
        >
          {{ $t('CONTACT_PANEL.LABELS.LABEL_SELECT.NO_RESULT') }}
        </div>
        <div
          v-if="allowCreation && shouldShowCreate"
          class="flex pt-1 border-t border-solid border-n-weak"
        >
          <NextButton
            icon="i-lucide-plus"
            slate
            sm
            ghost
            :label="`${createLabelPlaceholder} ${parsedSearch}`"
            :disabled="hasExactMatchInResults"
            @click="showCreateModal"
          />

          <woot-modal
            v-model:show="createModalVisible"
            :on-close="hideCreateModal"
          >
            <AddLabelModal
              :prefill-title="parsedSearch"
              @close="hideCreateModal"
            />
          </woot-modal>
        </div>
      </div>
    </div>
  </div>
</template>
