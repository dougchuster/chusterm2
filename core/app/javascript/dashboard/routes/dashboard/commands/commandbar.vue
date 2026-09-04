<script setup>
import '@ChusteRM/ninja-keys';
import { ref, computed, watchEffect, onMounted, onUnmounted } from 'vue';
import { useRouter } from 'vue-router';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useTrack } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { useLocale } from 'shared/composables/useLocale';
import { useAppearanceHotKeys } from 'dashboard/composables/commands/useAppearanceHotKeys';
import { useInboxHotKeys } from 'dashboard/composables/commands/useInboxHotKeys';
import { useGoToCommandHotKeys } from 'dashboard/composables/commands/useGoToCommandHotKeys';
import { useBulkActionsHotKeys } from 'dashboard/composables/commands/useBulkActionsHotKeys';
import { useConversationHotKeys } from 'dashboard/composables/commands/useConversationHotKeys';
import { useCrmCommandHotKeys } from 'dashboard/composables/commands/useCrmCommandHotKeys';
import wootConstants from 'dashboard/constants/globals';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { frontendURL } from 'dashboard/helper/URLHelper';
import ContactAPI from 'dashboard/api/contacts';
import CrmAPI from 'dashboard/api/crm';
import {
  GENERAL_EVENTS,
  SNOOZE_EVENTS,
} from 'dashboard/helper/AnalyticsHelper/events';
import { generateSnoozeSuggestions } from 'dashboard/helper/snoozeHelpers';
import {
  ICON_SNOOZE_CONVERSATION,
  ICON_CONTACT,
  ICON_DEAL,
} from 'dashboard/helper/commandbar/icons';
import {
  CMD_SNOOZE_CONVERSATION,
  CMD_SNOOZE_NOTIFICATION,
  CMD_BULK_ACTION_SNOOZE_CONVERSATION,
} from 'dashboard/helper/commandbar/events';
import { emitter } from 'shared/helpers/mitt';

const store = useStore();
const router = useRouter();
const { t, tm } = useI18n();
const { resolvedLocale } = useLocale();

const currentAccountId = useMapGetter('getCurrentAccountId');
const isFeatureEnabledOnAccount = useMapGetter(
  'accounts/isFeatureEnabledonAccount'
);

const ninjakeys = ref(null);

// Selected snooze type tracker
const selectedSnoozeType = ref(null);

const { goToAppearanceHotKeys } = useAppearanceHotKeys();
const { inboxHotKeys } = useInboxHotKeys();
const { goToCommandHotKeys } = useGoToCommandHotKeys();
const { bulkActionsHotKeys } = useBulkActionsHotKeys();
const { conversationHotKeys } = useConversationHotKeys();
const { crmRecentHotKeys } = useCrmCommandHotKeys();

const SNOOZE_PARENT_IDS = [
  'snooze_conversation',
  'snooze_notification',
  'bulk_action_snooze_conversation',
];
const DYNAMIC_SNOOZE_PREFIX = 'dynamic_snooze_';

const CUSTOM_SNOOZE = wootConstants.SNOOZE_OPTIONS.UNTIL_CUSTOM_TIME;

const dynamicSnoozeActions = ref([]);
const dynamicSearchActions = ref([]);
const recentActions = ref([]);
const currentCommandRoot = ref(null);
const isCommandBarOpen = ref(false);

const queryCache = new Map();
let searchDebounceTimer = null;
let currentAbortController = null;

const placeholder = computed(() =>
  SNOOZE_PARENT_IDS.includes(currentCommandRoot.value)
    ? t('COMMAND_BAR.SNOOZE_PLACEHOLDER')
    : t('COMMAND_BAR.SEARCH_PLACEHOLDER')
);

const SNOOZE_PRESET_IDS = new Set(Object.values(wootConstants.SNOOZE_OPTIONS));

