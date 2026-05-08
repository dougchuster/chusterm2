import { frontendURL } from '../../../helper/URLHelper';
import { FEATURE_FLAGS } from '../../../featureFlags';
import CrmIndex from './pages/CrmIndex.vue';
import AllLeads from './pages/AllLeads.vue';
import PipelineSettings from './pages/PipelineSettings.vue';
import Activities from './pages/Activities.vue';
import Agenda from './pages/Agenda.vue';
import Reports from './pages/Reports.vue';
import LossReasons from './pages/LossReasons.vue';
import ChecklistTemplates from './pages/ChecklistTemplates.vue';
import AutomationRules from './pages/AutomationRules.vue';
import ScoringConfig from './pages/ScoringConfig.vue';
import Cadences from './pages/Cadences.vue';
import DealDetails from './pages/DealDetails.vue';
import CrmMetrics from './pages/CrmMetrics.vue';

const commonMeta = {
  featureFlag: FEATURE_FLAGS.CRM,
  permissions: ['administrator', 'agent', 'contact_manage'],
};

export const routes = [
  {
    path: frontendURL('accounts/:accountId/crm'),
    name: 'crm_dashboard',
    component: CrmIndex,
    meta: commonMeta,
  },
  {
    path: frontendURL('accounts/:accountId/crm/leads'),
    name: 'crm_all_leads',
    component: AllLeads,
    meta: commonMeta,
  },
  {
    path: frontendURL('accounts/:accountId/crm/settings/pipelines'),
    name: 'crm_pipeline_settings',
    component: PipelineSettings,
    meta: { ...commonMeta, permissions: ['administrator'] },
  },
  {
    path: frontendURL('accounts/:accountId/crm/activities'),
    name: 'crm_activities',
    component: Activities,
    meta: commonMeta,
  },
  {
    path: frontendURL('accounts/:accountId/crm/agenda'),
    name: 'crm_agenda',
    component: Agenda,
    meta: commonMeta,
  },
  {
    path: frontendURL('accounts/:accountId/crm/reports'),
    name: 'crm_reports',
    component: Reports,
    meta: { ...commonMeta, permissions: ['administrator'] },
  },
  {
    path: frontendURL('accounts/:accountId/crm/settings/loss-reasons'),
    name: 'crm_loss_reasons',
    component: LossReasons,
    meta: { ...commonMeta, permissions: ['administrator'] },
  },
  {
    path: frontendURL('accounts/:accountId/crm/settings/checklist-templates'),
    name: 'crm_checklist_templates',
    component: ChecklistTemplates,
    meta: { ...commonMeta, permissions: ['administrator'] },
  },
  {
    path: frontendURL('accounts/:accountId/crm/settings/automation-rules'),
    name: 'crm_automation_rules',
    component: AutomationRules,
    meta: { ...commonMeta, permissions: ['administrator'] },
  },
  {
    path: frontendURL('accounts/:accountId/crm/settings/cadences'),
    name: 'crm_cadences',
    component: Cadences,
    meta: { ...commonMeta, permissions: ['administrator'] },
  },
  {
    path: frontendURL('accounts/:accountId/crm/settings/scoring'),
    name: 'crm_scoring_config',
    component: ScoringConfig,
    meta: { ...commonMeta, permissions: ['administrator'] },
  },
  {
    path: frontendURL('accounts/:accountId/crm/deals/:dealId'),
    name: 'crm_deal_details',
    component: DealDetails,
    meta: commonMeta,
  },
  {
    path: frontendURL('accounts/:accountId/crm/metrics'),
    name: 'crm_metrics',
    component: CrmMetrics,
    meta: commonMeta,
  },
];
