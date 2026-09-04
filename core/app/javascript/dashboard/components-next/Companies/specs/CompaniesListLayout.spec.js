import { mount, flushPromises } from '@vue/test-utils';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { createPinia, setActivePinia } from 'pinia';
import CompaniesListLayout from '../CompaniesListLayout.vue';
import { useCompaniesStore } from 'dashboard/stores/companies';
import CompanyAPI from 'dashboard/api/companies';
import * as composables from 'dashboard/composables';

// Mock dialog functions for DsDrawer
HTMLDialogElement.prototype.showModal = vi.fn();
HTMLDialogElement.prototype.close = vi.fn();

vi.mock('dashboard/api/companies', () => ({
  default: {
    listContacts: vi.fn(),
  },
}));

vi.mock('dashboard/composables', () => ({
  useAlert: vi.fn(),
  useTrack: vi.fn(),
}));

const mockCompanies = [
  {
    id: 1,
    name: 'Acme International',
    domain: 'acme.com',
    description: 'A global tools and hardware company',
    contactsCount: 15,
    updatedAt: '2026-03-01T10:00:00Z',
  },
  {
    id: 2,
    name: 'Globex Corporation',
    domain: 'globex.org',
    description: 'High tech innovations',
    contactsCount: 8,
    updatedAt: '2026-03-02T12:00:00Z',
  },
];

describe('CompaniesListLayout.vue', () => {
  let pinia;
  let companiesStore;

  beforeEach(() => {
    vi.clearAllMocks();
    pinia = createPinia();
    setActivePinia(pinia);
    companiesStore = useCompaniesStore();
    companiesStore.records = [...mockCompanies];
    companiesStore.update = vi.fn().mockResolvedValue({});
    CompanyAPI.listContacts.mockResolvedValue({
      data: {
        payload: [
          {
            id: 101,
            name: 'Alice Cooper',
            email: 'alice@acme.com',
            phone_number: '+123456789',
          },
        ],
      },
    });
  });

  const createWrapper = (props = {}) => {
    return mount(CompaniesListLayout, {
      global: {
        plugins: [pinia],
        stubs: {
          Icon: {
            props: ['icon'],
            template: '<span :data-icon="icon" />',
          },
          CompanyHeader: {
            template: '<div data-testid="company-header" />',
          },
          PaginationFooter: {
            template: '<div data-testid="pagination-footer" />',
          },
        },
        mocks: {
          $t: (key, fallback) =>
            typeof fallback === 'object' ? key : fallback || key,
          $te: () => true,
        },
      },
      props: {
        companies: mockCompanies,
        totalItems: 2,
        ...props,
      },
    });
  };

  it('renders the data grid with company columns and rows', () => {
    const wrapper = createWrapper();

    expect(wrapper.text()).toContain('Acme International');
    expect(wrapper.text()).toContain('acme.com');
    expect(wrapper.text()).toContain('Globex Corporation');
    expect(wrapper.text()).toContain('globex.org');
  });

  it('handles cellUpdate on company grid and updates store', async () => {
    const wrapper = createWrapper();
    const dataGrid = wrapper.findComponent({ name: 'DsDataGrid' });

    expect(dataGrid.exists()).toBe(true);

    await dataGrid.vm.$emit('cellUpdate', {
      rowId: 1,
      columnId: 'name',
      value: 'Acme Worldwide',
      previousValue: 'Acme International',
    });
    await flushPromises();

    expect(companiesStore.update).toHaveBeenCalledWith({
      id: 1,
      name: 'Acme Worldwide',
    });
    expect(composables.useAlert).toHaveBeenCalled();
  });

  it('rolls back cellUpdate if store update fails', async () => {
    companiesStore.update.mockRejectedValueOnce(new Error('Update failed'));
    const wrapper = createWrapper();
    const dataGrid = wrapper.findComponent({ name: 'DsDataGrid' });

    await dataGrid.vm.$emit('cellUpdate', {
      rowId: 1,
      columnId: 'name',
      value: 'Failed Name',
      previousValue: 'Acme International',
    });
    await flushPromises();

    expect(companiesStore.update).toHaveBeenCalledWith({
      id: 1,
      name: 'Failed Name',
    });
    expect(companiesStore.update).toHaveBeenCalledWith({
      id: 1,
      name: 'Acme International',
    });
    expect(composables.useAlert).toHaveBeenCalled();
  });

  it('opens DsRecordDrawer on row click with company 360 overview and fetches contacts', async () => {
    const wrapper = createWrapper();
    const dataGrid = wrapper.findComponent({ name: 'DsDataGrid' });

    await dataGrid.vm.$emit('rowClick', mockCompanies[0]);
    await flushPromises();

    const drawer = wrapper.findComponent({ name: 'DsRecordDrawer' });
    expect(drawer.exists()).toBe(true);
    expect(drawer.props('open')).toBe(true);
    expect(drawer.props('title')).toBe('Acme International');
    expect(drawer.props('subtitle')).toBe('acme.com');

    expect(CompanyAPI.listContacts).toHaveBeenCalledWith(1);
  });
});
