import { mount } from '@vue/test-utils';
import CRMDealOutcomeControl from './CRMDealOutcomeControl.vue';

const lossReasons = [
  { id: 12, name: 'Sem retorno do cliente' },
  { id: 13, name: 'Contratou outro escritório' },
];

const mountControl = (props = {}) =>
  mount(CRMDealOutcomeControl, {
    props: {
      status: 'open',
      lossReasons,
      ...props,
    },
  });

describe('CRMDealOutcomeControl', () => {
  it('exposes a clear action to mark an open deal as won', async () => {
    const wrapper = mountControl();

    await wrapper
      .findAll('button')
      .find(button => button.text() === 'Marcar ganho')
      .trigger('click');

    expect(wrapper.emitted('markWon')).toHaveLength(1);
  });

  it('requires a loss reason and submits the optional note', async () => {
    const wrapper = mountControl();

    await wrapper
      .findAll('button')
      .find(button => button.text() === 'Marcar perdido')
      .trigger('click');

    const submitButton = wrapper.get('button[type="submit"]');
    expect(submitButton.attributes('disabled')).toBeDefined();

    await wrapper.get('select').setValue('12');
    await wrapper.get('input[type="text"]').setValue('Cliente não respondeu.');
    await submitButton.trigger('submit');

    expect(wrapper.emitted('markLost')).toEqual([
      [{ lossReasonId: 12, note: 'Cliente não respondeu.' }],
    ]);
  });

  it('shows the recorded loss and allows the deal to be reopened', async () => {
    const wrapper = mountControl({
      status: 'lost',
      lossReasonId: 12,
      lossNote: 'Tentativas encerradas.',
    });

    expect(wrapper.get('[data-testid="deal-outcome-status"]').text()).toBe(
      'Perdido'
    );
    expect(wrapper.get('[data-testid="deal-loss-detail"]').text()).toContain(
      'Sem retorno do cliente'
    );

    await wrapper
      .findAll('button')
      .find(button => button.text() === 'Reabrir negócio')
      .trigger('click');

    expect(wrapper.emitted('reopen')).toHaveLength(1);
  });
});
