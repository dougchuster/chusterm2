<script setup>
import { nextTick, onBeforeUnmount, onMounted, ref } from 'vue';

import DsButton from './DsButton.vue';

const props = defineProps({
  label: { type: String, default: '' },
  ariaLabel: { type: String, default: '' },
  icon: { type: [String, Object, Function], default: 'i-lucide-ellipsis' },
  align: {
    type: String,
    default: 'end',
    validator: value => ['start', 'end'].includes(value),
  },
  disabled: { type: Boolean, default: false },
  loading: { type: Boolean, default: false },
});

const rootRef = ref(null);
const menuRef = ref(null);
const open = ref(false);
const menuStyle = ref({});

// O menu e teleportado para <body>: ancestors com overflow (coluna rolavel do
// kanban) ou backdrop-filter (a barra de ferramentas) criam contextos de
// empilhamento que prendiam o dropdown atras das colunas seguintes. `fixed`
// posiciona a partir do gatilho e a camada foge dos dois problemas.
const updatePosition = () => {
  const rect = rootRef.value?.getBoundingClientRect();
  if (!rect) return;

  const menuHeight = menuRef.value?.offsetHeight ?? 0;
  const spaceBelow = window.innerHeight - rect.bottom;
  const flip = menuHeight > spaceBelow && rect.top > spaceBelow;

  menuStyle.value = {
    top: flip ? 'auto' : `${rect.bottom + 8}px`,
    bottom: flip ? `${window.innerHeight - rect.top + 8}px` : 'auto',
    ...(props.align === 'start'
      ? { left: `${rect.left}px`, right: 'auto' }
      : {
          left: 'auto',
          right: `${Math.max(window.innerWidth - rect.right, 8)}px`,
        }),
  };
};

const close = () => {
  open.value = false;
};

const toggle = async () => {
  if (props.disabled || props.loading) return;
  open.value = !open.value;
  if (open.value) {
    await nextTick();
    updatePosition();
  }
};

const handleDocumentPointer = event => {
  if (
    rootRef.value?.contains(event.target) ||
    menuRef.value?.contains(event.target)
  ) {
    return;
  }
  close();
};

const handleDocumentKeydown = event => {
  if (event.key === 'Escape') close();
};

// capture=true enxerga o scroll das colunas do kanban; sem ele o menu ficava
// flutuando no lugar errado quando a coluna rolava com ele aberto.
const handleReposition = () => {
  if (open.value) updatePosition();
};

onMounted(() => {
  document.addEventListener('pointerdown', handleDocumentPointer);
  document.addEventListener('keydown', handleDocumentKeydown);
  document.addEventListener('scroll', handleReposition, true);
  window.addEventListener('resize', handleReposition);
});

onBeforeUnmount(() => {
  document.removeEventListener('pointerdown', handleDocumentPointer);
  document.removeEventListener('keydown', handleDocumentKeydown);
  document.removeEventListener('scroll', handleReposition, true);
  window.removeEventListener('resize', handleReposition);
});
</script>

<template>
  <div ref="rootRef" class="relative inline-flex">
    <slot name="trigger" :open="open" :toggle="toggle">
      <DsButton
        :label="label"
        :icon="icon"
        variant="secondary"
        size="sm"
        :disabled="disabled"
        :loading="loading"
        aria-haspopup="menu"
        :aria-label="ariaLabel || undefined"
        :aria-expanded="open"
        @click="toggle"
      />
    </slot>
    <Teleport to="body">
      <div
        v-if="open"
        ref="menuRef"
        role="menu"
        :style="menuStyle"
        class="fixed z-ui-overlay min-w-48 overflow-hidden rounded-ui-surface border border-ui-border bg-ui-elevated p-1 shadow-ui-overlay"
        @click="close"
      >
        <slot :close="close" />
      </div>
    </Teleport>
  </div>
</template>
