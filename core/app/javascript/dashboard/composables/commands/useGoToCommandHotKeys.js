import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import { useRouter } from 'vue-router';
import { useAdmin } from 'dashboard/composables/useAdmin';
import {
  ICON_ACCOUNT_SETTINGS,
  ICON_AGENT_REPORTS,
  ICON_APPS,
  ICON_CANNED_RESPONSE,
  ICON_CONTACT_DASHBOARD,
  ICON_CONVERSATION_DASHBOARD,
  ICON_INBOXES,
  ICON_INBOX_REPORTS,
  ICON_LABELS,
  ICON_LABEL_REPORTS,
  ICON_NOTIFICATION,
  ICON_REPORTS_OVERVIEW,
  ICON_TEAM_REPORTS,
  ICON_USER_PROFILE,
  ICON_CONVERSATION_REPORTS,
  ICON_AI_ASSIST,
  ICON_CRM_PIPELINES,
  ICON_CRM_LEADS,
  ICON_CRM_ACTIVITIES,
  ICON_CRM_AGENDA,
  ICON_CRM_METRICS,
  ICON_CRM_CADENCES,
  ICON_CRM_AUTOMATIONS,
  ICON_CRM_SETTINGS,
} from 'dashboard/helper/commandbar/icons';
import { frontendURL } from 'dashboard/helper/URLHelper';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

