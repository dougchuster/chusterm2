/* global axios */
/* eslint-disable class-methods-use-this */

const accountIdFromRoute = () => {
  const isInsideAccountScopedURLs =
    window.location.pathname.includes('/app/accounts');

  if (!isInsideAccountScopedURLs) return '';
  return window.location.pathname.split('/')[3];
};

const crmUrl = path => `/api/v1/accounts/${accountIdFromRoute()}/crm/${path}`;

const queryString = params => {
  const searchParams = new URLSearchParams();
  Object.entries(params || {}).forEach(([key, value]) => {
    if (value !== undefined && value !== null && value !== '') {
      searchParams.append(key, value);
    }
  });
  return searchParams.toString();
};

const normalizePipelinePayload = data => {
  const payload = { ...(data || {}) };

  if (Object.prototype.hasOwnProperty.call(payload, 'isDefault')) {
    payload.is_default = payload.isDefault;
    delete payload.isDefault;
  }

  delete payload.accountId;
  return payload;
};

const normalizeStagePayload = data => {
  const payload = { ...(data || {}) };

  if (Object.prototype.hasOwnProperty.call(payload, 'probabilityPct')) {
    payload.probability_pct = payload.probabilityPct;
    delete payload.probabilityPct;
  }

  if (Object.prototype.hasOwnProperty.call(payload, 'expectedDurationDays')) {
    const duration = payload.expectedDurationDays;
    payload.expected_duration_hours =
      duration === null || duration === '' || duration === undefined
        ? null
        : Number(duration) * 24;
    delete payload.expectedDurationDays;
  }

  if (Object.prototype.hasOwnProperty.call(payload, 'expectedDurationHours')) {
    payload.expected_duration_hours = payload.expectedDurationHours;
    delete payload.expectedDurationHours;
  }

  delete payload.accountId;
  return payload;
};

class CrmAPI {
  getPipelines() {
    return axios.get(crmUrl('pipelines'));
  }

  updatePipeline(pipelineId, data) {
    return axios.patch(crmUrl(`pipelines/${pipelineId}`), {
      pipeline: normalizePipelinePayload(data),
    });
  }

  archivePipeline(pipelineId) {
    return axios.delete(crmUrl(`pipelines/${pipelineId}`));
  }

  createPipeline(data) {
    return axios.post(crmUrl('pipelines'), {
      pipeline: normalizePipelinePayload(data),
    });
  }

  getPipelineStages(pipelineId) {
    return axios.get(crmUrl(`pipelines/${pipelineId}/stages`));
  }

  createPipelineStage(pipelineId, data) {
    return axios.post(crmUrl(`pipelines/${pipelineId}/stages`), {
      stage: normalizeStagePayload(data),
    });
  }

  updatePipelineStage(pipelineId, stageId, data) {
    return axios.patch(crmUrl(`pipelines/${pipelineId}/stages/${stageId}`), {
      stage: normalizeStagePayload(data),
    });
  }

  archivePipelineStage(pipelineId, stageId) {
    return axios.delete(crmUrl(`pipelines/${pipelineId}/stages/${stageId}`));
  }

  getArchivedPipelines() {
    return axios.get(crmUrl('pipelines/archived'));
  }

  purgePipeline(pipelineId) {
    return axios.delete(crmUrl(`pipelines/${pipelineId}/purge`));
  }

  restorePipeline(pipelineId) {
    return axios.patch(crmUrl(`pipelines/${pipelineId}/restore`));
  }

  getArchivedPipelineStages(pipelineId) {
    return axios.get(crmUrl(`pipelines/${pipelineId}/stages/archived`));
  }

  purgePipelineStage(pipelineId, stageId) {
    return axios.delete(
      crmUrl(`pipelines/${pipelineId}/stages/${stageId}/purge`)
    );
  }

  restorePipelineStage(pipelineId, stageId) {
    return axios.patch(
      crmUrl(`pipelines/${pipelineId}/stages/${stageId}/restore`)
    );
  }

  getDashboard(params = {}) {
    return axios.get(crmUrl('dashboard'), { params });
  }

  getHealth() {
    return axios.get(crmUrl('health'));
  }

  getDeals(params = {}) {
    return axios.get(crmUrl('deals'), { params });
  }

  createDeal(data) {
    return axios.post(crmUrl('deals'), data);
  }

  getDeal(dealId) {
    return axios.get(crmUrl(`deals/${dealId}`));
  }

  updateDeal(dealId, data) {
    return axios.patch(crmUrl(`deals/${dealId}`), data);
  }

