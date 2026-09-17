<script setup>
import { h, ref, computed, onMounted, watch } from 'vue';
import { provideSidebarContext, useSidebarResize } from './provider';
import { useAccount } from 'dashboard/composables/useAccount';
import { useMapGetter } from 'dashboard/composables/store';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useSidebarKeyboardShortcuts } from './useSidebarKeyboardShortcuts';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { useWindowSize, useEventListener } from '@vueuse/core';
import { useRoute, useRouter } from 'vue-router';
import CrmAPI from 'dashboard/api/crm';

import SidebarGroup from './SidebarGroup.vue';
import SidebarProfileMenu from './SidebarProfileMenu.vue';
import SidebarChangelogCard from './SidebarChangelogCard.vue';
import SidebarChangelogButton from './SidebarChangelogButton.vue';
import ChannelLeaf from './ChannelLeaf.vue';
import ChannelIcon from 'next/icon/ChannelIcon.vue';
import SidebarAccountSwitcher from './SidebarAccountSwitcher.vue';
import Logo from 'next/icon/Logo.vue';
import DsTooltip from 'dashboard/design-system/components/DsTooltip.vue';
import { emitter } from 'shared/helpers/mitt';

const props = defineProps({
  isMobileSidebarOpen: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits([
  'closeKeyShortcutModal',
  'openKeyShortcutModal',
  'showCreateAccountModal',
  'closeMobileSidebar',
]);

const { accountScopedRoute, isOnChusteRMCloud } = useAccount();
const store = useStore();
const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const productName = 'ChusteRM';
const commandShortcut = '⌘ K';

const isACustomBrandedInstance = useMapGetter(
  'globalConfig/isACustomBrandedInstance'
);
const isRTL = useMapGetter('accounts/isRTL');

const { width: windowWidth } = useWindowSize();
const isMobile = computed(() => windowWidth.value < 768);

watch(
  () => route.fullPath,
  () => {
    if (isMobile.value && props.isMobileSidebarOpen) {
      emit('closeMobileSidebar');
    }
  }
);

const accountId = useMapGetter('getCurrentAccountId');
const isFeatureEnabledonAccount = useMapGetter(
  'accounts/isFeatureEnabledonAccount'
);

const hasAdvancedAssignment = computed(() => {
  return isFeatureEnabledonAccount.value(
    accountId.value,
    FEATURE_FLAGS.ADVANCED_ASSIGNMENT
  );
});

const hasMarketing = computed(() => {
  return isFeatureEnabledonAccount.value(
    accountId.value,
    FEATURE_FLAGS.MARKETING
  );
});

const toggleShortcutModalFn = show => {
  if (show) {
    emit('openKeyShortcutModal');
  } else {
    emit('closeKeyShortcutModal');
  }
};

useSidebarKeyboardShortcuts(toggleShortcutModalFn);

const expandedItem = ref(null);

const setExpandedItem = name => {
  expandedItem.value = expandedItem.value === name ? null : name;
};

const {
  sidebarWidth,
  isCollapsed,
  setSidebarWidth,
  saveWidth,
  snapToCollapsed,
  snapToExpanded,
  snapToMinimumExpanded,
  MIN_WIDTH,
  MIN_EXPANDED_WIDTH,
  MAX_WIDTH,
  COLLAPSED_THRESHOLD,
} = useSidebarResize();

// On mobile, sidebar is always expanded (flyout mode)
const isEffectivelyCollapsed = computed(
  () => !isMobile.value && isCollapsed.value
);

// Favorites / Pinning System with localStorage persistence
const PINNED_STORAGE_PREFIX = 'chusterm_sidebar_pinned_v1_';
const getPinnedStorageKey = () =>
  `${PINNED_STORAGE_PREFIX}${accountId.value || 'default'}`;

const pinnedItems = ref([]);

const loadPinnedItems = () => {
  try {
    const raw = localStorage.getItem(getPinnedStorageKey());
    pinnedItems.value = raw ? JSON.parse(raw) : [];
  } catch {
    pinnedItems.value = [];
  }
};

loadPinnedItems();

const savePinnedItems = () => {
  try {
    localStorage.setItem(
      getPinnedStorageKey(),
      JSON.stringify(pinnedItems.value)
    );
  } catch {
    // ignore storage quota errors
  }
};

const isPinned = itemId => {
  if (!itemId) return false;
  return pinnedItems.value.some(p => p.id === itemId || p.name === itemId);
};

const togglePin = item => {
  if (!item) return;
  const id = item.id || item.name || item.label;
  const idx = pinnedItems.value.findIndex(p => p.id === id || p.name === id);
  if (idx >= 0) {
    pinnedItems.value.splice(idx, 1);
  } else {
    pinnedItems.value.push({
      id,
      name: item.name || id,
      label: item.label,
      icon: typeof item.icon === 'string' ? item.icon : 'i-lucide-star',
      to: item.to || accountScopedRoute('home'),
      activeOn: item.activeOn || [],
    });
  }
  savePinnedItems();
};

const unpin = itemId => {
  pinnedItems.value = pinnedItems.value.filter(
    p => p.id !== itemId && p.name !== itemId
  );
  savePinnedItems();
};

watch(
  () => accountId.value,
  () => {
    loadPinnedItems();
  }
);

// Collapsible Sections Management with localStorage persistence
const SECTION_STORAGE_KEY = 'chusterm_sidebar_collapsed_sections_v1';
const collapsedSections = ref({});

const loadCollapsedSections = () => {
  try {
    const raw = localStorage.getItem(SECTION_STORAGE_KEY);
    collapsedSections.value = raw ? JSON.parse(raw) : {};
  } catch {
    collapsedSections.value = {};
  }
};

loadCollapsedSections();

const saveCollapsedSections = () => {
  try {
    localStorage.setItem(
      SECTION_STORAGE_KEY,
      JSON.stringify(collapsedSections.value)
    );
  } catch {
    // ignore storage quota errors
  }
};

const isSectionOpen = sectionId => {
  return !collapsedSections.value[sectionId];
};

const toggleSection = sectionId => {
  collapsedSections.value = {
    ...collapsedSections.value,
    [sectionId]: !collapsedSections.value[sectionId],
  };
  saveCollapsedSections();
};

// Resize handle logic
const isResizing = ref(false);
const startX = ref(0);
const startWidth = ref(0);

provideSidebarContext({
  expandedItem,
  setExpandedItem,
  isCollapsed: isEffectivelyCollapsed,
  sidebarWidth,
  isResizing,
  pinnedItems,
  isPinned,
  togglePin,
  unpin,
});

// Get clientX from mouse or touch event
const getClientX = event =>
  event.touches ? event.touches[0].clientX : event.clientX;

const onResizeStart = event => {
  isResizing.value = true;
  startX.value = getClientX(event);
  startWidth.value = sidebarWidth.value;
  Object.assign(document.body.style, {
    cursor: 'col-resize',
    userSelect: 'none',
  });
  event.preventDefault();
};

const onResizeMove = event => {
  if (!isResizing.value) return;

  const delta = isRTL.value
    ? startX.value - getClientX(event)
    : getClientX(event) - startX.value;
  setSidebarWidth(startWidth.value + delta);
};

const onResizeEnd = () => {
  if (!isResizing.value) return;

  isResizing.value = false;
  Object.assign(document.body.style, { cursor: '', userSelect: '' });

  if (sidebarWidth.value < COLLAPSED_THRESHOLD) {
    snapToCollapsed();
  } else if (sidebarWidth.value < MIN_EXPANDED_WIDTH) {
    snapToMinimumExpanded();
  } else {
    saveWidth();
  }
};

const onResizeHandleDoubleClick = () => {
  if (isCollapsed.value) snapToExpanded();
  else snapToCollapsed();
};

const onResizeHandleKeydown = event => {
  const step = event.shiftKey ? 32 : 8;
  const direction = isRTL.value ? -1 : 1;
  const widthChange = {
    ArrowLeft: -step * direction,
    ArrowRight: step * direction,
  }[event.key];

  if (widthChange) {
    event.preventDefault();
    setSidebarWidth(sidebarWidth.value + widthChange);
    saveWidth();
    return;
  }

  if (event.key === 'Home' || event.key === 'End') {
    event.preventDefault();
    setSidebarWidth(event.key === 'Home' ? MIN_WIDTH : MAX_WIDTH);
    saveWidth();
  }
};

const toggleSidebarCollapsed = () => {
  if (isCollapsed.value) {
    snapToExpanded();
  } else {
    snapToCollapsed();
  }
};

const collapseToggleIcon = computed(() => {
  if (isEffectivelyCollapsed.value) {
    return isRTL.value ? 'i-lucide-chevron-left' : 'i-lucide-chevron-right';
  }

  return isRTL.value ? 'i-lucide-chevron-right' : 'i-lucide-chevron-left';
});

const collapseToggleLabel = computed(() =>
  isEffectivelyCollapsed.value
    ? t('SIDEBAR.EXPAND_SIDEBAR')
    : t('SIDEBAR.COLLAPSE_SIDEBAR')
);

const headerActionIcon = computed(() =>
  isMobile.value ? 'i-lucide-x' : collapseToggleIcon.value
);

const headerActionLabel = computed(() =>
  isMobile.value
    ? t('HELP_CENTER.EDIT_HEADER.CLOSE_SIDEBAR')
    : collapseToggleLabel.value
);

const handleHeaderAction = () => {
  if (isMobile.value) {
    emit('closeMobileSidebar');
    return;
  }

  toggleSidebarCollapsed();
};

const openCommandPalette = () => {
  emitter.emit('open-commandbar');
};

// Support both mouse and touch events
useEventListener(document, 'mousemove', onResizeMove);
useEventListener(document, 'mouseup', onResizeEnd);
useEventListener(document, 'touchmove', onResizeMove, { passive: false });
useEventListener(document, 'touchend', onResizeEnd);

const inboxes = useMapGetter('inboxes/getInboxes');
const teams = useMapGetter('teams/getMyTeams');
const contactCustomViews = useMapGetter('customViews/getContactCustomViews');
const conversationCustomViews = useMapGetter(
  'customViews/getConversationCustomViews'
);
const crmPipelines = ref([]);

const extractData = response => {
  const payload = response?.data ?? response;
  if (Array.isArray(payload)) return payload;
  return payload?.data ?? [];
};

const loadCrmPipelines = async () => {
  try {
    const response = await CrmAPI.getPipelines();
    crmPipelines.value = extractData(response);
  } catch {
    crmPipelines.value = [];
  }
};

onMounted(() => {
  store.dispatch('inboxes/get');
  store.dispatch('notifications/unReadCount');
  store.dispatch('teams/get');
  store.dispatch('attributes/get');
  store.dispatch('customViews/get', 'conversation');
  store.dispatch('customViews/get', 'contact');
  loadCrmPipelines();
  loadPinnedItems();
  loadCollapsedSections();
});

// Sem polling: a lista muda só quando um admin edita pipelines, e a tela de
// pipelines dispara `crm:pipelines:changed` para atualizar a sidebar.
useEventListener(window, 'crm:pipelines:changed', loadCrmPipelines);

const sortedInboxes = computed(() =>
  inboxes.value.slice().sort((a, b) => a.name.localeCompare(b.name))
);

const crmPipelineMenuItems = computed(() =>
  crmPipelines.value.map(pipeline => ({
    name: `Pipeline-${pipeline.id}`,
    label: pipeline.name,
    icon: 'i-lucide-git-branch',
    to: accountScopedRoute('crm_dashboard', {}, { pipeline_id: pipeline.id }),
  }))
);

const newReportRoutes = () => [
  {
    name: 'Reports Agent',
    label: t('SIDEBAR.REPORTS_AGENT'),
    to: accountScopedRoute('agent_reports_index'),
    activeOn: ['agent_reports_show'],
  },
  {
    name: 'Reports Label',
    label: t('SIDEBAR.REPORTS_LABEL'),
    to: accountScopedRoute('label_reports_index'),
  },
  {
    name: 'Reports Inbox',
    label: t('SIDEBAR.REPORTS_INBOX'),
    to: accountScopedRoute('inbox_reports_index'),
    activeOn: ['inbox_reports_show'],
  },
  {
    name: 'Reports Team',
    label: t('SIDEBAR.REPORTS_TEAM'),
    to: accountScopedRoute('team_reports_index'),
    activeOn: ['team_reports_show'],
  },
];

const reportRoutes = computed(() => newReportRoutes());

// ============================================================
// The 4 Collapsible Blocks Breakdown (Fase 1.2 UI/UX Master Plan)
// ============================================================

// Bloco 1: Principal (Inbox de Mensagens, Notificações, Conversas)
const mainMenuItems = computed(() => [
  {
    name: 'Inbox',
    label: t('SIDEBAR.INBOX'),
    icon: 'i-lucide-inbox',
    to: accountScopedRoute('inbox_view'),
    activeOn: ['inbox_view', 'inbox_view_conversation'],
    getterKeys: {
      count: 'notifications/getUnreadCount',
    },
  },
  {
    name: 'Notifications',
    label: t('SIDEBAR.NOTIFICATIONS'),
    icon: 'i-lucide-bell',
    to: accountScopedRoute('notifications_index'),
    activeOn: ['notifications_index'],
    getterKeys: {
      count: 'notifications/getUnreadCount',
    },
  },
  {
    name: 'Conversation',
    label: t('SIDEBAR.CONVERSATIONS'),
    icon: 'i-lucide-message-circle',
    children: [
      {
        name: 'All',
        label: t('SIDEBAR.ALL_CONVERSATIONS'),
        activeOn: ['inbox_conversation'],
        to: accountScopedRoute('home'),
      },
      {
        name: 'Mentions',
        label: t('SIDEBAR.MENTIONED_CONVERSATIONS'),
        activeOn: ['conversation_through_mentions'],
        to: accountScopedRoute('conversation_mentions'),
      },
      {
        name: 'Unattended',
        activeOn: ['conversation_through_unattended'],
        label: t('SIDEBAR.UNATTENDED_CONVERSATIONS'),
        to: accountScopedRoute('conversation_unattended'),
      },
      {
        name: 'Folders',
        label: t('SIDEBAR.CUSTOM_VIEWS_FOLDER'),
        icon: 'i-lucide-folder',
        activeOn: ['conversations_through_folders'],
        children: conversationCustomViews.value.map(view => ({
          name: `${view.name}-${view.id}`,
          label: view.name,
          to: accountScopedRoute('folder_conversations', { id: view.id }),
        })),
      },
      {
        name: 'Teams',
        label: t('SIDEBAR.TEAMS'),
        icon: 'i-lucide-users',
        activeOn: ['conversations_through_team'],
        children: teams.value.map(team => ({
          name: `${team.name}-${team.id}`,
          label: team.name,
          to: accountScopedRoute('team_conversations', { teamId: team.id }),
        })),
      },
      {
        name: 'Channels',
        label: t('SIDEBAR.CHANNELS'),
        icon: 'i-lucide-mailbox',
        activeOn: ['conversation_through_inbox'],
        children: sortedInboxes.value.map(inbox => ({
          name: `${inbox.name}-${inbox.id}`,
          label: inbox.name,
          icon: h(ChannelIcon, { inbox, class: 'size-[16px]' }),
          to: accountScopedRoute('inbox_dashboard', { inbox_id: inbox.id }),
          component: leafProps =>
            h(ChannelLeaf, {
              label: leafProps.label,
              active: leafProps.active,
              inbox,
            }),
        })),
      },
    ],
  },
]);

// Bloco 2: Vendas & CRM (Funis de Negócios, Contatos & Empresas, Atividades, Cadências)
const salesCrmMenuItems = computed(() => [
  {
    name: 'CRM',
    label: t('SIDEBAR.CRM'),
    icon: 'i-lucide-kanban-square',
    activeOn: [
      'crm_dashboard',
      'crm_all_leads',
      'crm_activities',
      'crm_agenda',
      'crm_reports',
      'crm_pipeline_settings',
      'crm_loss_reasons',
      'crm_checklist_templates',
      'crm_automation_rules',
      'crm_cadences',
      'crm_scoring_config',
    ],
    children: [
      {
        name: 'Pipeline',
        label: t('SIDEBAR.ALL_PIPELINES'),
        icon: 'i-lucide-columns',
        activeOn: ['crm_dashboard'],
        children: crmPipelineMenuItems.value,
      },
      {
        name: 'AllLeads',
        label: t('SIDEBAR.ALL_LEADS'),
        icon: 'i-lucide-list-filter',
        activeOn: ['crm_all_leads', 'crm_deal_details'],
        to: accountScopedRoute('crm_all_leads', {}, { page: 1 }),
      },
      {
        name: 'Activities',
        label: t('SIDEBAR.ACTIVITIES'),
        icon: 'i-lucide-calendar-check',
        activeOn: ['crm_activities'],
        to: accountScopedRoute('crm_activities'),
      },
      {
        name: 'Agenda',
        label: t('SIDEBAR.AGENDA'),
        icon: 'i-lucide-calendar-days',
        activeOn: ['crm_agenda'],
        to: accountScopedRoute('crm_agenda'),
      },
      {
        name: 'ScoringConfig',
        label: t('SIDEBAR.SCORING'),
        icon: 'i-lucide-sliders-horizontal',
        activeOn: ['crm_scoring_config'],
        to: accountScopedRoute('crm_scoring_config'),
      },
      {
        name: 'Checklists',
        label: t('SIDEBAR.CHECKLISTS'),
        icon: 'i-lucide-list-checks',
        activeOn: ['crm_checklist_templates', 'crm_loss_reasons'],
        to: accountScopedRoute('crm_checklist_templates'),
      },
      {
        name: 'PipelineSettings',
        label: t('SIDEBAR.PIPELINE_SETTINGS'),
        icon: 'i-lucide-settings-2',
        activeOn: ['crm_pipeline_settings'],
        to: accountScopedRoute('crm_pipeline_settings'),
      },
    ],
  },
  {
    name: 'Contacts',
    label: t('SIDEBAR.CONTACTS'),
    icon: 'i-lucide-contact',
    children: [
      {
        name: 'All Contacts',
        label: t('SIDEBAR.ALL_CONTACTS'),
        icon: 'i-lucide-users',
        to: accountScopedRoute(
          'contacts_dashboard_index',
          {},
          { page: 1, search: undefined }
        ),
        activeOn: ['contacts_dashboard_index', 'contacts_edit'],
      },
      {
        name: 'Contact Categories',
        label: t('SIDEBAR.CONTACT_CATEGORIES'),
        icon: 'i-lucide-tags',
        to: accountScopedRoute('contacts_dashboard_categories'),
        activeOn: [
          'contacts_dashboard_categories',
          'contacts_dashboard_category_kind',
          'contacts_dashboard_category_detail',
        ],
      },
      {
        name: 'Contact List',
        label: t('SIDEBAR.CONTACT_LIST'),
        icon: 'i-lucide-table-2',
        to: accountScopedRoute(
          'contacts_dashboard_list',
          {},
          { page: 1, search: undefined }
        ),
        activeOn: ['contacts_dashboard_list'],
      },
      {
        name: 'Segments',
        icon: 'i-lucide-group',
        label: t('SIDEBAR.CUSTOM_VIEWS_SEGMENTS'),
        children: contactCustomViews.value.map(view => ({
          name: `${view.name}-${view.id}`,
          label: view.name,
          to: accountScopedRoute(
            'contacts_dashboard_segments_index',
            { segmentId: view.id },
            { page: 1 }
          ),
          activeOn: [
            'contacts_dashboard_segments_index',
            'contacts_edit_segment',
          ],
        })),
      },
    ],
  },
  {
    name: 'Companies',
    label: t('SIDEBAR.COMPANIES'),
    icon: 'i-lucide-building-2',
    children: [
      {
        name: 'All Companies',
        label: t('SIDEBAR.ALL_COMPANIES'),
        to: accountScopedRoute(
          'companies_dashboard_index',
          {},
          { page: 1, search: undefined }
        ),
        activeOn: ['companies_dashboard_index'],
      },
    ],
  },
  {
    name: 'Cadencias',
    label: t('SIDEBAR.CADENCES'),
    icon: 'i-lucide-send',
    activeOn: ['crm_cadences'],
    to: accountScopedRoute('crm_cadences'),
  },
  ...(hasMarketing.value
    ? [
        {
          name: 'Marketing',
          label: t('SIDEBAR.MARKETING'),
          icon: 'i-lucide-megaphone',
          activeOn: [
            'marketing_overview',
            'marketing_campaigns',
            'marketing_leads',
            'marketing_insights',
            'marketing_events',
            'marketing_connections',
          ],
          children: [
            {
              name: 'MarketingOverview',
              label: t('MARKETING.OVERVIEW.TITLE'),
              icon: 'i-lucide-bar-chart-3',
              activeOn: ['marketing_overview'],
              to: accountScopedRoute('marketing_overview'),
            },
            {
              name: 'MarketingCampaigns',
              label: t('MARKETING.CAMPAIGNS.TITLE'),
              icon: 'i-lucide-target',
              activeOn: ['marketing_campaigns'],
              to: accountScopedRoute('marketing_campaigns'),
            },
            {
              name: 'MarketingLeads',
              label: t('MARKETING.LEADS.TITLE'),
              icon: 'i-lucide-user-plus',
              activeOn: ['marketing_leads'],
              to: accountScopedRoute('marketing_leads'),
            },
            {
              name: 'MarketingInsights',
              label: t('MARKETING.INSIGHTS.TITLE'),
              icon: 'i-lucide-sparkles',
              activeOn: ['marketing_insights'],
              to: accountScopedRoute('marketing_insights'),
            },
            {
              name: 'MarketingConnections',
              label: t('MARKETING.CONNECTIONS.TITLE'),
              icon: 'i-lucide-plug',
              activeOn: ['marketing_connections', 'marketing_events'],
              to: accountScopedRoute('marketing_connections'),
            },
          ],
        },
      ]
    : []),
]);

// Bloco 3: Automação & IA (Central Captain AI, Campanhas, Automações)
const automationAiMenuItems = computed(() => [
  {
    name: 'Captain',
    icon: 'i-woot-captain',
    label: t('SIDEBAR.CAPTAIN'),
    activeOn: ['captain_assistants_create_index'],
    children: [
      {
        name: 'My AI Agents',
        label: t('SIDEBAR.AI_AGENTS'),
        icon: 'i-lucide-users-round',
        activeOn: [
          'captain_assistants_settings_index',
          'captain_assistants_guidelines_index',
          'captain_assistants_guardrails_index',
          'captain_assistants_create_index',
        ],
        to: accountScopedRoute('captain_assistants_index', {
          navigationPath: 'captain_assistants_settings_index',
        }),
      },
      {
        name: 'AgentConfig',
        label: t('SIDEBAR.CAPTAIN_AGENT_PANEL'),
        icon: 'i-lucide-sliders-horizontal',
        activeOn: ['captain_agent_configs_index'],
        to: accountScopedRoute('captain_assistants_index', {
          navigationPath: 'captain_agent_configs_index',
        }),
      },
      {
        name: 'FAQs',
        label: t('SIDEBAR.CAPTAIN_RESPONSES'),
        activeOn: [
          'captain_assistants_responses_index',
          'captain_assistants_responses_pending',
        ],
        to: accountScopedRoute('captain_assistants_index', {
          navigationPath: 'captain_assistants_responses_index',
        }),
      },
      {
        name: 'Documents',
        label: t('SIDEBAR.CAPTAIN_DOCUMENTS'),
        activeOn: ['captain_assistants_documents_index'],
        to: accountScopedRoute('captain_assistants_index', {
          navigationPath: 'captain_assistants_documents_index',
        }),
      },
      {
        name: 'Scenarios',
        label: t('SIDEBAR.CAPTAIN_SCENARIOS'),
        activeOn: ['captain_assistants_scenarios_index'],
        to: accountScopedRoute('captain_assistants_index', {
          navigationPath: 'captain_assistants_scenarios_index',
        }),
      },
      {
        name: 'Playground',
        label: t('SIDEBAR.CAPTAIN_PLAYGROUND'),
        activeOn: ['captain_assistants_playground_index'],
        to: accountScopedRoute('captain_assistants_index', {
          navigationPath: 'captain_assistants_playground_index',
        }),
      },
      {
        name: 'Inboxes',
        label: t('SIDEBAR.CAPTAIN_INBOXES'),
        activeOn: ['captain_assistants_inboxes_index'],
        to: accountScopedRoute('captain_assistants_index', {
          navigationPath: 'captain_assistants_inboxes_index',
        }),
      },
      {
        name: 'Score',
        label: t('SIDEBAR.CAPTAIN_SCORE'),
        activeOn: ['captain_score_settings_index'],
        to: accountScopedRoute('captain_assistants_index', {
          navigationPath: 'captain_score_settings_index',
        }),
      },
      {
        name: 'Tools',
        label: t('SIDEBAR.CAPTAIN_TOOLS'),
        activeOn: ['captain_tools_index'],
        to: accountScopedRoute('captain_assistants_index', {
          navigationPath: 'captain_tools_index',
        }),
      },
      {
        name: 'Settings',
        label: t('SIDEBAR.CAPTAIN_SETTINGS'),
        activeOn: [
          'captain_assistants_settings_index',
          'captain_assistants_guidelines_index',
          'captain_assistants_guardrails_index',
        ],
        to: accountScopedRoute('captain_assistants_index', {
          navigationPath: 'captain_assistants_settings_index',
        }),
      },
    ],
  },
  {
    name: 'Campaigns',
    label: t('SIDEBAR.CAMPAIGNS'),
    icon: 'i-lucide-megaphone',
    children: [
      {
        name: 'Live chat',
        label: t('SIDEBAR.LIVE_CHAT'),
        to: accountScopedRoute('campaigns_livechat_index'),
      },
      {
        name: 'SMS',
        label: t('SIDEBAR.SMS'),
        to: accountScopedRoute('campaigns_sms_index'),
      },
      {
        name: 'Email',
        label: t('SIDEBAR.EMAIL'),
        to: accountScopedRoute('campaigns_email_index'),
      },
      {
        name: 'WhatsApp',
        label: t('SIDEBAR.WHATSAPP'),
        to: accountScopedRoute('campaigns_whatsapp_index'),
      },
    ],
  },
  {
    name: 'Automation',
    label: t('SIDEBAR.AUTOMATION'),
    icon: 'i-lucide-zap',
    children: [
      {
        name: 'CRM Automation',
        label: t('SIDEBAR.CRM_AUTOMATION'),
        icon: 'i-lucide-zap',
        activeOn: ['crm_automation_rules'],
        to: accountScopedRoute('crm_automation_rules'),
      },
      {
        name: 'Chatwoot Automation',
        label: t('SIDEBAR.AUTOMATION'),
        icon: 'i-lucide-repeat',
        activeOn: ['automation_list'],
        to: accountScopedRoute('automation_list'),
      },
      {
        name: 'Macros',
        label: t('SIDEBAR.MACROS'),
        icon: 'i-lucide-toy-brick',
        activeOn: ['macros_wrapper'],
        to: accountScopedRoute('macros_wrapper'),
      },
      {
        name: 'Conversation Workflow',
        label: t('SIDEBAR.CONVERSATION_WORKFLOW'),
        icon: 'i-lucide-workflow',
        activeOn: ['conversation_workflow_index'],
        to: accountScopedRoute('conversation_workflow_index'),
      },
    ],
  },
]);

// Bloco 4: Gestão (Relatórios & BI, Configurações do Sistema, Portais)
const managementMenuItems = computed(() => [
  {
    name: 'Reports',
    label: t('SIDEBAR.REPORTS'),
    icon: 'i-lucide-chart-spline',
    children: [
      {
        name: 'Report Overview',
        label: t('SIDEBAR.REPORTS_OVERVIEW'),
        to: accountScopedRoute('account_overview_reports'),
      },
      {
        name: 'CRM Reports',
        label: t('SIDEBAR.CRM_REPORTS'),
        icon: 'i-lucide-bar-chart-2',
        activeOn: ['crm_reports'],
        to: accountScopedRoute('crm_reports'),
      },
      {
        name: 'Report Conversation',
        label: t('SIDEBAR.REPORTS_CONVERSATION'),
        to: accountScopedRoute('conversation_reports'),
      },
      ...reportRoutes.value,
      {
        name: 'Reports CSAT',
        label: t('SIDEBAR.CSAT'),
        to: accountScopedRoute('csat_reports'),
      },
      {
        name: 'Reports SLA',
        label: t('SIDEBAR.REPORTS_SLA'),
        to: accountScopedRoute('sla_reports'),
      },
      {
        name: 'Reports Bot',
        label: t('SIDEBAR.REPORTS_BOT'),
        to: accountScopedRoute('bot_reports'),
      },
    ],
  },
  {
    name: 'Settings',
    label: t('SIDEBAR.SETTINGS'),
    icon: 'i-lucide-bolt',
    children: [
      {
        name: 'Settings Account Settings',
        label: t('SIDEBAR.ACCOUNT_SETTINGS'),
        icon: 'i-lucide-briefcase',
        to: accountScopedRoute('general_settings_index'),
      },
      {
        name: 'Settings Agents',
        label: t('SIDEBAR.AGENTS'),
        icon: 'i-lucide-square-user',
        to: accountScopedRoute('agent_list'),
      },
      {
        name: 'Settings Teams',
        label: t('SIDEBAR.TEAMS'),
        icon: 'i-lucide-users',
        activeOn: [
          'settings_teams_list',
          'settings_teams_new',
          'settings_teams_finish',
          'settings_teams_add_agents',
          'settings_teams_show',
          'settings_teams_edit',
          'settings_teams_edit_members',
          'settings_teams_edit_finish',
        ],
        to: accountScopedRoute('settings_teams_list'),
      },
      ...(hasAdvancedAssignment.value
        ? [
            {
              name: 'Settings Agent Assignment',
              label: t('SIDEBAR.AGENT_ASSIGNMENT'),
              icon: 'i-lucide-user-cog',
              activeOn: [
                'assignment_policy_index',
                'agent_assignment_policy_index',
                'agent_assignment_policy_create',
                'agent_assignment_policy_edit',
                'agent_capacity_policy_index',
                'agent_capacity_policy_create',
                'agent_capacity_policy_edit',
              ],
              to: accountScopedRoute('assignment_policy_index'),
            },
          ]
        : []),
      {
        name: 'Settings Inboxes',
        label: t('SIDEBAR.INBOXES'),
        icon: 'i-lucide-inbox',
        activeOn: [
          'settings_inbox_list',
          'settings_inbox_show',
          'settings_inbox_new',
          'settings_inbox_finish',
          'settings_inboxes_page_channel',
          'settings_inboxes_add_agents',
        ],
        to: accountScopedRoute('settings_inbox_list'),
      },
      {
        name: 'Settings Evolution API',
        label: t('SIDEBAR.EVOLUTION_API'),
        icon: 'i-lucide-message-circle',
        activeOn: ['settings_evolution_index'],
        to: accountScopedRoute('settings_evolution_index'),
      },
      {
        name: 'Settings Labels',
        label: t('SIDEBAR.LABELS'),
        icon: 'i-lucide-tags',
        to: accountScopedRoute('labels_list'),
      },
      {
        name: 'Settings Custom Attributes',
        label: t('SIDEBAR.CUSTOM_ATTRIBUTES'),
        icon: 'i-lucide-code',
        to: accountScopedRoute('attributes_list'),
      },
      {
        name: 'Settings Automation',
        label: t('SIDEBAR.AUTOMATION'),
        icon: 'i-lucide-repeat',
        to: accountScopedRoute('automation_list'),
      },
      {
        name: 'Settings Agent Bots',
        label: t('SIDEBAR.AGENT_BOTS'),
        icon: 'i-lucide-bot',
        to: accountScopedRoute('agent_bots'),
      },
      {
        name: 'Settings Macros',
        label: t('SIDEBAR.MACROS'),
        icon: 'i-lucide-toy-brick',
        to: accountScopedRoute('macros_wrapper'),
      },
      {
        name: 'Settings Canned Responses',
        label: t('SIDEBAR.CANNED_RESPONSES'),
        icon: 'i-lucide-message-square-quote',
        to: accountScopedRoute('canned_list'),
      },
      {
        name: 'Settings Integrations',
        label: t('SIDEBAR.INTEGRATIONS'),
        icon: 'i-lucide-blocks',
        to: accountScopedRoute('settings_applications'),
      },
      {
        name: 'Settings Audit Logs',
        label: t('SIDEBAR.AUDIT_LOGS'),
        icon: 'i-lucide-briefcase',
        to: accountScopedRoute('auditlogs_list'),
      },
      {
        name: 'Settings Custom Roles',
        label: t('SIDEBAR.CUSTOM_ROLES'),
        icon: 'i-lucide-shield-plus',
        to: accountScopedRoute('custom_roles_list'),
      },
      {
        name: 'Settings Sla',
        label: t('SIDEBAR.SLA'),
        icon: 'i-lucide-clock-alert',
        to: accountScopedRoute('sla_list'),
      },
      {
        name: 'Conversation Workflow',
        label: t('SIDEBAR.CONVERSATION_WORKFLOW'),
        icon: 'i-lucide-workflow',
        to: accountScopedRoute('conversation_workflow_index'),
      },
      {
        name: 'Settings Security',
        label: t('SIDEBAR.SECURITY'),
        icon: 'i-lucide-shield',
        to: accountScopedRoute('security_settings_index'),
      },
      {
        name: 'Settings Billing',
        label: t('SIDEBAR.BILLING'),
        icon: 'i-lucide-credit-card',
        to: accountScopedRoute('billing_settings_index'),
      },
    ],
  },
  {
    name: 'Portals',
    label: t('SIDEBAR.HELP_CENTER.TITLE'),
    icon: 'i-lucide-library-big',
    children: [
      {
        name: 'Articles',
        label: t('SIDEBAR.HELP_CENTER.ARTICLES'),
        activeOn: [
          'portals_articles_index',
          'portals_articles_new',
          'portals_articles_edit',
        ],
        to: accountScopedRoute('portals_index', {
          navigationPath: 'portals_articles_index',
        }),
      },
      {
        name: 'Categories',
        label: t('SIDEBAR.HELP_CENTER.CATEGORIES'),
        activeOn: [
          'portals_categories_index',
          'portals_categories_articles_index',
          'portals_categories_articles_edit',
        ],
        to: accountScopedRoute('portals_index', {
          navigationPath: 'portals_categories_index',
        }),
      },
      {
        name: 'Locales',
        label: t('SIDEBAR.HELP_CENTER.LOCALES'),
        activeOn: ['portals_locales_index'],
        to: accountScopedRoute('portals_index', {
          navigationPath: 'portals_locales_index',
        }),
      },
      {
        name: 'Settings',
        label: t('SIDEBAR.HELP_CENTER.SETTINGS'),
        activeOn: ['portals_settings_index'],
        to: accountScopedRoute('portals_index', {
          navigationPath: 'portals_settings_index',
        }),
      },
    ],
  },
]);

// Four Section Blocks definition
const sectionBlocks = computed(() => [
  {
    id: 'main',
    label: t('SIDEBAR.SECTION_MAIN'),
    items: mainMenuItems.value,
  },
  {
    id: 'sales_crm',
    label: t('SIDEBAR.SECTION_SALES_CRM'),
    items: salesCrmMenuItems.value,
  },
  {
    id: 'automation_ai',
    label: t('SIDEBAR.SECTION_AUTOMATION_AI'),
    items: automationAiMenuItems.value,
  },
  {
    id: 'management',
    label: t('SIDEBAR.SECTION_MANAGEMENT'),
    items: managementMenuItems.value,
  },
]);

// Check if a pinned item is currently active
const isPinnedItemActive = fav => {
  if (!fav?.to) return false;
  try {
    const resolved = router.resolve(fav.to);
    if (resolved?.path && route.path === resolved.path) return true;
  } catch {
    return false;
  }
  if (fav.activeOn?.includes(route.name)) return true;
  return false;
};

// Auto-expand section if active route belongs to it
const autoExpandActiveSection = () => {
  sectionBlocks.value.forEach(sec => {
    const hasActive = sec.items.some(item => {
      if (item.activeOn?.includes(route.name)) return true;
      if (item.to) {
        try {
          if (router.resolve(item.to)?.path === route.path) return true;
        } catch {
          // ignore route resolution error
        }
      }
      if (item.children) {
        const checkChildren = list =>
          list.some(child => {
            if (child.activeOn?.includes(route.name)) return true;
            if (child.to) {
              try {
                if (router.resolve(child.to)?.path === route.path) return true;
              } catch {
                // ignore route resolution error
              }
            }
            if (child.children) return checkChildren(child.children);
            return false;
          });
        return checkChildren(item.children);
      }
      return false;
    });

    if (hasActive && collapsedSections.value[sec.id]) {
      collapsedSections.value[sec.id] = false;
      saveCollapsedSections();
    }
  });
};

watch(
  () => route.fullPath,
  () => {
    autoExpandActiveSection();
  },
  { immediate: true }
);
</script>

<template>
  <button
    v-if="isMobileSidebarOpen"
    type="button"
    class="fixed inset-0 z-30 hidden bg-ds-shell-canvas/60 backdrop-blur-sm max-md:block"
    :aria-label="t('HELP_CENTER.EDIT_HEADER.CLOSE_SIDEBAR')"
    @click="emit('closeMobileSidebar')"
  />
  <aside
    class="fixed top-0 z-40 flex h-full w-[min(88vw,288px)] flex-col bg-ds-shell-canvas/95 pb-px font-inter text-sm text-ds-shell-fg backdrop-blur-xl ltr:left-0 rtl:right-0 md:relative md:w-auto md:flex-shrink-0 md:bg-ds-shell-canvas md:backdrop-blur-none md:ltr:translate-x-0 md:rtl:translate-x-0"
    :class="[
      {
        'shadow-2xl shadow-black/30 md:shadow-none': isMobileSidebarOpen,
        'ltr:-translate-x-full rtl:translate-x-full': !isMobileSidebarOpen,
        'transition-transform duration-200 ease-out md:transition-[width]':
          !isResizing,
      },
    ]"
    :style="isMobile ? undefined : { width: `${sidebarWidth}px` }"
  >
    <!-- Sidebar Header & Account Switcher -->
    <section
      class="grid"
      :class="isEffectivelyCollapsed ? 'mb-4 mt-3 gap-3' : 'mb-4 mt-4 gap-3'"
    >
      <div
        class="flex min-w-0 items-center gap-2.5"
        :class="{
          'justify-center px-1': isEffectivelyCollapsed,
          'px-3': !isEffectivelyCollapsed,
        }"
      >
        <template v-if="isEffectivelyCollapsed">
          <SidebarAccountSwitcher
            is-collapsed
            @show-create-account-modal="emit('showCreateAccountModal')"
          />
        </template>
        <template v-else>
          <div
            class="grid size-10 flex-shrink-0 place-content-center rounded-2xl bg-gradient-to-br from-ds-shell-accent/25 via-ds-shell-panel-strong to-ds-shell-panel shadow-lg shadow-black/20 ring-1 ring-inset ring-ds-shell-accent/25"
          >
            <Logo class="size-6" />
          </div>
          <div class="min-w-0 flex-1">
            <p
              class="m-0 truncate font-manrope text-[0.95rem] font-bold leading-5 tracking-[-0.02em] text-ds-shell-fg"
            >
              {{ productName }}
            </p>
            <p
              class="m-0 truncate text-[0.6rem] font-semibold uppercase leading-4 tracking-[0.16em] text-ds-shell-muted"
            >
              {{ t('SIDEBAR.PRODUCT_SCOPE') }}
            </p>
          </div>
          <button
            type="button"
            class="flex size-10 flex-shrink-0 items-center justify-center rounded-xl bg-ds-shell-panel text-ds-shell-muted ring-1 ring-inset ring-ds-shell-border transition duration-150 hover:bg-ds-shell-hover hover:text-ds-shell-fg hover:ring-ds-shell-accent/50 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-shell-focus"
            :title="headerActionLabel"
            :aria-label="headerActionLabel"
            @click="handleHeaderAction"
          >
            <span :class="headerActionIcon" class="size-4" aria-hidden="true" />
          </button>
        </template>
      </div>
      <div v-if="!isEffectivelyCollapsed" class="px-3">
        <SidebarAccountSwitcher
          class="min-w-0"
          @show-create-account-modal="emit('showCreateAccountModal')"
        />
      </div>
      <!-- Search & Collapse Controls -->
      <div
        class="flex gap-2"
        :class="isEffectivelyCollapsed ? 'flex-col items-center px-1' : 'px-3'"
      >
        <button
          v-if="!isEffectivelyCollapsed"
          type="button"
          class="flex min-h-10 w-full cursor-pointer items-center gap-2.5 rounded-xl bg-ds-shell-panel px-3 py-1.5 text-ds-shell-fg shadow-sm shadow-black/5 transition duration-150 ease-out hover:bg-ds-shell-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-shell-focus"
          :aria-label="t('COMBOBOX.SEARCH_PLACEHOLDER')"
          @click="openCommandPalette"
        >
          <span
            class="i-lucide-search size-4 flex-shrink-0 text-ds-shell-muted"
            aria-hidden="true"
          />
          <span
            class="flex-grow text-start text-[0.82rem] font-medium text-ds-shell-muted"
          >
            {{ t('COMBOBOX.SEARCH_PLACEHOLDER') }}
          </span>
          <kbd
            class="hidden rounded-md bg-ds-shell-hover px-1.5 py-0.5 text-[0.62rem] font-semibold text-ds-shell-muted min-[1120px]:inline"
          >
            {{ commandShortcut }}
          </kbd>
        </button>
        <DsTooltip
          v-else
          :text="t('COMBOBOX.SEARCH_PLACEHOLDER')"
          placement="right"
        >
          <button
            type="button"
            class="flex size-11 items-center justify-center rounded-xl bg-ds-shell-panel text-ds-shell-muted ring-1 ring-inset ring-ds-shell-border transition duration-150 ease-out hover:bg-ds-shell-hover hover:text-ds-shell-fg hover:ring-ds-shell-accent/40 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-shell-focus cursor-pointer"
            :title="t('COMBOBOX.SEARCH_PLACEHOLDER')"
            :aria-label="t('COMBOBOX.SEARCH_PLACEHOLDER')"
            @click="openCommandPalette"
          >
            <span class="i-lucide-search size-5" aria-hidden="true" />
          </button>
        </DsTooltip>
        <DsTooltip
          v-if="isEffectivelyCollapsed"
          :text="collapseToggleLabel"
          placement="right"
        >
          <button
            type="button"
            class="flex size-11 items-center justify-center rounded-xl bg-ds-shell-panel text-ds-shell-muted ring-1 ring-inset ring-ds-shell-border transition duration-150 hover:bg-ds-shell-hover hover:text-ds-shell-fg hover:ring-ds-shell-accent/50 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-shell-focus"
            :title="collapseToggleLabel"
            :aria-label="collapseToggleLabel"
            @click="toggleSidebarCollapsed"
          >
            <span :class="collapseToggleIcon" class="size-4" />
          </button>
        </DsTooltip>
      </div>
    </section>

    <!-- Navigation Area -->
    <nav
      class="grid min-w-0 flex-grow content-start gap-2 overflow-y-auto pb-6 no-scrollbar"
      :aria-label="productName"
      :class="isEffectivelyCollapsed ? 'px-1' : 'px-3'"
    >
      <!-- Pinned Favorites Block (Expanded Mode) -->
      <div
        v-if="!isEffectivelyCollapsed && pinnedItems.length > 0"
        class="mb-2 flex flex-col gap-1 rounded-xl bg-ds-shell-panel/50 p-1.5 ring-1 ring-inset ring-ds-shell-border/40"
      >
        <div
          class="flex items-center justify-between px-2 py-1 text-[0.65rem] font-bold uppercase tracking-wider text-ds-shell-muted"
        >
          <div class="flex items-center gap-1.5">
            <span
              class="i-lucide-pin size-3 text-ds-shell-accent"
              aria-hidden="true"
            />
            <span>{{ t('SIDEBAR.SECTION_FAVORITES') }}</span>
          </div>
          <span
            class="rounded-full bg-ds-shell-panel-strong px-1.5 py-0.2 text-[0.6rem] font-bold text-ds-shell-accent"
          >
            {{ pinnedItems.length }}
          </span>
        </div>
        <ul class="m-0 flex min-w-0 list-none flex-col gap-0.5">
          <li
            v-for="fav in pinnedItems"
            :key="fav.id"
            class="group/fav flex min-h-8 items-center justify-between rounded-lg px-2.5 py-1 text-sm text-ds-shell-muted transition duration-150 hover:bg-ds-shell-hover hover:text-ds-shell-fg"
            :class="{
              'bg-ds-shell-active font-medium text-ds-shell-fg':
                isPinnedItemActive(fav),
            }"
          >
            <RouterLink
              :to="fav.to"
              class="flex min-w-0 flex-1 items-center gap-2 text-inherit no-underline"
            >
              <span
                :class="fav.icon || 'i-lucide-star'"
                class="size-3.5 flex-shrink-0 text-ds-shell-accent"
                aria-hidden="true"
              />
              <span class="truncate text-[0.8rem]">{{ fav.label }}</span>
            </RouterLink>
            <button
              type="button"
              class="hidden size-5 flex-shrink-0 items-center justify-center rounded text-ds-shell-muted opacity-60 hover:text-ds-shell-danger hover:opacity-100 group-hover/fav:flex"
              :title="t('SIDEBAR.UNPIN_FROM_FAVORITES')"
              :aria-label="t('SIDEBAR.UNPIN_FROM_FAVORITES')"
              @click.stop.prevent="unpin(fav.id)"
            >
              <span class="i-lucide-x size-3" aria-hidden="true" />
            </button>
          </li>
        </ul>
      </div>

      <!-- Pinned Favorites Block (Collapsed Mode) -->
      <div
        v-else-if="isEffectivelyCollapsed && pinnedItems.length > 0"
        class="flex flex-col items-center gap-1 py-0.5"
      >
        <DsTooltip
          v-for="fav in pinnedItems"
          :key="fav.id"
          :text="fav.label"
          placement="right"
        >
          <RouterLink
            :to="fav.to"
            class="flex size-11 items-center justify-center rounded-xl text-ds-shell-accent transition-colors duration-150 hover:bg-ds-shell-hover hover:text-ds-shell-fg focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-shell-focus"
            :class="{
              'bg-ds-shell-active text-ds-shell-fg': isPinnedItemActive(fav),
            }"
            :title="fav.label"
            :aria-label="fav.label"
          >
            <span
              :class="fav.icon || 'i-lucide-star'"
              class="size-5"
              aria-hidden="true"
            />
          </RouterLink>
        </DsTooltip>
        <div class="my-1 h-px w-6 bg-ds-shell-border opacity-50" />
      </div>

      <!-- The 4 Collapsible Blocks (Expanded Mode) -->
      <template v-if="!isEffectivelyCollapsed">
        <section
          v-for="(block, bIndex) in sectionBlocks"
          :key="block.id"
          class="flex flex-col gap-1"
        >
          <!-- Section Divider (between blocks) -->
          <div
            v-if="bIndex > 0"
            class="my-1.5 h-px bg-ds-shell-border/40 mx-2"
          />
          <!-- Section Header / Collapse Toggle -->
          <button
            type="button"
            class="group/section-btn flex w-full items-center justify-between rounded-lg px-2.5 py-1.5 text-start transition duration-150 hover:bg-ds-shell-hover/50 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-shell-focus"
            :aria-expanded="isSectionOpen(block.id)"
            @click="toggleSection(block.id)"
          >
            <span
              class="font-manrope text-[0.65rem] font-bold uppercase tracking-[0.11em] text-ds-shell-muted transition group-hover/section-btn:text-ds-shell-fg"
            >
              {{ block.label }}
            </span>
            <span
              class="size-3.5 text-ds-shell-muted opacity-60 transition group-hover/section-btn:opacity-100"
              :class="
                isSectionOpen(block.id)
                  ? 'i-lucide-chevron-down'
                  : 'i-lucide-chevron-right'
              "
              aria-hidden="true"
            />
          </button>
          <!-- Section Items -->
          <ul
            v-show="isSectionOpen(block.id)"
            class="m-0 flex min-w-0 list-none flex-col gap-0.5"
          >
            <SidebarGroup
              v-for="item in block.items"
              :key="item.name"
              v-bind="item"
            />
          </ul>
        </section>
      </template>

      <!-- The 4 Blocks (Collapsed Mode) -->
      <template v-else>
        <div
          v-for="(block, bIndex) in sectionBlocks"
          :key="block.id"
          class="flex flex-col items-center gap-1"
        >
          <div
            v-if="bIndex > 0"
            class="my-1.5 h-px w-6 bg-ds-shell-border opacity-40"
          />
          <ul class="m-0 flex min-w-0 list-none flex-col items-center gap-1">
            <SidebarGroup
              v-for="item in block.items"
              :key="item.name"
              v-bind="item"
            />
          </ul>
        </div>
      </template>
    </nav>

    <!-- Sidebar Footer -->
    <section
      class="relative flex flex-shrink-0 flex-col items-center justify-between gap-1"
    >
      <div
        class="pointer-events-none absolute inset-x-0 -top-8 h-8 bg-gradient-to-t from-ds-shell-canvas to-transparent"
      />
      <SidebarChangelogCard
        v-if="
          isOnChusteRMCloud &&
          !isACustomBrandedInstance &&
          !isEffectivelyCollapsed
        "
      />
      <SidebarChangelogButton
        v-if="
          isOnChusteRMCloud &&
          !isACustomBrandedInstance &&
          isEffectivelyCollapsed
        "
      />
      <div
        class="z-50 flex w-full flex-shrink-0 items-center gap-2 bg-ds-shell-canvas px-2 py-2.5"
        :class="isEffectivelyCollapsed ? 'justify-center' : 'justify-between'"
      >
        <SidebarProfileMenu
          :is-collapsed="isEffectivelyCollapsed"
          @open-key-shortcut-modal="emit('openKeyShortcutModal')"
        />
      </div>
    </section>

    <!-- Resize Handle (desktop only) -->
    <div
      class="group absolute top-0 z-40 hidden h-full w-2 cursor-col-resize focus-visible:outline-none md:block ltr:right-0 rtl:left-0"
      role="separator"
      aria-orientation="vertical"
      tabindex="0"
      :aria-valuemin="MIN_WIDTH"
      :aria-valuemax="MAX_WIDTH"
      :aria-valuenow="Math.round(sidebarWidth)"
      @mousedown="onResizeStart"
      @touchstart="onResizeStart"
      @dblclick="onResizeHandleDoubleClick"
      @keydown="onResizeHandleKeydown"
    >
      <div
        class="absolute top-0 h-full w-px bg-transparent transition-colors group-hover:bg-ds-shell-accent/35 group-focus-visible:bg-ds-shell-focus ltr:right-0 rtl:left-0"
        :class="{ 'bg-ds-shell-accent/55': isResizing }"
      />
    </div>
  </aside>
</template>
