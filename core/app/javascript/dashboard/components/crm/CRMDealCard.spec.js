import { mount } from '@vue/test-utils';

import CRMDealCard from './CRMDealCard.vue';

// F2.4 do PLANO-KANBAN-CRM-2026.md — card redesenhado segundo a §7.
//
// As quatro regras de hierarquia que este arquivo protege:
//   1. O olho bate primeiro no nome, depois na próxima ação. Nada mais compete.
//   2. Negócio aberto sem próxima ação é o estado mais alarmante do board.
//   3. No máximo 2 badges + "+N".
//   4. Densidade compacta esconde valor e categoria; detalhada acrescenta.

const AGORA = new Date('2026-08-28T15:00:00Z');

const deal = (overrides = {}) => ({
  id: 4,
  title: 'Maria Souza',
  status: 'open',
  contact_name: 'Maria Souza',
  score_total: 84,
  score_classification: 'hot',
  legal_area: 'previdenciario',
  value_estimate_cents: 1_240_000,
  owner_id: 9,
  next_activity_due_at: '2026-08-28T18:00:00Z',
  stage_entered_at: '2026-08-25T15:00:00Z',
  ...overrides,
});

const mountCard = (props = {}) =>
  mount(CRMDealCard, {
    props: {
      deal: deal(),
      stage: { id: 10, color: '#2563eb', expected_duration_hours: 48 },
      selected: false,
      ownerName: 'Dra. Paula',
      density: 'normal',
      now: AGORA,
      href: '/app/accounts/55/crm/deals/4',
      ...props,
    },
    global: {
      mocks: {
        // As strings vivem em crm.json (regra 7 do prompt: zero bare-string
        // nova). O mock devolve a chave para o teste falar de contrato, não de
        // tradução.
        $t: (key, params) =>
          params ? `${key}:${JSON.stringify(params)}` : key,
      },
      stubs: {
        DsButton: { template: '<button v-bind="$attrs" />' },
        DsDropdown: { template: '<div><slot /></div>' },
        Icon: { template: '<i />' },
        CRMScoreBadge: { template: '<span data-testid="score" />' },
      },
    },
  });

describe('CRMDealCard — hierarquia da §7', () => {
  // Regra 1
  it('leads with the contact name', () => {
    const wrapper = mountCard();

    expect(wrapper.find('[data-testid="crm-card-name"]').text()).toBe(
      'Maria Souza'
    );
  });

  // §7: "ref. do deal (só se ≠ do nome)". Repetir o nome duas vezes gasta a
  // linha mais valiosa do card com redundância.
  it('hides the deal reference when it just repeats the contact name', () => {
    const wrapper = mountCard();

    expect(wrapper.find('[data-testid="crm-card-reference"]').exists()).toBe(
      false
    );
  });

  it('shows the deal reference when it says something the name does not', () => {
    const wrapper = mountCard({
      deal: deal({ title: 'Aposentadoria por idade' }),
    });

    expect(wrapper.find('[data-testid="crm-card-reference"]').text()).toBe(
      'Aposentadoria por idade'
    );
  });

  it('says there is no contact instead of leaving the line empty', () => {
    const wrapper = mountCard({
      deal: deal({ contact_name: '', contact_phone_number: '', title: '' }),
    });

    expect(wrapper.find('[data-testid="crm-card-name"]').text()).toContain(
      'CRM.CARD.NO_CONTACT'
    );
  });
});

describe('CRMDealCard — a próxima ação', () => {
  // Regra 2: o estado mais alarmante do board.
  describe('quando não existe', () => {
    it('shows the alarm block', () => {
      const wrapper = mountCard({
        deal: deal({ next_activity_due_at: null }),
      });

      const block = wrapper.find('[data-testid="crm-card-no-next-action"]');
      expect(block.exists()).toBe(true);
      expect(block.text()).toContain('CRM.CARD.NO_NEXT_ACTION');
    });

    it('offers to schedule it in one click', async () => {
      const wrapper = mountCard({
        deal: deal({ next_activity_due_at: null }),
      });

      await wrapper.find('[data-testid="crm-card-schedule"]').trigger('click');

      expect(wrapper.emitted('scheduleNextAction')).toHaveLength(1);
    });

    // Cobrar próxima ação de negócio fechado encheria o board de alarme falso.
    it('does not alarm on a deal that is already closed', () => {
      const wrapper = mountCard({
        deal: deal({ status: 'won', next_activity_due_at: null }),
      });

      expect(
        wrapper.find('[data-testid="crm-card-no-next-action"]').exists()
      ).toBe(false);
    });
  });

  describe('quando existe', () => {
    it.each([
      ['2026-08-27T14:00:00Z', 'overdue'],
      ['2026-08-28T18:00:00Z', 'today'],
      ['2026-09-02T14:00:00Z', 'future'],
    ])('marks %s as %s', (dueAt, tone) => {
      const wrapper = mountCard({
        deal: deal({ next_activity_due_at: dueAt }),
      });

      expect(
        wrapper.find('[data-testid="crm-card-next-action"]').attributes()[
          'data-tone'
        ]
      ).toBe(tone);
    });
  });
});

