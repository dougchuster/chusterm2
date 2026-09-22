import {
  initialFolderId,
  lineage,
  totalCount,
  visibleRows,
} from './folderTree';

const folders = [
  {
    id: 5,
    parent_id: null,
    name: '04 Processos',
    position: 4,
    slot: 'processos',
    documents_count: 0,
  },
  {
    id: 1,
    parent_id: null,
    name: '00 Triagem',
    position: 0,
    slot: 'triagem',
    documents_count: 0,
  },
  {
    id: 2,
    parent_id: null,
    name: '01 Documentos Pessoais',
    position: 1,
    slot: 'pessoais',
    documents_count: 3,
  },
  {
    id: 9,
    parent_id: 5,
    name: '2026-0042 · Aposentadoria',
    position: 0,
    slot: 'processo',
    documents_count: 1,
  },
  {
    id: 11,
    parent_id: 9,
    name: '01 Documentos do Caso',
    position: 0,
    slot: 'processo_docs',
    documents_count: 2,
  },
];

describe('folderTree', () => {
  it('ordena em árvore pela posição e informa a profundidade', () => {
    const rows = visibleRows(folders);

    expect(rows.map(row => [row.folder.name, row.depth])).toEqual([
      ['00 Triagem', 0],
      ['01 Documentos Pessoais', 0],
      ['04 Processos', 0],
      ['2026-0042 · Aposentadoria', 1],
      ['01 Documentos do Caso', 2],
    ]);
    expect(rows[2].hasChildren).toBe(true);
  });

  it('esconde as filhas de pasta recolhida', () => {
    const rows = visibleRows(folders, new Set([5]));

    expect(rows.map(row => row.folder.id)).toEqual([1, 2, 5]);
  });

  it('monta a linhagem da raiz até a pasta', () => {
    expect(lineage(folders, 11).map(folder => folder.id)).toEqual([5, 9, 11]);
  });

  it('soma os documentos das subpastas', () => {
    expect(totalCount(folders, 5)).toBe(3);
  });

  it('abre na pasta do processo quando há uma', () => {
    expect(initialFolderId(folders, 9)).toBe(9);
  });

  it('abre na triagem só quando há algo nela', () => {
    expect(initialFolderId(folders, null)).toBe(2);

    const withTriage = folders.map(folder =>
      folder.id === 1 ? { ...folder, documents_count: 2 } : folder
    );
    expect(initialFolderId(withTriage, null)).toBe(1);
  });
});
