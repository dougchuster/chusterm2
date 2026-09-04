import { mount } from '@vue/test-utils';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import DsRecordDrawer from './DsRecordDrawer.vue';
import DsSkeleton from './DsSkeleton.vue';
import DsEmptyState from './DsEmptyState.vue';

// Mock dialog HTML methods for jsdom
beforeEach(() => {
  HTMLDialogElement.prototype.showModal = vi.fn(function showModal() {
    this.open = true;
  });
  HTMLDialogElement.prototype.close = vi.fn(function close() {
    this.open = false;
  });
});

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

const sampleFields = [
  {
    id: 'name',
    label: 'Contact Name',
    value: 'John Doe',
    editable: true,
    editType: 'text',
  },
  {
    id: 'email',
    label: 'Work Email',
    value: 'john.doe@example.com',
    editable: true,
    editType: 'text',
  },
  {
    id: 'deal_stage',
    label: 'Stage',
    value: 'qualified',
    editable: true,
    editType: 'select',
    options: [
      { value: 'lead', label: 'Lead' },
      { value: 'qualified', label: 'Qualified' },
      { value: 'negotiation', label: 'In Negotiation' },
      { value: 'won', label: 'Closed Won' },
    ],
  },
  {
    id: 'deal_value',
    label: 'Estimated Value',
    value: 15000,
    editable: true,
    editType: 'number',
  },
  {
    id: 'created_at',
    label: 'Created At',
    value: '2025-01-15',
    editable: false,
  },
  {
    id: 'empty_field',
    label: 'Phone Number',
    value: '',
    editable: true,
    editType: 'text',
  },
];

const sampleQuickActions = [
  {
    id: 'whatsapp',
    label: 'Send WhatsApp',
    icon: 'i-lucide-message-circle',
    variant: 'primary',
  },
  {
    id: 'schedule_activity',
    label: 'Schedule Activity',
    icon: 'i-lucide-calendar',
    variant: 'secondary',
  },
];

