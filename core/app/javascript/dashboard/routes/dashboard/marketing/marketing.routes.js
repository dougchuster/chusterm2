import { frontendURL } from '../../../helper/URLHelper';
import { FEATURE_FLAGS } from '../../../featureFlags';

// PERF: paginas de marketing carregam sob demanda (dynamic import) — seguem o
// mesmo contrato do CRM para nao inflar o chunk principal do dashboard.
const MarketingOverview = () => import('./pages/MarketingOverview.vue');
const MarketingConnections = () => import('./pages/MarketingConnections.vue');
const MarketingCampaigns = () => import('./pages/MarketingCampaigns.vue');
const MarketingLeads = () => import('./pages/MarketingLeads.vue');
const MarketingEvents = () => import('./pages/MarketingEvents.vue');

const commonMeta = {
  featureFlag: FEATURE_FLAGS.MARKETING,
  permissions: ['administrator', 'agent', 'contact_manage'],
};

export const routes = [
  {
    path: frontendURL('accounts/:accountId/marketing'),
    name: 'marketing_overview',
    component: MarketingOverview,
    meta: commonMeta,
  },
  {
    path: frontendURL('accounts/:accountId/marketing/connections'),
    name: 'marketing_connections',
    component: MarketingConnections,
    meta: { ...commonMeta, permissions: ['administrator'] },
  },
  {
    path: frontendURL('accounts/:accountId/marketing/campaigns'),
    name: 'marketing_campaigns',
    component: MarketingCampaigns,
    meta: commonMeta,
  },
  {
    path: frontendURL('accounts/:accountId/marketing/leads'),
    name: 'marketing_leads',
    component: MarketingLeads,
    meta: commonMeta,
  },
  {
    path: frontendURL('accounts/:accountId/marketing/events'),
    name: 'marketing_events',
    component: MarketingEvents,
    meta: { ...commonMeta, permissions: ['administrator'] },
  },
];
