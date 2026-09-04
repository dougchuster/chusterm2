import {
  useCrmCommandHotKeys,
  normalizeText,
  extractInitials,
  formatCurrency,
  buildContactAction,
  buildDealAction,
} from '../useCrmCommandHotKeys';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useLocale } from 'shared/composables/useLocale';
import { frontendURL } from 'dashboard/helper/URLHelper';

vi.mock('dashboard/composables/store');
vi.mock('vue-i18n');
vi.mock('vue-router');
vi.mock('shared/composables/useLocale');
vi.mock('dashboard/helper/URLHelper');

describe('useCrmCommandHotKeys', () => {
  let store;
  const routerPushMock = vi.fn();

  beforeEach(() => {
    routerPushMock.mockClear();
    store = {
      getters: {
        getCurrentAccountId: 1,
        'accounts/isFeatureEnabledonAccount': vi.fn().mockReturnValue(true),
        'contacts/getContacts': [
          {
            id: 101,
            name: 'Ana Silva',
            email: 'ana@empresa.com',
            phone_number: '+5511999998888',
            company_name: 'Tech Corp',
          },
        ],
        'crm/getDeals': [
          {
            id: 201,
            title: 'Contrato Enterprise',
            value: 50000,
            currency: 'BRL',
            stage: { name: 'Proposta' },
            contact: { name: 'Ana Silva' },
          },
        ],
      },
    };

    useStore.mockReturnValue(store);
    useMapGetter.mockImplementation(key => ({
      value: store.getters[key],
    }));

    useI18n.mockReturnValue({ t: vi.fn(key => key) });
    useRouter.mockReturnValue({ push: routerPushMock });
    useLocale.mockReturnValue({ resolvedLocale: { value: 'pt-BR' } });
    frontendURL.mockImplementation(url => `/${url}`);
  });

  describe('Recent contacts and deals from Vuex store', () => {
    it('provides navigation commands for store contacts and deals', () => {
      const { crmRecentHotKeys } = useCrmCommandHotKeys();
      expect(crmRecentHotKeys.value.length).toBe(2);

      const contactAction = crmRecentHotKeys.value.find(
        act => act.id === 'recent_contact_101'
      );
      expect(contactAction).toBeDefined();
      expect(contactAction.title).toContain('Ana Silva');
      expect(contactAction.title).toContain('Tech Corp');
      expect(contactAction.section).toBe(
        'COMMAND_BAR.SECTIONS.RECENT_CONTACTS'
      );

      const dealAction = crmRecentHotKeys.value.find(
        act => act.id === 'recent_deal_201'
      );
      expect(dealAction).toBeDefined();
      expect(dealAction.title).toContain('Contrato Enterprise');
      expect(dealAction.title).toContain('Proposta');
      expect(dealAction.section).toBe('COMMAND_BAR.SECTIONS.RECENT_DEALS');
    });

    it('navigates to contact details on contact action click', () => {
      const { crmRecentHotKeys } = useCrmCommandHotKeys();
      const contactAction = crmRecentHotKeys.value.find(
        act => act.id === 'recent_contact_101'
      );
      contactAction.handler();
      expect(routerPushMock).toHaveBeenCalledWith('/accounts/1/contacts/101');
    });

    it('navigates to deal details on deal action click', () => {
      const { crmRecentHotKeys } = useCrmCommandHotKeys();
      const dealAction = crmRecentHotKeys.value.find(
        act => act.id === 'recent_deal_201'
      );
      dealAction.handler();
      expect(routerPushMock).toHaveBeenCalledWith('/accounts/1/crm/deals/201');
    });

    it('handles empty store gracefully', () => {
      store.getters['contacts/getContacts'] = null;
      store.getters['crm/getDeals'] = null;

      const { crmRecentHotKeys } = useCrmCommandHotKeys();
      expect(crmRecentHotKeys.value).toEqual([]);
    });
  });

  describe('Utility functions', () => {
    it('normalizes text and strips diacritics', () => {
      expect(normalizeText('Negócios & Automações')).toBe(
        'negocios & automacoes'
      );
      expect(normalizeText('')).toBe('');
      expect(normalizeText(null)).toBe('');
    });

    it('extracts initials from multi-word strings', () => {
      expect(extractInitials('João Pedro Silva')).toBe('jps');
      expect(extractInitials('Alpha')).toBe('a');
      expect(extractInitials('')).toBe('');
    });

    it('formats currency values correctly', () => {
      const formatted = formatCurrency(1500, 'BRL', 'pt-BR');
      expect(formatted).toMatch(/1\.500|1500/);
      expect(formatCurrency(null)).toBe('');
      expect(formatCurrency('abc')).toBe('');
    });

    it('buildContactAction formats keywords with search tags and prefixes', () => {
      const action = buildContactAction({
        contact: {
          id: 42,
          name: 'Carlos Mendes',
          email: 'carlos@empresa.com',
          phone_number: '11999990000',
          company_name: 'Empresa X',
        },
        accountId: 1,
        t: key => key,
        isRecent: false,
        router: { push: vi.fn() },
      });

      expect(action.id).toBe('dynamic_contact_42');
      expect(action.keywords).toContain('@contact');
      expect(action.keywords).toContain('@contato');
      expect(action.keywords).toContain('carlos mendes');
      expect(action.keywords).toContain('cm');
    });

    it('buildDealAction formats keywords with deal tags and currency prefixes', () => {
      const action = buildDealAction({
        deal: {
          id: 88,
          title: 'Venda de Software',
          value: 12000,
          currency: 'BRL',
          stage: { name: 'Negociação' },
          contact: { name: 'Carlos Mendes' },
        },
        accountId: 1,
        t: key => key,
        isRecent: false,
        router: { push: vi.fn() },
        locale: 'pt-BR',
      });

      expect(action.id).toBe('dynamic_deal_88');
      expect(action.keywords).toContain('#deal');
      expect(action.keywords).toContain('#negocio');
      expect(action.keywords).toContain('negociacao');
      expect(action.keywords).toContain('venda de software');
    });
  });
});
