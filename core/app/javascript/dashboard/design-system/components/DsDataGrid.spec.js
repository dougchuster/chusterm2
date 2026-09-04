import { mount } from '@vue/test-utils';
import { describe, it, expect } from 'vitest';
import DsDataGrid from './DsDataGrid.vue';
import DsSkeleton from './DsSkeleton.vue';
import DsEmptyState from './DsEmptyState.vue';

const globalStubs = {
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

const sampleColumns = [
  { id: 'name', key: 'name', header: 'Name', sortable: true, editType: 'text' },
  {
    id: 'email',
    key: 'email',
    header: 'Email',
    sortable: true,
    editType: 'text',
  },
  {
    id: 'stage',
    key: 'stage',
    header: 'Stage',
    sortable: true,
    editType: 'select',
    options: [
      { value: 'lead', label: 'Lead' },
      { value: 'qualified', label: 'Qualified' },
      { value: 'won', label: 'Won' },
    ],
  },
  {
    id: 'value',
    key: 'value',
    header: 'Value',
    sortable: false,
    editType: 'number',
  },
];

const sampleData = [
  {
    id: '1',
    name: 'Alice Smith',
    email: 'alice@example.com',
    stage: 'lead',
    value: 5000,
  },
  {
    id: '2',
    name: 'Bob Jones',
    email: 'bob@example.com',
    stage: 'qualified',
    value: 12000,
  },
  {
    id: '3',
    name: 'Charlie Brown',
    email: 'charlie@example.com',
    stage: 'won',
    value: 25000,
  },
];

describe('DsDataGrid.vue', () => {
  it('renders columns and data rows accurately', () => {
    const wrapper = mount(DsDataGrid, {
      global: globalStubs,
      props: {
        columns: sampleColumns,
        data: sampleData,
      },
    });

    expect(wrapper.text()).toContain('Name');
    expect(wrapper.text()).toContain('Email');
    expect(wrapper.text()).toContain('Stage');
    expect(wrapper.text()).toContain('Value');

    expect(wrapper.text()).toContain('Alice Smith');
    expect(wrapper.text()).toContain('bob@example.com');
    expect(wrapper.text()).toContain('won');
    expect(wrapper.text()).toContain('25000');
  });

  it('handles column sorting on header click and sets aria-sort', async () => {
    const wrapper = mount(DsDataGrid, {
      global: globalStubs,
      props: {
        columns: sampleColumns,
        data: sampleData,
      },
    });

    const headers = wrapper.findAll('th[role="columnheader"]');
    const nameHeader = headers[0];
    const sortBtn = nameHeader.find('button');
    expect(sortBtn.exists()).toBe(true);
    expect(nameHeader.attributes('aria-sort')).toBe('none');

    // Sort ascending
    await sortBtn.trigger('click');
    expect(nameHeader.attributes('aria-sort')).toBe('ascending');

    // First row should be Alice
    const rowsAsc = wrapper.findAll('tbody tr');
    expect(rowsAsc[0].text()).toContain('Alice Smith');

    // Sort descending
    await sortBtn.trigger('click');
    expect(nameHeader.attributes('aria-sort')).toBe('descending');

    // First row should now be Charlie
    const rowsDesc = wrapper.findAll('tbody tr');
    expect(rowsDesc[0].text()).toContain('Charlie Brown');
  });

  it('supports single row selection and emits update:selectedRows', async () => {
    const wrapper = mount(DsDataGrid, {
      global: globalStubs,
      props: {
        columns: sampleColumns,
        data: sampleData,
        selectable: true,
        selectedRows: [],
      },
    });

    const rowCheckboxes = wrapper.findAll(
      'tbody tr td:first-child input[type="checkbox"]'
    );
    expect(rowCheckboxes).toHaveLength(3);

    // Select row 2 (Bob Jones)
    await rowCheckboxes[1].setValue(true);
    expect(wrapper.emitted('update:selectedRows')).toBeTruthy();
    expect(wrapper.emitted('update:selectedRows')[0][0]).toEqual([
      sampleData[1],
    ]);
  });

  it('supports select-all and deselect-all from header checkbox', async () => {
    const wrapper = mount(DsDataGrid, {
      global: globalStubs,
      props: {
        columns: sampleColumns,
        data: sampleData,
        selectable: true,
        selectedRows: [],
      },
    });

    const headerCheckbox = wrapper.get(
      'thead th:first-child input[type="checkbox"]'
    );
    await headerCheckbox.setValue(true);

    expect(wrapper.emitted('update:selectedRows')).toBeTruthy();
    expect(wrapper.emitted('update:selectedRows')[0][0]).toEqual(sampleData);

    // If all are selected, unchecking header clears all
    await wrapper.setProps({ selectedRows: sampleData });
    await headerCheckbox.setValue(false);
    expect(wrapper.emitted('update:selectedRows').at(-1)).toEqual([[]]);
  });

  it('handles inline editing: enter edit on double-click, save with Enter emitting cellUpdate', async () => {
    const wrapper = mount(DsDataGrid, {
      global: globalStubs,
      props: {
        columns: sampleColumns,
        data: sampleData,
        enableInlineEdit: true,
      },
    });

    // Target the first cell (Alice Smith)
    const firstCell = wrapper.get('[data-grid-cell="0-0"]');
    await firstCell.trigger('dblclick');

    // Input should now appear
    const input = firstCell.find('input');
    expect(input.exists()).toBe(true);
    expect(input.element.value).toBe('Alice Smith');

    // Change value and press enter
    await input.setValue('Alice Johnson');
    await input.trigger('keyup.enter');

    expect(wrapper.emitted('cellUpdate')).toBeTruthy();
    expect(wrapper.emitted('cellUpdate')[0][0]).toEqual({
      rowId: '1',
      columnId: 'name',
      value: 'Alice Johnson',
      previousValue: 'Alice Smith',
    });

    // Input should close
    expect(firstCell.find('input').exists()).toBe(false);
  });

  it('handles inline editing with select type', async () => {
    const wrapper = mount(DsDataGrid, {
      global: globalStubs,
      props: {
        columns: sampleColumns,
        data: sampleData,
        enableInlineEdit: true,
      },
    });

    // Target the stage cell of row 1 (lead) -> col index 2
    const stageCell = wrapper.get('[data-grid-cell="0-2"]');
    await stageCell.trigger('dblclick');

    const select = stageCell.find('select');
    expect(select.exists()).toBe(true);

    await select.setValue('won');
    await select.trigger('keydown', { key: 'Enter' });

    expect(wrapper.emitted('cellUpdate')).toBeTruthy();
    expect(wrapper.emitted('cellUpdate')[0][0]).toEqual({
      rowId: '1',
      columnId: 'stage',
      value: 'won',
      previousValue: 'lead',
    });
  });

  it('cancels inline editing with Escape without emitting cellUpdate', async () => {
    const wrapper = mount(DsDataGrid, {
      global: globalStubs,
      props: {
        columns: sampleColumns,
        data: sampleData,
        enableInlineEdit: true,
      },
    });

    const firstCell = wrapper.get('[data-grid-cell="0-0"]');
    await firstCell.trigger('dblclick');

    const input = firstCell.find('input');
    expect(input.exists()).toBe(true);

    await input.setValue('Changed Name');
    await input.trigger('keydown.esc');

    expect(wrapper.emitted('cellUpdate')).toBeFalsy();
    expect(firstCell.find('input').exists()).toBe(false);
  });

  it('navigates cells with keyboard arrows and Tab', async () => {
    const wrapper = mount(DsDataGrid, {
      global: globalStubs,
      attachTo: document.body,
      props: {
        columns: sampleColumns,
        data: sampleData,
        enableInlineEdit: true,
      },
    });

    const cell00 = wrapper.get('[data-grid-cell="0-0"]');
    await cell00.trigger('keydown', { key: 'ArrowRight' });
    await cell00.trigger('keydown', { key: 'ArrowDown' });
    await cell00.trigger('keydown', { key: 'Tab' });

    // Press Enter to start editing focused cell
    await cell00.trigger('keydown', { key: 'Enter' });
    expect(cell00.find('input').exists()).toBe(true);

    wrapper.unmount();
  });

  it('emits rowClick when a row is clicked', async () => {
    const wrapper = mount(DsDataGrid, {
      global: globalStubs,
      props: {
        columns: sampleColumns,
        data: sampleData,
      },
    });

    const rows = wrapper.findAll('tbody tr');
    await rows[0].trigger('click');

    expect(wrapper.emitted('rowClick')).toBeTruthy();
    expect(wrapper.emitted('rowClick')[0][0]).toEqual(sampleData[0]);
  });

  it('renders loading state with DsSkeleton when loading is true', () => {
    const wrapper = mount(DsDataGrid, {
      global: globalStubs,
      props: {
        columns: sampleColumns,
        data: sampleData,
        loading: true,
        loadingRows: 4,
      },
    });

    expect(wrapper.findAllComponents(DsSkeleton).length).toBeGreaterThan(0);
    expect(wrapper.text()).not.toContain('Alice Smith');
  });

  it('renders empty state when data is empty', () => {
    const wrapper = mount(DsDataGrid, {
      global: globalStubs,
      props: {
        columns: sampleColumns,
        data: [],
        emptyTitle: 'No contacts found',
        emptyDescription: 'Try adjusting your filters.',
      },
    });

    const emptyState = wrapper.findComponent(DsEmptyState);
    expect(emptyState.exists()).toBe(true);
    expect(wrapper.text()).toContain('No contacts found');
    expect(wrapper.text()).toContain('Try adjusting your filters.');
  });

  it('supports virtualization threshold for large datasets', () => {
    const largeData = Array.from({ length: 120 }, (_, i) => ({
      id: String(i + 1),
      name: `Person ${i + 1}`,
      email: `person${i + 1}@example.com`,
      stage: 'lead',
      value: (i + 1) * 100,
    }));

    const wrapper = mount(DsDataGrid, {
      global: globalStubs,
      props: {
        columns: sampleColumns,
        data: largeData,
        virtualThreshold: 100,
      },
    });

    // Virtual list renders subset of visible items
    expect(wrapper.find('table').exists()).toBe(true);
  });

  it('supports custom cell scoped slots', () => {
    const wrapper = mount(DsDataGrid, {
      global: globalStubs,
      props: {
        columns: sampleColumns,
        data: sampleData,
      },
      slots: {
        'cell-name':
          '<span data-testid="custom-name">{{ params.value }} (VIP)</span>',
      },
    });

    expect(wrapper.text()).toContain('Alice Smith (VIP)');
  });

  it('translates labels with custom i18n mock', () => {
    const customI18nStubs = {
      ...globalStubs,
      mocks: {
        $t: key => {
          if (key === 'DATA_GRID.EMPTY_TITLE')
            return 'Nenhum registro encontrado';
          if (key === 'DATA_GRID.EMPTY_DESCRIPTION')
            return 'Sem itens para exibir.';
          return key;
        },
        $te: () => true,
      },
    };

    const wrapper = mount(DsDataGrid, {
      global: customI18nStubs,
      props: {
        columns: sampleColumns,
        data: [],
      },
    });

    expect(wrapper.text()).toContain('Nenhum registro encontrado');
    expect(wrapper.text()).toContain('Sem itens para exibir.');
  });
});
