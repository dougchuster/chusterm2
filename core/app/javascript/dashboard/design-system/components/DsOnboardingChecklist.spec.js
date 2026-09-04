import { mount } from '@vue/test-utils';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { routerKey } from 'vue-router';
import DsOnboardingChecklist from './DsOnboardingChecklist.vue';
import DsEmptyState from './DsEmptyState.vue';

const mockRouter = {
  push: vi.fn().mockResolvedValue(true),
  currentRoute: {
    value: {
      params: {},
    },
  },
};

const globalStubs = {
  provide: {
    [routerKey]: mockRouter,
  },
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

describe('DsOnboardingChecklist.vue', () => {
  let localStorageStore = {};

  beforeEach(() => {
    localStorageStore = {};
    mockRouter.push.mockClear();
    vi.stubGlobal('localStorage', {
      getItem: vi.fn(key => localStorageStore[key] || null),
      setItem: vi.fn((key, value) => {
        localStorageStore[key] = String(value);
      }),
      removeItem: vi.fn(key => {
        delete localStorageStore[key];
      }),
      clear: vi.fn(() => {
        localStorageStore = {};
      }),
    });
  });

  it('renders the 4 essential activation steps by default in English with i18n fallbacks', () => {
    const wrapper = mount(DsOnboardingChecklist, {
      global: globalStubs,
      props: { persist: false },
    });

    expect(wrapper.text()).toContain('Activation Guide');
    expect(wrapper.text()).toContain('Connect WhatsApp Channel');
    expect(wrapper.text()).toContain('Import Contacts');
    expect(wrapper.text()).toContain('Create First Pipeline');
    expect(wrapper.text()).toContain('Send First Message');

    const progressFill = wrapper.get(
      '[data-testid="onboarding-progress-fill"]'
    );
    expect(progressFill.attributes('style')).toContain('width: 0%');
  });

  it('calculates dynamic progress as steps are toggled and emits events', async () => {
    const wrapper = mount(DsOnboardingChecklist, {
      global: globalStubs,
      props: { persist: false },
    });

    const checkbox1 = wrapper.get(
      '[data-testid="step-checkbox-connect_channel"]'
    );
    await checkbox1.trigger('click');

    expect(wrapper.emitted('stepToggle')).toBeTruthy();
    expect(wrapper.emitted('stepToggle')[0][0]).toMatchObject({
      stepId: 'connect_channel',
      completed: true,
      completedSteps: ['connect_channel'],
    });
    expect(wrapper.emitted('update:completedSteps')[0][0]).toEqual([
      'connect_channel',
    ]);

    const progressFill = wrapper.get(
      '[data-testid="onboarding-progress-fill"]'
    );
    expect(progressFill.attributes('style')).toContain('width: 25%');
    expect(
      wrapper.get('[data-testid="onboarding-percent-indicator"]').text()
    ).toBe('25%');

    // Complete all remaining steps
    await wrapper
      .get('[data-testid="step-checkbox-import_contacts"]')
      .trigger('click');
    await wrapper
      .get('[data-testid="step-checkbox-create_pipeline"]')
      .trigger('click');
    await wrapper
      .get('[data-testid="step-checkbox-send_message"]')
      .trigger('click');

    expect(
      wrapper.get('[data-testid="onboarding-percent-indicator"]').text()
    ).toBe('100%');
    expect(
      wrapper.find('[data-testid="onboarding-complete-banner"]').exists()
    ).toBe(true);
    expect(wrapper.emitted('complete')).toBeTruthy();
  });

  it('supports expanding and collapsing the widget', async () => {
    const wrapper = mount(DsOnboardingChecklist, {
      global: globalStubs,
      props: { modelValue: true, persist: false },
    });

    expect(
      wrapper.find('[data-testid="onboarding-expanded-card"]').exists()
    ).toBe(true);

    const collapseButton = wrapper.get(
      '[data-testid="onboarding-collapse-button"]'
    );
    await collapseButton.trigger('click');

    expect(wrapper.emitted('update:modelValue')).toBeTruthy();
    expect(wrapper.emitted('update:modelValue').at(-1)).toEqual([false]);

    await wrapper.setProps({ modelValue: false });
    expect(
      wrapper.find('[data-testid="onboarding-expanded-card"]').exists()
    ).toBe(false);
    expect(
      wrapper.find('[data-testid="onboarding-collapsed-trigger"]').exists()
    ).toBe(true);

    // Click collapsed trigger to expand
    await wrapper
      .get('[data-testid="onboarding-collapsed-trigger"]')
      .trigger('click');
    expect(wrapper.emitted('update:modelValue').at(-1)).toEqual([true]);
  });

  it('triggers step action and emits stepAction with resolved accountId', async () => {
    const wrapper = mount(DsOnboardingChecklist, {
      global: globalStubs,
      props: {
        accountId: 42,
        persist: false,
      },
    });

    // The first incomplete step (connect_channel) is active by default
    const actionButton = wrapper.get(
      '[data-testid="step-action-button-connect_channel"]'
    );
    await actionButton.trigger('click');

    expect(wrapper.emitted('stepAction')).toBeTruthy();
    expect(wrapper.emitted('stepAction')[0][0]).toMatchObject({
      step: expect.objectContaining({ id: 'connect_channel' }),
      index: 0,
      path: '/app/accounts/42/settings/inboxes/new',
      route: 'settings_inbox_new',
    });
    expect(mockRouter.push).toHaveBeenCalledWith(
      '/app/accounts/42/settings/inboxes/new'
    );

    // Open another step accordion (import_contacts) and trigger its action
    const stepHeader = wrapper.get(
      '[data-testid="onboarding-step-import_contacts"] > div'
    );
    await stepHeader.trigger('click');

    const importAction = wrapper.get(
      '[data-testid="step-action-button-import_contacts"]'
    );
    await importAction.trigger('click');

    expect(wrapper.emitted('stepAction')[1][0]).toMatchObject({
      step: expect.objectContaining({ id: 'import_contacts' }),
      index: 1,
      path: '/app/accounts/42/contacts',
      route: 'contacts_dashboard',
    });
  });

  it('resolves step path cleanly without double slashes when accountId is empty', async () => {
    const wrapper = mount(DsOnboardingChecklist, {
      global: globalStubs,
      props: {
        accountId: '',
        persist: false,
      },
    });

    const actionButton = wrapper.get(
      '[data-testid="step-action-button-connect_channel"]'
    );
    await actionButton.trigger('click');

    expect(wrapper.emitted('stepAction')).toBeTruthy();
    const emitted = wrapper.emitted('stepAction')[0][0];
    expect(emitted.path).toBe('/app/settings/inboxes/new');
    expect(emitted.path).not.toContain('//');
    expect(emitted.path).not.toContain(':accountId');
  });

  it('synchronizes persisted state reactively when accountId is updated asynchronously', async () => {
    localStorageStore.chusterm_onboarding_ftue_999 = JSON.stringify({
      completedSteps: ['connect_channel', 'import_contacts', 'create_pipeline'],
      isExpanded: true,
      isDismissed: false,
    });

    const wrapper = mount(DsOnboardingChecklist, {
      global: globalStubs,
      props: {
        accountId: '',
        persist: true,
      },
    });

    // Initially 0% complete because accountId is empty
    expect(
      wrapper.get('[data-testid="onboarding-percent-indicator"]').text()
    ).toBe('0%');

    // Asynchronously resolve / update accountId to 999
    await wrapper.setProps({ accountId: 999 });

    // Expect the component to re-read localStorage for account 999 and reflect 75% progress
    expect(
      wrapper.get('[data-testid="onboarding-percent-indicator"]').text()
    ).toBe('75%');
  });

  it('persists and loads state from localStorage', async () => {
    localStorageStore.chusterm_onboarding_ftue_123 = JSON.stringify({
      completedSteps: ['connect_channel', 'import_contacts'],
      isExpanded: true,
      isDismissed: false,
    });

    const wrapper = mount(DsOnboardingChecklist, {
      global: globalStubs,
      props: {
        accountId: 123,
        persist: true,
      },
    });

    expect(
      wrapper.get('[data-testid="onboarding-percent-indicator"]').text()
    ).toBe('50%');

    // Toggle another step and verify localStorage save
    await wrapper
      .get('[data-testid="step-checkbox-create_pipeline"]')
      .trigger('click');

    expect(window.localStorage.setItem).toHaveBeenCalled();
    const lastSaved = JSON.parse(
      window.localStorage.setItem.mock.calls.at(-1)[1]
    );
    expect(lastSaved.completedSteps).toContain('create_pipeline');
  });

  it('handles dismiss action and unmounts region', async () => {
    const wrapper = mount(DsOnboardingChecklist, {
      global: globalStubs,
      props: { dismissible: true, persist: false },
    });

    const dismissButton = wrapper.get(
      '[data-testid="onboarding-dismiss-button"]'
    );
    await dismissButton.trigger('click');

    expect(wrapper.emitted('dismiss')).toBeTruthy();
    expect(
      wrapper.find('[data-testid="ds-onboarding-checklist"]').exists()
    ).toBe(false);
  });

  it('emits demoData when clicking the mock data action', async () => {
    const wrapper = mount(DsOnboardingChecklist, {
      global: globalStubs,
      props: {
        showDemoDataAction: true,
        demoDataLabel: 'Explore with Demo Data',
        persist: false,
      },
    });

    const demoButton = wrapper.get(
      '[data-testid="onboarding-demo-data-button"]'
    );
    expect(demoButton.text()).toContain('Explore with Demo Data');

    await demoButton.trigger('click');
    expect(wrapper.emitted('demoData')).toBeTruthy();
  });

  it('supports custom steps array and initial completed ids', () => {
    const customSteps = [
      {
        id: 'custom_1',
        title: 'Custom Step 1',
        description: 'First custom step description',
        actionLabel: 'Do Step 1',
        icon: 'i-lucide-check',
      },
      {
        id: 'custom_2',
        title: 'Custom Step 2',
        description: 'Second custom step description',
        actionLabel: 'Do Step 2',
        icon: 'i-lucide-check',
      },
    ];

    const wrapper = mount(DsOnboardingChecklist, {
      global: globalStubs,
      props: {
        steps: customSteps,
        initialCompletedIds: ['custom_1'],
        persist: false,
      },
    });

    expect(wrapper.text()).toContain('Custom Step 1');
    expect(wrapper.text()).toContain('Custom Step 2');
    expect(
      wrapper.get('[data-testid="onboarding-percent-indicator"]').text()
    ).toBe('50%');
  });

  it('translates content dynamically when vue-i18n is injected', () => {
    const customI18nStubs = {
      ...globalStubs,
      mocks: {
        $t: (key, values) => {
          if (key === 'ONBOARDING_CHECKLIST.TITLE') return 'Guia de Ativação';
          if (key === 'ONBOARDING_CHECKLIST.STEPS.CONNECT_CHANNEL.TITLE') {
            return 'Conectar Canal WhatsApp';
          }
          if (key === 'ONBOARDING_CHECKLIST.PROGRESS_SUBTITLE') {
            return `${values.completed} de ${values.total} passos (${values.percent}%)`;
          }
          return key;
        },
        $te: () => true,
      },
    };

    const wrapper = mount(DsOnboardingChecklist, {
      global: customI18nStubs,
      props: {
        title: 'Guia de Ativação',
        subtitle: '1 de 4 passos (25%)',
        steps: [
          {
            id: 'connect_channel',
            title: 'Conectar Canal WhatsApp',
            description: 'Conecte sua conta do WhatsApp.',
            actionLabel: 'Conectar',
            icon: 'i-lucide-message-circle',
          },
        ],
        persist: false,
      },
    });

    expect(wrapper.text()).toContain('Guia de Ativação');
    expect(wrapper.text()).toContain('Conectar Canal WhatsApp');
    expect(wrapper.text()).toContain('1 de 4 passos (25%)');
  });

  it('toggles step accordion open and closed on click and keyboard interaction', async () => {
    const wrapper = mount(DsOnboardingChecklist, {
      global: globalStubs,
      props: { persist: false },
    });

    // Step 1 is active initially (first incomplete step)
    expect(
      wrapper.find('[data-testid="step-body-connect_channel"]').exists()
    ).toBe(true);

    const step1Header = wrapper.get(
      '[data-testid="onboarding-step-connect_channel"] [role="button"]'
    );
    // Clicking active step collapses it
    await step1Header.trigger('click');
    expect(
      wrapper.find('[data-testid="step-body-connect_channel"]').exists()
    ).toBe(false);

    // Pressing Enter expands it again
    await step1Header.trigger('keydown.enter');
    expect(
      wrapper.find('[data-testid="step-body-connect_channel"]').exists()
    ).toBe(true);

    // Pressing Space collapses it
    await step1Header.trigger('keydown.space');
    expect(
      wrapper.find('[data-testid="step-body-connect_channel"]').exists()
    ).toBe(false);
  });

  it('loads dismissed state from localStorage if previously dismissed', () => {
    localStorageStore.chusterm_onboarding_ftue = JSON.stringify({
      completedSteps: [],
      isExpanded: true,
      isDismissed: true,
    });

    const wrapper = mount(DsOnboardingChecklist, {
      global: globalStubs,
      props: { persist: true },
    });

    expect(
      wrapper.find('[data-testid="ds-onboarding-checklist"]').exists()
    ).toBe(false);
  });
});

describe('DsEmptyState.vue guided empty state actions', () => {
  it('renders primary and secondary actions for demo data exploration', async () => {
    const wrapper = mount(DsEmptyState, {
      global: globalStubs,
      props: {
        title: 'No contacts found',
        description:
          'Create your first contact or explore the platform with sample demo data.',
        icon: 'i-lucide-users',
        actionLabel: 'Create Contact',
        secondaryActionLabel: 'Enable Demo Data',
      },
    });

    expect(wrapper.text()).toContain('No contacts found');
    expect(wrapper.text()).toContain('Create your first contact');
    expect(wrapper.text()).toContain('Create Contact');
    expect(wrapper.text()).toContain('Enable Demo Data');

    const buttons = wrapper.findAll('button');
    expect(buttons).toHaveLength(2);

    await buttons[0].trigger('click');
    expect(wrapper.emitted('action')).toHaveLength(1);

    await buttons[1].trigger('click');
    expect(wrapper.emitted('secondaryAction')).toHaveLength(1);
  });
});
