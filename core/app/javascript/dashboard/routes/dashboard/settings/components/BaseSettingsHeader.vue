<script setup>
import { useSlots } from 'vue';
import CustomBrandPolicyWrapper from 'dashboard/components/CustomBrandPolicyWrapper.vue';
import { getHelpUrlForFeature } from '../../../../helper/featureHelper';
import BackButton from '../../../../components/widgets/BackButton.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Input from 'dashboard/components-next/input/Input.vue';

const props = defineProps({
  title: {
    type: String,
    required: true,
  },
  description: {
    type: String,
    default: '',
  },
  linkText: {
    type: String,
    default: '',
  },
  featureName: {
    type: String,
    default: '',
  },
  backButtonLabel: {
    type: String,
    default: '',
  },
  searchPlaceholder: {
    type: String,
    default: '',
  },
});

const slots = useSlots();

const searchQuery = defineModel('searchQuery', { type: String, default: '' });

const helpURL = getHelpUrlForFeature(props.featureName);
const eyebrowLabel = 'Configura\u00e7\u00e3o do espa\u00e7o';
const statusLabel = 'Painel unificado';
</script>

<template>
  <div class="base-settings-header w-full">
    <div class="base-settings-header__hero">
      <BackButton
        v-if="backButtonLabel"
        compact
        :button-label="backButtonLabel"
        class="my-1"
      />

      <div
        class="flex flex-col gap-3 lg:flex-row lg:items-end lg:justify-between"
      >
        <div class="min-w-0 flex-1">
          <span class="base-settings-header__eyebrow">
            {{ eyebrowLabel }}
          </span>
          <div v-if="title" class="mt-2 flex min-w-0 items-center gap-3">
            <div class="base-settings-header__title-icon">
              <Icon icon="i-lucide-settings-2" class="size-4" />
            </div>
            <h1 class="base-settings-header__title text-n-slate-12">
              {{ title }}
            </h1>
          </div>

          <div
            v-if="description || $slots.description || linkText || helpURL"
            class="mt-3 flex max-w-3xl flex-col gap-2 text-n-slate-11"
          >
            <p
              v-if="description || $slots.description"
              class="mb-0 line-clamp-5 text-body-main sm:line-clamp-none"
            >
              <slot name="description">{{ description }}</slot>
            </p>
            <CustomBrandPolicyWrapper :show-on-custom-branded-instance="false">
              <a
                v-if="helpURL && linkText"
                :href="helpURL"
                target="_blank"
                rel="noopener noreferrer"
                class="inline-flex w-fit items-center gap-1 text-sm font-medium text-n-blue-11 hover:underline"
              >
                {{ linkText }}
                <Icon
                  icon="i-lucide-chevron-right"
                  class="size-4 flex-shrink-0 text-n-blue-11"
                />
              </a>
            </CustomBrandPolicyWrapper>
          </div>
        </div>

        <div class="hidden shrink-0 lg:block">
          <div class="base-settings-header__status-chip">
            {{ statusLabel }}
          </div>
        </div>
      </div>
    </div>

    <div
      v-if="searchPlaceholder || slots.actions || slots.tabs"
      class="base-settings-header__toolbar"
    >
      <div
        v-if="slots.tabs || searchPlaceholder"
        class="flex min-w-0 items-center gap-3"
        :class="{
          'hidden sm:flex': !slots.tabs,
        }"
      >
        <slot name="tabs" />
        <Input
          v-if="searchPlaceholder"
          v-model="searchQuery"
          :placeholder="searchPlaceholder"
          class="group hidden w-64 min-w-0 sm:flex [&>input]:!rounded-[1rem] [&>input]:!border-0 [&>input]:!bg-n-alpha-3 [&>input]:!py-3 [&>input]:ltr:!pl-9 [&>input]:rtl:!pr-9"
          size="sm"
          type="search"
        >
          <template #prefix>
            <Icon
              icon="i-lucide-search"
              class="absolute top-1/2 size-3.5 -translate-y-1/2 text-n-slate-11 group-focus-within:text-n-brand ltr:left-3 rtl:right-3"
            />
          </template>
        </Input>
      </div>

      <div
        class="flex min-w-0 items-center gap-3"
        :class="{ 'flex-row-reverse sm:flex-row': !slots.tabs }"
      >
        <slot name="count" />
        <div
          v-if="slots.count"
          class="h-3 w-px flex-shrink-0 rounded-lg bg-n-weak ltr:ml-1 ltr:mr-2 rtl:ml-2 rtl:mr-1"
        />
        <slot name="actions" />
      </div>
    </div>
  </div>
  <div
    v-if="searchPlaceholder || slots.actions || slots.tabs"
    class="mt-3 sm:hidden"
  >
    <Input
      v-if="searchPlaceholder"
      v-model="searchQuery"
      :placeholder="searchPlaceholder"
      class="group w-full [&>input]:!rounded-[1rem] [&>input]:!border-0 [&>input]:!bg-n-alpha-3 [&>input]:!py-3 [&>input]:ltr:!pl-9 [&>input]:rtl:!pr-9"
      size="sm"
      type="search"
    >
      <template #prefix>
        <Icon
          icon="i-lucide-search"
          class="absolute top-1/2 size-3.5 -translate-y-1/2 text-n-slate-11 group-focus-within:text-n-brand ltr:left-3 rtl:right-3"
        />
      </template>
    </Input>
  </div>
