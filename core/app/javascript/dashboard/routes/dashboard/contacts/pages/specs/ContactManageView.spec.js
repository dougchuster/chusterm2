import { mount, flushPromises } from '@vue/test-utils';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { createStore } from 'vuex';
import ContactManageView from '../ContactManageView.vue';
import BulkActionsAPI from 'dashboard/api/bulkActions';
import * as composables from 'dashboard/composables';

// Mock dialog functions for DsDrawer
HTMLDialogElement.prototype.showModal = vi.fn();
HTMLDialogElement.prototype.close = vi.fn();

vi.mock('dashboard/api/bulkActions', () => ({
  default: {
    create: vi.fn(),
  },
}));

vi.mock('dashboard/composables', () => ({
  useAlert: vi.fn(),
  useTrack: vi.fn(),
}));

vi.mock('vue-router', () => ({
  useRoute: () => ({
    params: {},
    query: {},
  }),
  useRouter: () => ({
    push: vi.fn(),
    replace: vi.fn(),
  }),
}));

const mockContacts = [
  {
    id: 1,
    name: 'John Doe',
    email: 'john@example.com',
    phone_number: '+1234567890',
    additional_attributes: { company_name: 'Acme Corp' },
    relationship_status: 'lead',
    lifecycle_stage: 'triage',
    location: 'New York',
    blocked: false,
  },
  {
    id: 2,
    name: 'Jane Smith',
    email: 'jane@example.com',
    phone_number: '+1987654321',
    additional_attributes: { company_name: 'Stark Industries' },
    relationship_status: 'customer',
    lifecycle_stage: 'active_customer',
    location: 'Boston',
    blocked: false,
  },
];

describe('ContactManageView.vue', () => {
  let store;
  let updateError;

  beforeEach(() => {
    vi.clearAllMocks();
    updateError = null;

    store = createStore({
      getters: {
        getUISettings: () => ({
          contacts_grid_visibility: {},
          contacts_grid_order: [],
          contacts_grid_sizing: {},
        }),
      },
      actions: {
        updateUISettings: vi.fn(),
      },
      modules: {
        contacts: {
          namespaced: false,
          state: {
            records: mockContacts,
            uiFlags: { isFetching: false, isFetchingItem: false },
            meta: { count: 2, currentPage: 1 },
          },
          getters: {
            'contacts/getContactsList': () => mockContacts,
            'contacts/getContactById': () => id =>
              mockContacts.find(c => String(c.id) === String(id)),
            'contacts/getUIFlags': () => ({
              isFetching: false,
              isFetchingItem: false,
            }),
            'contacts/getMeta': () => ({ count: 2, currentPage: 1 }),
          },
          actions: {
            'contacts/get': vi.fn(),
            'contacts/search': vi.fn(),
            'contacts/show': vi.fn(),
            'contacts/update': vi.fn((ctx, payload) => {
              if (updateError) {
                return Promise.reject(updateError);
              }
              return Promise.resolve(payload);
            }),
          },
          mutations: {
            'contacts/EDIT_CONTACT': vi.fn(),
            'contacts/SET_CONTACTS': vi.fn(),
          },
        },
      },
    });
  });

  const createWrapper = () => {
    return mount(ContactManageView, {
      global: {
        plugins: [store],
        stubs: {
          Icon: {
            props: ['icon'],
            template: '<span :data-icon="icon" />',
          },
        },
        mocks: {
          $t: (key, fallback) =>
            typeof fallback === 'object' ? key : fallback || key,
          $te: () => true,
        },
      },
    });
  };

  it('renders the data grid with contact columns and records', () => {
    const wrapper = createWrapper();

    expect(wrapper.text()).toContain('John Doe');
    expect(wrapper.text()).toContain('john@example.com');
    expect(wrapper.text()).toContain('Acme Corp');
    expect(wrapper.text()).toContain('Jane Smith');
    expect(wrapper.text()).toContain('Stark Industries');
  });

  it('handles cellUpdate with optimistic update and dispatches contacts/update', async () => {
    const commitSpy = vi.spyOn(store, 'commit');
    const dispatchSpy = vi.spyOn(store, 'dispatch');
    const wrapper = createWrapper();
    const dataGrid = wrapper.findComponent({ name: 'DsDataGrid' });

    expect(dataGrid.exists()).toBe(true);

    await dataGrid.vm.$emit('cellUpdate', {
      rowId: 1,
      columnId: 'name',
      value: 'John Updated',
      previousValue: 'John Doe',
    });
    await flushPromises();

    // Optimistic commit
    expect(commitSpy).toHaveBeenCalledWith('contacts/EDIT_CONTACT', {
      id: 1,
      name: 'John Updated',
    });

    // API dispatch
    expect(dispatchSpy).toHaveBeenCalledWith('contacts/update', {
      id: 1,
      name: 'John Updated',
    });

    expect(composables.useAlert).toHaveBeenCalled();
  });

  it('rolls back optimistic update and alerts user on API update failure', async () => {
    updateError = new Error('Network error');
    const commitSpy = vi.spyOn(store, 'commit');
    const wrapper = createWrapper();
    const dataGrid = wrapper.findComponent({ name: 'DsDataGrid' });

    await dataGrid.vm.$emit('cellUpdate', {
      rowId: 1,
      columnId: 'name',
      value: 'Failed Name',
      previousValue: 'John Doe',
    });
    await flushPromises();

    // Initial optimistic commit
    expect(commitSpy).toHaveBeenCalledWith('contacts/EDIT_CONTACT', {
      id: 1,
      name: 'Failed Name',
    });

    // Rollback commit
    expect(commitSpy).toHaveBeenCalledWith('contacts/EDIT_CONTACT', {
      id: 1,
      name: 'John Doe',
    });

    expect(composables.useAlert).toHaveBeenCalled();
  });

  it('opens DsRecordDrawer on row click with contact details', async () => {
    const wrapper = createWrapper();
    const dataGrid = wrapper.findComponent({ name: 'DsDataGrid' });

    await dataGrid.vm.$emit('rowClick', mockContacts[0]);
    await flushPromises();

    const drawer = wrapper.findComponent({ name: 'DsRecordDrawer' });
    expect(drawer.exists()).toBe(true);
    expect(drawer.props('open')).toBe(true);
    expect(drawer.props('title')).toBe('John Doe');
    expect(drawer.props('subtitle')).toBe('john@example.com');
  });

  it('performs bulk delete action when selected rows are deleted', async () => {
    BulkActionsAPI.create.mockResolvedValueOnce({});
    const wrapper = createWrapper();
    const dataGrid = wrapper.findComponent({ name: 'DsDataGrid' });

    // Select contacts
    await dataGrid.vm.$emit('update:selectedRows', [
      mockContacts[0],
      mockContacts[1],
    ]);
    await flushPromises();

    const bulkBar = wrapper.findComponent({ name: 'DsBulkActionBar' });
    expect(bulkBar.exists()).toBe(true);
    expect(bulkBar.props('count')).toBe(2);

    await bulkBar.vm.$emit('action', 'delete');
    await flushPromises();

    expect(BulkActionsAPI.create).toHaveBeenCalledWith({
      type: 'Contact',
      ids: [1, 2],
      action_name: 'delete',
    });
    expect(composables.useAlert).toHaveBeenCalled();
  });
});
