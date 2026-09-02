import { onBeforeUnmount, onMounted } from 'vue';
import { emitter } from 'shared/helpers/mitt';

/**
 * F1.8 do PLANO-KANBAN-CRM-2026.md — o evento de outra sessão vira patch no
 * estado local do board, e não um refetch do quadro inteiro.
 *
 * Dois princípios inegociáveis do plano moldam este arquivo:
 *
 * 1. **Realtime é aditivo, nunca destrutivo.** Um card que o atendente está
 *    arrastando ou editando agora não pode saltar porque um colega mexeu nele.
 *    O evento espera na fila e é aplicado quando o card é solto.
 * 2. **O payload é leve de propósito** (F1.7). Ele é mesclado sobre o card que
 *    o board já tem; sobrescrever apagaria contato, score e próxima ação.
 *
 * O patch opera sobre **colunas**, que é o estado que o board guarda desde a
 * F2.2 (ele consome o endpoint da F1.5). O card entra na coluna pela `position`
 * que o servidor decidiu, e não no fim por conveniência.
 */

export const CRM_DEAL_EVENT = 'crm_deal_changed';

const NO_POSITION = Number.POSITIVE_INFINITY;

// `position` nula é o estado transitório de quem o backfill da F1.2 ainda não
// alcançou. O board já mostra esses no fim da coluna; o patch faz o mesmo.
const sortKey = deal =>
  deal.position === null || deal.position === undefined
    ? NO_POSITION
    : Number(deal.position);

const insertByPosition = (deals, deal) => {
  const index = deals.findIndex(current => sortKey(current) > sortKey(deal));
  return index === -1
    ? [...deals, deal]
    : [...deals.slice(0, index), deal, ...deals.slice(index)];
};

// Só o agrupamento por etapa traz `stage_id` nas colunas (F2.8).
const groupedByStage = columns =>
  columns.some(
    column => column.stage_id !== null && column.stage_id !== undefined
  );

const findDeal = (columns, dealId) => {
  const column = columns.find(item =>
    item.deals.some(deal => deal.id === dealId)
  );
  return column?.deals.find(deal => deal.id === dealId) || null;
};

const withoutDeal = (columns, dealId) =>
  columns.map(column =>
    column.deals.some(deal => deal.id === dealId)
      ? { ...column, deals: column.deals.filter(deal => deal.id !== dealId) }
      : column
  );

/**
 * Há eventos que o board não consegue posicionar sozinho.
 *
 * Agrupado por responsável, faixa de score ou área, a coluna não é uma etapa:
 * saber em que balde um negócio **novo** cai exigiria repetir no cliente a
 * regra que o servidor aplicou. Em vez de adivinhar — ou de engolir o evento e
 * deixar o quadro desatualizado até alguém recarregar — o board pergunta de
 * novo ao servidor.
 */
export function isUnplaceable(columns, { type, deal } = {}) {
  if (!deal || !Array.isArray(columns)) return false;
  // Por etapa, `crm_pipeline_stage_id` basta para recolocar o card.
  if (groupedByStage(columns)) return false;
  // Sumir com um card não depende de saber em que balde ele estaria.
  if (type === 'deleted') return false;

  return !findDeal(columns, deal.id);
}

/**
 * Aplica um evento ao estado das colunas e devolve um estado novo.
 *
 * Devolve a **mesma referência** quando não há o que fazer, para o Vue não
 * repintar o board à toa.
 */