const hotKeys = computed(() => {
  const allActions = [
    ...dynamicSnoozeActions.value,
    ...dynamicSearchActions.value,
    ...recentActions.value,
    ...crmRecentHotKeys.value,
    ...inboxHotKeys.value,
    ...goToCommandHotKeys.value,
    ...goToAppearanceHotKeys.value,
    ...bulkActionsHotKeys.value,
    ...conversationHotKeys.value,
  ];

  const seenIds = new Set();
  const uniqueActions = allActions.filter(action => {
    if (!action?.id || seenIds.has(action.id)) return false;
    seenIds.add(action.id);
    return true;
  });

  // When dynamic NLP snooze suggestions exist, hide preset snooze actions to prevent duplicates
  if (dynamicSnoozeActions.value.length) {
    return uniqueActions.filter(
      a => !SNOOZE_PRESET_IDS.has(a.id) || !SNOOZE_PARENT_IDS.includes(a.parent)
    );
  }

  return uniqueActions;
});

const setCommandBarData = () => {
  if (ninjakeys.value) {
    ninjakeys.value.data = hotKeys.value;
  }
};

const SNOOZE_EVENT_MAP = {
  snooze_conversation: CMD_SNOOZE_CONVERSATION,
  snooze_notification: CMD_SNOOZE_NOTIFICATION,
  bulk_action_snooze_conversation: CMD_BULK_ACTION_SNOOZE_CONVERSATION,
};

const SNOOZE_SECTION_MAP = {
  snooze_conversation: 'COMMAND_BAR.SECTIONS.SNOOZE_CONVERSATION',
  snooze_notification: 'COMMAND_BAR.SECTIONS.SNOOZE_NOTIFICATION',
  bulk_action_snooze_conversation: 'COMMAND_BAR.SECTIONS.BULK_ACTIONS',
};

const snoozeTranslations = computed(() => {
  const raw = tm('SNOOZE_PARSER');
  if (!raw || typeof raw !== 'object') return {};
  return JSON.parse(JSON.stringify(raw));
});

const buildDynamicSnoozeActions = (search, parentId) => {
  const suggestions = generateSnoozeSuggestions(search, new Date(), {
    translations: snoozeTranslations.value,
    locale: resolvedLocale.value,
  });
  if (!suggestions.length) return [];

  const busEvent = SNOOZE_EVENT_MAP[parentId];
  const section = t(SNOOZE_SECTION_MAP[parentId]);

  return suggestions.map((parsed, index) => ({
    id: `${DYNAMIC_SNOOZE_PREFIX}${index}`,
    title:
      parsed.label !== parsed.formattedDate
        ? `${parsed.label} - ${parsed.formattedDate}`
        : parsed.formattedDate,
    parent: parentId,
    section,
    icon: ICON_SNOOZE_CONVERSATION,
    keywords: search,
    handler: () => {
      emitter.emit(busEvent, parsed.resolve());
      useTrack(SNOOZE_EVENTS.NLP_SNOOZE_APPLIED, { label: parsed.label });
    },
  }));
};

const formatCurrency = (val, currency = 'BRL') => {
  if (val === null || val === undefined || Number.isNaN(Number(val))) return '';
  try {
    return new Intl.NumberFormat(resolvedLocale.value || 'pt-BR', {
      style: 'currency',
      currency: currency || 'BRL',
      maximumFractionDigits: 0,
    }).format(Number(val));
  } catch (e) {
    return `${currency || 'R$'} ${val}`;
  }
};

const normalizeText = text =>
  (text || '')
    .toString()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase();

const extractInitials = str => {
  if (!str || typeof str !== 'string') return '';
  return str
    .split(/\s+/)
    .filter(Boolean)
    .map(w => w[0])
    .join('')
    .toLowerCase();
};

const buildContactAction = (contact, isRecent = false) => {
  const name = contact.name || '';
  const email = contact.email || '';
  const phone = contact.phone_number || '';
  const company = contact.company_name || '';
  const subtitle = [company, email, phone].filter(Boolean).join(' • ');

  const title = subtitle
    ? `${name || `#${contact.id}`} (${subtitle})`
    : name || email || phone || `#${contact.id}`;

  const section = isRecent
    ? t('COMMAND_BAR.SECTIONS.RECENT_CONTACTS')
    : t('COMMAND_BAR.SECTIONS.CONTACTS');

  const nameNorm = normalizeText(name);
  const companyNorm = normalizeText(company);
  const initials = extractInitials(name);

  const keywords = [
    name,
    nameNorm,
    email,
    phone,
    company,
    companyNorm,
    initials,
    '@contact',
    '@contato',
    '@cliente',
    '@lead',
    '@pessoa',
    'contact',
    'contato',
    'cliente',
    'lead',
    'pessoa',
  ]
    .filter(Boolean)
    .join(' ');

  return {
    id: `${isRecent ? 'recent' : 'dynamic'}_contact_${contact.id}`,
    title,
    section,
    icon: ICON_CONTACT,
    keywords,
    handler: () => {
      router.push(
        frontendURL(`accounts/${currentAccountId.value}/contacts/${contact.id}`)
      );
    },
  };
};

