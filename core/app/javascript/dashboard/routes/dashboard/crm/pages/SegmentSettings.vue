<script setup>
import { onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';

import CrmAPI from '../../../../api/crm';
import CRMPackAiCard from 'dashboard/components/crm/CRMPackAiCard.vue';
import {
  DsBadge,
  DsButton,
  DsCard,
  DsEmptyState,
  DsSkeleton,
} from 'dashboard/design-system/components';
import { DsPageHeader } from 'dashboard/design-system/templates';

// Fase 2 (2.2): escolha do segmento/vertical da conta — cada pack define
// categorias, tipos de atividade e campos dinâmicos. Só existe com a flag
// crm_universal; a API responde 404 fora dela.
const { t } = useI18n();

const packs = ref([]);
const loading = ref(true);
const installingSlug = ref('');
const error = ref('');
const promptOverride = ref('');

async function loadPacks() {
  loading.value = true;
  error.value = '';
  try {
    const { data } = await CrmAPI.getPacks();
    packs.value = data?.packs || [];
    promptOverride.value = data?.ai_settings?.prompt_override || '';
  } catch {
    error.value = t('CRM.SEGMENT.ERROR_LOAD');
  } finally {
    loading.value = false;
  }
}

function onAiSaved(value) {
  promptOverride.value = value;
}

function onAiError(message) {
  error.value = message;
}

async function install(pack) {
  if (pack.installed || installingSlug.value) return;
  installingSlug.value = pack.slug;
  error.value = '';
  try {
    await CrmAPI.installPack(pack.slug);
    await loadPacks();
  } catch {
    error.value = t('CRM.SEGMENT.ERROR_INSTALL');
  } finally {
    installingSlug.value = '';
  }
}

onMounted(loadPacks);
</script>

<template>
  <section
    class="flex min-h-0 w-full min-w-0 flex-1 flex-col bg-ui-canvas text-ui-text"
    :aria-busy="loading || undefined"
  >
    <DsPageHeader
      :title="t('CRM.SEGMENT.TITLE')"
      :breadcrumbs="[
        { label: t('CRM.SEGMENT.BREADCRUMB') },
        { label: t('CRM.SEGMENT.TITLE') },
      ]"
    />

    <div class="flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto p-4 sm:p-6">
      <DsCard as="section" aria-labelledby="segment-intro-title">
        <h2
          id="segment-intro-title"
          class="m-0 font-manrope text-ui-label font-semibold text-ui-text"
        >
          {{ t('CRM.SEGMENT.TITLE') }}
        </h2>
        <p class="m-0 mt-1 text-ui-body-sm text-ui-text-muted">
          {{ t('CRM.SEGMENT.SUBTITLE') }}
        </p>
      </DsCard>

      <CRMPackAiCard
        :packs="packs"
        :prompt-override="promptOverride"
        @saved="onAiSaved"
        @error="onAiError"
      />

      <p
        v-if="error"
        role="alert"
        class="m-0 rounded-ui-control bg-ui-danger-soft px-3 py-2 text-ui-body-sm text-ui-danger-foreground"
      >
        {{ error }}
      </p>

      <div
        v-if="loading"
        role="status"
        :aria-label="t('CRM.SEGMENT.LOADING')"
        class="flex flex-col gap-2"
      >
        <span class="sr-only">{{ t('CRM.SEGMENT.LOADING') }}</span>
        <DsSkeleton v-for="row in 3" :key="row" shape="block" class="h-24" />
      </div>

      <DsEmptyState
        v-else-if="!packs.length && !error"
        icon="i-lucide-package"
        :title="t('CRM.SEGMENT.EMPTY')"
      />

      <div v-else class="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <DsCard
          v-for="pack in packs"
          :key="pack.slug"
          as="article"
          :aria-label="pack.name"
        >
          <div class="flex items-start justify-between gap-3">
            <div class="min-w-0">
              <h3
                class="m-0 font-manrope text-ui-label font-semibold text-ui-text"
              >
                {{ pack.name }}
              </h3>
              <p class="m-0 mt-0.5 text-ui-caption text-ui-text-muted">
                v{{ pack.version }}
              </p>
            </div>
            <DsBadge
              v-if="pack.installed"
              variant="success"
              :label="t('CRM.SEGMENT.INSTALLED')"
            />
          </div>

          <div
            v-if="pack.categories?.length"
            class="mt-3 flex flex-wrap gap-1.5"
          >
            <DsBadge
              v-for="category in pack.categories.slice(0, 6)"
              :key="category.value"
              variant="neutral"
              :label="category.label"
            />
            <DsBadge
              v-if="pack.categories.length > 6"
              variant="neutral"
              :label="
                t('CRM.SEGMENT.MORE_CATEGORIES', {
                  count: pack.categories.length - 6,
                })
              "
            />
          </div>

          <div
            class="mt-4 flex items-center justify-between border-t border-ui-border-subtle/60 pt-3"
          >
            <span class="text-ui-caption text-ui-text-muted">
              {{
                t('CRM.SEGMENT.FIELDS_COUNT', {
                  count:
                    (pack.field_definitions?.length || 0) +
                    (pack.activity_types?.length || 0),
                })
              }}
            </span>
            <DsButton
              v-if="!pack.installed"
              variant="primary"
              size="sm"
              :label="t('CRM.SEGMENT.INSTALL')"
              :is-loading="installingSlug === pack.slug"
              :disabled="Boolean(installingSlug)"
              @click="install(pack)"
            />
          </div>
        </DsCard>
      </div>
    </div>
  </section>
</template>