  deleteDeal(dealId) {
    return axios.delete(crmUrl(`deals/${dealId}`));
  }

  bulkActionDeals(data) {
    return axios.post(crmUrl('deals/bulk_action'), data);
  }

  // F1.3: afterId e o card que fica acima do movido, beforeId o que fica
  // abaixo. Quem calcula a posicao e o servidor; o cliente so relata os
  // vizinhos. Omitir os dois joga o card para o topo da coluna de destino.
  // F1.6: continua a coluna de onde o endpoint do board parou. Sem
  // `order: board` a pagina 2 volta a ordenar por data e repete cards.
  getColumnPage(stageId, { page = 2, perPage = 25, ...filters } = {}) {
    return axios.get(crmUrl('deals'), {
      params: {
        ...filters,
        stage_id: stageId,
        order: 'board',
        page,
        per_page: perPage,
      },
    });
  }

  // F2.7: visoes salvas. `board_views` devolve as minhas mais as que a equipe
  // compartilhou; editar e apagar so valem para as minhas (o servidor responde
  // 404 para o resto).
  getBoardViews() {
    return axios.get(crmUrl('board_views'));
  }

  createBoardView(boardView) {
    return axios.post(crmUrl('board_views'), { board_view: boardView });
  }

  updateBoardView(viewId, boardView) {
    return axios.patch(crmUrl(`board_views/${viewId}`), {
      board_view: boardView,
    });
  }

  deleteBoardView(viewId) {
    return axios.delete(crmUrl(`board_views/${viewId}`));
  }

  getBoard(pipelineId, { perColumn, ...filters } = {}) {
    return axios.get(crmUrl(`pipelines/${pipelineId}/board`), {
      params: { ...filters, per_column: perColumn },
    });
  }

  moveDeal(dealId, stageId, { afterId, beforeId } = {}) {
    return axios.post(crmUrl(`deals/${dealId}/move`), {
      stage_id: stageId,
      after_id: afterId,
      before_id: beforeId,
    });
  }

  markDealWon(dealId) {
    return axios.post(crmUrl(`deals/${dealId}/mark_won`));
  }

  markDealLost(dealId, lossReasonId, note) {
    return axios.post(crmUrl(`deals/${dealId}/mark_lost`), {
      loss_reason_id: lossReasonId,
      note,
    });
  }

  reopenDeal(dealId) {
    return axios.post(crmUrl(`deals/${dealId}/reopen`));
  }

  archiveDeal(dealId, data = {}) {
    return axios.post(crmUrl(`deals/${dealId}/archive`), data);
  }

  discardDeal(dealId, data = {}) {
    return axios.post(crmUrl(`deals/${dealId}/discard`), data);
  }

  markDealBaseClient(dealId, data = {}) {
    return axios.post(crmUrl(`deals/${dealId}/mark_base_client`), data);
  }

  // UX-05: listas de domínio (áreas, origens, urgências) vêm do backend
  getOptions() {
    return axios.get(crmUrl('options'));
  }

  getLossReasons() {
    return axios.get(crmUrl('loss-reasons'));
  }

  createLossReason(data) {
    return axios.post(crmUrl('loss-reasons'), data);
  }

  updateLossReason(lossReasonId, data) {
    return axios.patch(crmUrl(`loss-reasons/${lossReasonId}`), data);
  }

  getActivities(params = {}) {
    return axios.get(crmUrl('activities'), { params });
  }

  getAgendaEvents(params = {}) {
    return axios.get(crmUrl('agenda_events'), { params });
  }

  activitiesCalendarUrl(params = {}) {
    const query = queryString(params);
    return `${crmUrl('activities/calendar')}${query ? `?${query}` : ''}`;
  }

  createActivity(data) {
    return axios.post(crmUrl('activities'), data);
  }

  updateActivity(activityId, data) {
    return axios.patch(crmUrl(`activities/${activityId}`), data);
  }

  deleteActivity(activityId) {
    return axios.delete(crmUrl(`activities/${activityId}`));
  }

  completeActivity(activityId, outcome) {
    return axios.post(crmUrl(`activities/${activityId}/complete`), { outcome });
  }

  snoozeActivity(activityId, hours = 24) {
    return axios.post(crmUrl(`activities/${activityId}/snooze`), { hours });
  }

  syncActivityGoogleCalendar(activityId) {
    return axios.post(crmUrl(`activities/${activityId}/sync_google_calendar`));
  }

  importActivitiesGoogleCalendar(params = {}) {
    return axios.post(crmUrl('activities/import_google_calendar'), params);
  }

