import { ref } from 'vue';

import CrmAPI from 'dashboard/api/crm';
import { messageFrom } from 'dashboard/helper/crmErrors';

/**
 * Ações que o atendente dispara a partir do card, sem sair do quadro.
 *
 * Extraído de `CrmIndexOperational.vue` quando a página passou do teto de 800
 * linhas. Cada ação devolve o card já atualizado; quem redesenha o quadro é o
 * `useBoardCards`.
 *
 * @param {Function} t       tradutor
 * @param {Ref} saving       trava os botões enquanto o servidor responde
 * @param {Ref} error        onde a mensagem de falha aparece
 * @param {Function} patchDeal            dobra a resposta de volta no card
 * @param {Function} removeDealFromBoard  tira o card do quadro
 */
export function useBoardDealActions({
  t,
  saving,
  error,
  patchDeal,
  removeDealFromBoard,
}) {
  const discardTarget = ref(null);
  const dispositionReason = ref('invalid');

  const dispositionOptions = [
    { value: 'invalid', label: t('CRM.DISPOSITION.INVALID') },
    { value: 'spam', label: t('CRM.DISPOSITION.SPAM') },
    { value: 'duplicated', label: t('CRM.DISPOSITION.DUPLICATED') },
    { value: 'no_lead', label: t('CRM.DISPOSITION.NO_LEAD') },
  ];

  // Descartar não é o mesmo que perder: o descartado nunca foi um lead de
  // verdade e não pode entrar na taxa de conversão. E ele deixou o funil, então
  // sai do quadro — mesclar o status e manter o card mostraria um lead ativo
  // que não existe mais.
  const discard = async () => {
    const deal = discardTarget.value;
    if (!deal?.id) return;

    saving.value = true;
    error.value = '';
    try {
      await CrmAPI.discardDeal(deal.id, { reason: dispositionReason.value });
      removeDealFromBoard(deal);
      discardTarget.value = null;
    } catch (exception) {
      error.value = messageFrom(exception, t('CRM.ERRORS.DISCARD'));
    } finally {
      saving.value = false;
    }
  };

  // Regra de produto 10: cliente antigo não é lead novo.
  const markBaseClient = async deal => {
    if (!deal?.id) return;

    saving.value = true;
    error.value = '';
    try {
      const response = await CrmAPI.markDealBaseClient(deal.id);
      patchDeal(deal, response?.data || {});
    } catch (exception) {
      error.value = messageFrom(exception, t('CRM.ERRORS.MARK_BASE_CLIENT'));
    } finally {
      saving.value = false;
    }
  };

  // O recálculo é assíncrono no servidor; o card se atualiza pelo realtime da
  // F1.8 quando o job terminar, sem prender o atendente esperando.
  const recomputeScore = async deal => {
    if (!deal?.id) return;

    error.value = '';
    try {
      await CrmAPI.recomputeScore(deal.id);
    } catch (exception) {
      error.value = messageFrom(exception, t('CRM.ERRORS.RECOMPUTE_SCORE'));
    }
  };

  return {
    discardTarget,
    dispositionReason,
    dispositionOptions,
    discard,
    markBaseClient,
    recomputeScore,
  };
}
