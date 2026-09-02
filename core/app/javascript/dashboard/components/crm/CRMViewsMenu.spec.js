import { mount } from '@vue/test-utils';

import CRMViewsMenu from './CRMViewsMenu.vue';

// F2.7 do PLANO-KANBAN-CRM-2026.md — "menu de visões com minhas e da equipe".
//
// A separação não é estética: uma visão da equipe eu **uso**, não edito. O menu
// tem que deixar isso óbvio antes de o atendente clicar, não depois de o
// servidor recusar com 404.

const views = [
  { id: 1, name: 'Meus quentes', is_mine: true, is_shared: false },
  {
    id: 2,
    name: 'Sem próxima ação',
    is_mine: false,
    is_shared: true,
    owner_name: 'Dra. Paula',
  },
  { id: 3, name: 'Radar', is_mine: true, is_shared: true },
];

const mountMenu = (props = {}) =>
  mount(CRMViewsMenu, {
    props: { views, activeViewId: null, hasActiveFilters: false, ...props },
    global: {
      mocks: {
        $t: (key, params) =>
          params ? `${key}:${JSON.stringify(params)}` : key,
      },
      stubs: {
        Icon: { template: '<i />' },
        DsButton: { template: '<button v-bind="$attrs"><slot /></button>' },
        DsDropdown: { template: '<div><slot /></div>' },
      },
    },
  });

describe('CRMViewsMenu', () => {
  it('separates my views from the ones the team shared', () => {
    const wrapper = mountMenu();

    const mine = wrapper.findAll('[data-testid="crm-view-mine"]');
    const team = wrapper.findAll('[data-testid="crm-view-team"]');

    expect(mine.map(item => item.text())).toEqual(
      expect.arrayContaining(['Meus quentes', 'Radar'])
    );
    expect(team).toHaveLength(1);
    expect(team[0].text()).toContain('Sem próxima ação');
  });

  // Saber de quem é a visão da equipe é o que faz o atendente confiar nela.
  it('says who owns a team view', () => {
    const wrapper = mountMenu();

    expect(wrapper.find('[data-testid="crm-view-team"]').text()).toContain(
      'Dra. Paula'
    );
  });

  it('applies the view the attendant picked', async () => {
    const wrapper = mountMenu();

    await wrapper.findAll('[data-testid="crm-view-mine"]')[0].trigger('click');

    expect(wrapper.emitted('select')[0]).toEqual([views[0]]);
  });

  it('marks which view is showing right now', () => {
    const wrapper = mountMenu({ activeViewId: 1 });

    expect(
      wrapper
        .findAll('[data-testid="crm-view-mine"]')[0]
        .attributes('aria-current')
    ).toBe('true');
  });

  describe('salvar a visão atual', () => {
    // Sem filtro não há o que salvar: oferecer o botão seria oferecer uma visão
    // vazia, que é o mesmo que nenhuma visão.
    it('does not offer to save when nothing is filtered', () => {
      const wrapper = mountMenu({ hasActiveFilters: false });

      expect(wrapper.find('[data-testid="crm-view-save"]').exists()).toBe(
        false
      );
    });

    it('offers to save once there is a filter worth keeping', async () => {
      const wrapper = mountMenu({ hasActiveFilters: true });

      await wrapper.find('[data-testid="crm-view-save"]').trigger('click');

      expect(wrapper.emitted('save')).toHaveLength(1);
    });
  });

  describe('o que eu posso mexer', () => {
    it('lets me delete my own view', async () => {
      const wrapper = mountMenu();

      await wrapper
        .findAll('[data-testid="crm-view-delete"]')[0]
        .trigger('click');

      expect(wrapper.emitted('delete')[0]).toEqual([views[0]]);
    });

    // O servidor recusa com 404; o menu não deve nem oferecer.
    it('does not offer to delete a view that is not mine', () => {
      const team = wrapper => wrapper.find('[data-testid="crm-view-team"]');
      const wrapper = mountMenu();

      expect(
        team(wrapper).find('[data-testid="crm-view-delete"]').exists()
      ).toBe(false);
    });

    it('lets me share and unshare my own view', async () => {
      const wrapper = mountMenu();

      await wrapper
        .findAll('[data-testid="crm-view-share"]')[0]
        .trigger('click');

      expect(wrapper.emitted('share')[0]).toEqual([views[0]]);
    });
  });

  it('says the menu is empty instead of showing an empty box', () => {
    const wrapper = mountMenu({ views: [] });

    expect(wrapper.find('[data-testid="crm-view-empty"]').text()).toContain(
      'CRM.VIEWS.EMPTY'
    );
  });
});
