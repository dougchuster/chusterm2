import { useGoToCommandHotKeys } from '../useGoToCommandHotKeys';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { frontendURL } from 'dashboard/helper/URLHelper';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

vi.mock('dashboard/composables/store');
vi.mock('vue-i18n');
vi.mock('vue-router');
vi.mock('dashboard/composables/useAdmin');
vi.mock('dashboard/helper/URLHelper');

const mockRoutes = [
  { path: 'accounts/:accountId/dashboard', name: 'conversation_dashboard' },
  {
    path: 'accounts/:accountId/contacts',
    name: 'contacts_dashboard',
    featureFlag: FEATURE_FLAGS.CRM,
  },
  {
    path: 'accounts/:accountId/companies',
    name: 'companies_dashboard',
    featureFlag: FEATURE_FLAGS.CRM,
  },
  {
    path: 'accounts/:accountId/crm',
    name: 'crm_dashboard',
    featureFlag: FEATURE_FLAGS.CRM,
  },
  {
    path: 'accounts/:accountId/crm/leads',
    name: 'crm_leads',
    featureFlag: FEATURE_FLAGS.CRM,
  },
  {
    path: 'accounts/:accountId/crm/activities',
    name: 'crm_activities',
    featureFlag: FEATURE_FLAGS.CRM,
  },
  {
    path: 'accounts/:accountId/crm/agenda',
    name: 'crm_agenda',
    featureFlag: FEATURE_FLAGS.CRM,
  },
  {
    path: 'accounts/:accountId/crm/analytics',
    name: 'crm_analytics',
    featureFlag: FEATURE_FLAGS.CRM,
  },
  {
    path: 'accounts/:accountId/crm/metrics',
    name: 'crm_metrics',
    featureFlag: FEATURE_FLAGS.CRM,
  },
  {
    path: 'accounts/:accountId/crm/reports',
    name: 'crm_reports',
    featureFlag: FEATURE_FLAGS.CRM,
  },
  {
    path: 'accounts/:accountId/crm/settings/cadences',
    name: 'crm_cadences',
    featureFlag: FEATURE_FLAGS.CRM,
  },
  {
    path: 'accounts/:accountId/crm/settings/automation-rules',
    name: 'crm_automation_rules',
    featureFlag: FEATURE_FLAGS.CRM,
  },
  {
    path: 'accounts/:accountId/crm/settings/pipelines',
    name: 'crm_pipeline_settings',
    featureFlag: FEATURE_FLAGS.CRM,
  },
  {
    path: 'accounts/:accountId/crm/settings/loss-reasons',
    name: 'crm_loss_reasons',
    featureFlag: FEATURE_FLAGS.CRM,
  },
  {
    path: 'accounts/:accountId/crm/settings/checklist-templates',
    name: 'crm_checklist_templates',
    featureFlag: FEATURE_FLAGS.CRM,
  },
  {
    path: 'accounts/:accountId/crm/settings/scoring',
    name: 'crm_scoring_config',
    featureFlag: FEATURE_FLAGS.CRM,
  },
  {
    path: 'accounts/:accountId/crm/ai-center',
    name: 'crm_ai_center',
    featureFlag: FEATURE_FLAGS.CRM,
  },
  {
    path: 'accounts/:accountId/settings/agents/list',
    name: 'agent_settings',
    featureFlag: FEATURE_FLAGS.AGENT_MANAGEMENT,
  },
  {
    path: 'accounts/:accountId/settings/teams/list',
    name: 'team_settings',
    featureFlag: FEATURE_FLAGS.TEAM_MANAGEMENT,
  },
  {
    path: 'accounts/:accountId/settings/inboxes/list',
    name: 'inbox_settings',
    featureFlag: FEATURE_FLAGS.INBOX_MANAGEMENT,
  },
  { path: 'accounts/:accountId/profile/settings', name: 'profile_settings' },
  { path: 'accounts/:accountId/notifications', name: 'notifications' },
  {
    path: 'accounts/:accountId/reports/overview',
    name: 'reports_overview',
    featureFlag: FEATURE_FLAGS.REPORTS,
  },
  {
    path: 'accounts/:accountId/settings/labels/list',
    name: 'label_settings',
    featureFlag: FEATURE_FLAGS.LABELS,
  },
  {
    path: 'accounts/:accountId/settings/canned-response/list',
    name: 'canned_responses',
    featureFlag: FEATURE_FLAGS.CANNED_RESPONSES,
  },
  {
    path: 'accounts/:accountId/settings/applications',
    name: 'applications',
    featureFlag: FEATURE_FLAGS.INTEGRATIONS,
  },
  {
    path: 'accounts/:accountId/settings/automation/list',
    name: 'automation_settings',
    featureFlag: FEATURE_FLAGS.AUTOMATIONS,
  },
  {
    path: 'accounts/:accountId/settings/macros',
    name: 'macros_settings',
    featureFlag: FEATURE_FLAGS.MACROS,
  },
  {
    path: 'accounts/:accountId/settings/attributes/list',
    name: 'custom_attributes_settings',
    featureFlag: FEATURE_FLAGS.CUSTOM_ATTRIBUTES,
  },
  {
    path: 'accounts/:accountId/settings/sla/list',
    name: 'sla_settings',
    featureFlag: FEATURE_FLAGS.SLA,
  },
  {
    path: 'accounts/:accountId/settings/audit-logs/list',
    name: 'audit_logs_settings',
    featureFlag: FEATURE_FLAGS.AUDIT_LOGS,
  },
];

