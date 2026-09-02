<script setup>
import Avatar from 'next/avatar/Avatar.vue';
import { ref, computed, watch, nextTick } from 'vue';
import { useStoreGetters, useMapGetter } from 'dashboard/composables/store';
import { useKeyboardNavigableList } from 'dashboard/composables/useKeyboardNavigableList';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  searchKey: {
    type: String,
    default: '',
  },
});

const emit = defineEmits(['selectAgent']);

const { t } = useI18n();
const getters = useStoreGetters();
const agents = computed(() => getters['agents/getVerifiedAgents'].value);
const teams = useMapGetter('teams/getTeams');

const tagAgentsRef = ref(null);
const selectedIndex = ref(0);

const items = computed(() => {
  const search = props.searchKey?.trim().toLowerCase() || '';

  const buildItems = (list, type, infoKey) =>
    list
      .map(item => ({
        ...item,
        type,
        displayName: item.name,
        displayInfo: item[infoKey],
      }))
      .filter(item =>
        search ? item.displayName.toLowerCase().includes(search) : true
      );

  const categories = [
    {
      title: t('CONVERSATION.MENTION.AGENTS'),
      data: buildItems(agents.value, 'user', 'email'),
    },
    {
      title: t('CONVERSATION.MENTION.TEAMS'),
      data: buildItems(teams.value, 'team', 'description'),
    },
  ];

  return categories.flatMap(({ title, data }) =>
    data.length
      ? [
          { type: 'header', title, id: `${title.toLowerCase()}-header` },
          ...data,
        ]
      : []
  );
});

const selectableItems = computed(() => {
  return items.value.filter(item => item.type !== 'header');
});

const getSelectableIndex = item => {
  return selectableItems.value.findIndex(
    selectableItem =>
      selectableItem.type === item.type && selectableItem.id === item.id
  );
};

const adjustScroll = () => {
  nextTick(() => {
    if (tagAgentsRef.value) {
      const selectedElement = tagAgentsRef.value.querySelector(
        `#mention-item-${selectedIndex.value}`
      );
      if (selectedElement) {
        selectedElement.scrollIntoView({
          block: 'nearest',
          behavior: 'auto',
        });
      }
    }
  });
};

const onSelect = () => {
  emit('selectAgent', selectableItems.value[selectedIndex.value]);
};

useKeyboardNavigableList({
  items: selectableItems,
  onSelect,
  adjustScroll,
  selectedIndex,
});

watch(selectableItems, newListOfAgents => {
  if (newListOfAgents.length < selectedIndex.value + 1) {
    selectedIndex.value = 0;
  }
});

const onHover = index => {
  selectedIndex.value = index;
};

const onAgentSelect = index => {
  selectedIndex.value = index;
  onSelect();
};
</script>

<template>
  <div>
    <ul
      v-if="items.length"
      ref="tagAgentsRef"
      :aria-label="t('CONVERSATION.MENTION.AGENTS')"
      class="mention--box absolute bottom-full left-0 z-20 m-0 max-h-[12.5rem] w-full list-none overflow-auto rounded-xl bg-ds-bg-elevated p-1 text-sm leading-[1.2] text-ds-fg-default shadow-[var(--ds-shadow-lg)] ring-1 ring-ds-border-subtle"
      role="listbox"
    >
      <li
        v-for="item in items"
        :id="
          item.type === 'header'
            ? undefined
            : `mention-item-${getSelectableIndex(item)}`
        "
        :key="`${item.type}-${item.id}`"
      >
        <!-- Section Header -->
        <div
          v-if="item.type === 'header'"
          class="px-2 py-2 text-xs font-semibold uppercase tracking-[0.08em] text-ds-fg-subtle"
        >
          {{ item.title }}
        </div>
        <!-- Selectable Item -->
        <div
          v-else
          tabindex="-1"
          :aria-selected="getSelectableIndex(item) === selectedIndex"
          :class="{
            'bg-ds-accent-soft': getSelectableIndex(item) === selectedIndex,
          }"
          class="flex cursor-pointer items-center rounded-lg px-2 py-1.5 outline-none transition-colors hover:bg-ds-bg-hover focus-visible:ring-2 focus-visible:ring-ds-border-focus"
          role="option"
          @click="onAgentSelect(getSelectableIndex(item))"
          @mouseover="onHover(getSelectableIndex(item))"
        >
          <div class="ltr:mr-2 rtl:ml-2">
            <Avatar
              :src="item.thumbnail"
              :name="item.displayName"
              rounded-full
            />
          </div>
          <div
            class="overflow-hidden flex-1 max-w-full whitespace-nowrap text-ellipsis"
          >
            <h5
              class="mb-0 overflow-hidden text-ellipsis whitespace-nowrap text-sm font-medium capitalize text-ds-fg-muted"
              :class="{
                'text-ds-fg-default':
                  getSelectableIndex(item) === selectedIndex,
              }"
            >
              {{ item.displayName }}
            </h5>
            <div
              class="overflow-hidden text-ellipsis whitespace-nowrap text-xs text-ds-fg-subtle"
              :class="{
                'text-ds-fg-muted': getSelectableIndex(item) === selectedIndex,
              }"
            >
              {{ item.displayInfo }}
            </div>
          </div>
        </div>
      </li>
    </ul>
  </div>
</template>
