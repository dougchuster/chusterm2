<script setup>
// 3.4: card de IA do segmento — persona/prompt_base do pack instalado +
// override por conta. Compartilhado entre SegmentSettings e a aba Assistente
// do AiCenter (tela única de IA).
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';

import CrmAPI from 'dashboard/api/crm';
import { DsBadge, DsButton, DsCard } from 'dashboard/design-system/components';

const props = defineProps({
  packs: { type: Array, default: () => [] },
  promptOverride: { type: String, default: '' },
});

const emit = defineEmits(['saved', 'error']);

const { t } = useI18n();

const overrideDraft = ref(props.promptOverride);
const saving = ref(false);
const saved = ref(false);

watch(
  () => props.promptOverride,
  value => {
    overrideDraft.value = value;
  }
);

const installedAiPacks = computed(() =>
  props.packs.filter(pack => pack.installed && pack.ai?.prompt_base)
);

async function save() {
  if (saving.value) return;
  saving.value = true;
  saved.value = false;
  try {
    await CrmAPI.updateAiSettings(overrideDraft.value);
    saved.value = true;
    emit('saved', overrideDraft.value);
  } catch {
    emit('error', t('CRM.SEGMENT.ERROR_AI_SAVE'));
  } finally {
    saving.value = false;
  }
}
</script>

<template>
  <DsCard
    v-if="installedAiPacks.length"
    as="section"
    aria-labelledby="pack-ai-title"
  >
    <div class="flex items-start justify-between gap-3">
      <div class="min-w-0">
        <h2
          id="pack-ai-title"
          class="m-0 font-manrope text-ui-label font-semibold text-ui-text"
        >
          {{ t('CRM.SEGMENT.AI.TITLE') }}
        </h2>
        <p class="m-0 mt-1 text-ui-body-sm text-ui-text-muted">
          {{ t('CRM.SEGMENT.AI.SUBTITLE') }}
        </p>
      </div>
      <DsBadge
        v-for="pack in installedAiPacks"
        :key="pack.slug"
        variant="neutral"
        :label="pack.ai.persona || pack.name"
      />
    </div>

    <div
      v-for="pack in installedAiPacks"
      :key="`prompt-${pack.slug}`"
      class="mt-3 rounded-ui-card bg-ui-surface-muted/60 p-3"
    >
      <p class="m-0 whitespace-pre-line text-ui-body-sm text-ui-text-muted">
        {{ pack.ai.prompt_base }}
      </p>
    </div>

    <label
      class="mt-4 block text-ui-caption font-medium text-ui-text-muted"
      for="pack-ai-override"
    >
      {{ t('CRM.SEGMENT.AI.OVERRIDE_LABEL') }}
    </label>
    <textarea
      id="pack-ai-override"
      v-model="overrideDraft"
      rows="4"
      class="mt-1 w-full rounded-ui-control border border-ui-border-subtle bg-ui-surface px-3 py-2 text-ui-body-sm text-ui-text placeholder:text-ui-text-faint focus:border-ui-brand focus:outline-none"
      :placeholder="t('CRM.SEGMENT.AI.OVERRIDE_PLACEHOLDER')"
    />
    <div class="mt-3 flex items-center gap-3">
      <DsButton
        variant="primary"
        size="sm"
        :label="t('CRM.SEGMENT.AI.SAVE')"
        :is-loading="saving"
        @click="save"
      />
      <span
        v-if="saved"
        role="status"
        class="text-ui-caption text-ui-success-foreground"
      >
        {{ t('CRM.SEGMENT.AI.SAVED') }}
      </span>
    </div>
  </DsCard>
  <template v-else />
</template>
