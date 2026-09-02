# F0 — Baseline do frontend Core

Data: 2026-07-10  
Branch/commit de partida: `main` / `f5f0dde`  
Ambiente validado: Windows, Node 24.18.0 via `npx`, pnpm 10.2.0

## Resultado consolidado

| Verificação | Resultado |
|---|---|
| Arquivos de teste coletados | 342 |
| Testes coletados | 3.349 |
| Suíte integral Vitest | passou |
| Lint incremental do diff frontend | passou, somente avisos legados |
| Build de produção | passou; 4.547 módulos transformados |
| Auditoria de produção | sem vulnerabilidade alta ou crítica; 1 baixa e 8 moderadas |
| Vite | atualizado de 5.4.21 para 6.4.3 |
| `@vitejs/plugin-vue` | atualizado de 5.1.4 para 5.2.4 |

## Falhas encontradas e corrigidas

- 253 blobs no `HEAD` tinham BOM UTF-8 introduzido por regravação anterior. O marcador impedia a análise de imports do Vite em 14 suítes. Os arquivos foram normalizados para UTF-8 sem BOM e LF.
- Os scripts de teste dependiam da sintaxe POSIX `TZ=UTC`; passaram a usar `cross-env` para funcionar no Windows e no CI.
- O hook `prepare` do Husky supunha que `core/` era a raiz Git. O instalador agora encontra a raiz do repositório e respeita `HUSKY=0` em CI/Docker.
- Testes de data, número e branding tinham expectativas dependentes de fuso, locale ou dados alterados pela troca de marca.
- Os testes de conversas não refletiam a atualização intencional de estatísticas em tempo real.
- `setActiveChat` podia buscar mensagens novamente mesmo com `dataFetched=true`; o predicado foi corrigido.
- Dois mocks alteravam diretamente o namespace ESM; passaram a retornar um novo módulo, compatível com Vite 6.
- Erros incrementais de Prettier, i18n e variável não usada foram corrigidos nos arquivos do diff.

## Segurança de dependências

O Vite 5.4.21 era afetado por `GHSA-fx2h-pf6j-xcff`, classificado como alto e sem correção na linha 5. A migração mínima compatível removeu o achado alto. Os achados baixos/moderados restantes devem permanecer no backlog de atualização de dependências da F0/F2, mas não quebram o gate configurado para severidade alta.

## Avisos não bloqueantes observados

- chunks `DashboardIcon` e `dashboard` ainda excedem o limite de 1 MB e entram no trabalho de performance das fases F2/F3;
- base Browserslist desatualizada;
- avisos legados de Vue/jsdom em alguns testes;
- avisos de i18n dinâmica em componentes preexistentes.

## Comandos reproduzíveis

```powershell
npx -y -p node@24 -p pnpm@10.2.0 pnpm install --frozen-lockfile
npx -y -p node@24 -p pnpm@10.2.0 pnpm test
npx -y -p node@24 -p pnpm@10.2.0 pnpm exec vite build
npx -y -p node@24 -p pnpm@10.2.0 pnpm audit --prod --audit-level high
```
