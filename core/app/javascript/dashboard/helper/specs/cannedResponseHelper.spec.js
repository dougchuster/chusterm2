import {
  normalizeText,
  scoreSubsequence,
  filterCannedResponses,
} from '../cannedResponseHelper';

describe('cannedResponseHelper', () => {
  describe('normalizeText', () => {
    it('handles empty and non-string inputs safely', () => {
      expect(normalizeText('')).toBe('');
      expect(normalizeText(null)).toBe('');
      expect(normalizeText(undefined)).toBe('');
      expect(normalizeText(123)).toBe('');
    });

    it('converts text to lowercase and trims whitespace', () => {
      expect(normalizeText('  HELLO World  ')).toBe('hello world');
    });

    it('removes accents and diacritics', () => {
      expect(normalizeText('olá')).toBe('ola');
      expect(normalizeText('preço')).toBe('preco');
      expect(normalizeText('informações')).toBe('informacoes');
      expect(normalizeText('ÁÉÍÓÚ àèìòù âêîôû ãõ ñ ç')).toBe(
        'aeiou aeiou aeiou ao n c'
      );
    });
  });

  describe('scoreSubsequence', () => {
    it('returns highest score for exact matches', () => {
      expect(scoreSubsequence('ola', 'ola')).toBe(1000);
    });

    it('scores prefix matches higher than substrings', () => {
      const prefixScore = scoreSubsequence('ola_amigo', 'ola');
      const substringScore = scoreSubsequence('diga_ola_amigo', 'ola');
      expect(prefixScore).toBeGreaterThan(substringScore);
    });

    it('matches fuzzy subsequences in order', () => {
      const score = scoreSubsequence('obrigado', 'obg');
      expect(score).toBeGreaterThan(0);
    });

    it('returns -1 when query is not a subsequence', () => {
      expect(scoreSubsequence('obrigado', 'xyz')).toBe(-1);
      expect(scoreSubsequence('ola', 'al')).toBe(-1);
    });
  });

  describe('filterCannedResponses', () => {
    const responses = [
      {
        id: 1,
        short_code: 'ola',
        content: 'Olá! Como posso ajudar você hoje?',
      },
      {
        id: 2,
        short_code: 'ola_equipe',
        content: 'Olá time de atendimento',
      },
      {
        id: 3,
        short_code: 'obrigado',
        content: 'Muito obrigado pelo seu contato!',
      },
      {
        id: 4,
        short_code: 'tabela_precos',
        content: 'Segue a nossa tabela de preços atualizada',
      },
      {
        id: 5,
        short_code: 'suporte_tecnico',
        content: 'Atendimento do suporte técnico de CRM',
      },
      {
        id: 6,
        short_code: 'encerramento',
        content: 'Agradecemos o contato, tenha um ótimo dia!',
      },
    ];

    it('returns all items when query is empty or whitespace', () => {
      expect(filterCannedResponses(responses, '')).toEqual(responses);
      expect(filterCannedResponses(responses, '   ')).toEqual(responses);
      expect(filterCannedResponses(null, 'ola')).toEqual([]);
    });

    it('matches by prefix on short_code', () => {
      const results = filterCannedResponses(responses, 'ola');
      const shortCodes = results.map(r => r.short_code);
      expect(shortCodes).toContain('ola');
      expect(shortCodes).toContain('ola_equipe');
    });

    it('matches by subsequence (fuzzy acronym)', () => {
      const results = filterCannedResponses(responses, 'obg');
      expect(results.length).toBeGreaterThanOrEqual(1);
      expect(results[0].short_code).toBe('obrigado');
    });

    it('is case-insensitive', () => {
      const upper = filterCannedResponses(responses, 'OBRIGADO');
      const lower = filterCannedResponses(responses, 'obrigado');
      expect(upper).toEqual(lower);
    });

    it('is accent-insensitive (diacritics tolerance)', () => {
      const withoutAccent = filterCannedResponses(responses, 'precos');
      const withAccent = filterCannedResponses(responses, 'preços');
      expect(withoutAccent.map(r => r.short_code)).toContain('tabela_precos');
      expect(withAccent.map(r => r.short_code)).toContain('tabela_precos');

      const olaWithAccent = filterCannedResponses(responses, 'olá');
      expect(olaWithAccent[0].short_code).toBe('ola');
    });

    it('is tolerant to word order in multi-term queries', () => {
      const order1 = filterCannedResponses(responses, 'tecnico suporte');
      const order2 = filterCannedResponses(responses, 'suporte tecnico');
      expect(order1.map(r => r.short_code)).toContain('suporte_tecnico');
      expect(order2.map(r => r.short_code)).toContain('suporte_tecnico');
    });

    it('sorts by relevance (exact match > prefix > substring > subsequence > content-only)', () => {
      const candidateList = [
        { id: 10, short_code: 'suporte_crm_avancado', content: 'Ajuda' },
        { id: 11, short_code: 'suporte', content: 'Suporte geral' },
        { id: 12, short_code: 'atendimento_suporte', content: 'Suporte' },
        {
          id: 13,
          short_code: 'contato',
          content: 'Entre em contato com suporte',
        },
      ];

      const results = filterCannedResponses(candidateList, 'suporte');
      expect(results[0].short_code).toBe('suporte'); // exact match
      expect(results[1].short_code).toBe('suporte_crm_avancado'); // prefix match
      expect(results[2].short_code).toBe('atendimento_suporte'); // substring match
      expect(results[3].short_code).toBe('contato'); // content-only match
    });

    it('returns empty array when no responses match', () => {
      const results = filterCannedResponses(
        responses,
        'palavra_inexistente_999'
      );
      expect(results).toEqual([]);
    });

    it('handles items with label and description props (MentionBox item format)', () => {
      const mentionItems = [
        { label: 'ola', description: 'Olá mundo' },
        { label: 'ajuda', description: 'Como posso ajudar' },
      ];
      const results = filterCannedResponses(mentionItems, 'ola');
      expect(results).toHaveLength(1);
      expect(results[0].label).toBe('ola');
    });
  });
});
