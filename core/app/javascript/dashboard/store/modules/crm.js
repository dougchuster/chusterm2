import CrmAPI from 'dashboard/api/crm';

const initialState = () => ({
  dashboard: null,
  pipelines: [],
  stagesByPipeline: {},
  deals: [],
  activities: [],
  lossReasons: [],
  auditEvents: [],
  selectedDeal: null,
  uiFlags: {
    isFetching: false,
    isFetchingDeal: false,
    isUpdatingDeal: false,
    isMovingDeal: false,
    isFetchingActivities: false,
    isFetchingAuditEvents: false,
  },
});

export const state = initialState();

const extractData = response => {
  const payload = response?.data ?? response;
  if (Array.isArray(payload)) return payload;
  return payload?.data ?? [];
};

export const getters = {
  getDashboard($state) {
    return $state.dashboard;
  },
  getPipelines($state) {
    return $state.pipelines;
  },
  getDeals($state) {
    return $state.deals;
  },
  getSelectedDeal($state) {
    return $state.selectedDeal;
  },
  getActivities($state) {
    return $state.activities;
  },
  getAuditEvents($state) {
    return $state.auditEvents;
  },
  getLossReasons($state) {
    return $state.lossReasons;
  },
  getStagesByPipeline: $state => pipelineId => {
    return $state.stagesByPipeline[pipelineId] || [];
  },
  getUIFlags($state) {
    return $state.uiFlags;
  },
};

export const actions = {
  async fetchDashboard({ commit }) {
    commit('setUIFlags', { isFetching: true });
    try {
      const { data } = await CrmAPI.getDashboard();
      commit('setDashboard', data);
      return data;
    } finally {
      commit('setUIFlags', { isFetching: false });
    }
  },

  async fetchPipelines({ commit }) {
    commit('setUIFlags', { isFetching: true });
    try {
      const response = await CrmAPI.getPipelines();
      const records = extractData(response);
      commit('setPipelines', records);
      return records;
    } finally {
      commit('setUIFlags', { isFetching: false });
    }
  },

  async fetchPipelineStages({ commit }, pipelineId) {
    const response = await CrmAPI.getPipelineStages(pipelineId);
    const records = extractData(response);
    commit('setPipelineStages', { pipelineId, records });
    return records;
  },

  async fetchDeals({ commit }, params = {}) {
    commit('setUIFlags', { isFetching: true });
    try {
      const response = await CrmAPI.getDeals(params);
      const records = extractData(response);
      commit('setDeals', records);
      return records;
    } finally {
      commit('setUIFlags', { isFetching: false });
    }
  },

  async fetchDeal({ commit }, dealId) {
    commit('setUIFlags', { isFetchingDeal: true });
    try {
      const { data } = await CrmAPI.getDeal(dealId);
      commit('setSelectedDeal', data);
      commit('upsertDeal', data);
      return data;
    } finally {
      commit('setUIFlags', { isFetchingDeal: false });
    }
  },

  async updateDeal({ commit }, { dealId, data }) {
    commit('setUIFlags', { isUpdatingDeal: true });
    try {
      const response = await CrmAPI.updateDeal(dealId, data);
      commit('setSelectedDeal', response.data);
      commit('upsertDeal', response.data);
      return response.data;
    } finally {
      commit('setUIFlags', { isUpdatingDeal: false });
    }
  },

  async moveDeal({ commit }, { dealId, stageId }) {
    commit('setUIFlags', { isMovingDeal: true });
    try {
      const { data } = await CrmAPI.moveDeal(dealId, stageId);
      commit('upsertDeal', data);
      return data;
    } finally {
      commit('setUIFlags', { isMovingDeal: false });
    }
  },

  async fetchActivities({ commit }, params = {}) {
    commit('setUIFlags', { isFetchingActivities: true });
    try {
      const response = await CrmAPI.getActivities(params);
      const records = extractData(response);
      commit('setActivities', records);
      return records;
    } finally {
      commit('setUIFlags', { isFetchingActivities: false });
    }
  },

  async completeActivity({ commit }, { activityId, outcome }) {
    const { data } = await CrmAPI.completeActivity(activityId, outcome);
    commit('upsertActivity', data);
    return data;
  },

  async fetchAuditEvents({ commit }, params = {}) {
    commit('setUIFlags', { isFetchingAuditEvents: true });
    try {
      const response = await CrmAPI.getAuditEvents(params);
      const records = extractData(response);
      commit('setAuditEvents', records);
      return records;
    } finally {
      commit('setUIFlags', { isFetchingAuditEvents: false });
    }
  },

  async fetchLossReasons({ commit }) {
    const response = await CrmAPI.getLossReasons();
    const records = extractData(response);
    commit('setLossReasons', records);
    return records;
  },
};

export const mutations = {
  setUIFlags($state, flags) {
    $state.uiFlags = { ...$state.uiFlags, ...flags };
  },
  setDashboard($state, dashboard) {
    $state.dashboard = dashboard;
  },
  setPipelines($state, pipelines) {
    $state.pipelines = pipelines;
  },
  setPipelineStages($state, { pipelineId, records }) {
    $state.stagesByPipeline = {
      ...$state.stagesByPipeline,
      [pipelineId]: records,
    };
  },
  setDeals($state, deals) {
    $state.deals = deals;
  },
  upsertDeal($state, deal) {
    const index = $state.deals.findIndex(record => record.id === deal.id);
    if (index >= 0) $state.deals.splice(index, 1, deal);
    else $state.deals.unshift(deal);
  },
  setSelectedDeal($state, deal) {
    $state.selectedDeal = deal;
  },
  setActivities($state, activities) {
    $state.activities = activities;
  },
  upsertActivity($state, activity) {
    const index = $state.activities.findIndex(
      record => record.id === activity.id
    );
    if (index >= 0) $state.activities.splice(index, 1, activity);
    else $state.activities.unshift(activity);
  },
  setAuditEvents($state, events) {
    $state.auditEvents = events;
  },
  setLossReasons($state, reasons) {
    $state.lossReasons = reasons;
  },
  reset($state) {
    Object.assign($state, initialState());
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
