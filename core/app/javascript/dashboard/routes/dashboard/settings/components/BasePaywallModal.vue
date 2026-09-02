<script setup>
import { computed } from 'vue';
import Icon from 'next/icon/Icon.vue';
import ButtonV4 from 'next/button/Button.vue';

const props = defineProps({
  featurePrefix: {
    type: String,
    required: true,
  },
  i18nKey: {
    type: String,
    required: true,
  },
  isOnChusteRMCloud: {
    type: Boolean,
    default: false,
  },
  isOnChustermCloud: {
    type: Boolean,
    default: false,
  },
  isOnChatwootCloud: {
    type: Boolean,
    default: false,
  },
  isSuperAdmin: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['upgrade']);

const isCloudInstance = computed(
  () =>
    props.isOnChusteRMCloud ||
    props.isOnChustermCloud ||
    props.isOnChatwootCloud
);
</script>

<template>
  <div
    class="base-paywall-modal flex flex-col max-w-lg overflow-hidden rounded-[28px] border px-6 py-6 shadow"
  >
    <div class="base-paywall-modal__ambient" aria-hidden="true" />

    <div class="relative z-10 flex items-center w-full gap-3 mb-5">
      <span class="base-paywall-modal__icon">
        <Icon
          class="flex-shrink-0 text-n-brand size-4"
          icon="i-lucide-lock-keyhole"
        />
      </span>
      <div class="min-w-0">
        <span class="base-paywall-modal__eyebrow">
          {{ $t('GENERAL.PREMIUM_ACCESS') }}
        </span>
        <p class="base-paywall-modal__title mb-0 mt-1 text-n-slate-12">
          {{ $t(`${featurePrefix}.PAYWALL.TITLE`) }}
        </p>
      </div>
    </div>

    <p
      v-dompurify-html="$t(`${featurePrefix}.${i18nKey}.AVAILABLE_ON`)"
      class="relative z-10 text-sm font-normal leading-7 text-n-slate-11"
    />

    <p class="relative z-10 mt-3 text-sm font-normal leading-7 text-n-slate-11">
      {{ $t(`${featurePrefix}.${i18nKey}.UPGRADE_PROMPT`) }}
      <span v-if="!isCloudInstance && !isSuperAdmin">
        {{ $t(`${featurePrefix}.ENTERPRISE_PAYWALL.ASK_ADMIN`) }}
      </span>
    </p>

    <template v-if="isCloudInstance">
      <ButtonV4
        blue
        solid
        md
        class="relative z-10 mt-6 w-full"
        @click="emit('upgrade')"
      >
        {{ $t(`${featurePrefix}.PAYWALL.UPGRADE_NOW`) }}
      </ButtonV4>
      <span
        class="relative z-10 mt-3 text-xs tracking-[0.08em] uppercase text-center text-n-slate-11"
      >
        {{ $t(`${featurePrefix}.PAYWALL.CANCEL_ANYTIME`) }}
      </span>
    </template>
    <template v-else-if="isSuperAdmin">
      <a href="/super_admin" class="relative z-10 block mt-6 w-full">
        <ButtonV4 solid blue md class="w-full">
          {{ $t(`${featurePrefix}.PAYWALL.UPGRADE_NOW`) }}
        </ButtonV4>
      </a>
    </template>
  </div>
</template>

<style scoped>
.base-paywall-modal {
  position: relative;
  border-color: rgba(var(--shell-border-strong));
  background: linear-gradient(
    180deg,
    rgba(var(--shell-panel-strong)) 0%,
    rgb(var(--slate-1) / 0.98) 100%
  );
  box-shadow: 0 28px 64px rgb(var(--slate-1) / 0.3);
}

.base-paywall-modal__ambient {
  position: absolute;
  inset: 0;
  pointer-events: none;
  background: radial-gradient(
      circle at top right,
      rgba(var(--shell-glow-primary)) 0%,
      transparent 30%
    ),
    radial-gradient(
      circle at bottom left,
      rgba(var(--shell-glow-tertiary)) 0%,
      transparent 34%
    );
  opacity: 0.95;
}

.base-paywall-modal__icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 2.5rem;
  height: 2.5rem;
  border-radius: 9999px;
  border: 1px solid rgba(var(--shell-border));
  background: rgb(var(--slate-2) / 0.72);
}

.base-paywall-modal__eyebrow {
  display: inline-flex;
  font-size: 0.72rem;
  font-weight: 700;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: rgb(var(--slate-10));
}

.base-paywall-modal__title {
  font-family: Manrope, sans-serif;
  font-size: 1.15rem;
  font-weight: 700;
  line-height: 1.3;
}
</style>
