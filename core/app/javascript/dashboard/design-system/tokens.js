const rgbToken = token => `rgb(var(${token}) / <alpha-value>)`;

/**
 * ChusteRM Operational UI — contrato de tokens da Fase 2.
 *
 * Esta camada é deliberadamente pequena. Ela deriva das variáveis semânticas
 * que já alternam entre tema claro e escuro, mas não expõe as escalas legadas
 * aos componentes novos.
 */
export const operationalTokens = Object.freeze({
  colors: {
    canvas: rgbToken('--ds-bg-canvas'),
    surface: rgbToken('--ds-bg-surface'),
    elevated: rgbToken('--ds-bg-elevated'),
    sunken: rgbToken('--ds-bg-sunken'),
    hover: rgbToken('--ds-bg-hover'),
    active: rgbToken('--ds-bg-active'),
    text: {
      DEFAULT: rgbToken('--ds-fg-default'),
      muted: rgbToken('--ds-fg-muted'),
      subtle: rgbToken('--ds-fg-subtle'),
      disabled: rgbToken('--ds-fg-disabled'),
      inverse: rgbToken('--ds-fg-on-accent'),
    },
    border: {
      subtle: rgbToken('--ds-border-subtle'),
      DEFAULT: rgbToken('--ds-border-default'),
      strong: rgbToken('--ds-border-strong'),
      focus: rgbToken('--ds-border-focus'),
    },
    brand: {
      DEFAULT: rgbToken('--ds-accent-primary'),
      hover: rgbToken('--ds-accent-primary-hover'),
      active: rgbToken('--ds-accent-primary-active'),
      soft: rgbToken('--ds-accent-primary-soft'),
      foreground: rgbToken('--ds-accent-primary-fg'),
    },
    success: {
      DEFAULT: rgbToken('--ds-state-success'),
      soft: rgbToken('--ds-state-success-soft'),
      foreground: rgbToken('--ds-state-success-fg'),
    },
    warning: {
      DEFAULT: rgbToken('--ds-state-warning'),
      soft: rgbToken('--ds-state-warning-soft'),
      foreground: rgbToken('--ds-state-warning-fg'),
    },
    danger: {
      DEFAULT: rgbToken('--ds-state-danger'),
      soft: rgbToken('--ds-state-danger-soft'),
      foreground: rgbToken('--ds-state-danger-fg'),
      solid: rgbToken('--ds-state-danger-solid'),
    },
    info: {
      DEFAULT: rgbToken('--ds-state-info'),
      soft: rgbToken('--ds-state-info-soft'),
      foreground: rgbToken('--ds-state-info-fg'),
    },
    chart: {
      brand: rgbToken('--ds-chart-brand'),
      violet: rgbToken('--ds-chart-violet'),
      success: rgbToken('--ds-chart-success'),
      danger: rgbToken('--ds-chart-danger'),
      warning: rgbToken('--ds-chart-warning'),
      'warning-strong': rgbToken('--ds-chart-warning-strong'),
      info: rgbToken('--ds-chart-info'),
      neutral: rgbToken('--ds-chart-neutral'),
    },
  },
  fontFamily: {
    sans: [
      'Inter',
      '-apple-system',
      'system-ui',
      'BlinkMacSystemFont',
      '"Segoe UI"',
      'Roboto',
      'sans-serif',
    ],
  },
  fontSize: {
    'ui-caption': ['0.75rem', { lineHeight: '1rem' }],
    'ui-body-sm': ['0.8125rem', { lineHeight: '1.25rem' }],
    'ui-body': ['0.875rem', { lineHeight: '1.25rem' }],
    'ui-label': ['0.875rem', { lineHeight: '1.25rem' }],
    'ui-heading': ['1rem', { lineHeight: '1.5rem' }],
    'ui-title': ['1.25rem', { lineHeight: '1.75rem' }],
  },
  fontWeight: {
    normal: '400',
    medium: '500',
    semibold: '600',
  },
  spacing: {
    0: '0',
    1: '0.25rem',
    2: '0.5rem',
    3: '0.75rem',
    4: '1rem',
    5: '1.25rem',
    6: '1.5rem',
    8: '2rem',
    10: '2.5rem',
    12: '3rem',
  },
  borderRadius: {
    'ui-control': '0.375rem',
    'ui-surface': '0.625rem',
  },
  boxShadow: {
    'ui-raised':
      '0 1px 2px rgb(15 23 42 / 0.06), 0 4px 12px rgb(15 23 42 / 0.05)',
    'ui-overlay':
      '0 12px 32px rgb(15 23 42 / 0.16), 0 2px 8px rgb(15 23 42 / 0.08)',
  },
  transitionDuration: {
    'ui-fast': '120ms',
    'ui-base': '180ms',
  },
  zIndex: {
    'ui-sticky': '20',
    'ui-overlay': '40',
    'ui-modal': '50',
    'ui-toast': '60',
  },
  sizing: {
    touchTarget: '2.75rem',
    row: '3.25rem',
    iconStroke: 2,
  },
});

export const operationalTokenContract = Object.freeze({
  fontFamilies: 1,
  fontSizes: 6,
  fontWeights: 3,
  spacingBase: 4,
  radii: 2,
  shadows: 2,
  iconFamily: 'lucide',
  iconStroke: operationalTokens.sizing.iconStroke,
});
