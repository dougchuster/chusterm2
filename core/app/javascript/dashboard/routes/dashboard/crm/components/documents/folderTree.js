// Lógica pura da árvore de pastas do cofre: a API devolve uma lista plana
// (id, parent_id, position, name) e a tela precisa de linhas em ordem de
// árvore, com profundidade, para desenhar e navegar por teclado.

const byPosition = (a, b) =>
  (a.position ?? 0) - (b.position ?? 0) ||
  String(a.name).localeCompare(String(b.name), 'pt-BR');

export const buildChildrenMap = folders => {
  const map = new Map();
  folders.forEach(folder => {
    const key = folder.parent_id ?? null;
    if (!map.has(key)) map.set(key, []);
    map.get(key).push(folder);
  });
  map.forEach(list => list.sort(byPosition));
  return map;
};

// Linhas visíveis: filhas de pasta recolhida ficam de fora.
export const visibleRows = (folders, collapsedIds = new Set()) => {
  const children = buildChildrenMap(folders);
  const rows = [];
  const walk = (parentId, depth) => {
    (children.get(parentId) || []).forEach(folder => {
      const hasChildren = (children.get(folder.id) || []).length > 0;
      rows.push({ folder, depth, hasChildren });
      if (hasChildren && !collapsedIds.has(folder.id))
        walk(folder.id, depth + 1);
    });
  };
  walk(null, 0);
  return rows;
};

// Da raiz até a pasta — alimenta o breadcrumb.
export const lineage = (folders, folderId) => {
  const byId = new Map(folders.map(folder => [folder.id, folder]));
  const chain = [];
  let current = byId.get(folderId);
  while (current && chain.length <= 5) {
    chain.unshift(current);
    current = byId.get(current.parent_id);
  }
  return chain;
};

// Soma dos documentos da pasta e de todas as subpastas.
export const totalCount = (folders, folderId) => {
  const children = buildChildrenMap(folders);
  const byId = new Map(folders.map(folder => [folder.id, folder]));
  const sum = id =>
    (byId.get(id)?.documents_count || 0) +
    (children.get(id) || []).reduce((acc, child) => acc + sum(child.id), 0);
  return sum(folderId);
};

// Pasta onde o cofre abre: a do processo, se houver; senão a Triagem quando
// tem algo a classificar; senão a primeira pasta depois dela.
export const initialFolderId = (folders, caseFolderId) => {
  if (caseFolderId) return caseFolderId;
  const triage = folders.find(folder => folder.slot === 'triagem');
  if (triage?.documents_count) return triage.id;
  const firstOther = visibleRows(folders).find(
    row => row.folder.slot !== 'triagem'
  );
  return firstOther?.folder.id ?? triage?.id ?? null;
};
