/**
 * Sinais do card do Kanban — F2.4 do PLANO-KANBAN-CRM-2026.md, §7.
 *
 * Vivem fora do componente de propósito: são regra de negócio, não desenho.
 * "Negócio aberto sem próxima ação é o estado mais alarmante do board" é uma
 * afirmação que precisa de teste, não de CSS. E as três telas do CRM (quadro,
 * lista e ficha) precisam concordar sobre o que é urgente.
 */

const MAX_VISIBLE_BADGES = 2;
const HOURS_IN_DAY = 24;
const MS_IN_HOUR = 60 * 60 * 1000;

// §7: 0–70% do prazo da etapa é normal; 70–100% acende âmbar; acima, vermelho.
const ROTTING_WARNING_RATIO = 0.7;

const isClosed = deal => Boolean(deal?.status) && deal.status !== 'open';

const sameDay = (first, second) =>
  first.getFullYear() === second.getFullYear() &&
  first.getMonth() === second.getMonth() &&
  first.getDate() === second.getDate();

/**
 * Em que estado está a próxima ação do negócio.
 *
 * `actionable` marca o único caso em que o card oferece um botão: negócio
 * aberto sem nenhuma próxima ação, que é o que a meta de "<10% sem próxima
 * ação" persegue.
 */
export function nextActionSignal(deal, now = new Date()) {
  if (isClosed(deal)) return { tone: 'none', actionable: false, dueAt: null };

  const dueAt = deal?.next_activity_due_at;

  if (!dueAt) {
    // Atividade pendente sem data é trabalho combinado sem quando: não é
    // atraso, mas também não é "tudo certo".
    if (Number(deal?.pending_activities_count || 0) > 0) {
      return { tone: 'undated', actionable: false, dueAt: null };
    }

    return { tone: 'missing', actionable: true, dueAt: null };
  }

  const due = new Date(dueAt);
  const reference = new Date(now);

  if (due < reference && !sameDay(due, reference)) {
    return { tone: 'overdue', actionable: false, dueAt };
  }

  if (sameDay(due, reference)) {
    return {
      tone: due < reference ? 'overdue' : 'today',
      actionable: false,
      dueAt,
    };
  }

  return { tone: 'future', actionable: false, dueAt };
}

/**
 * Há quanto tempo o negócio está parado nesta etapa, contra o prazo esperado.
 *
 * Sem `expected_duration_hours` não dá para acusar nada — inventar um padrão
 * faria o board apontar etapas que ninguém configurou.
 */
export function rottingSignal(deal, stage, now = new Date()) {
  if (isClosed(deal)) return { level: 'none', daysInStage: 0 };

  const expectedHours = Number(stage?.expected_duration_hours || 0);
  // A F1.5 deixou `stage_entered_at` nula de propósito, sem backfill: quem
  // nunca se moveu está na etapa desde que foi criado.
  const since = deal?.stage_entered_at || deal?.created_at;

  if (!since) return { level: 'unknown', daysInStage: 0 };

  const elapsedHours = (new Date(now) - new Date(since)) / MS_IN_HOUR;
  const daysInStage = Math.floor(elapsedHours / HOURS_IN_DAY);

  if (!expectedHours) return { level: 'unknown', daysInStage };

  const ratio = elapsedHours / expectedHours;
  if (ratio > 1) return { level: 'late', daysInStage };
  if (ratio >= ROTTING_WARNING_RATIO) return { level: 'warning', daysInStage };

  return { level: 'ok', daysInStage };
}

/**
 * Regra 3 da §7: no máximo dois badges visíveis, e um contador para o resto.
 * O card compete com o nome do contato por atenção; empilhar badges perde a
 * disputa que o plano diz que o nome tem que ganhar.
 */
export function visibleBadges(badges = []) {
  const present = badges.filter(Boolean);

  return {
    shown: present.slice(0, MAX_VISIBLE_BADGES),
    overflow: Math.max(0, present.length - MAX_VISIBLE_BADGES),
  };
}
