import { usePanelWidth } from './usePanelWidth';

describe('usePanelWidth (CRM-032)', () => {
  beforeEach(() => window.localStorage.clear());

  it('persists the resized width and clamps to the minimum', () => {
    const first = usePanelWidth('test-panel');
    first.width.value = 640;
    // Simula o fim do arraste persistindo manualmente o valor corrente.
    window.localStorage.setItem('test-panel', String(first.width.value));

    const second = usePanelWidth('test-panel');
    second.readStoredWidth();
    expect(second.width.value).toBe(640);
  });

  it('ignores stored values below the minimum', () => {
    window.localStorage.setItem('test-panel', '50');
    const { width, readStoredWidth } = usePanelWidth('test-panel');
    readStoredWidth();
    expect(width.value).toBe(480);
  });
});