  suggestActivitySchedule(params = {}) {
    return axios.post(crmUrl('activities/suggest_schedule'), params);
  }

  scheduleActivitySuggestion(params = {}) {
    return axios.post(crmUrl('activities/schedule_suggestion'), params);
  }

  getGoogleWorkspaceAuthorization() {
    return axios.get(crmUrl('google_authorization'));
  }

  authorizeGoogleWorkspace(returnTo = '') {
    return axios.post(crmUrl('google_authorization'), {
      return_to: returnTo,
    });
  }

  recomputeScore(dealId) {
    return axios.post(crmUrl('lead-scores/recompute'), { deal_id: dealId });
  }

  triageFromConversation(conversationDatabaseId) {
    return axios.post(
      crmUrl(`triage/from-conversation/${conversationDatabaseId}`)
    );
  }

  getAuditEvents(params = {}) {
    return axios.get(crmUrl('audit-events'), { params });
  }

  getAutomationRuns(params = {}) {
    return axios.get(crmUrl('automation-runs'), { params });
  }

  // PERF-04: o export roda em job no backend; a resposta é JSON (202) e o
  // arquivo chega por email — não é mais um download direto (blob).
  exportDeals(params = {}) {
    return axios.post(crmUrl('deals/export'), params);
  }

  purgeOrphanDeals() {
    return axios.delete(crmUrl('deals/purge_orphans'));
  }

  getChecklistTemplates(params = {}) {
    return axios.get(crmUrl('checklist-templates'), { params });
  }

  createChecklistTemplate(data) {
    return axios.post(crmUrl('checklist-templates'), {
      checklist_template: data,
    });
  }

  updateChecklistTemplate(id, data) {
    return axios.patch(crmUrl(`checklist-templates/${id}`), {
      checklist_template: data,
    });
  }

  deleteChecklistTemplate(id) {
    return axios.delete(crmUrl(`checklist-templates/${id}`));
  }

  getAutomationRules() {
    return axios.get(crmUrl('automation-rules'));
  }

  createAutomationRule(data) {
    return axios.post(crmUrl('automation-rules'), { automation_rule: data });
  }

  updateAutomationRule(id, data) {
    return axios.patch(crmUrl(`automation-rules/${id}`), {
      automation_rule: data,
    });
  }

  deleteAutomationRule(id) {
    return axios.delete(crmUrl(`automation-rules/${id}`));
  }

  getCadences() {
    return axios.get(crmUrl('cadences'));
  }

  createCadence(data) {
    return axios.post(crmUrl('cadences'), { cadence: data });
  }

  updateCadence(id, data) {
    return axios.patch(crmUrl(`cadences/${id}`), { cadence: data });
  }

  deleteCadence(id) {
    return axios.delete(crmUrl(`cadences/${id}`));
  }

  enrollDeal(cadenceId, dealId) {
    return axios.post(crmUrl('cadences/enroll_deal'), {
      cadence_id: cadenceId,
      deal_id: dealId,
    });
  }

  unenrollDeal(cadenceId, dealId) {
    return axios.post(crmUrl('cadences/unenroll_deal'), {
      cadence_id: cadenceId,
      deal_id: dealId,
    });
  }

  // --- Métricas ---

  getMetricsOverview(params = {}) {
    return axios.get(crmUrl('metrics/overview'), { params });
  }

  getMetricsStageFunnel(params = {}) {
    return axios.get(crmUrl('metrics/stage_funnel'), { params });
  }

  getMetricsTimeInStage(params = {}) {
    return axios.get(crmUrl('metrics/time_in_stage'), { params });
  }

  getMetricsWinLossTrend(params = {}) {
    return axios.get(crmUrl('metrics/win_loss_trend'), { params });
  }

  getMetricsTopLossReasons(params = {}) {
    return axios.get(crmUrl('metrics/top_loss_reasons'), { params });
  }

  getMetricsScoreByStage(params = {}) {
    return axios.get(crmUrl('metrics/score_by_stage'), { params });
  }

  getMetricsAreaDistribution(params = {}) {
    return axios.get(crmUrl('metrics/area_distribution'), { params });
  }

  getMetricsTopDeals(params = {}) {
    return axios.get(crmUrl('metrics/top_deals'), { params });
  }

  getMetricsStaleDeals(params = {}) {
    return axios.get(crmUrl('metrics/stale_deals'), { params });
  }

  askAnalyst(data = {}) {
    return axios.post(crmUrl('analyst/ask'), data);
  }
}

export default new CrmAPI();
