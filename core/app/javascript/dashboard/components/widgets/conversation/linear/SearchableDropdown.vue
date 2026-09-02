<script setup>
import { ref, computed, defineOptions } from 'vue';
import FilterButton from 'dashboard/components/ui/Dropdown/DropdownButton.vue';
import FilterListDropdown from 'dashboard/components/ui/Dropdown/DropdownList.vue';

const props = defineProps({
  type: { type: String, required: true },
  label: { type: String, default: null },
  items: { type: Array, required: true },
  value: { type: [Number, String], default: null },
  placeholder: { type: String, default: null },
  error: { type: String, default: null },
});

const emit = defineEmits(['change']);

defineOptions({
  name: 'SearchableDropdown',
});

const shouldShowDropdown = ref(false);

const toggleDropdown = () => {
  shouldShowDropdown.value = !shouldShowDropdown.value;
};
const onSelect = item => {
  emit('change', item, props.type);
  toggleDropdown();
};

const hasError = computed(() => !!props.error);

const selectedItem = computed(() => {
  if (!props.value) return null;
  return props.items.find(i => i.id === props.value);
});

const selectedItemName = computed(
  () => selectedItem.value?.name || props.placeholder
);

const selectedItemId = computed(() => selectedItem.value?.id || null);
</script>

<template>
  <div
    class="flex w-full"
    :class="type === 'stateId' && shouldShowDropdown ? 'h-[150px]' : 'gap-2'"
  >
    <label class="w-full" :class="{ error: hasError }">
      {{ label }}
      <FilterButton
        type="button"
        aria-haspopup="listbox"
        :aria-expanded="shouldShowDropdown"
        :aria-invalid="hasError"
        :aria-describedby="hasError ? `${type}-error` : undefined"
        trailing-icon
        icon="i-lucide-chevron-down"
        :button-text="selectedItemName"
        class="h-10 w-full justify-between rounded-xl bg-ds-bg-sunken px-3 py-1.5 text-ds-fg-default outline outline-1 outline-ds-border-subtle transition-shadow hover:bg-ds-bg-hover hover:outline-ds-border-strong focus-visible:outline-ds-border-focus focus-visible:ring-2 focus-visible:ring-ds-border-focus/30"
        @click="toggleDropdown"
      >
        <template v-if="shouldShowDropdown" #dropdown>
          <FilterListDropdown
            v-on-clickaway="toggleDropdown"
            :show-clear-filter="false"
            :list-items="items"
            :active-filter-id="selectedItemId"
            :input-placeholder="placeholder"
            enable-search
            role="listbox"
            :aria-label="label"
            class="left-0 top-10 flex h-fit max-h-[160px] w-full flex-col overflow-y-auto bg-ds-bg-elevated text-ds-fg-default outline-ds-border-subtle md:left-auto md:right-0"
            @select="onSelect"
          />
        </template>
      </FilterButton>
      <span v-if="hasError" :id="`${type}-error`" class="message mt-1">
        {{ error }}
      </span>
    </label>
  </div>
</template>
