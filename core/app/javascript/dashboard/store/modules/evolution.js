import EvolutionAPI from '../../api/evolution';

export const state = {
  configuration: null,
  uiFlags: {
    isFetching: false,
    isSaving: false,
    isValidating: false,
  },
};

export const getters = {
  configuration: $state => $state.configuration,
  isConfigured: $state => Boolean($state.configuration?.configured),
  uiFlags: $state => $state.uiFlags,
};

export const actions = {
  async fetchConfiguration({ commit }, accountId) {
    commit('setUIFlags', { isFetching: true });
    try {
      const { data } = await EvolutionAPI.getConfiguration(accountId);
      commit('setConfiguration', data);
      return data;
    } finally {
      commit('setUIFlags', { isFetching: false });
    }
  },

  async saveConfiguration({ commit }, { accountId, ...payload }) {
    commit('setUIFlags', { isSaving: true });
    try {
      const { data } = await EvolutionAPI.saveConfiguration(accountId, payload);
      commit('setConfiguration', data);
      return data;
    } finally {
      commit('setUIFlags', { isSaving: false });
    }
  },

  async validateConfiguration({ commit }, { accountId, ...payload }) {
    commit('setUIFlags', { isValidating: true });
    try {
      const { data } = await EvolutionAPI.validateConfiguration(
        accountId,
        payload
      );
      return data;
    } finally {
      commit('setUIFlags', { isValidating: false });
    }
  },
};

export const mutations = {
  setConfiguration($state, configuration) {
    $state.configuration = configuration;
  },
  setUIFlags($state, flags) {
    $state.uiFlags = { ...$state.uiFlags, ...flags };
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
