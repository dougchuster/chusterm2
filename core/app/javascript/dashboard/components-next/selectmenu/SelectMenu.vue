<script setup>
import { ref, computed } from 'vue';
import { useWindowSize } from '@vueuse/core';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  options: {
    type: Array,
    required: true,
  },
  modelValue: {
    type: String,
    required: true,
  },
  label: {
    type: String,
    required: true,
  },
  subMenuPosition: {
    type: String,
    default: 'right',
    validator: value => {
      return ['right', 'left', 'bottom'].includes(value);
    },
  },
});

const emit = defineEmits(['update:modelValue']);

const isOpen = ref(false);
const { width: windowWidth } = useWindowSize();

const labelValue = computed(() => props.label);
const menuPositionClass = computed(() => {
  if ((windowWidth.value ?? window.innerWidth) < 520) {
    return 'top-full mt-1 ltr:right-0 rtl:left-0';
  }

  return {
    right: 'ltr:left-full rtl:right-full ltr:ml-1 rtl:mr-1',
    left: 'ltr:right-full rtl:left-full ltr:mr-1 rtl:ml-1',
    bottom: 'top-full mt-1 ltr:right-0 rtl:left-0',
  }[props.subMenuPosition];
});

const toggleMenu = () => {
  isOpen.value = !isOpen.value;
};

const handleSelect = value => {
  emit('update:modelValue', value);
  isOpen.value = false;
};
</script>

<template>
  <div
    v-on-clickaway="() => (isOpen = false)"
    class="relative flex flex-col gap-1 w-fit"
  >
    <Button
      icon="i-lucide-chevron-down"
      size="sm"
      trailing-icon
      color="slate"
      variant="faded"
      class="!w-fit max-w-40"
      :class="{ '!bg-ds-bg-active': isOpen }"
      :label="labelValue"
      aria-haspopup="menu"
      :aria-expanded="isOpen"
      @click="toggleMenu"
    />
    <div
      v-if="isOpen"
      class="absolute top-0 z-40 flex max-w-64 select-none flex-col gap-1 rounded-lg border border-ds-border-subtle bg-ds-bg-elevated/95 p-1 shadow-lg backdrop-blur-xl"
      :class="menuPositionClass"
      role="menu"
    >
      <Button
        v-for="option in options"
        :key="option.value"
        :label="option.label"
        :icon="option.value === modelValue ? 'i-lucide-check' : ''"
        size="sm"
        variant="ghost"
        color="slate"
        trailing-icon
        class="!justify-end !px-2.5 !h-7"
        :class="{ '!bg-ds-bg-active': option.value === modelValue }"
        role="menuitemradio"
        :aria-checked="option.value === modelValue"
        @click="handleSelect(option.value)"
      />
    </div>
  </div>
</template>
