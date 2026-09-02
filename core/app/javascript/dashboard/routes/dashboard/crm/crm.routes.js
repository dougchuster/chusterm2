import { frontendURL } from '../../../helper/URLHelper';
import { FEATURE_FLAGS } from '../../../featureFlags';

// PERF-03: todas as páginas CRM são carregadas sob demanda (dynamic import)
// para sair do chunk principal do dashboard. Não voltar a importar
// estaticamente — cada página gera seu próprio chunk no build do Vite.
const CrmIndex = () => import('./pages/CrmIndex.vue');
const AllLeads = () => import('./pages/AllLeads.vue');
const PipelineSettings = () => import('./pages/PipelineSettings.vue');
const Activities = () => import('./pages/Activities.vue');
const Agenda = () => import('./pages/Agenda.vue');
const Reports = () => import('./pages/Reports.vue');
const LossReasons = () => import('./pages/LossReasons.vue');
const ChecklistTemplates = () => import('./pages/ChecklistTemplates.vue');
const AutomationRules = () => import('./pages/AutomationRules.vue');
const ScoringConfig = () => import('./pages/ScoringConfig.vue');
const Cadences = () => import('./pages/Cadences.vue');
const DealDetails = () => import('./pages/DealDetails.vue');
const CrmMetrics = () => import('./pages/CrmMetrics.vue');
const AiCenter = () => import('./pages/AiCenter.vue');
const PageTemplatesGallery = () => import('./pages/PageTemplatesGallery.vue');

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
  {
    path: frontendURL('accounts/:accountId/crm/ai-center'),
    name: 'crm_ai_center',
    component: AiCenter,
    meta: commonMeta,
  },
  {
    path: frontendURL('accounts/:accountId/crm/design-system/templates'),
    name: 'crm_page_templates',
    component: PageTemplatesGallery,
    meta: {
      featureFlag: FEATURE_FLAGS.CRM_V2,
      permissions: ['administrator'],
    },
  },
];
