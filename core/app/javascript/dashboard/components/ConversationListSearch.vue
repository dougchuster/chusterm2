<script setup>
import {
  computed,
  nextTick,
  onBeforeUnmount,
  onMounted,
  ref,
  watch,
} from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  modelValue: {
    type: String,
    default: '',
  },
  loading: {
    type: Boolean,
    default: false,
  },
  minLength: {
    type: Number,
    default: 3,
  },
  maxLength: {
    type: Number,
    default: 120,
  },
});

const emit = defineEmits(['update:modelValue', 'search']);
const { t } = useI18n();
const shortcutLabel = '/';

const inputRef = ref(null);
const inputValue = ref(props.modelValue);
let debounceTimer;

const normalizedValue = computed(() => inputValue.value.trim());
const hasValue = computed(() => Boolean(inputValue.value));

const emitSearch = () => {
  const query =
    normalizedValue.value.length >= props.minLength
      ? normalizedValue.value
      : '';
  emit('search', query);
};

const clearTimer = () => {
  if (debounceTimer) {
    window.clearTimeout(debounceTimer);
    debounceTimer = undefined;
  }
};

const queueSearch = () => {
  clearTimer();

  if (!normalizedValue.value) {
    emitSearch();
    return;
  }

  debounceTimer = window.setTimeout(emitSearch, 350);
};

const updateValue = event => {
  inputValue.value = event.target.value;
  emit('update:modelValue', inputValue.value);
  queueSearch();
};

const submitSearch = () => {
  clearTimer();
  emitSearch();
};

const clearSearch = async () => {
  inputValue.value = '';
  emit('update:modelValue', '');
  clearTimer();
  emit('search', '');
  await nextTick();
  inputRef.value?.focus();
};

const handleKeydown = event => {
  if (event.key === 'Escape' && hasValue.value) {
    event.preventDefault();
    clearSearch();
  }
};

const focusFromShortcut = event => {
  const target = event.target;
  const isEditable =
    target instanceof HTMLElement &&
    (target.isContentEditable ||
      ['INPUT', 'TEXTAREA', 'SELECT'].includes(target.tagName));

  if (event.key === '/' && !event.metaKey && !event.ctrlKey && !isEditable) {
    event.preventDefault();
    inputRef.value?.focus();
  }
};

watch(
  () => props.modelValue,
  value => {
    if (value !== inputValue.value) inputValue.value = value;
  }
);

onMounted(() => document.addEventListener('keydown', focusFromShortcut));
onBeforeUnmount(() => {
  clearTimer();
  document.removeEventListener('keydown', focusFromShortcut);
});
</script>

<template>
  <form
    role="search"
    class="px-3 pb-3"
    :aria-busy="loading"
    @submit.prevent="submitSearch"
  >
    <div
      class="group flex h-10 items-center gap-2 rounded-xl bg-ds-bg-sunken px-3 text-ds-fg-muted ring-1 ring-inset ring-ds-border-subtle transition focus-within:bg-ds-bg-surface focus-within:text-ds-fg-default focus-within:ring-2 focus-within:ring-ds-border-focus"
    >
      <span
        v-if="loading"
        class="i-lucide-loader-circle size-4 shrink-0 animate-spin text-ds-accent"
        aria-hidden="true"
      />
      <span
        v-else
        class="i-lucide-search size-4 shrink-0 transition group-focus-within:text-ds-accent"
        aria-hidden="true"
      />
      <input
        ref="inputRef"
        :value="inputValue"
        type="search"
        enterkeyhint="search"
        autocomplete="off"
        :maxlength="maxLength"
        aria-keyshortcuts="/"
        class="reset-base m-0 h-full min-w-0 flex-1 border-0 bg-transparent p-0 text-sm text-ds-fg-default outline-none placeholder:text-ds-fg-subtle focus:outline-none"
        :aria-label="t('CHAT_LIST.SEARCH.INPUT')"
        :placeholder="t('SEARCH.INPUT_PLACEHOLDER')"
        @input="updateValue"
        @keydown="handleKeydown"
      />
      <button
        v-if="hasValue"
        type="button"
        class="flex size-7 shrink-0 items-center justify-center rounded-lg text-ds-fg-subtle transition hover:bg-ds-bg-hover hover:text-ds-fg-default focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-border-focus"
        :aria-label="t('SEARCH.CLEAR_ALL')"
        :title="t('SEARCH.CLEAR_ALL')"
        @click="clearSearch"
      >
        <span class="i-lucide-x size-4" aria-hidden="true" />
      </button>
      <kbd
        v-else
        class="hidden rounded-md bg-ds-bg-elevated px-1.5 py-0.5 font-mono text-[10px] text-ds-fg-subtle ring-1 ring-inset ring-ds-border-subtle sm:inline-flex"
        aria-hidden="true"
      >
        {{ shortcutLabel }}
      </kbd>
    </div>
  </form>
</template>
