import CopilotThreadsAPI from 'dashboard/api/captain/copilotThreads';
import { createStore } from '../storeFactory';

export default createStore({
  name: 'CopilotThreads',
  API: CopilotThreadsAPI,
  actions: mutationTypes => ({
    async create({ commit, dispatch }, dataObj) {
      commit(mutationTypes.SET_UI_FLAG, { creatingItem: true });
      try {
        const response = await CopilotThreadsAPI.create(dataObj);
        const { data } = response;

        const thread = data.thread || data;
        commit(mutationTypes.UPSERT, thread);

        if (data.first_message) {
          dispatch('copilotMessages/upsert', data.first_message, {
            root: true,
          });
        }

        return data;
      } finally {
        commit(mutationTypes.SET_UI_FLAG, { creatingItem: false });
      }
    },
  }),
});
