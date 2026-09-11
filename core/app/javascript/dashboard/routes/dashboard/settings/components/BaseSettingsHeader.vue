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
</script>

<template>
  <div class="flex w-full flex-col gap-3">
    <div class="border-b border-n-weak pb-4">
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
          <div v-if="title" class="flex min-w-0 items-center gap-3">
            <div
              class="flex size-9 shrink-0 items-center justify-center rounded-lg bg-n-alpha-2 text-n-slate-11"
            >
              <Icon icon="i-lucide-settings-2" class="size-4" />
            </div>
            <h1 class="m-0 min-w-0 text-xl font-semibold text-n-slate-12">
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
      </div>
    </div>

    <div
      v-if="searchPlaceholder || slots.actions || slots.tabs"
      class="flex flex-col justify-between gap-3 rounded-xl border border-n-weak bg-n-solid-2 p-3 lg:flex-row lg:items-center"
      :class="{
        'hidden sm:flex': searchPlaceholder && !slots.actions && !slots.tabs,
      }"
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
          class="group hidden w-64 min-w-0 sm:flex [&>input]:!rounded-lg [&>input]:!border-n-weak [&>input]:!bg-n-surface-1 [&>input]:!py-2 [&>input]:ltr:!pl-9 [&>input]:rtl:!pr-9"
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
        class="flex w-full min-w-0 items-center justify-between gap-3 lg:w-auto lg:justify-start"
        :class="{ 'flex-row-reverse sm:flex-row': !slots.tabs }"
      >
        <div v-if="slots.count" class="shrink-0 whitespace-nowrap">
          <slot name="count" />
        </div>
        <div
          v-if="slots.count"
          class="h-3 w-px flex-shrink-0 rounded-lg bg-n-weak ltr:ml-1 ltr:mr-2 rtl:ml-2 rtl:mr-1"
        />
        <div v-if="slots.actions" class="shrink-0">
          <slot name="actions" />
        </div>
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
      class="group w-full [&>input]:!rounded-lg [&>input]:!border-n-weak [&>input]:!bg-n-surface-1 [&>input]:!py-2 [&>input]:ltr:!pl-9 [&>input]:rtl:!pr-9"
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
