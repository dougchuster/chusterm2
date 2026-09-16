<script setup>
import {
  computed,
  getCurrentInstance,
  nextTick,
  onBeforeUnmount,
  onMounted,
  ref,
} from 'vue';

const props = defineProps({
  text: { type: String, required: true },
  placement: {
    type: String,
    default: 'top',
    validator: value => ['top', 'bottom', 'left', 'right'].includes(value),
  },
  disabled: { type: Boolean, default: false },
});

const { uid } = getCurrentInstance();
const tooltipId = `ds-tooltip-${uid}`;

const rootRef = ref(null);
const tooltipRef = ref(null);
const visible = ref(false);
const tooltipStyle = ref({});

const OFFSET = 8;

// O tooltip e teleportado para <body> pelos mesmos motivos do DsDropdown:
// ancestors com overflow (colunas do kanban, lista de atividades, sidebar)
// clipavam o balao absoluto. `fixed` mede a partir do gatilho e respeita o
// viewport, invertendo o lado quando nao ha espaco.
const updatePosition = () => {
  const rect = rootRef.value?.getBoundingClientRect();
  const tip = tooltipRef.value;
  if (!rect || !tip) return;

  const tipWidth = tip.offsetWidth;
  const tipHeight = tip.offsetHeight;
  const vw = window.innerWidth;
  const vh = window.innerHeight;

  const space = {
    top: rect.top,
    bottom: vh - rect.bottom,
    left: rect.left,
    right: vw - rect.right,
  };

  const needed = {
    top: tipHeight,
    bottom: tipHeight,
    left: tipWidth,
    right: tipWidth,
  };
  const opposite = {
    top: 'bottom',
    bottom: 'top',
    left: 'right',
    right: 'left',
  };
  const placement =
    space[props.placement] >= needed[props.placement] + OFFSET
      ? props.placement
      : opposite[props.placement];

  let x;
  let y;
  if (placement === 'top' || placement === 'bottom') {
    x = rect.left + rect.width / 2 - tipWidth / 2;
    y =
      placement === 'top'
        ? rect.top - tipHeight - OFFSET
        : rect.bottom + OFFSET;
  } else {
    x =
      placement === 'left'
        ? rect.left - tipWidth - OFFSET
        : rect.right + OFFSET;
    y = rect.top + rect.height / 2 - tipHeight / 2;
  }

  tooltipStyle.value = {
    left: `${Math.min(Math.max(x, OFFSET), Math.max(vw - tipWidth - OFFSET, OFFSET))}px`,
    top: `${Math.min(Math.max(y, OFFSET), Math.max(vh - tipHeight - OFFSET, OFFSET))}px`,
  };
};

const show = async () => {
  if (props.disabled || visible.value) return;
  visible.value = true;
  await nextTick();
  updatePosition();
};

const hide = () => {
  visible.value = false;
};

const handleFocusOut = event => {
  if (!rootRef.value?.contains(event.relatedTarget)) hide();
};

// Tooltips sao transientes: rolagem ou resize escondem em vez de recalcular.
onMounted(() => {
  document.addEventListener('scroll', hide, true);
  window.addEventListener('resize', hide);
});

onBeforeUnmount(() => {
  document.removeEventListener('scroll', hide, true);
  window.removeEventListener('resize', hide);
});

const describedBy = computed(() => (props.disabled ? undefined : tooltipId));
</script>

<template>
  <span
    ref="rootRef"
    class="inline-flex"
    @mouseenter="show"
    @mouseleave="hide"
    @focusin="show"
    @focusout="handleFocusOut"
  >
    <slot :tooltip-id="describedBy" />
    <Teleport to="body">
      <span
        v-if="visible && !disabled"
        :id="tooltipId"
        ref="tooltipRef"
        role="tooltip"
        :style="tooltipStyle"
        class="pointer-events-none fixed z-ui-overlay max-w-64 whitespace-nowrap rounded-ui-control bg-ui-text px-2 py-1 text-ui-caption text-ui-surface shadow-ui-raised"
      >
        {{ text }}
      </span>
    </Teleport>
  </span>
</template>
