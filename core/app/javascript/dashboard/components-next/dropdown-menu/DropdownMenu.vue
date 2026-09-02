<script setup>
import { defineProps, ref, defineEmits, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';

import Icon from 'dashboard/components-next/icon/Icon.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  menuItems: {
    type: Array,
    default: () => [],
    validator: value => {
      return value.every(item => item.action && item.value && item.label);
    },
  },
  menuSections: {
    type: Array,
    default: () => [],
  },
  thumbnailSize: {
    type: Number,
    default: 20,
  },
  showSearch: {
    type: Boolean,
    default: false,
  },
  searchPlaceholder: {
    type: String,
    default: '',
  },
  isSearching: {
    type: Boolean,
    default: false,
  },
  labelClass: {
    type: String,
    default: '',
  },
  disableLocalFiltering: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['action', 'search']);

const { t } = useI18n();

const searchInput = ref(null);
const searchQuery = ref('');

const hasSections = computed(() => props.menuSections.length > 0);

const flattenedMenuItems = computed(() => {
  if (!hasSections.value) {
    return props.menuItems;
  }

  return props.menuSections.flatMap(section => section.items || []);
});

const filteredMenuItems = computed(() => {
  if (props.disableLocalFiltering) return props.menuItems;
  if (!searchQuery.value) return flattenedMenuItems.value;

  return flattenedMenuItems.value.filter(item =>
    item.label.toLowerCase().includes(searchQuery.value.toLowerCase())
  );
});

const filteredMenuSections = computed(() => {
  if (!hasSections.value) {
    return [];
  }

  if (props.disableLocalFiltering || !searchQuery.value) {
    return props.menuSections;
  }

  const query = searchQuery.value.toLowerCase();

  return props.menuSections
    .map(section => {
      const filteredItems = (section.items || []).filter(item =>
        item.label.toLowerCase().includes(query)
      );

      return {
        ...section,
        items: filteredItems,
      };
    })
    .filter(section => section.items.length > 0);
});

const handleSearchInput = event => {
  if (props.disableLocalFiltering) {
    emit('search', event.target.value);
  }
};

const handleAction = item => {
  const { action, value, ...rest } = item;
  emit('action', { action, value, ...rest });
};

const shouldShowEmptyState = computed(() => {
  if (hasSections.value) {
    return filteredMenuSections.value.length === 0;
  }

  return filteredMenuItems.value.length === 0;
});

onMounted(() => {
  if (searchInput.value && props.showSearch) {
    searchInput.value.focus();
  }
});
</script>

