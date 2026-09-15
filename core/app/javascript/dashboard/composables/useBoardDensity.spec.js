import { useBoardDensity } from './useBoardDensity';

const t = key => key;

describe('useBoardDensity (CRM-031)', () => {
  beforeEach(() => window.localStorage.clear());

  it('persists the chosen density and reads it back', () => {
    const first = useBoardDensity(t);
    first.setDensity('compact');
    expect(window.localStorage.getItem('crm-board-density')).toBe('compact');

    const second = useBoardDensity(t);
    second.readStoredDensity();
    expect(second.cardDensity.value).toBe('compact');
  });

  it('rejects invalid densities and survives blocked storage', () => {
    const { cardDensity, setDensity } = useBoardDensity(t);
    setDensity('huge');
    expect(cardDensity.value).toBe('normal');
    expect(window.localStorage.getItem('crm-board-density')).toBeNull();
  });
});