const GO_TO_COMMANDS = [
  {
    id: 'goto_conversation_dashboard',
    title: 'COMMAND_BAR.COMMANDS.GO_TO_CONVERSATION_DASHBOARD',
    section: 'COMMAND_BAR.SECTIONS.GENERAL',
    icon: ICON_CONVERSATION_DASHBOARD,
    keywords:
      'inbox conversations chat messages conversas atendimento caixa de entrada dashboard /dashboard conversacao conversação mensagens chats',
    path: accountId => `accounts/${accountId}/dashboard`,
    role: ['administrator', 'agent'],
  },
  {
    id: 'goto_contacts_dashboard',
    title: 'COMMAND_BAR.COMMANDS.GO_TO_CONTACTS_DASHBOARD',
    section: 'COMMAND_BAR.SECTIONS.GENERAL',
    featureFlag: FEATURE_FLAGS.CRM,
    icon: ICON_CONTACT_DASHBOARD,
    keywords:
      'contacts companies contatos empresas clientes leads pessoas address book /contacts lista agenda contatos pessoas diretório diretorio',
    path: accountId => `accounts/${accountId}/contacts`,
    role: ['administrator', 'agent'],
  },
  {
    id: 'goto_companies_dashboard',
    title: 'COMMAND_BAR.COMMANDS.GO_TO_COMPANIES_DASHBOARD',
    section: 'COMMAND_BAR.SECTIONS.GENERAL',
    featureFlag: FEATURE_FLAGS.CRM,
    icon: ICON_CONTACT_DASHBOARD,
    keywords:
      'companies empresas organizações organizacoes organizations clientes pj b2b /companies corporativo contas accounts',
    path: accountId => `accounts/${accountId}/companies`,
    role: ['administrator', 'agent'],
  },
  // CRM Routes
  {
    id: 'goto_crm_dashboard',
    title: 'COMMAND_BAR.COMMANDS.GO_TO_CRM_DASHBOARD',
    section: 'COMMAND_BAR.SECTIONS.CRM',
    featureFlag: FEATURE_FLAGS.CRM,
    icon: ICON_CRM_PIPELINES,
    keywords:
      'crm funil funis pipelines board kanban crm/board /crm/board /crm deals negócios negocios vendas oportunidades pipeline stages quadro pipeline board cartões cartoes',
    path: accountId => `accounts/${accountId}/crm`,
    role: ['administrator', 'agent'],
  },
  {
    id: 'goto_crm_leads',
    title: 'COMMAND_BAR.COMMANDS.GO_TO_CRM_LEADS',
    section: 'COMMAND_BAR.SECTIONS.CRM',
    featureFlag: FEATURE_FLAGS.CRM,
    icon: ICON_CRM_LEADS,
    keywords:
      'crm leads contatos deals negócios negocios oportunidades prospects list tabela grid /crm/leads lista visualização visualizacao planilha',
    path: accountId => `accounts/${accountId}/crm/leads`,
    role: ['administrator', 'agent'],
  },
  {
    id: 'goto_crm_activities',
    title: 'COMMAND_BAR.COMMANDS.GO_TO_CRM_ACTIVITIES',
    section: 'COMMAND_BAR.SECTIONS.CRM',
    featureFlag: FEATURE_FLAGS.CRM,
    icon: ICON_CRM_ACTIVITIES,
    keywords:
      'crm atividades tasks tarefas follow-up ligações ligacoes reuniões reunioes calls checklist /crm/activities pendentes historico próximas proximas',
    path: accountId => `accounts/${accountId}/crm/activities`,
    role: ['administrator', 'agent'],
  },
  {
    id: 'goto_crm_agenda',
    title: 'COMMAND_BAR.COMMANDS.GO_TO_CRM_AGENDA',
    section: 'COMMAND_BAR.SECTIONS.CRM',
    featureFlag: FEATURE_FLAGS.CRM,
    icon: ICON_CRM_AGENDA,
    keywords:
      'crm agenda calendário calendario calendar compromissos reuniões reunioes events google calendar /crm/agenda datas eventos agendamentos',
    path: accountId => `accounts/${accountId}/crm/agenda`,
    role: ['administrator', 'agent'],
  },
  {
    id: 'goto_crm_analytics',
    title: 'CRM.ANALYTICS.TITLE',
    section: 'COMMAND_BAR.SECTIONS.CRM',
    featureFlag: FEATURE_FLAGS.CRM,
    icon: ICON_REPORTS_OVERVIEW,
    keywords:
      'crm analytics central analítica analitica bi relatórios relatorios métricas metricas kpi desempenho vendas suporte sla csat funil /crm/analytics',
    path: accountId => `accounts/${accountId}/crm/analytics`,
    role: ['administrator', 'agent'],
  },
  {
    id: 'goto_crm_metrics',
    title: 'COMMAND_BAR.COMMANDS.GO_TO_CRM_METRICS',
    section: 'COMMAND_BAR.SECTIONS.CRM',
    featureFlag: FEATURE_FLAGS.CRM,
    icon: ICON_CRM_METRICS,
    keywords:
      'crm métricas metricas metrics kpi conversão conversao taxa desempenho vendas analytics /crm/metrics estatísticas estatisticas faturamento metas',
    path: accountId => `accounts/${accountId}/crm/metrics`,
    role: ['administrator', 'agent'],
  },
  {
    id: 'goto_crm_reports',
    title: 'COMMAND_BAR.COMMANDS.GO_TO_CRM_REPORTS',
    section: 'COMMAND_BAR.SECTIONS.CRM',
    featureFlag: FEATURE_FLAGS.CRM,
    icon: ICON_REPORTS_OVERVIEW,
    keywords:
      'crm relatórios relatorios reports desempenho funil vendas analytics /crm/reports gráficos graficos bi exportação exportacao',
    path: accountId => `accounts/${accountId}/crm/reports`,
    role: ['administrator'],
  },
  {
    id: 'goto_crm_cadences',
    title: 'COMMAND_BAR.COMMANDS.GO_TO_CRM_CADENCES',
    section: 'COMMAND_BAR.SECTIONS.CRM',
    featureFlag: FEATURE_FLAGS.CRM,
    icon: ICON_CRM_CADENCES,
    keywords:
      'crm cadências cadencias cadences sequências sequencias outbound fluxos prospecção prospeccao /crm/cadences /crm/settings/cadences automação automacao réguas reguas',
    path: accountId => `accounts/${accountId}/crm/settings/cadences`,
    role: ['administrator'],
  },
  {
    id: 'goto_crm_automation_rules',
    title: 'COMMAND_BAR.COMMANDS.GO_TO_CRM_AUTOMATIONS',
    section: 'COMMAND_BAR.SECTIONS.CRM',
    featureFlag: FEATURE_FLAGS.CRM,
    icon: ICON_CRM_AUTOMATIONS,
    keywords:
      'crm automações automacoes automations workflows gatilhos regras triggers fluxos /crm/automation /crm/settings/automation-rules nó nos nós builder',
    path: accountId => `accounts/${accountId}/crm/settings/automation-rules`,
    role: ['administrator'],
  },
  {
    id: 'goto_crm_pipeline_settings',
    title: 'COMMAND_BAR.COMMANDS.GO_TO_CRM_PIPELINE_SETTINGS',
    section: 'COMMAND_BAR.SECTIONS.SETTINGS',
    featureFlag: FEATURE_FLAGS.CRM,
    icon: ICON_CRM_SETTINGS,
    keywords:
      'crm configurações configuracoes funis etapas pipelines stages settings /crm/settings/pipelines fases colunas pipeline funil setup',
    path: accountId => `accounts/${accountId}/crm/settings/pipelines`,
    role: ['administrator'],
  },
  {
    id: 'goto_crm_loss_reasons',
    title: 'COMMAND_BAR.COMMANDS.GO_TO_CRM_LOSS_REASONS',
    section: 'COMMAND_BAR.SECTIONS.SETTINGS',
    featureFlag: FEATURE_FLAGS.CRM,
    icon: ICON_CRM_SETTINGS,
    keywords:
      'crm motivos perda loss reasons descarte motivos /crm/settings/loss-reasons cancelamento desistência desistencias descarte',
    path: accountId => `accounts/${accountId}/crm/settings/loss-reasons`,
    role: ['administrator'],
  },
  {
    id: 'goto_crm_checklist_templates',
    title: 'COMMAND_BAR.COMMANDS.GO_TO_CRM_CHECKLIST_TEMPLATES',
    section: 'COMMAND_BAR.SECTIONS.SETTINGS',
    featureFlag: FEATURE_FLAGS.CRM,
    icon: ICON_CRM_ACTIVITIES,
    keywords:
      'crm checklist modelos templates etapas tarefas /crm/settings/checklist-templates padrão padrao roteiro procedimento playbook',
    path: accountId => `accounts/${accountId}/crm/settings/checklist-templates`,
    role: ['administrator'],
  },
  {
    id: 'goto_crm_scoring_config',
    title: 'COMMAND_BAR.COMMANDS.GO_TO_CRM_SCORING_CONFIG',
    section: 'COMMAND_BAR.SECTIONS.SETTINGS',
    featureFlag: FEATURE_FLAGS.CRM,
    icon: ICON_CRM_METRICS,
    keywords:
      'crm lead scoring pontuação pontuacao regras qualificação qualificacao /crm/settings/scoring score temperatura pontos icp fit',
    path: accountId => `accounts/${accountId}/crm/settings/scoring`,
    role: ['administrator'],
  },
  {
    id: 'goto_crm_ai_center',
    title: 'COMMAND_BAR.COMMANDS.GO_TO_CRM_AI_CENTER',
    section: 'COMMAND_BAR.SECTIONS.CRM',
    featureFlag: FEATURE_FLAGS.CRM,
    icon: ICON_AI_ASSIST,
    keywords:
      'crm inteligência inteligencia artificial ai captain copilot insights smart summary /crm/ai-center resumo sugestão sugestao assistente ia',
    path: accountId => `accounts/${accountId}/crm/ai-center`,
    role: ['administrator', 'agent'],
  },
  // Reports
  {
    id: 'open_reports_overview',
    section: 'COMMAND_BAR.SECTIONS.REPORTS',
    title: 'COMMAND_BAR.COMMANDS.GO_TO_REPORTS_OVERVIEW',
    featureFlag: FEATURE_FLAGS.REPORTS,
    icon: ICON_REPORTS_OVERVIEW,
    keywords:
      'reports overview relatórios relatorios visão geral visao geral /reports',
    path: accountId => `accounts/${accountId}/reports/overview`,
    role: ['administrator'],
  },
  {
    id: 'open_conversation_reports',
    section: 'COMMAND_BAR.SECTIONS.REPORTS',
    title: 'COMMAND_BAR.COMMANDS.GO_TO_CONVERSATION_REPORTS',
    featureFlag: FEATURE_FLAGS.REPORTS,
    icon: ICON_CONVERSATION_REPORTS,
    keywords:
      'conversation reports relatórios relatorios conversas atendimento /reports/conversation',
    path: accountId => `accounts/${accountId}/reports/conversation`,
    role: ['administrator'],
  },
  {
    id: 'open_agent_reports',
    section: 'COMMAND_BAR.SECTIONS.REPORTS',
    title: 'COMMAND_BAR.COMMANDS.GO_TO_AGENT_REPORTS',
    featureFlag: FEATURE_FLAGS.REPORTS,
    icon: ICON_AGENT_REPORTS,
    keywords:
      'agent reports relatórios relatorios atendentes agentes equipe /reports/agent',
    path: accountId => `accounts/${accountId}/reports/agent`,
    role: ['administrator'],
  },
  {
    id: 'open_label_reports',
    section: 'COMMAND_BAR.SECTIONS.REPORTS',
    title: 'COMMAND_BAR.COMMANDS.GO_TO_LABEL_REPORTS',
    featureFlag: FEATURE_FLAGS.REPORTS,
    icon: ICON_LABEL_REPORTS,
    keywords:
      'label reports relatórios relatorios etiquetas tags marcadores /reports/label',
    path: accountId => `accounts/${accountId}/reports/label`,
    role: ['administrator'],
  },
  {
    id: 'open_inbox_reports',
    section: 'COMMAND_BAR.SECTIONS.REPORTS',
    title: 'COMMAND_BAR.COMMANDS.GO_TO_INBOX_REPORTS',
    featureFlag: FEATURE_FLAGS.REPORTS,
    icon: ICON_INBOX_REPORTS,
    keywords:
      'inbox reports relatórios relatorios caixas de entrada canais whatsapp /reports/inboxes',
    path: accountId => `accounts/${accountId}/reports/inboxes`,
    role: ['administrator'],
  },
  {
    id: 'open_team_reports',
    section: 'COMMAND_BAR.SECTIONS.REPORTS',
    title: 'COMMAND_BAR.COMMANDS.GO_TO_TEAM_REPORTS',
    featureFlag: FEATURE_FLAGS.REPORTS,
    icon: ICON_TEAM_REPORTS,
    keywords:
      'team reports relatórios relatorios equipes times setores /reports/teams',
    path: accountId => `accounts/${accountId}/reports/teams`,
    role: ['administrator'],
  },
  // Settings
  {
    id: 'open_agent_settings',
    section: 'COMMAND_BAR.SECTIONS.SETTINGS',
    title: 'COMMAND_BAR.COMMANDS.GO_TO_SETTINGS_AGENTS',
    featureFlag: FEATURE_FLAGS.AGENT_MANAGEMENT,
    icon: ICON_AGENT_REPORTS,
    keywords:
      'settings agents configurações configuracoes agentes atendentes equipe membros /settings/agents',
    path: accountId => `accounts/${accountId}/settings/agents/list`,
    role: ['administrator'],
  },
  {
    id: 'open_team_settings',
    title: 'COMMAND_BAR.COMMANDS.GO_TO_SETTINGS_TEAMS',
    featureFlag: FEATURE_FLAGS.TEAM_MANAGEMENT,
    section: 'COMMAND_BAR.SECTIONS.SETTINGS',
    icon: ICON_TEAM_REPORTS,
    keywords:
      'settings teams configurações configuracoes equipes times departamentos grupos /settings/teams',
    path: accountId => `accounts/${accountId}/settings/teams/list`,
    role: ['administrator'],
  },
  {
    id: 'open_inbox_settings',
    title: 'COMMAND_BAR.COMMANDS.GO_TO_SETTINGS_INBOXES',
    featureFlag: FEATURE_FLAGS.INBOX_MANAGEMENT,
    section: 'COMMAND_BAR.SECTIONS.SETTINGS',
    icon: ICON_INBOXES,
    keywords:
      'settings inboxes configurações configuracoes caixas de entrada canais whatsapp email chat /settings/inboxes',
    path: accountId => `accounts/${accountId}/settings/inboxes/list`,
    role: ['administrator'],
  },
  {
    id: 'open_label_settings',
    title: 'COMMAND_BAR.COMMANDS.GO_TO_SETTINGS_LABELS',
    featureFlag: FEATURE_FLAGS.LABELS,
    section: 'COMMAND_BAR.SECTIONS.SETTINGS',
    icon: ICON_LABELS,
    keywords:
      'settings labels configurações configuracoes etiquetas tags marcadores cores /settings/labels',
    path: accountId => `accounts/${accountId}/settings/labels/list`,
    role: ['administrator'],
  },
  {
    id: 'open_canned_response_settings',
    title: 'COMMAND_BAR.COMMANDS.GO_TO_SETTINGS_CANNED_RESPONSES',
    featureFlag: FEATURE_FLAGS.CANNED_RESPONSES,
    section: 'COMMAND_BAR.SECTIONS.SETTINGS',
    icon: ICON_CANNED_RESPONSE,
    keywords:
      'settings canned responses configurações configuracoes respostas rápidas rapidas macros templates atalhos /settings/canned-response',
    path: accountId => `accounts/${accountId}/settings/canned-response/list`,
    role: ['administrator', 'agent'],
  },
  {
    id: 'open_applications_settings',
    title: 'COMMAND_BAR.COMMANDS.GO_TO_SETTINGS_APPLICATIONS',
    featureFlag: FEATURE_FLAGS.INTEGRATIONS,
    section: 'COMMAND_BAR.SECTIONS.SETTINGS',
    icon: ICON_APPS,
    keywords:
      'settings integrations applications integrações integracoes aplicativos webhooks hooks api /settings/applications',
    path: accountId => `accounts/${accountId}/settings/applications`,
    role: ['administrator'],
  },
  {
    id: 'open_automation_settings',
    title: 'COMMAND_BAR.COMMANDS.GO_TO_SETTINGS_AUTOMATIONS',
    featureFlag: FEATURE_FLAGS.AUTOMATIONS,
    section: 'COMMAND_BAR.SECTIONS.SETTINGS',
    icon: ICON_CRM_AUTOMATIONS,
    keywords:
      'settings automation automations configurações configuracoes automação automacao regras fluxos triggers /settings/automation',
    path: accountId => `accounts/${accountId}/settings/automation/list`,
    role: ['administrator'],
  },
  {
    id: 'open_macros_settings',
    title: 'COMMAND_BAR.COMMANDS.GO_TO_SETTINGS_MACROS',
    featureFlag: FEATURE_FLAGS.MACROS,
    section: 'COMMAND_BAR.SECTIONS.SETTINGS',
    icon: ICON_CANNED_RESPONSE,
    keywords:
      'settings macros configurações configuracoes macros automação rapida rápida ações /settings/macros',
    path: accountId => `accounts/${accountId}/settings/macros`,
    role: ['administrator', 'agent'],
  },
  {
    id: 'open_custom_attributes_settings',
    title: 'COMMAND_BAR.COMMANDS.GO_TO_SETTINGS_CUSTOM_ATTRIBUTES',
    featureFlag: FEATURE_FLAGS.CUSTOM_ATTRIBUTES,
    section: 'COMMAND_BAR.SECTIONS.SETTINGS',
    icon: ICON_ACCOUNT_SETTINGS,
    keywords:
      'settings custom attributes configurações configuracoes atributos personalizados campos customizados /settings/attributes',
    path: accountId => `accounts/${accountId}/settings/attributes/list`,
    role: ['administrator'],
  },
  {
    id: 'open_sla_settings',
    title: 'COMMAND_BAR.COMMANDS.GO_TO_SETTINGS_SLA',
    featureFlag: FEATURE_FLAGS.SLA,
    section: 'COMMAND_BAR.SECTIONS.SETTINGS',
    icon: ICON_ACCOUNT_SETTINGS,
    keywords:
      'settings sla configurações configuracoes prazos atendimento acordos tempo limite /settings/sla',
    path: accountId => `accounts/${accountId}/settings/sla/list`,
    role: ['administrator'],
  },
  {
    id: 'open_audit_logs_settings',
    title: 'COMMAND_BAR.COMMANDS.GO_TO_SETTINGS_AUDIT_LOGS',
    featureFlag: FEATURE_FLAGS.AUDIT_LOGS,
    section: 'COMMAND_BAR.SECTIONS.SETTINGS',
    icon: ICON_ACCOUNT_SETTINGS,
    keywords:
      'settings audit logs configurações configuracoes auditoria histórico historico logs eventos /settings/audit-logs',
    path: accountId => `accounts/${accountId}/settings/audit-logs/list`,
    role: ['administrator'],
  },
  {
    id: 'open_account_settings',
    title: 'COMMAND_BAR.COMMANDS.GO_TO_SETTINGS_ACCOUNT',
    section: 'COMMAND_BAR.SECTIONS.SETTINGS',
    icon: ICON_ACCOUNT_SETTINGS,
    keywords:
      'settings account configurações configuracoes conta geral empresa organização organizacao /settings/general',
    path: accountId => `accounts/${accountId}/settings/general`,
    role: ['administrator'],
  },
  {
    id: 'open_profile_settings',
    title: 'COMMAND_BAR.COMMANDS.GO_TO_SETTINGS_PROFILE',
    section: 'COMMAND_BAR.SECTIONS.SETTINGS',
    icon: ICON_USER_PROFILE,
    keywords:
      'settings profile configurações configuracoes perfil usuário usuario senha avatar preferências preferencias /profile/settings',
    path: accountId => `accounts/${accountId}/profile/settings`,
    role: ['administrator', 'agent'],
  },
  {
    id: 'open_notifications',
    title: 'COMMAND_BAR.COMMANDS.GO_TO_NOTIFICATIONS',
    section: 'COMMAND_BAR.SECTIONS.SETTINGS',
    icon: ICON_NOTIFICATION,
    keywords:
      'notifications notificações notificacoes alertas avisos sininho central de avisos /notifications',
    path: accountId => `accounts/${accountId}/notifications`,
    role: ['administrator', 'agent'],
  },
];

export function useGoToCommandHotKeys() {
  const { t } = useI18n();
  const router = useRouter();
  const { isAdmin } = useAdmin();

  const currentAccountId = useMapGetter('getCurrentAccountId');
  const isFeatureEnabledOnAccount = useMapGetter(
    'accounts/isFeatureEnabledonAccount'
  );

  const openRoute = url => {
    router.push(frontendURL(url));
  };

  const goToCommandHotKeys = computed(() => {
    let commands = GO_TO_COMMANDS.filter(cmd => {
      if (cmd.featureFlag) {
        return isFeatureEnabledOnAccount.value(
          currentAccountId.value,
          cmd.featureFlag
        );
      }
      return true;
    });

    if (!isAdmin.value) {
      commands = commands.filter(command => command.role.includes('agent'));
    }

    return commands.map(command => ({
      id: command.id,
      section: t(command.section),
      title: t(command.title),
      icon: command.icon,
      keywords: command.keywords || '',
      handler: () => openRoute(command.path(currentAccountId.value)),
    }));
  });

  return {
    goToCommandHotKeys,
  };
}
