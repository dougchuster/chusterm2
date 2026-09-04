<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter, useRoute } from 'vue-router';
import CrmAPI from 'dashboard/api/crm';
import { useAlert } from 'dashboard/composables';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import CRMScoreBadge from './CRMScoreBadge.vue';
import {
  DsBadge,
  DsButton,
  DsCard,
  DsSkeleton,
} from 'dashboard/design-system/components';
import { crmConversationUrl } from 'dashboard/helper/conversationIdentifier';

const props = defineProps({
  deal: {
    type: Object,
    required: true,
  },
  loading: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['recompute', 'dealUpdated']);

const { t } = useI18n();
const router = useRouter();
const route = useRoute();
const accountId = computed(() => Number(route.params.accountId));

const recomputing = ref(false);

const aiMode = computed(() => props.deal?.captain_ai_mode);
const aiModeVariant = computed(() => {
  switch (aiMode.value) {
    case 'auto':
      return 'success';
    case 'supervised':
      return 'brand';
    case 'paused':
      return 'warning';
    case 'human_only':
      return 'info';
    default:
      return 'neutral';
  }
});

const aiModeLabel = computed(() => {
  switch (aiMode.value) {
    case 'auto':
      return t('COPILOT.AI_MODE.AUTO');
    case 'supervised':
      return t('COPILOT.AI_MODE.SUPERVISED');
    case 'paused':
      return t('COPILOT.AI_MODE.PAUSED');
    case 'human_only':
      return t('COPILOT.AI_MODE.HUMAN_ONLY');
    default:
      return '';
  }
});

const nextBestAction = computed(() => props.deal?.next_best_action);
const summary = computed(() => props.deal?.summary);
const scoreTotal = computed(() => Number(props.deal?.score_total || 0));
const scoreClassification = computed(
  () => props.deal?.score_classification || ''
);
const scoreReason = computed(() => props.deal?.score_reason);

const conversationLink = computed(() =>
  crmConversationUrl({ accountId: accountId.value, record: props.deal })
);

const handleRecomputeScore = async () => {
  if (!props.deal?.id || recomputing.value) return;
  recomputing.value = true;
  try {
    const response = await CrmAPI.recomputeLeadScore(props.deal.id);
    useAlert(t('CRM.DEAL_INSIGHTS.SCORE_UPDATED'));
    emit('recompute', response?.data);
    emit('dealUpdated', response?.data);
  } catch (error) {
    useAlert(t('CRM.DEAL_INSIGHTS.SCORE_UPDATE_ERROR'));
  } finally {
    recomputing.value = false;
  }
};

const openConversation = () => {
  if (conversationLink.value) {
    router.push(conversationLink.value);
  }
};
</script>

<template>
  <DsCard data-testid="crm-deal-ai-insights-card" padding="md" class="space-y-4">
    <!-- Header -->
    <div class="flex items-start justify-between gap-3">
      <div class="flex items-center gap-2">
        <span
          class="flex size-8 shrink-0 items-center justify-center rounded-xl bg-ds-accent-soft text-ds-accent"
        >
          <Icon icon="i-lucide-sparkles" class="size-4" />
        </span>
        <div>
          <h2 class="m-0 text-ui-body font-semibold text-ui-text">
            {{ $t('CRM.DEAL_INSIGHTS.TITLE') }}
          </h2>
          <p class="m-0 text-ui-caption text-ui-text-muted">
            {{ $t('CRM.DEAL_INSIGHTS.SUBTITLE') }}
          </p>
        </div>
      </div>
      <DsBadge
        v-if="aiModeLabel"
        data-testid="ai-mode-badge"
        :label="aiModeLabel"
        :variant="aiModeVariant"
      />
    </div>

    <!-- Loading Skeleton -->
    <div v-if="loading || recomputing" class="space-y-3 py-2" data-testid="insights-loading">
      <DsSkeleton class="h-4 w-1/3" />
      <DsSkeleton class="h-16 w-full rounded-ui-control" />
      <DsSkeleton class="h-4 w-1/2" />
      <DsSkeleton class="h-12 w-full rounded-ui-control" />
    </div>

    <div v-else class="space-y-4">
      <!-- Next Best Action -->
      <div class="space-y-1.5">
        <div class="flex items-center gap-1.5">
          <Icon icon="i-lucide-zap" class="size-3.5 text-ds-accent" />
          <span class="text-ui-caption font-semibold uppercase tracking-wider text-ui-text-muted">
            {{ $t('CRM.DEAL_INSIGHTS.NEXT_ACTION_TITLE') }}
          </span>
        </div>
        <div
          data-testid="deal-next-best-action"
          class="rounded-ui-control border border-ui-brand/20 bg-ui-brand-soft p-3 text-ui-body-sm text-ui-brand-foreground"
        >
          <p v-if="nextBestAction" class="m-0 font-medium">
            {{ nextBestAction }}
          </p>
          <p v-else class="m-0 text-ui-caption text-ui-text-muted italic">
            {{ $t('CRM.DEAL_INSIGHTS.NO_NEXT_ACTION') }}
          </p>
        </div>
      </div>

      <!-- Deal Summary -->
      <div class="space-y-1.5">
        <div class="flex items-center gap-1.5">
          <Icon icon="i-lucide-file-text" class="size-3.5 text-ui-text-muted" />
          <span class="text-ui-caption font-semibold uppercase tracking-wider text-ui-text-muted">
            {{ $t('CRM.DEAL_INSIGHTS.SUMMARY_TITLE') }}
          </span>
        </div>
        <div
          data-testid="deal-ai-summary"
          class="rounded-ui-control border border-ui-border-subtle bg-ui-sunken p-3 text-ui-body-sm text-ui-text whitespace-pre-wrap"
        >
          <p v-if="summary" class="m-0">
            {{ summary }}
          </p>
          <p v-else class="m-0 text-ui-caption text-ui-text-muted italic">
            {{ $t('CRM.DEAL_INSIGHTS.NO_SUMMARY') }}
          </p>
        </div>
      </div>

      <!-- Lead Score & Rationale -->
      <div class="space-y-2 border-t border-ui-border-subtle pt-3">
        <div class="flex items-center justify-between gap-2">
          <span class="text-ui-caption font-semibold uppercase tracking-wider text-ui-text-muted">
            {{ $t('CRM.DEAL_INSIGHTS.SCORE_TITLE') }}
          </span>
          <div class="flex items-center gap-2">
            <CRMScoreBadge
              data-testid="deal-score-badge"
              :score="scoreTotal"
              :classification="scoreClassification"
              show-label
              size="sm"
            />
            <DsButton
              icon="i-lucide-refresh-cw"
              variant="ghost"
              size="sm"
              :loading="recomputing"
              :aria-label="$t('CRM.DEAL_INSIGHTS.RECOMPUTE_SCORE')"
              @click="handleRecomputeScore"
            />
          </div>
        </div>
        <p
          v-if="scoreReason"
          data-testid="deal-score-reason"
          class="m-0 text-ui-caption text-ui-text-muted"
        >
          <strong class="font-medium text-ui-text">{{ $t('CRM.DEAL_INSIGHTS.SCORE_REASON') }}:</strong>
          {{ scoreReason }}
        </p>
      </div>

      <!-- Context Action: Open conversation -->
      <div v-if="conversationLink" class="border-t border-ui-border-subtle pt-3">
        <DsButton
          :label="$t('CRM.DEAL_INSIGHTS.OPEN_CONVERSATION')"
          icon="i-lucide-message-circle"
          variant="secondary"
          size="sm"
          class="w-full"
          @click="openConversation"
        />
      </div>
    </div>
  </DsCard>
</template>
