const BRL_FORMATTER = new Intl.NumberFormat('pt-BR', {
  style: 'currency',
  currency: 'BRL',
});

const normalizedCents = value => {
  const cents = Number(value);
  return Number.isFinite(cents) ? cents : 0;
};

export const formatCurrencyFromCents = value =>
  BRL_FORMATTER.format(normalizedCents(value) / 100);

export const sumDealValueCents = deals =>
  (Array.isArray(deals) ? deals : []).reduce((total, deal) => {
    const value = deal?.value_estimate_cents ?? deal?.valueEstimateCents ?? 0;
    return total + normalizedCents(value);
  }, 0);