export function applyDealEvent(columns, { type, deal, accountId } = {}) {
  if (!deal || !Array.isArray(columns)) return columns;
  // Guarda de conta: o socket é da conta, mas trocar de conta sem recarregar a
  // página deixaria eventos da anterior em trânsito.
  if (accountId !== undefined && deal.account_id !== accountId) return columns;

  const existing = findDeal(columns, deal.id);

  // F2.8: agrupado por responsável, faixa de score ou área, a coluna não é uma
  // etapa — não há como recolocar o card a partir de `crm_pipeline_stage_id`.
  // Atualizar no lugar é a resposta honesta: o card mostra o dado novo e só
  // muda de coluna no próximo carregamento.
  if (!groupedByStage(columns)) {
    if (type === 'deleted')
      return existing ? withoutDeal(columns, deal.id) : columns;
    if (!existing) return columns;

    return columns.map(column => ({
      ...column,
      deals: column.deals.map(item =>
        item.id === deal.id ? { ...item, ...deal } : item
      ),
    }));
  }

  const withoutIt = existing ? withoutDeal(columns, deal.id) : columns;

  if (type === 'deleted') return withoutIt;

  const target = withoutIt.find(
    column => column.stage_id === deal.crm_pipeline_stage_id
  );
  // Etapa fora do board — outro pipeline, ou uma coluna que o filtro atual
  // esconde. Deixar o card na coluna antiga mostraria uma mentira; some.
  if (!target) return withoutIt;

  // O payload do realtime é leve de propósito (F1.7). Sobrescrever o card
  // inteiro apagaria o que o board já buscou: contato, score, próxima ação.
  const merged = { ...(existing || {}), ...deal };

  return withoutIt.map(column =>
    column.stage_id === target.stage_id
      ? { ...column, deals: insertByPosition(column.deals, merged) }
      : column
  );
}

/**
 * Fila de eventos por card ocupado.
 *
 * `isBusy(dealId)` responde se aquele card está sendo arrastado ou editado
 * agora. Enquanto estiver, o evento espera. Uma rajada (ação em massa,
 * automação) guarda só o último estado de cada card, para o card não dar dez
 * saltos quando for solto — exceto quando um dos eventos é a exclusão, que
 * vence os demais porque o card deixou de existir.
 */
export function createDealEventQueue({ isBusy = () => false } = {}) {
  const held = new Map();

  const keep = event => {
    const previous = held.get(event.deal.id);
    if (previous?.type === 'deleted') return;
    held.set(event.deal.id, event);
  };

  return {
    push(event, apply) {
      if (!event?.deal) return;
      if (isBusy(event.deal.id)) {
        keep(event);
        return;
      }
      apply(event);
    },

    flush(apply) {
      // Só sai da fila o que já pode entrar: um card ainda em edição continua
      // represado até o próximo flush.
      [...held.entries()]
        .filter(([dealId]) => !isBusy(dealId))
        .forEach(([dealId, event]) => {
          held.delete(dealId);
          apply(event);
        });
    },

    pending() {
      return held.size;
    },

    clear() {
      held.clear();
    },
  };
}

/**
 * Liga o board ao barramento de eventos.
 *
 * @param {Function} getColumns   devolve o estado atual das colunas
 * @param {Function} setColumns   recebe o estado novo
 * @param {Function} getAccountId conta corrente, para a guarda
 * @param {Function} isBusy       se o card está sendo arrastado/editado agora
 * @param {Function} onUnplaceable evento que só um recarregamento resolve
 */
export function useBoardRealtime({
  getColumns,
  setColumns,
  getAccountId,
  isBusy = () => false,
  onUnplaceable = null,
} = {}) {
  const queue = createDealEventQueue({ isBusy });

  const apply = event => {
    const columns = getColumns();
    const accountId = getAccountId?.();
    // A guarda de conta vale para os dois caminhos: evento de outra conta não
    // altera o board nem provoca requisição.
    if (accountId !== undefined && event.deal?.account_id !== accountId) return;

    if (isUnplaceable(columns, event)) {
      onUnplaceable?.(event);
      return;
    }

    const next = applyDealEvent(columns, { ...event, accountId });
    if (next !== columns) setColumns(next);
  };

  const onDealChanged = event => queue.push(event, apply);

  onMounted(() => emitter.on(CRM_DEAL_EVENT, onDealChanged));
  onBeforeUnmount(() => {
    emitter.off(CRM_DEAL_EVENT, onDealChanged);
    queue.clear();
  });

  return {
    // Chamado quando o atendente solta o card ou sai do campo: é aqui que o
    // que ficou represado entra.
    flushPendingDealEvents: () => queue.flush(apply),
    pendingDealEvents: () => queue.pending(),
  };
}
