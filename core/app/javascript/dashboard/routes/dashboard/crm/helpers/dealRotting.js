/**
 * Deal Rotting (Negócios Estagnados) Helper.
 *
 * Funções puras para cálculo de tempo de inatividade, detecção de estagnação
 * e níveis de alerta com base nas datas de movimentação/interação do negócio
 * e nos limiares definidos pela etapa ou padrão do sistema.
 */

export const DEFAULT_ROTTING_THRESHOLD_DAYS = 7;
export const MS_PER_DAY = 24 * 60 * 60 * 1000;
export const ROTTING_WARNING_RATIO = 0.7;

/**
 * Retorna a data de referência mais recente de atividade ou movimentação do negócio.
 * Prioridade:
 * 1. deal.last_activity_at
 * 2. deal.stage_entered_at / deal.stage_changed_at
 * 3. deal.updated_at
 * 4. deal.created_at
 *
 * @param {Object} deal
 * @returns {Date|null}
 */
export function getDealLastActivityDate(deal) {
  if (!deal) return null;
  const rawDate =
    deal.last_activity_at ||
    deal.stage_entered_at ||
    deal.stage_changed_at ||
    deal.updated_at ||
    deal.created_at;

  if (!rawDate) return null;
  const parsed = new Date(rawDate);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

/**
 * Calcula o número inteiro de dias que o negócio está sem movimentação/interação.
 *
 * @param {Object} deal
 * @param {Date|string} [now=new Date()]
 * @returns {number}
 */
export function getDaysInactive(deal, now = new Date()) {
  const lastActivity = getDealLastActivityDate(deal);
  if (!lastActivity) return 0;

  const reference = new Date(now);
  if (Number.isNaN(reference.getTime())) return 0;

  const diffMs = reference.getTime() - lastActivity.getTime();
  if (diffMs <= 0) return 0;

  return Math.floor(diffMs / MS_PER_DAY);
}

/**
 * Determina o limiar em dias para uma etapa específica ou retorna o padrão (7 dias).
 *
 * Suporta:
 * - stage.rotting_days_threshold (dias)
 * - stage.expected_duration_hours (horas convertidas em dias)
 * - fallback padrão de 7 dias
 *
 * @param {Object} [stage]
 * @param {number} [fallbackThreshold=DEFAULT_ROTTING_THRESHOLD_DAYS]
 * @returns {number}
 */
export function getStageRottingThreshold(
  stage,
  fallbackThreshold = DEFAULT_ROTTING_THRESHOLD_DAYS
) {
  if (!stage) return fallbackThreshold;

  if (
    stage.rotting_days_threshold != null &&
    Number(stage.rotting_days_threshold) > 0
  ) {
    return Number(stage.rotting_days_threshold);
  }

  if (
    stage.expected_duration_hours != null &&
    Number(stage.expected_duration_hours) > 0
  ) {
    const hours = Number(stage.expected_duration_hours);
    return Math.max(1, Math.round(hours / 24));
  }

  return fallbackThreshold;
}

/**
 * Avalia se um negócio está estagnado (deal rotting) e retorna os dados de alerta.
 *
 * Regras:
 * - Negócios que não estão com status "open" (ex.: won, lost, archived) não entram em rotting.
 * - Se daysInactive >= threshold, isRotting é true e level é 'late'.
 * - Se daysInactive >= threshold * 0.7, level é 'warning'.
 * - Caso contrário level é 'ok'.
 *
 * @param {Object} deal
 * @param {Object} [stage]
 * @param {Date|string} [now=new Date()]
 * @param {number} [customThreshold]
 * @returns {{
 *   daysInactive: number,
 *   threshold: number,
 *   isRotting: boolean,
 *   level: 'none' | 'ok' | 'warning' | 'late',
 *   badgeVariant: 'neutral' | 'warning' | 'danger'
 * }}
 */
export function calculateDealRotting(
  deal,
  stage,
  now = new Date(),
  customThreshold = null
) {
  if (!deal || (deal.status && deal.status !== 'open')) {
    return {
      daysInactive: 0,
      threshold: DEFAULT_ROTTING_THRESHOLD_DAYS,
      isRotting: false,
      level: 'none',
      badgeVariant: 'neutral',
    };
  }

  const daysInactive = getDaysInactive(deal, now);
  const threshold =
    customThreshold != null && customThreshold > 0
      ? customThreshold
      : getStageRottingThreshold(stage);

  const isRotting = daysInactive >= threshold;
  let level = 'ok';
  let badgeVariant = 'neutral';

  if (isRotting) {
    level = 'late';
    // O token semântico --ds-status-rotting cai no warning/laranja conforme diretriz
    badgeVariant = 'warning';
  } else if (daysInactive >= threshold * ROTTING_WARNING_RATIO) {
    level = 'warning';
    badgeVariant = 'warning';
  }

  return {
    daysInactive,
    threshold,
    isRotting,
    level,
    badgeVariant,
  };
}
