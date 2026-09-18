import { ref } from 'vue';

import CrmAPI from 'dashboard/api/crm';

/**
 * F2.7 do PLANO-KANBAN-CRM-2026.md — visões salvas do quadro.
 *
 * Extraído de `CrmIndexOperational.vue` quando a página passou do teto de 800
 * linhas. A página continua dona dos filtros: aqui só se guarda a lista de
 * visões e se conversa com o servidor. Quem aplica uma visão é a página, via
 * `onApply` — ela é que sabe recarregar o quadro depois.
 *
 * @param {Function} t          tradutor
 * @param {Function} readFilters devolve os filtros do quadro, prontos para a API
 * @param {Function} onApply    recebe os filtros da visão escolhida
 * @param {Function} onError    recebe a mensagem quando o servidor recusa
 * @param {string}   context    'board' (default) ou 'report' (6.3 — filtros
 *                              salvos de relatórios na mesma tabela)
 */
export function useBoardViews({
  t,
  readFilters,
  onApply,
  onError,
  context = 'board',
}) {
  const boardViews = ref([]);
  const activeViewId = ref(null);

  const fail = exception =>
    onError?.(
      exception?.response?.data?.error ||
        exception?.response?.data?.message ||
        t('CRM.VIEWS.SAVE_FAILED')
    );

  const loadBoardViews = async () => {
    try {
      const response = await CrmAPI.getBoardViews({ context });
      boardViews.value = response?.data || [];
    } catch {
      // Visão salva é conveniência: falhar em carregar não pode derrubar o
      // quadro, só tirar o menu do ar.
      boardViews.value = [];
    }
  };

  const applyView = async view => {
    activeViewId.value = view?.id ?? null;
    await onApply?.(view?.filters || {});
  };

  const saveCurrentView = async name => {
    const trimmed = String(name || '').trim();
    if (!trimmed) return;

    try {
      const response = await CrmAPI.createBoardView({
        name: trimmed,
        filters: readFilters(),
        group_by: 'stage',
        context,
      });
      boardViews.value = [...boardViews.value, response.data];
      activeViewId.value = response.data.id;
    } catch (exception) {
      fail(exception);
    }
  };

  const toggleViewSharing = async view => {
    try {
      const response = await CrmAPI.updateBoardView(view.id, {
        is_shared: !view.is_shared,
      });
      boardViews.value = boardViews.value.map(item =>
        item.id === view.id ? response.data : item
      );
    } catch (exception) {
      fail(exception);
    }
  };

  const deleteView = async view => {
    try {
      await CrmAPI.deleteBoardView(view.id);
      boardViews.value = boardViews.value.filter(item => item.id !== view.id);
      if (activeViewId.value === view.id) activeViewId.value = null;
    } catch (exception) {
      fail(exception);
    }
  };

  // O nome é pedido aqui, e não dentro do menu: o menu não deveria saber abrir
  // caixa de diálogo nem validar texto. Dívida B-17: continua sendo
  // `window.prompt`/`window.confirm`, agora num lugar só.
  const promptForViewName = () => {
    const name = window.prompt(t('CRM.VIEWS.SAVE_PROMPT'));
    if (name) saveCurrentView(name);
  };

  const confirmDeleteView = view => {
    if (!window.confirm(t('CRM.VIEWS.DELETE_CONFIRM', { name: view.name }))) {
      return;
    }

    deleteView(view);
  };

  return {
    boardViews,
    activeViewId,
    loadBoardViews,
    applyView,
    saveCurrentView,
    toggleViewSharing,
    deleteView,
    promptForViewName,
    confirmDeleteView,
  };
}
