import { mount } from '@vue/test-utils';

import {
  BoardPageTemplate,
  CalendarPageTemplate,
  ConversationPageTemplate,
  DsPageHeader,
  ListPageTemplate,
  RecordPageTemplate,
  SettingsPageTemplate,
} from '.';

const global = {
  stubs: {
    Icon: {
      props: ['icon'],
      template: '<span :data-icon="icon" />',
    },
    Spinner: {
      template: '<span data-testid="spinner" />',
    },
  },
};

describe('Phase 3 page archetypes', () => {
  it('uses one compact header hierarchy with breadcrumbs and actions', () => {
    const wrapper = mount(DsPageHeader, {
      props: {
        title: 'Leads',
        breadcrumbs: [{ label: 'CRM' }, { label: 'Leads' }],
      },
      slots: {
        actions: '<button type="button">Novo lead</button>',
      },
      global,
    });

    expect(wrapper.get('h1').text()).toBe('Leads');
    expect(wrapper.get('nav').attributes('aria-label')).toBe(
      'Navegação estrutural'
    );
    expect(wrapper.get('[aria-current="page"]').text()).toBe('Leads');
    expect(wrapper.get('button').text()).toBe('Novo lead');
  });

  it.each([
    [ListPageTemplate, 'list', 'content'],
    [BoardPageTemplate, 'board', 'board'],
    [RecordPageTemplate, 'record', 'timeline'],
    [ConversationPageTemplate, 'conversation', 'conversation'],
    [CalendarPageTemplate, 'calendar', 'calendar'],
    [SettingsPageTemplate, 'settings', 'settings-form'],
  ])(
    'renders the %s contract and its primary region',
    (component, templateName, primaryRegion) => {
      const wrapper = mount(component, {
        props: { title: 'Página operacional' },
        slots: {
          default: '<div data-testid="business-content">Conteúdo</div>',
          list: '<div>Lista</div>',
          mobile: '<div>Agenda móvel</div>',
          navigation: '<button>Geral</button>',
        },
        global,
      });

      expect(wrapper.attributes('data-page-template')).toBe(templateName);
      expect(
        wrapper.find(`[data-template-region="${primaryRegion}"]`).exists()
      ).toBe(true);
      expect(wrapper.get('h1').text()).toBe('Página operacional');
    }
  );

  it('provides stable loading skeletons and accessible busy state', () => {
    const wrapper = mount(ListPageTemplate, {
      props: { title: 'Leads', loading: true },
      global,
    });

    expect(wrapper.attributes('aria-busy')).toBe('true');
    expect(wrapper.findAll('[aria-hidden="true"]').length).toBeGreaterThan(1);
    expect(wrapper.get('[aria-label="Carregando registros"]').exists()).toBe(
      true
    );
  });

  it('keeps empty copy concise and forwards the recovery action', async () => {
    const wrapper = mount(BoardPageTemplate, {
      props: {
        title: 'Pipeline',
        empty: true,
        emptyTitle: 'Nenhum negócio neste pipeline.',
        emptyActionLabel: 'Criar negócio',
      },
      global,
    });

    expect(wrapper.text()).toContain('Nenhum negócio neste pipeline.');
    await wrapper.get('button').trigger('click');
    expect(wrapper.emitted('empty-action')).toHaveLength(1);
  });

  it('shows only the requested conversation panel on mobile', async () => {
    const wrapper = mount(ConversationPageTemplate, {
      props: { title: 'Conversas', mobilePanel: 'conversation' },
      slots: {
        list: '<div>Lista</div>',
        default: '<div>Mensagens</div>',
        context: '<div>Contexto</div>',
      },
      global,
    });

    expect(
      wrapper.get('[data-template-region="conversation-list"]').classes()
    ).toContain('hidden');
    expect(
      wrapper.get('[data-template-region="conversation"]').classes()
    ).toContain('block');

    await wrapper.setProps({ mobilePanel: 'context' });
    expect(
      wrapper.get('[data-template-region="conversation-context"]').classes()
    ).toContain('block');
    expect(
      wrapper.get('[data-template-region="conversation"]').classes()
    ).toContain('hidden');
  });
});