<template>
  <div
    class="absolute z-50 flex min-w-[136px] flex-col gap-2 rounded-xl bg-ds-bg-elevated/95 px-2 pb-2 text-ds-fg-default shadow-lg ring-1 ring-ds-border-subtle backdrop-blur-xl"
    :class="{
      'pt-2': !showSearch,
    }"
    role="menu"
  >
    <div
      v-if="showSearch"
      class="sticky top-0 z-20 bg-ds-bg-elevated/95 pt-2 backdrop-blur-sm"
    >
      <div class="relative">
        <span class="absolute i-lucide-search size-3.5 top-2 left-3" />
        <input
          ref="searchInput"
          v-model="searchQuery"
          type="search"
          :placeholder="
            searchPlaceholder || t('DROPDOWN_MENU.SEARCH_PLACEHOLDER')
          "
          :aria-label="
            searchPlaceholder || t('DROPDOWN_MENU.SEARCH_PLACEHOLDER')
          "
          class="reset-base h-8 w-full rounded-lg border border-ds-border-subtle bg-ds-bg-sunken py-2 pl-10 pr-2 text-sm text-ds-fg-default outline-none placeholder:text-ds-fg-subtle focus:border-ds-border-focus focus:ring-2 focus:ring-ds-border-focus/30"
          @input="handleSearchInput"
        />
      </div>
    </div>
    <template v-if="hasSections">
      <div
        v-for="(section, sectionIndex) in filteredMenuSections"
        :key="section.title || sectionIndex"
        class="flex flex-col gap-1"
      >
        <p
          v-if="section.title"
          class="sticky z-10 mb-0 bg-ds-bg-elevated/95 px-2 py-2 text-xs font-medium uppercase tracking-wide text-ds-fg-subtle backdrop-blur-sm"
          :class="showSearch ? 'top-10' : 'top-0'"
        >
          {{ section.title }}
        </p>
        <div
          v-if="section.isLoading"
          class="flex items-center justify-center py-2"
        >
          <Spinner :size="24" />
        </div>
        <div
          v-else-if="!section.items.length && section.emptyState"
          class="px-2 py-1.5 text-sm text-ds-fg-muted"
        >
          {{ section.emptyState }}
        </div>
        <button
          v-for="(item, itemIndex) in section.items"
          :key="item.value || itemIndex"
          type="button"
          role="menuitem"
          class="inline-flex h-8 w-full min-w-0 items-center justify-start gap-2 rounded-lg border-0 px-2 py-1.5 transition-colors duration-150 hover:bg-ds-bg-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-ds-border-focus disabled:pointer-events-none disabled:cursor-not-allowed disabled:opacity-50"
          :class="{
            'bg-ds-bg-active': item.isSelected,
            'text-ds-state-danger': item.action === 'delete',
            'text-ds-fg-default': item.action !== 'delete',
          }"
          :disabled="item.disabled"
          @click="handleAction(item)"
        >
          <slot name="thumbnail" :item="item">
            <Avatar
              v-if="item.thumbnail"
              :name="item.thumbnail.name"
              :src="item.thumbnail.src"
              :size="thumbnailSize"
              rounded-full
            />
          </slot>
          <Icon
            v-if="item.icon"
            :icon="item.icon"
            class="flex-shrink-0 size-3.5"
          />
          <span v-if="item.emoji" class="flex-shrink-0">{{ item.emoji }}</span>
          <span
            v-if="item.label"
            class="min-w-0 text-sm truncate"
            :class="labelClass"
          >
            {{ item.label }}
          </span>
        </button>
        <div
          v-if="sectionIndex < filteredMenuSections.length - 1"
          class="mx-2 my-1 h-px bg-ds-border-subtle"
        />
      </div>
    </template>
    <template v-else>
      <button
        v-for="(item, index) in filteredMenuItems"
        :key="index"
        type="button"
        role="menuitem"
        class="inline-flex h-8 w-full min-w-0 items-center justify-start gap-2 rounded-lg border-0 px-2 py-1.5 transition-colors duration-150 hover:bg-ds-bg-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-ds-border-focus disabled:pointer-events-none disabled:cursor-not-allowed disabled:opacity-50"
        :class="{
          'bg-ds-bg-active': item.isSelected,
          'text-ds-state-danger': item.action === 'delete',
          'text-ds-fg-default': item.action !== 'delete',
        }"
        :disabled="item.disabled"
        @click="handleAction(item)"
      >
        <slot name="thumbnail" :item="item">
          <Avatar
            v-if="item.thumbnail"
            :name="item.thumbnail.name"
            :src="item.thumbnail.src"
            :size="thumbnailSize"
            rounded-full
          />
        </slot>
        <Icon
          v-if="item.icon"
          :icon="item.icon"
          class="flex-shrink-0 size-3.5"
        />
        <span v-if="item.emoji" class="flex-shrink-0">{{ item.emoji }}</span>
        <span
          v-if="item.label"
          class="min-w-0 text-sm truncate"
          :class="labelClass"
        >
          {{ item.label }}
        </span>
      </button>
    </template>
    <div
      v-if="shouldShowEmptyState"
      class="px-2 py-1.5 text-sm text-ds-fg-muted"
    >
      {{
        isSearching
          ? t('DROPDOWN_MENU.SEARCHING')
          : t('DROPDOWN_MENU.EMPTY_STATE')
      }}
    </div>
    <slot name="footer" />
  </div>
</template>