const buildDealAction = (deal, isRecent = false) => {
  const stageName = deal.stage?.name || deal.crm_pipeline_stage?.name || '';
  const stageNorm = normalizeText(stageName);
  const formattedVal = deal.value
    ? formatCurrency(deal.value, deal.currency)
    : '';
  const rawVal = deal.value ? String(deal.value) : '';
  const contactName = deal.contact?.name || '';
  const companyName = deal.company?.name || '';
  const titleText = deal.title || deal.name || `#${deal.id}`;
  const titleNorm = normalizeText(titleText);
  const initials = extractInitials(titleText);

  const contextSubtitle = [formattedVal, stageName, contactName || companyName]
    .filter(Boolean)
    .join(' • ');

  const title = contextSubtitle
    ? `${titleText} (${contextSubtitle})`
    : titleText;

  const section = isRecent
    ? t('COMMAND_BAR.SECTIONS.RECENT_DEALS')
    : t('COMMAND_BAR.SECTIONS.DEALS');

  const keywords = [
    titleText,
    titleNorm,
    stageName,
    stageNorm,
    contactName,
    normalizeText(contactName),
    companyName,
    normalizeText(companyName),
    rawVal,
    formattedVal,
    initials,
    '#deal',
    '#negocio',
    '#oportunidade',
    '#venda',
    '#funil',
    '#pipeline',
    '$deal',
    'deal',
    'negócio',
    'negocio',
    'funil',
    'pipeline',
    'oportunidade',
    'venda',
  ]
    .filter(Boolean)
    .join(' ');

  return {
    id: `${isRecent ? 'recent' : 'dynamic'}_deal_${deal.id}`,
    title,
    section,
    icon: ICON_DEAL,
    keywords,
    handler: () => {
      router.push(
        frontendURL(`accounts/${currentAccountId.value}/crm/deals/${deal.id}`)
      );
    },
  };
};

const fetchRecentItems = async () => {
  try {
    const isCrmEnabled = isFeatureEnabledOnAccount.value(
      currentAccountId.value,
      FEATURE_FLAGS.CRM
    );

    const promises = [
      ContactAPI.get(1)
        .then(res => res.data?.payload || res.data || [])
        .catch(() => []),
    ];

    if (isCrmEnabled) {
      promises.push(
        CrmAPI.getDeals({ per_page: 5 })
          .then(res => res.data?.data || res.data?.payload || res.data || [])
          .catch(() => [])
      );
    } else {
      promises.push(Promise.resolve([]));
    }

    const [contacts, deals] = await Promise.all(promises);

    const contactActions = Array.isArray(contacts)
      ? contacts.slice(0, 4).map(c => buildContactAction(c, true))
      : [];

    const dealActions = Array.isArray(deals)
      ? deals.slice(0, 4).map(d => buildDealAction(d, true))
      : [];

    recentActions.value = [...contactActions, ...dealActions];
    setCommandBarData();
  } catch (err) {
    // Fail silently on background recents fetch
  }
};

