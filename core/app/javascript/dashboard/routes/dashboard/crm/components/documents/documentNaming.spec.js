import { extensionOf, previewFileName } from './documentNaming';

const document = {
  created_at: '2026-09-22T15:00:00',
  file_name: '2026-09-22 12h00 — WhatsApp — IMG-WA0012.JPG',
};

describe('documentNaming', () => {
  it('monta data, tipo e descrição como o servidor', () => {
    expect(
      previewFileName({
        document,
        typeSlug: 'rg',
        typeLabel: 'RG',
        description: 'Frente e verso',
      })
    ).toBe('2026-09-22 — RG — Frente e verso.jpg');
  });

  it('omite a descrição vazia', () => {
    expect(
      previewFileName({
        document,
        typeSlug: 'cnis',
        typeLabel: 'CNIS',
        description: '',
      })
    ).toBe('2026-09-22 — CNIS.jpg');
  });

  it('usa a descrição como rótulo no tipo "outro"', () => {
    expect(
      previewFileName({
        document,
        typeSlug: 'outro',
        typeLabel: 'Outro',
        description: 'Declaração do vizinho',
      })
    ).toBe('2026-09-22 — Declaração do vizinho.jpg');
  });

  it('prefere a data do documento', () => {
    expect(
      previewFileName({
        document: { ...document, document_date: '2026-03-10' },
        typeSlug: 'rg',
        typeLabel: 'RG',
      })
    ).toBe('2026-03-10 — RG.jpg');
  });

  it('limpa caracteres proibidos da descrição', () => {
    expect(
      previewFileName({
        document,
        typeSlug: 'rg',
        typeLabel: 'RG',
        description: 'frente/verso?',
      })
    ).toBe('2026-09-22 — RG — frente verso.jpg');
  });

  it('extrai a extensão em minúsculas', () => {
    expect(extensionOf('x.PDF')).toBe('pdf');
    expect(extensionOf('sem-extensao')).toBe('bin');
  });
});