describe('DsRecordDrawer.vue', () => {
  it('renders title, subtitle, and avatar in the header', () => {
    const wrapper = mount(DsRecordDrawer, {
      global: globalStubs,
      props: {
        open: true,
        title: 'Acme Corp',
        subtitle: 'Enterprise Tier • 120 employees',
        avatarUrl: 'https://example.com/avatar.jpg',
        avatarName: 'Acme Corp',
      },
    });

    expect(wrapper.text()).toContain('Acme Corp');
    expect(wrapper.text()).toContain('Enterprise Tier • 120 employees');
  });

  it('emits close event when clicking the header close button', async () => {
    const wrapper = mount(DsRecordDrawer, {
      global: globalStubs,
      props: {
        open: true,
        title: 'Acme Corp',
      },
    });

    const closeBtn = wrapper.find('button[aria-label="Close record panel"]');
    expect(closeBtn.exists()).toBe(true);
    await closeBtn.trigger('click');

    expect(wrapper.emitted('close')).toBeTruthy();
  });

  it('renders default tabs (Overview, Timeline, Notes) and changes active tab emitting update:activeTab', async () => {
    const wrapper = mount(DsRecordDrawer, {
      global: globalStubs,
      props: {
        open: true,
        title: 'Acme Corp',
        activeTab: 'overview',
      },
    });

    expect(wrapper.text()).toContain('Overview');
    expect(wrapper.text()).toContain('Timeline');
    expect(wrapper.text()).toContain('Notes');

    const tabs = wrapper.findAll('button[role="tab"]');
    expect(tabs.length).toBe(3);

    // Click Timeline tab (index 1)
    await tabs[1].trigger('click');
    expect(wrapper.emitted('update:activeTab')).toBeTruthy();
    expect(wrapper.emitted('update:activeTab')[0][0]).toBe('timeline');
  });

  it('renders custom tabs when provided', () => {
    const customTabs = [
      { id: 'summary', label: 'Summary', icon: 'i-lucide-info' },
      { id: 'deals', label: 'Deals', icon: 'i-lucide-dollar-sign' },
    ];

    const wrapper = mount(DsRecordDrawer, {
      global: globalStubs,
      props: {
        open: true,
        title: 'Acme Corp',
        tabs: customTabs,
        activeTab: 'summary',
      },
    });

    expect(wrapper.text()).toContain('Summary');
    expect(wrapper.text()).toContain('Deals');
    expect(wrapper.text()).not.toContain('Timeline');
  });

  it('renders fields with proper display labels and values', () => {
    const wrapper = mount(DsRecordDrawer, {
      global: globalStubs,
      props: {
        open: true,
        title: 'John Doe',
        fields: sampleFields,
        activeTab: 'overview',
      },
    });

    expect(wrapper.text()).toContain('Contact Name');
    expect(wrapper.text()).toContain('John Doe');
    expect(wrapper.text()).toContain('Work Email');
    expect(wrapper.text()).toContain('john.doe@example.com');
    expect(wrapper.text()).toContain('Stage');
    // Select option label for 'qualified' is 'Qualified'
    expect(wrapper.text()).toContain('Qualified');
    expect(wrapper.text()).toContain('Estimated Value');
    expect(wrapper.text()).toContain('15000');
    expect(wrapper.text()).toContain('Created At');
    expect(wrapper.text()).toContain('2025-01-15');
    // Empty field placeholder
    expect(wrapper.text()).toContain('Phone Number');
    expect(wrapper.text()).toContain('—');
  });

  it('handles inline editing for text fields: enters edit mode, Enter confirms and emits fieldUpdate', async () => {
    const wrapper = mount(DsRecordDrawer, {
      global: globalStubs,
      props: {
        open: true,
        title: 'John Doe',
        fields: sampleFields,
        activeTab: 'overview',
      },
    });

    // Find the first field display area
    const fieldDisplays = wrapper.findAll('[data-testid="field-display"]');
    expect(fieldDisplays.length).toBeGreaterThan(0);

    // Click to start editing 'name'
    await fieldDisplays[0].trigger('click');

    const editor = wrapper.find('[data-testid="field-editor"]');
    expect(editor.exists()).toBe(true);

    const input = editor.find('input');
    expect(input.exists()).toBe(true);
    expect(input.element.value).toBe('John Doe');

    // Update input value
    await input.setValue('Jane Doe');

    // Press Enter to save
    await input.trigger('keyup.enter');

    expect(wrapper.emitted('fieldUpdate')).toBeTruthy();
    expect(wrapper.emitted('fieldUpdate')[0][0]).toEqual({
      fieldId: 'name',
      value: 'Jane Doe',
      previousValue: 'John Doe',
    });
  });

  it('handles inline editing cancellation via Escape and cancel button', async () => {
    const wrapper = mount(DsRecordDrawer, {
      global: globalStubs,
      props: {
        open: true,
        title: 'John Doe',
        fields: sampleFields,
        activeTab: 'overview',
      },
    });

    // Start editing 'name'
    const fieldDisplays = wrapper.findAll('[data-testid="field-display"]');
    await fieldDisplays[0].trigger('click');

    expect(wrapper.find('[data-testid="field-editor"]').exists()).toBe(true);

    // Click cancel button
    const cancelBtn = wrapper.find('[data-testid="field-cancel-button"]');
    await cancelBtn.trigger('click');

    // Editor should be closed
    expect(wrapper.find('[data-testid="field-editor"]').exists()).toBe(false);
    expect(wrapper.emitted('fieldUpdate')).toBeFalsy();
  });

  it('handles inline editing for select fields and saving with save button', async () => {
    const wrapper = mount(DsRecordDrawer, {
      global: globalStubs,
      props: {
        open: true,
        title: 'John Doe',
        fields: sampleFields,
        activeTab: 'overview',
      },
    });

    // Field index 2 is 'deal_stage'
    const fieldDisplays = wrapper.findAll('[data-testid="field-display"]');
    await fieldDisplays[2].trigger('click');

    const editor = wrapper.find('[data-testid="field-editor"]');
    expect(editor.exists()).toBe(true);

    const select = editor.find('select');
    expect(select.exists()).toBe(true);
    expect(select.element.value).toBe('qualified');

    // Change value to 'won'
    await select.setValue('won');

    // Click save button
    const saveBtn = wrapper.find('[data-testid="field-save-button"]');
    await saveBtn.trigger('click');

    expect(wrapper.emitted('fieldUpdate')).toBeTruthy();
    expect(wrapper.emitted('fieldUpdate')[0][0]).toEqual({
      fieldId: 'deal_stage',
      value: 'won',
      previousValue: 'qualified',
    });
  });

  it('does not allow editing non-editable fields', async () => {
    const wrapper = mount(DsRecordDrawer, {
      global: globalStubs,
      props: {
        open: true,
        title: 'John Doe',
        fields: sampleFields,
        activeTab: 'overview',
      },
    });

    // Field index 4 is 'created_at' with editable: false
    const allFieldRows = wrapper.findAll('.space-y-3 > .group');
    const nonEditableRow = allFieldRows[4];

    // Non-editable row does not have role="button" or cursor-pointer
    const displayDiv = nonEditableRow.find('[data-testid="field-display"]');
    expect(displayDiv.attributes('role')).toBeUndefined();

    await displayDiv.trigger('click');
    expect(wrapper.find('[data-testid="field-editor"]').exists()).toBe(false);
  });

  it('renders quick actions toolbar in footer and emits quickAction on click', async () => {
    const wrapper = mount(DsRecordDrawer, {
      global: globalStubs,
      props: {
        open: true,
        title: 'John Doe',
        quickActions: sampleQuickActions,
      },
    });

    const buttons = wrapper.findAll('footer button');
    expect(buttons.length).toBe(2);

    expect(buttons[0].text()).toContain('Send WhatsApp');
    await buttons[0].trigger('click');
    expect(wrapper.emitted('quickAction')).toBeTruthy();
    expect(wrapper.emitted('quickAction')[0][0]).toBe('whatsapp');

    expect(buttons[1].text()).toContain('Schedule Activity');
    await buttons[1].trigger('click');
    expect(wrapper.emitted('quickAction')[1][0]).toBe('schedule_activity');
  });

  it('renders loading skeletons in header and overview tab when loading is true', () => {
    const wrapper = mount(DsRecordDrawer, {
      global: globalStubs,
      props: {
        open: true,
        title: 'Loading Record',
        loading: true,
        fields: sampleFields,
        activeTab: 'overview',
      },
    });

    const skeletons = wrapper.findAllComponents(DsSkeleton);
    expect(skeletons.length).toBeGreaterThan(0);
  });

  it('renders empty states for timeline and notes tabs when no slot is provided', async () => {
    const wrapper = mount(DsRecordDrawer, {
      global: globalStubs,
      props: {
        open: true,
        title: 'John Doe',
        activeTab: 'timeline',
      },
    });

    const emptyStates = wrapper.findAllComponents(DsEmptyState);
    expect(emptyStates.length).toBe(1);
    expect(wrapper.text()).toContain('No activity recorded');

    // Switch to notes tab
    await wrapper.setProps({ activeTab: 'notes' });
    expect(wrapper.text()).toContain('No notes yet');
  });

  it('renders empty state for overview when fields array is empty', () => {
    const wrapper = mount(DsRecordDrawer, {
      global: globalStubs,
      props: {
        open: true,
        title: 'Empty Record',
        fields: [],
        activeTab: 'overview',
      },
    });

    const emptyStates = wrapper.findAllComponents(DsEmptyState);
    expect(emptyStates.length).toBe(1);
    expect(wrapper.text()).toContain('No fields to display');
  });

  it('renders custom slot contents for overview, timeline, notes, custom tab, and footer', () => {
    const wrapper = mount(DsRecordDrawer, {
      global: globalStubs,
      props: {
        open: true,
        title: 'Custom Slots',
        activeTab: 'timeline',
      },
      slots: {
        timeline:
          '<div data-testid="custom-timeline">Custom Timeline Items</div>',
        footer: '<div data-testid="custom-footer">Custom Footer Content</div>',
      },
    });

    expect(wrapper.find('[data-testid="custom-timeline"]').exists()).toBe(true);
    expect(wrapper.find('[data-testid="custom-timeline"]').text()).toBe(
      'Custom Timeline Items'
    );
    expect(wrapper.find('[data-testid="custom-footer"]').exists()).toBe(true);
    expect(wrapper.find('[data-testid="custom-footer"]').text()).toBe(
      'Custom Footer Content'
    );
  });
});
