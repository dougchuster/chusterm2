import { applyDealEvent } from './useBoardRealtime';

/**
 * Mexer nos cards e nos números do cabeçalho do quadro.
 *
 * Extraído de `CrmIndexOperational.vue` quando a página passou do teto de 800
 * linhas. Contagem, soma e WIP vêm do servidor (F1.5) e valem para a coluna
 * inteira — não só para os 25 cards carregados. Quando um card troca de coluna,
 * esses números precisam acompanhar; senão o cabeçalho mente até o próximo
 * recarregamento, e o limite de WIP pode ser estourado sem o indicador acusar.
 *
 * @param {Ref} columns  as colunas do quadro
 * @param {Function} onChange chamado depois de cada alteração
 */
export function useBoardCards(columns, onChange = () => {}) {
  const shiftAggregates = (stageId, deal, direction) =>
    columns.value.map(column => {
      if (column.stage_id !== stageId) return column;

      const openDelta = deal.status === 'open' ? direction : 0;
      const openCount = Math.max(0, Number(column.open_count || 0) + openDelta);

      return {
        ...column,
        count: Math.max(0, Number(column.count || 0) + direction),
        open_count: openCount,
        sum_value_cents: Math.max(
          0,
          Number(column.sum_value_cents || 0) +
            direction * Number(deal.value_estimate_cents || 0)
        ),
        over_wip: Boolean(column.wip_limit) && openCount > column.wip_limit,
      };
    });

  const moveAggregates = (deal, fromStageId, toStageId) => {
    if (fromStageId === toStageId) return;

    columns.value = shiftAggregates(fromStageId, deal, -1);
    columns.value = shiftAggregates(toStageId, deal, 1);
  };

  const removeDealFromBoard = deal => {
    columns.value = shiftAggregates(deal.crm_pipeline_stage_id, deal, -1).map(
      column => ({
        ...column,
        deals: column.deals.filter(item => item.id !== deal.id),
      })
    );
    onChange();
  };

  /**
   * Dobra de volta no card o que aconteceu fora do quadro (chat, ficha, ação em
   * massa), reusando o mesmo caminho do realtime — foi por não reusar que o card
   * já ficou parado na coluna antiga depois de mudar de etapa pelo chat.
   */
  const patchDeal = (deal, changes) => {
    const current =
      columns.value
        .flatMap(column => column.deals)
        .find(item => item.id === deal.id) || deal;

    const next = applyDealEvent(columns.value, {
      type: 'updated',
      deal: {
        ...changes,
        id: deal.id,
        // Sem a etapa, `applyDealEvent` não acha a coluna de destino e some com
        // o card. Nem toda ação devolve a etapa (descartar, por exemplo).
        crm_pipeline_stage_id:
          changes.crm_pipeline_stage_id ?? current.crm_pipeline_stage_id,
      },
    });

    if (next === columns.value) return;

    columns.value = next;
    onChange();
  };

  return { shiftAggregates, moveAggregates, removeDealFromBoard, patchDeal };
}