const fetchDynamicCrmAndContacts = async query => {
  const clean = (query || '').trim();
  if (!clean) {
    dynamicSearchActions.value = [];
    return;
  }

  // Determine prefix modifier mode
  const isContactSearch = clean.startsWith('@');
  const isDealSearch = clean.startsWith('#') || clean.startsWith('$');
  const isCommandSearch = clean.startsWith('>') || clean.startsWith('/');
  const isHelpSearch = clean.startsWith('?');

  if (isCommandSearch || isHelpSearch) {
    dynamicSearchActions.value = [];
    return;
  }

  const term = isContactSearch || isDealSearch ? clean.slice(1).trim() : clean;

  // Instant response from query cache if present
  const cacheKey = `${currentAccountId.value}_${clean}`;
  if (queryCache.has(cacheKey)) {
    dynamicSearchActions.value = queryCache.get(cacheKey);
    setCommandBarData();
  }

  if (currentAbortController) {
    currentAbortController.abort();
  }
  currentAbortController = new AbortController();
  const { signal } = currentAbortController;

  try {
    const promises = [];

    // Search contacts
    if (!isDealSearch) {
      if (term) {
        promises.push(
          ContactAPI.search(term, 1, 'name', '', { signal })
            .then(res => res.data?.payload || res.data || [])
            .catch(() => [])
        );
      } else {
        promises.push(
          ContactAPI.get(1)
            .then(res => res.data?.payload || res.data || [])
            .catch(() => [])
        );
      }
    } else {
      promises.push(Promise.resolve([]));
    }

    // Search deals if CRM is enabled
    const isCrmEnabled = isFeatureEnabledOnAccount.value(
      currentAccountId.value,
      FEATURE_FLAGS.CRM
    );

    if (!isContactSearch && isCrmEnabled) {
      if (term) {
        promises.push(
          CrmAPI.getDeals({ search: term, per_page: 8 })
            .then(res => res.data?.data || res.data?.payload || res.data || [])
            .catch(() => [])
        );
      } else {
        promises.push(
          CrmAPI.getDeals({ per_page: 8 })
            .then(res => res.data?.data || res.data?.payload || res.data || [])
            .catch(() => [])
        );
      }
    } else {
      promises.push(Promise.resolve([]));
    }

    const [contacts, deals] = await Promise.all(promises);

    const contactActions = Array.isArray(contacts)
      ? contacts.slice(0, 8).map(c => {
          const action = buildContactAction(c, false);
          action.keywords = `${clean} ${term} ${action.keywords}`;
          return action;
        })
      : [];

    const dealActions = Array.isArray(deals)
      ? deals.slice(0, 8).map(d => {
          const action = buildDealAction(d, false);
          action.keywords = `${clean} ${term} ${action.keywords}`;
          return action;
        })
      : [];

    const results = [...contactActions, ...dealActions];

    if (queryCache.size > 50) {
      const firstKey = queryCache.keys().next().value;
      queryCache.delete(firstKey);
    }
    queryCache.set(cacheKey, results);

    // Hide recents while actively querying dynamic results
    recentActions.value = [];
    dynamicSearchActions.value = results;
    setCommandBarData();
  } catch (err) {
    // Ignore aborted request errors
  }
};

const resetSnoozeState = () => {
  currentCommandRoot.value = null;
  dynamicSnoozeActions.value = [];
};

const patchNinjaKeysOpenClose = el => {
  if (!el || typeof el.open !== 'function' || typeof el.close !== 'function') {
    return;
  }

  const originalOpen = el.open.bind(el);
  const originalClose = el.close.bind(el);

  el.open = (...args) => {
    const [options = {}] = args;
    isCommandBarOpen.value = true;
    currentCommandRoot.value = options.parent || null;
    dynamicSnoozeActions.value = [];
    dynamicSearchActions.value = [];
    fetchRecentItems();
    return originalOpen(...args);
  };

  el.close = (...args) => {
    isCommandBarOpen.value = false;
    resetSnoozeState();
    dynamicSearchActions.value = [];
    recentActions.value = [];
    return originalClose(...args);
  };
};

const openCommandBar = (options = {}) => {
  if (ninjakeys.value && typeof ninjakeys.value.open === 'function') {
    ninjakeys.value.open(options);
  }
};

const handleGlobalKeydown = event => {
  const isMac =
    navigator.userAgent.includes('Mac') ||
    navigator.platform?.toUpperCase().indexOf('MAC') >= 0;
  const isCmdOrCtrl = isMac ? event.metaKey : event.ctrlKey;

  if (isCmdOrCtrl && (event.key === 'k' || event.key === 'K')) {
    event.preventDefault();
    event.stopPropagation();
    openCommandBar();
  }
};

const onSelected = item => {
  const {
    detail: {
      action: { title = null, section = null, id = null, children = null } = {},
    } = {},
  } = item;

  selectedSnoozeType.value = id === CUSTOM_SNOOZE ? id : null;

  if (Array.isArray(children) && children.length) {
    currentCommandRoot.value = id;
  }

  useTrack(GENERAL_EVENTS.COMMAND_BAR, { section, action: title });
  setCommandBarData();
};

