<script setup>
import { computed, onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import MarketingAPI from '../../../../api/marketing';
import { useAlert } from 'dashboard/composables';
import {
  DsBadge,
  DsButton,
  DsCard,
  DsSkeleton,
} from 'dashboard/design-system/components';
import { DsPageHeader } from 'dashboard/design-system/templates';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const { t } = useI18n();
const route = useRoute();

const connections = ref([]);
const oauthConfigured = ref({});
const loading = ref(false);
const actionLoading = ref('');

const oauthFeedback = computed(() => route.query.marketing_oauth || '');

const providerIcons = {
  meta_ads: 'i-lucide-share-2',
  google_ads: 'i-lucide-target',
  ga4: 'i-lucide-bar-chart-3',
};

const providerDescriptions = {
  meta_ads: 'MARKETING.CONNECTIONS.META_DESC',
  google_ads: 'MARKETING.CONNECTIONS.GOOGLE_ADS_DESC',
  ga4: 'MARKETING.CONNECTIONS.GA4_DESC',
};

const statusVariant = status =>
  ({ active: 'success', error: 'danger', disconnected: 'neutral' })[status] ||
  'neutral';

async function loadConnections() {
  loading.value = true;
  try {
    const { data } = await MarketingAPI.getConnections();
    connections.value = data?.connections || [];
    oauthConfigured.value = data?.oauth_configured || {};
  } finally {
    loading.value = false;
  }
}

async function connect(provider) {
  actionLoading.value = provider;
  try {
    const { data } = await MarketingAPI.authorizeConnection(
      provider,
      route.fullPath
    );
    if (data?.url) window.location.href = data.url;
  } catch (err) {
    useAlert(
      err?.response?.data?.message || t('MARKETING.CONNECTIONS.CONNECT_ERROR')
    );
  } finally {
    actionLoading.value = '';
  }
}

async function disconnect(item) {
  if (!item.connection_id) return;
  actionLoading.value = item.provider;
  try {
    await MarketingAPI.disconnectConnection(item.connection_id);
    useAlert(t('MARKETING.CONNECTIONS.DISCONNECTED'));
    await loadConnections();
  } catch (err) {
    useAlert(
      err?.response?.data?.error || t('MARKETING.CONNECTIONS.DISCONNECT_ERROR')
    );
  } finally {
    actionLoading.value = '';
  }
}

async function syncNow(item) {
  if (!item.connection_id) return;
  actionLoading.value = `sync-${item.provider}`;
  try {
    await MarketingAPI.syncConnection(item.connection_id);
    useAlert(t('MARKETING.CONNECTIONS.SYNC_QUEUED'));
  } catch (err) {
    useAlert(
      err?.response?.data?.error || t('MARKETING.CONNECTIONS.SYNC_ERROR')
    );
  } finally {
    actionLoading.value = '';
  }
}

function adAccounts(item) {
  return item.metadata?.ad_accounts || [];
}

onMounted(async () => {
  await loadConnections();
  if (oauthFeedback.value === 'connected') {
    useAlert(t('MARKETING.CONNECTIONS.CONNECTED'));
  } else if (oauthFeedback.value === 'error') {
    useAlert(t('MARKETING.CONNECTIONS.CONNECT_ERROR'));
  } else if (oauthFeedback.value === 'not_configured') {
    useAlert(t('MARKETING.CONNECTIONS.NOT_CONFIGURED'));
  }
});
</script>

<template>
  <section
    class="flex min-h-0 w-full min-w-0 flex-1 flex-col bg-ui-canvas text-ui-text"
    :aria-busy="loading || undefined"
  >
    <DsPageHeader
      :title="t('MARKETING.CONNECTIONS.TITLE')"
      :breadcrumbs="[
        { label: t('MARKETING.TITLE') },
        { label: t('MARKETING.CONNECTIONS.TITLE') },
      ]"
    />

    <div class="flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto p-4 sm:p-6">
      <p class="m-0 max-w-3xl text-ui-body-sm text-ui-text-muted">
        {{ t('MARKETING.CONNECTIONS.SUBTITLE') }}
      </p>

      <div v-if="loading" class="grid gap-4 md:grid-cols-3">
        <DsSkeleton v-for="n in 3" :key="n" class="h-44 rounded-ui-surface" />
      </div>

      <div v-else class="grid gap-4 md:grid-cols-3">
        <DsCard
          v-for="item in connections"
          :key="item.provider"
          as="article"
          :aria-labelledby="`marketing-provider-${item.provider}`"
          class="flex flex-col gap-3"
        >
          <div class="flex items-start justify-between gap-3">
            <div class="flex items-center gap-2.5">
              <span
                class="flex size-9 items-center justify-center rounded-ui-control bg-ui-brand-soft text-ui-brand-foreground"
              >
                <Icon :icon="providerIcons[item.provider]" class="size-4.5" />
              </span>
              <h2
                :id="`marketing-provider-${item.provider}`"
                class="m-0 font-manrope text-ui-label font-semibold text-ui-text"
              >
                {{ item.label }}
              </h2>
            </div>
            <DsBadge
              :variant="statusVariant(item.status)"
              :label="
                t(`MARKETING.CONNECTIONS.STATUS.${item.status.toUpperCase()}`)
              "
            />
          </div>

          <p class="m-0 text-ui-body-sm text-ui-text-muted">
            {{ t(providerDescriptions[item.provider]) }}
          </p>

          <template v-if="item.connected">
            <div
              v-if="item.provider === 'meta_ads' && adAccounts(item).length"
              class="rounded-ui-control bg-ui-sunken p-2.5"
            >
              <p
                class="m-0 mb-1.5 text-ui-caption font-medium uppercase tracking-wide text-ui-text-muted"
              >
                {{ t('MARKETING.CONNECTIONS.AD_ACCOUNTS') }}
              </p>
              <ul class="m-0 flex list-none flex-col gap-1 p-0">
                <li
                  v-for="acc in adAccounts(item)"
                  :key="acc.id"
                  class="truncate text-ui-body-sm text-ui-text"
                >
                  {{ acc.name }}
                  <span class="text-ui-text-muted">· {{ acc.account_id }}</span>
                </li>
              </ul>
            </div>
            <p
              v-if="item.last_synced_at"
              class="m-0 text-ui-caption text-ui-text-muted"
            >
              {{
                t('MARKETING.CONNECTIONS.LAST_SYNC', {
                  at: new Date(item.last_synced_at).toLocaleString('pt-BR'),
                })
              }}
            </p>
            <p
              v-if="item.last_error"
              class="m-0 text-ui-caption text-ui-danger"
              role="alert"
            >
              {{ item.last_error }}
            </p>
          </template>

          <p
            v-if="!oauthConfigured[item.provider]"
            class="m-0 text-ui-caption text-ui-warning-foreground"
            role="note"
          >
            {{ t('MARKETING.CONNECTIONS.OAUTH_MISSING') }}
          </p>

          <div class="mt-auto flex flex-wrap gap-2 pt-1">
            <DsButton
              v-if="!item.connected"
              variant="primary"
              size="sm"
              :label="t('MARKETING.CONNECTIONS.CONNECT')"
              icon="i-lucide-plug"
              :disabled="!oauthConfigured[item.provider]"
              :loading="actionLoading === item.provider"
              @click="connect(item.provider)"
            />
            <template v-else>
              <DsButton
                variant="secondary"
                size="sm"
                :label="t('MARKETING.CONNECTIONS.SYNC_NOW')"
                icon="i-lucide-refresh-cw"
                :loading="actionLoading === `sync-${item.provider}`"
                @click="syncNow(item)"
              />
              <DsButton
                variant="secondary"
                size="sm"
                :label="t('MARKETING.CONNECTIONS.DISCONNECT')"
                icon="i-lucide-unplug"
                :loading="actionLoading === item.provider"
                @click="disconnect(item)"
              />
            </template>
          </div>
        </DsCard>
      </div>
    </div>
  </section>
</template>
