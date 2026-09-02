import {
  formatCurrencyFromCents,
  sumDealValueCents,
} from 'dashboard/helper/crmMoney';

describe('CRM money helpers', () => {
  describe('formatCurrencyFromCents', () => {
    it('formats cents consistently as Brazilian reais', () => {
      expect(formatCurrencyFromCents(123456)).toBe('R$\u00a01.234,56');
      expect(formatCurrencyFromCents('1099')).toBe('R$\u00a010,99');
      expect(formatCurrencyFromCents(0)).toBe('R$\u00a00,00');
    });

    it('formats missing or invalid values as zero', () => {
      expect(formatCurrencyFromCents()).toBe('R$\u00a00,00');
      expect(formatCurrencyFromCents('valor inválido')).toBe('R$\u00a00,00');
    });
  });

  describe('sumDealValueCents', () => {
    it('sums every loaded deal, including records after the first 200', () => {
      const deals = Array.from({ length: 201 }, () => ({
        value_estimate_cents: 100,
      }));

      expect(sumDealValueCents(deals)).toBe(20100);
    });

    it('accepts API strings, camelCase fallback and ignores invalid values', () => {
      const deals = [
        { value_estimate_cents: '1250' },
        { valueEstimateCents: 750 },
        { value_estimate_cents: null },
        { value_estimate_cents: 'inválido' },
      ];

      expect(sumDealValueCents(deals)).toBe(2000);
      expect(sumDealValueCents()).toBe(0);
    });
  });
});