const onCommandBarChange = item => {
  const { detail: { search = '', actions = [] } = {} } = item;
  const normalizedSearch = search.trim();

  if (actions.length > 0) {
    const uniqueParents = [
      ...new Set(actions.map(action => action.parent).filter(Boolean)),
    ];
    if (uniqueParents.length === 1) {
      currentCommandRoot.value = uniqueParents[0];
    } else {
      currentCommandRoot.value = null;
    }
  }

  if (
    normalizedSearch &&
    SNOOZE_PARENT_IDS.includes(currentCommandRoot.value || '')
  ) {
    dynamicSnoozeActions.value = buildDynamicSnoozeActions(
      normalizedSearch,
      currentCommandRoot.value
    );
    return;
  }
  dynamicSnoozeActions.value = [];

  // When search input is cleared, restore recent items and clear dynamic search
  if (!normalizedSearch) {
    dynamicSearchActions.value = [];
    clearTimeout(searchDebounceTimer);
    fetchRecentItems();
    return;
  }

  // Debounced search for Contacts & CRM Deals (100ms for instant feel)
  clearTimeout(searchDebounceTimer);
  searchDebounceTimer = setTimeout(() => {
    fetchDynamicCrmAndContacts(normalizedSearch);
  }, 100);
};

const onClosed = () => {
  isCommandBarOpen.value = false;
  if (selectedSnoozeType.value !== CUSTOM_SNOOZE) {
    store.dispatch('setContextMenuChatId', null);
  }
  resetSnoozeState();
  dynamicSearchActions.value = [];
  recentActions.value = [];
  clearTimeout(searchDebounceTimer);
  if (currentAbortController) {
    currentAbortController.abort();
  }
};

watchEffect(() => {
  if (ninjakeys.value) {
    ninjakeys.value.data = hotKeys.value;
  }
});

onMounted(() => {
  setCommandBarData();
  fetchRecentItems();
  patchNinjaKeysOpenClose(ninjakeys.value);

  // Universal trigger used by the sidebar search and other surfaces
  emitter.on('open-commandbar', openCommandBar);
  window.addEventListener('keydown', handleGlobalKeydown, true);
});

onUnmounted(() => {
  emitter.off('open-commandbar', openCommandBar);
  window.removeEventListener('keydown', handleGlobalKeydown, true);
  clearTimeout(searchDebounceTimer);
  if (currentAbortController) {
    currentAbortController.abort();
  }
});
</script>

<!-- eslint-disable vue/attribute-hyphenation -->
<template>
  <ninja-keys
    ref="ninjakeys"
    noAutoLoadMdIcons
    hideBreadcrumbs
    :placeholder="placeholder"
    @change="onCommandBarChange"
    @selected="onSelected"
    @closed="onClosed"
  />
</template>

<style lang="scss">
ninja-keys {
  --ninja-accent-color: var(--ds-accent-primary);
  --ninja-font-family: var(--ds-font-sans, 'Inter', sans-serif);
  --ninja-overflow-background: rgba(6, 14, 32, 0.72);
  --ninja-modal-background: var(--ds-bg-elevated);
  --ninja-secondary-background-color: var(--ds-bg-surface);
  --ninja-selected-background: var(--ds-bg-active);
  --ninja-footer-background: var(--ds-bg-canvas);
  --ninja-text-color: var(--ds-fg-default);
  --ninja-icon-color: var(--ds-fg-muted);
  --ninja-secondary-text-color: var(--ds-fg-subtle);
  --ninja-border-radius: 14px;
  --ninja-actions-height: 48px;
  --ninja-backdrop-filter: blur(12px);
  z-index: 9999;
}

body.dark ninja-keys,
.dark ninja-keys {
  --ninja-overflow-background: rgba(6, 14, 32, 0.85);
  --ninja-modal-background: var(--ds-bg-elevated);
  --ninja-secondary-background-color: var(--ds-bg-surface);
  --ninja-selected-background: var(--ds-bg-active);
  --ninja-footer-background: var(--ds-bg-canvas);
  --ninja-text-color: var(--ds-fg-default);
  --ninja-icon-color: var(--ds-fg-muted);
  --ninja-secondary-text-color: var(--ds-fg-subtle);
  --ninja-accent-color: var(--ds-accent-primary);
}
</style>
