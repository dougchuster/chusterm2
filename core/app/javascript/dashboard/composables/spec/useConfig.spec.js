import { useConfig } from '../useConfig';

describe('useConfig', () => {
  const originalchustermConfig = window.chustermConfig;

  beforeEach(() => {
    window.chustermConfig = {
      hostURL: 'https://example.com',
      vapidPublicKey: 'vapid-key',
      enabledLanguages: ['en', 'fr'],
      isEnterprise: 'true',
      enterprisePlanName: 'enterprise',
    };
  });

  afterEach(() => {
    window.chustermConfig = originalchustermConfig;
  });

  it('returns the correct configuration values', () => {
    const config = useConfig();

    expect(config.hostURL).toBe('https://example.com');
    expect(config.vapidPublicKey).toBe('vapid-key');
    expect(config.enabledLanguages).toEqual(['en', 'fr']);
    expect(config.isEnterprise).toBe(true);
    expect(config.enterprisePlanName).toBe('enterprise');
  });

  it('handles missing configuration values', () => {
    window.chustermConfig = {};
    const config = useConfig();

    expect(config.hostURL).toBeUndefined();
    expect(config.vapidPublicKey).toBeUndefined();
    expect(config.enabledLanguages).toBeUndefined();
    expect(config.isEnterprise).toBe(false);
    expect(config.enterprisePlanName).toBeUndefined();
  });

  it('handles undefined window.chustermConfig', () => {
    window.chustermConfig = undefined;
    const config = useConfig();

    expect(config.hostURL).toBeUndefined();
    expect(config.vapidPublicKey).toBeUndefined();
    expect(config.enabledLanguages).toBeUndefined();
    expect(config.isEnterprise).toBe(false);
    expect(config.enterprisePlanName).toBeUndefined();
  });
});
