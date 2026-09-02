<script setup>
import { ref, computed } from 'vue';

import wootConstants from 'dashboard/constants/globals';
import SLAEventItem from './SLAEventItem.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  slaMissedEvents: {
    type: Array,
    required: true,
  },
});

const { SLA_MISS_TYPES } = wootConstants;

const shouldShowAllNrts = ref(false);

const frtMisses = computed(() =>
  props.slaMissedEvents.filter(
    slaEvent => slaEvent.event_type === SLA_MISS_TYPES.FRT
  )
);
const nrtMisses = computed(() => {
  const missedEvents = props.slaMissedEvents.filter(
    slaEvent => slaEvent.event_type === SLA_MISS_TYPES.NRT
  );
  return shouldShowAllNrts.value ? missedEvents : missedEvents.slice(0, 6);
});
const rtMisses = computed(() =>
  props.slaMissedEvents.filter(
    slaEvent => slaEvent.event_type === SLA_MISS_TYPES.RT
  )
);

const shouldShowMoreNRTButton = computed(() => nrtMisses.value.length > 6);
const toggleShowAllNRT = () => {
  shouldShowAllNrts.value = !shouldShowAllNrts.value;
};
</script>

<template>
  <div
    role="region"
    :aria-label="$t('SLA.EVENTS.TITLE')"
    class="absolute z-50 flex max-h-96 w-[min(24rem,calc(100vw-2rem))] flex-col items-start gap-4 overflow-auto rounded-2xl bg-ds-bg-elevated/95 px-6 py-5 text-ds-fg-default shadow-[var(--ds-shadow-lg)] ring-1 ring-ds-border-subtle backdrop-blur-xl"
  >
    <span class="font-manrope text-sm font-semibold text-ds-fg-default">
      {{ $t('SLA.EVENTS.TITLE') }}
    </span>
    <SLAEventItem
      v-if="frtMisses.length"
      :label="$t('SLA.EVENTS.FRT')"
      :items="frtMisses"
    />
    <SLAEventItem
      v-if="nrtMisses.length"
      :label="$t('SLA.EVENTS.NRT')"
      :items="nrtMisses"
    >
      <template #showMore>
        <div
          v-if="shouldShowMoreNRTButton"
          class="flex flex-col items-end w-full"
        >
          <Button
            type="button"
            link
            xs
            color="primary"
            :aria-expanded="shouldShowAllNrts"
            class="hover:no-underline"
            :icon="!shouldShowAllNrts ? 'i-lucide-plus' : ''"
            :label="
              shouldShowAllNrts
                ? $t('SLA.EVENTS.HIDE', { count: nrtMisses.length })
                : $t('SLA.EVENTS.SHOW_MORE', { count: nrtMisses.length })
            "
            @click="toggleShowAllNRT"
          />
        </div>
      </template>
    </SLAEventItem>
    <SLAEventItem
      v-if="rtMisses.length"
      :label="$t('SLA.EVENTS.RT')"
      :items="rtMisses"
    />
  </div>
</template>