describe('useGoToCommandHotKeys', () => {
  let store;

  beforeEach(() => {
    store = {
      getters: {
        getCurrentAccountId: 1,
        'accounts/isFeatureEnabledonAccount': vi.fn().mockReturnValue(true),
      },
    };

    useStore.mockReturnValue(store);
    useMapGetter.mockImplementation(key => ({
      value: store.getters[key],
    }));

    useI18n.mockReturnValue({ t: vi.fn(key => key) });
    useRouter.mockReturnValue({ push: vi.fn() });
    useAdmin.mockReturnValue({ isAdmin: { value: true } });
    frontendURL.mockImplementation(url => url);
  });

  it('should return goToCommandHotKeys computed property', () => {
    const { goToCommandHotKeys } = useGoToCommandHotKeys();
    expect(goToCommandHotKeys.value).toBeDefined();
    expect(goToCommandHotKeys.value.length).toBeGreaterThan(0);
  });

  it('should index all CRM routes with rich keywords', () => {
    const { goToCommandHotKeys } = useGoToCommandHotKeys();
    const crmCommands = [
      'goto_crm_dashboard',
      'goto_crm_leads',
      'goto_crm_activities',
      'goto_crm_agenda',
      'goto_crm_analytics',
      'goto_crm_metrics',
      'goto_crm_reports',
      'goto_crm_cadences',
      'goto_crm_automation_rules',
      'goto_crm_pipeline_settings',
      'goto_crm_loss_reasons',
      'goto_crm_checklist_templates',
      'goto_crm_scoring_config',
      'goto_crm_ai_center',
    ];

    crmCommands.forEach(cmdId => {
      const found = goToCommandHotKeys.value.find(cmd => cmd.id === cmdId);
      expect(found).toBeDefined();
      expect(found.keywords).toBeDefined();
      expect(found.keywords.length).toBeGreaterThan(0);
    });
  });

  it('should support fuzzy search keywords with both accented and normalized Portuguese tokens', () => {
    const { goToCommandHotKeys } = useGoToCommandHotKeys();
    const boardCmd = goToCommandHotKeys.value.find(
      cmd => cmd.id === 'goto_crm_dashboard'
    );
    expect(boardCmd.keywords).toContain('negócios');
    expect(boardCmd.keywords).toContain('negocios');
    expect(boardCmd.keywords).toContain('funil');
    expect(boardCmd.keywords).toContain('funis');
    expect(boardCmd.keywords).toContain('/crm/board');

    const metricsCmd = goToCommandHotKeys.value.find(
      cmd => cmd.id === 'goto_crm_metrics'
    );
    expect(metricsCmd.keywords).toContain('métricas');
    expect(metricsCmd.keywords).toContain('metricas');
    expect(metricsCmd.keywords).toContain('/crm/metrics');

    const automationsCmd = goToCommandHotKeys.value.find(
      cmd => cmd.id === 'goto_crm_automation_rules'
    );
    expect(automationsCmd.keywords).toContain('automações');
    expect(automationsCmd.keywords).toContain('automacoes');
    expect(automationsCmd.keywords).toContain('/crm/automation');
  });

  it('should index companies and general routes', () => {
    const { goToCommandHotKeys } = useGoToCommandHotKeys();
    const generalCommands = [
      'goto_conversation_dashboard',
      'goto_contacts_dashboard',
      'goto_companies_dashboard',
    ];

    generalCommands.forEach(cmdId => {
      const found = goToCommandHotKeys.value.find(cmd => cmd.id === cmdId);
      expect(found).toBeDefined();
    });
  });

  it('should index all settings routes including automations and macros', () => {
    const { goToCommandHotKeys } = useGoToCommandHotKeys();
    const settingsCommands = [
      'open_agent_settings',
      'open_team_settings',
      'open_inbox_settings',
      'open_label_settings',
      'open_canned_response_settings',
      'open_applications_settings',
      'open_automation_settings',
      'open_macros_settings',
      'open_custom_attributes_settings',
      'open_sla_settings',
      'open_audit_logs_settings',
      'open_account_settings',
      'open_profile_settings',
      'open_notifications',
    ];

    settingsCommands.forEach(cmdId => {
      const found = goToCommandHotKeys.value.find(cmd => cmd.id === cmdId);
      expect(found).toBeDefined();
    });
  });

  it('should filter commands based on feature flags', () => {
    store.getters['accounts/isFeatureEnabledonAccount'] = vi.fn(
      (accountId, flag) => flag !== FEATURE_FLAGS.CRM
    );
    const { goToCommandHotKeys } = useGoToCommandHotKeys();

    const crmCommands = goToCommandHotKeys.value.filter(cmd =>
      cmd.id.startsWith('goto_crm_')
    );
    expect(crmCommands.length).toBe(0);

    const nonCrmCommand = goToCommandHotKeys.value.find(
      cmd => cmd.id === 'goto_conversation_dashboard'
    );
    expect(nonCrmCommand).toBeDefined();
  });

  it('should filter admin-only CRM and settings commands for non-admin users', () => {
    useAdmin.mockReturnValue({ isAdmin: { value: false } });
    const { goToCommandHotKeys } = useGoToCommandHotKeys();

    const adminOnlyCommands = goToCommandHotKeys.value.filter(
      cmd =>
        cmd.id.includes('agent_settings') ||
        cmd.id.includes('team_settings') ||
        cmd.id.includes('inbox_settings') ||
        cmd.id.includes('crm_pipeline_settings') ||
        cmd.id.includes('crm_cadences') ||
        cmd.id.includes('crm_automation_rules') ||
        cmd.id.includes('crm_loss_reasons') ||
        cmd.id.includes('crm_checklist_templates') ||
        cmd.id.includes('crm_scoring_config') ||
        cmd.id.includes('open_automation_settings') ||
        cmd.id.includes('open_audit_logs_settings') ||
        cmd.id.includes('open_sla_settings')
    );
    expect(adminOnlyCommands.length).toBe(0);

    // Operational CRM routes should still be visible to agents
    const agentCrmCommands = goToCommandHotKeys.value.filter(
      cmd =>
        cmd.id === 'goto_crm_dashboard' ||
        cmd.id === 'goto_crm_leads' ||
        cmd.id === 'goto_crm_activities' ||
        cmd.id === 'goto_crm_agenda' ||
        cmd.id === 'goto_crm_analytics' ||
        cmd.id === 'goto_crm_metrics' ||
        cmd.id === 'goto_crm_ai_center'
    );
    expect(agentCrmCommands.length).toBe(7);
  });

  it('should include commands for both admin and agent roles when user is admin', () => {
    const { goToCommandHotKeys } = useGoToCommandHotKeys();
    const adminCommand = goToCommandHotKeys.value.find(cmd =>
      cmd.id.includes('agent_settings')
    );
    const agentCommand = goToCommandHotKeys.value.find(cmd =>
      cmd.id.includes('profile_settings')
    );
    const crmBoard = goToCommandHotKeys.value.find(
      cmd => cmd.id === 'goto_crm_dashboard'
    );
    expect(adminCommand).toBeDefined();
    expect(agentCommand).toBeDefined();
    expect(crmBoard).toBeDefined();
  });

  it('should translate section and title for each command', () => {
    const { goToCommandHotKeys } = useGoToCommandHotKeys();
    goToCommandHotKeys.value.forEach(command => {
      expect(useI18n().t).toHaveBeenCalledWith(
        expect.stringContaining('COMMAND_BAR.SECTIONS.')
      );
      expect(useI18n().t).toHaveBeenCalledWith(
        expect.stringContaining('COMMAND_BAR.COMMANDS.')
      );
      expect(command.section).toBeDefined();
      expect(command.title).toBeDefined();
    });
  });

  it('should call router.push with correct URL when handler is called', () => {
    const { goToCommandHotKeys } = useGoToCommandHotKeys();
    goToCommandHotKeys.value.forEach(command => {
      command.handler();
      expect(useRouter().push).toHaveBeenCalledWith(expect.any(String));
    });
  });

  it('should use current account ID in the path', () => {
    store.getters.getCurrentAccountId = 42;
    const { goToCommandHotKeys } = useGoToCommandHotKeys();
    goToCommandHotKeys.value.forEach(command => {
      command.handler();
      expect(useRouter().push).toHaveBeenCalledWith(
        expect.stringContaining('42')
      );
    });
  });

  it('should include icon for each command', () => {
    const { goToCommandHotKeys } = useGoToCommandHotKeys();
    goToCommandHotKeys.value.forEach(command => {
      expect(command.icon).toBeDefined();
    });
  });

  it('should return commands for all enabled features', () => {
    const { goToCommandHotKeys } = useGoToCommandHotKeys();
    const enabledFeatureCommands = goToCommandHotKeys.value.filter(cmd =>
      mockRoutes.some(route => route.featureFlag && cmd.id.includes(route.name))
    );
    expect(enabledFeatureCommands.length).toBeGreaterThan(0);
  });

  it('should not return commands for disabled features', () => {
    store.getters['accounts/isFeatureEnabledonAccount'] = vi.fn(() => false);
    const { goToCommandHotKeys } = useGoToCommandHotKeys();
    const disabledFeatureCommands = goToCommandHotKeys.value.filter(cmd =>
      mockRoutes.some(route => route.featureFlag && cmd.id.includes(route.name))
    );
    expect(disabledFeatureCommands.length).toBe(0);
  });
});