describe('CRMDealCard — rotting', () => {
  it('is quiet while the deal is inside the expected time', () => {
    const wrapper = mountCard({
      deal: deal({ stage_entered_at: '2026-08-28T03:00:00Z' }),
    });

    expect(wrapper.attributes()['data-rotting']).toBe('ok');
  });

  it('goes loud once the deal passed the stage duration', () => {
    const wrapper = mountCard();

    expect(wrapper.attributes()['data-rotting']).toBe('late');
    expect(wrapper.find('[data-testid="crm-card-stale"]').text()).toContain(
      'CRM.CARD.STALE'
    );
  });

  it('says nothing when the stage has no expected duration', () => {
    const wrapper = mountCard({
      stage: { id: 10, expected_duration_hours: null },
    });

    expect(wrapper.attributes()['data-rotting']).toBe('unknown');
  });

  // §7: a borda esquerda carrega a cor da etapa.
  it('carries the stage colour on the left border', () => {
    const wrapper = mountCard();

    // jsdom normaliza o hex para rgb; o que importa e a cor vir da etapa.
    expect(wrapper.attributes('style')).toContain('rgb(37, 99, 235)');
  });
});

describe('CRMDealCard — densidade', () => {
  // Regra 4
  it('hides value and category when compact', () => {
    const wrapper = mountCard({ density: 'compact' });

    expect(wrapper.find('[data-testid="crm-card-value"]').exists()).toBe(false);
    expect(wrapper.find('[data-testid="crm-card-area"]').exists()).toBe(false);
  });

  it('shows value and category on the normal density', () => {
    const wrapper = mountCard();

    expect(wrapper.find('[data-testid="crm-card-value"]').text()).toContain(
      '12.400,00'
    );
    expect(wrapper.find('[data-testid="crm-card-area"]').exists()).toBe(true);
  });

  it('adds the next best action when detailed', () => {
    const wrapper = mountCard({
      density: 'detailed',
      deal: deal({ next_best_action: 'Pedir o CNIS antes da consulta' }),
    });

    expect(
      wrapper.find('[data-testid="crm-card-next-best-action"]').text()
    ).toBe('Pedir o CNIS antes da consulta');
  });

  it('does not show the next best action on the normal density', () => {
    const wrapper = mountCard({
      deal: deal({ next_best_action: 'Pedir o CNIS antes da consulta' }),
    });

    expect(
      wrapper.find('[data-testid="crm-card-next-best-action"]').exists()
    ).toBe(false);
  });
});

describe('CRMDealCard — badges', () => {
  // Regra 3: no máximo 2 + "+N".
  it('shows at most two badges and counts the rest', () => {
    const wrapper = mountCard({
      deal: deal({
        captain_ai_mode: 'auto',
        legal_area: 'previdenciario',
        is_stale: true,
        operational_status: 'returning_client',
      }),
    });

    expect(
      wrapper.findAll('[data-testid="crm-card-badge"]').length
    ).toBeLessThanOrEqual(2);
    expect(
      wrapper.find('[data-testid="crm-card-badge-overflow"]').exists()
    ).toBe(true);
  });

  it('does not show the counter when everything fits', () => {
    const wrapper = mountCard({
      deal: deal({ captain_ai_mode: null, is_stale: false }),
    });

    expect(
      wrapper.find('[data-testid="crm-card-badge-overflow"]').exists()
    ).toBe(false);
  });
});

describe('CRMDealCard — o que ele pede ao board', () => {
  it.each([
    ['crm-card-open', 'open'],
    ['crm-card-attend', 'attend'],
    ['crm-card-recompute', 'recompute'],
    ['crm-card-base-client', 'markBaseClient'],
    ['crm-card-discard', 'discard'],
  ])('asks for %s', async (testId, event) => {
    const wrapper = mountCard();

    await wrapper.find(`[data-testid="${testId}"]`).trigger('click');

    expect(wrapper.emitted(event)).toHaveLength(1);
  });

  it('reports the selection with the new state', async () => {
    const wrapper = mountCard();

    await wrapper.find('input[type="checkbox"]').setValue(true);

    expect(wrapper.emitted('select')[0]).toEqual([true]);
  });

  it('hides the discard action on a deal that is already closed', () => {
    const wrapper = mountCard({ deal: deal({ status: 'won' }) });

    expect(wrapper.find('[data-testid="crm-card-discard"]').exists()).toBe(
      false
    );
  });
});