</template>

<style scoped>
.base-settings-header {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.base-settings-header__hero,
.base-settings-header__toolbar {
  position: relative;
  overflow: hidden;
  border: 1px solid rgb(var(--border-weak));
  border-radius: 12px;
  background: rgb(var(--bg-card));
  box-shadow: 0 12px 34px rgba(var(--shell-shadow));
}

.base-settings-header__hero {
  padding: 1rem;
}

.base-settings-header__toolbar {
  display: flex;
  justify-content: space-between;
  gap: 0.75rem;
  padding: 1rem 1.1rem;
}

.base-settings-header__hero::before,
.base-settings-header__toolbar::before {
  display: none;
}

.base-settings-header__eyebrow {
  display: inline-flex;
  align-items: center;
  padding: 0.35rem 0.8rem;
  border-radius: 9999px;
  border: 1px solid rgb(var(--border-weak));
  background: rgb(var(--surface-2));
  font-family: Manrope, sans-serif;
  font-size: 0.72rem;
  font-weight: 700;
  letter-spacing: 0;
  text-transform: uppercase;
  color: rgb(var(--slate-11));
}

.base-settings-header__title {
  margin: 0;
  min-width: 0;
  font-family: Manrope, sans-serif;
  font-size: clamp(1.5rem, 2vw, 2.15rem);
  font-weight: 700;
  line-height: 1.05;
  overflow-wrap: anywhere;
}

.base-settings-header__title-icon {
  display: inline-flex;
  width: 2.5rem;
  height: 2.5rem;
  flex-shrink: 0;
  align-items: center;
  justify-content: center;
  border: 1px solid rgb(var(--border-weak));
  border-radius: 10px;
  background: rgb(var(--surface-2));
  color: rgb(var(--slate-12));
}

.base-settings-header__status-chip {
  padding: 0.65rem 0.9rem;
  border-radius: 9999px;
  border: 1px solid rgb(var(--border-weak));
  background: rgb(var(--surface-2));
  color: rgb(var(--slate-11));
  font-size: 0.82rem;
  white-space: nowrap;
}

@media (max-width: 640px) {
  .base-settings-header__hero {
    padding: 0.9rem;
  }

  .base-settings-header__toolbar {
    flex-direction: column;
    align-items: stretch;
    padding: 0.9rem;
  }

  .base-settings-header__title-icon {
    width: 2.25rem;
    height: 2.25rem;
  }
}
</style>
