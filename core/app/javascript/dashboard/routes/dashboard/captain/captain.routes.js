import { INSTALLATION_TYPES } from 'dashboard/constants/installationTypes';
import { frontendURL } from '../../../helper/URLHelper';

import CaptainPageRouteView from './pages/CaptainPageRouteView.vue';
import AssistantsIndexPage from './pages/AssistantsIndexPage.vue';
import AssistantEmptyStateIndex from './assistants/Index.vue';

import AssistantSettingsIndex from './assistants/settings/Settings.vue';
import AssistantInboxesIndex from './assistants/inboxes/Index.vue';
import AssistantPlaygroundIndex from './assistants/playground/Index.vue';
import AssistantGuardrailsIndex from './assistants/guardrails/Index.vue';
import AssistantGuidelinesIndex from './assistants/guidelines/Index.vue';
import AssistantScenariosIndex from './assistants/scenarios/Index.vue';
import DocumentsIndex from './documents/Index.vue';
import ResponsesIndex from './responses/Index.vue';
import ResponsesPendingIndex from './responses/Pending.vue';
import CustomToolsIndex from './tools/Index.vue';
import ScoreSettingsIndex from './score/Index.vue';
import AgentConfigIndex from './config/Index.vue';
import FlowsIndex from './flows/Index.vue';
import FlowEditor from './flows/Editor.vue';

const meta = {
  permissions: ['administrator', 'agent', 'custom_role'],
  // Keep Captain menu/routes visible in self-hosted forks even when
  // account-level feature sync is stale in the frontend store.
  featureFlag: '',
  installationTypes: [
    INSTALLATION_TYPES.CLOUD,
    INSTALLATION_TYPES.ENTERPRISE,
    INSTALLATION_TYPES.COMMUNITY,
  ],
};

const metaV2 = {
  permissions: ['administrator', 'agent', 'custom_role'],
  featureFlag: '',
  installationTypes: [
    INSTALLATION_TYPES.CLOUD,
    INSTALLATION_TYPES.ENTERPRISE,
    INSTALLATION_TYPES.COMMUNITY,
  ],
};

const assistantRoutes = [
  {
    path: frontendURL('accounts/:accountId/captain/:assistantId/faqs'),
    component: ResponsesIndex,
    name: 'captain_assistants_responses_index',
    meta,
  },
  {
    path: frontendURL('accounts/:accountId/captain/:assistantId/documents'),
    component: DocumentsIndex,
    name: 'captain_assistants_documents_index',
    meta,
  },
  {
    path: frontendURL('accounts/:accountId/captain/:assistantId/tools'),
    component: CustomToolsIndex,
    name: 'captain_tools_index',
    meta: metaV2,
  },
  {
    path: frontendURL('accounts/:accountId/captain/:assistantId/scenarios'),
    component: AssistantScenariosIndex,
    name: 'captain_assistants_scenarios_index',
    meta: metaV2,
  },
  {
    path: frontendURL('accounts/:accountId/captain/:assistantId/playground'),
    component: AssistantPlaygroundIndex,
    name: 'captain_assistants_playground_index',
    meta,
  },
  {
    path: frontendURL('accounts/:accountId/captain/:assistantId/inboxes'),
    component: AssistantInboxesIndex,
    name: 'captain_assistants_inboxes_index',
    meta,
  },
  {
    path: frontendURL('accounts/:accountId/captain/:assistantId/score'),
    component: ScoreSettingsIndex,
    name: 'captain_score_settings_index',
    meta,
  },
  {
    path: frontendURL('accounts/:accountId/captain/:assistantId/config'),
    component: AgentConfigIndex,
    name: 'captain_agent_configs_index',
    meta,
  },
  {
    path: frontendURL('accounts/:accountId/captain/:assistantId/faqs/pending'),
    component: ResponsesPendingIndex,
    name: 'captain_assistants_responses_pending',
    meta,
  },
  {
    path: frontendURL('accounts/:accountId/captain/:assistantId/settings'),
    component: AssistantSettingsIndex,
    name: 'captain_assistants_settings_index',
    meta,
  },
  // Settings sub-pages (guardrails and guidelines)
  {
    path: frontendURL(
      'accounts/:accountId/captain/:assistantId/settings/guardrails'
    ),
    component: AssistantGuardrailsIndex,
    name: 'captain_assistants_guardrails_index',
    meta: metaV2,
  },
  {
    path: frontendURL(
      'accounts/:accountId/captain/:assistantId/settings/guidelines'
    ),
    component: AssistantGuidelinesIndex,
    name: 'captain_assistants_guidelines_index',
    meta: metaV2,
  },
  {
    path: frontendURL('accounts/:accountId/captain/flows'),
    component: FlowsIndex,
    name: 'captain_flow_list',
    meta: metaV2,
  },
  {
    path: frontendURL('accounts/:accountId/captain/flows/:flowId/editor'),
    component: FlowEditor,
    name: 'captain_flow_editor',
    meta: metaV2,
  },
  {
    path: frontendURL('accounts/:accountId/captain/assistants'),
    component: AssistantEmptyStateIndex,
    name: 'captain_assistants_create_index',
    meta: {
      permissions: ['administrator', 'agent', 'custom_role'],
      installationTypes: [
        INSTALLATION_TYPES.CLOUD,
        INSTALLATION_TYPES.ENTERPRISE,
        INSTALLATION_TYPES.COMMUNITY,
      ],
    },
  },
  {
    path: frontendURL('accounts/:accountId/captain/:navigationPath'),
    component: AssistantsIndexPage,
    name: 'captain_assistants_index',
    meta,
  },
];

export const routes = [
  {
    path: frontendURL('accounts/:accountId/captain'),
    component: CaptainPageRouteView,
    redirect: to => {
      return {
        name: 'captain_assistants_index',
        params: {
          navigationPath: 'captain_assistants_responses_index',
          ...to.params,
        },
      };
    },
    children: [...assistantRoutes],
  },
];
