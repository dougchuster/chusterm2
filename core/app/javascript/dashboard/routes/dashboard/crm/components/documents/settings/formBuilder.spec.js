import {
  conditionSources,
  conditionValues,
  keyFromLabel,
  localWarnings,
  move,
} from './formBuilder';

describe('formBuilder', () => {
  it('gera chave a partir do nome, sem acento e sem repetir', () => {
    expect(keyFromLabel('Carteira de Trabalho (CTPS)')).toBe(
      'carteira_de_trabalho_ctps'
    );
    expect(keyFromLabel('Endereço', ['endereco'])).toBe('endereco_2');
    expect(keyFromLabel('3x4')).toBe('c_3x4');
  });

  it('move itens sem sair da lista', () => {
    expect(move(['a', 'b', 'c'], 0, 1)).toEqual(['b', 'a', 'c']);
    expect(move(['a', 'b'], 0, -1)).toEqual(['a', 'b']);
  });

  it('só oferece como condição campos de escolha anteriores', () => {
    const fields = [
      { key: 'nome', type: 'text' },
      { key: 'assunto', type: 'radio', options: ['A', 'B'] },
      { key: 'aceite', type: 'checkbox' },
    ];

    expect(conditionSources(fields, 2).map(f => f.key)).toEqual(['assunto']);
    expect(conditionValues(fields[1])).toEqual(['A', 'B']);
    expect(conditionValues(fields[2])).toEqual(['true']);
  });

  it('avisa quando falta identificar o contato ou opções', () => {
    const warnings = localWarnings([
      { label: 'Assunto', type: 'select', options: [] },
    ]);

    expect(warnings).toEqual(
      expect.arrayContaining([
        'Ligue um campo ao nome do contato.',
        'Ligue um campo ao telefone ou ao e-mail do contato.',
        '"Assunto" precisa de opções.',
      ])
    );
  });
});
