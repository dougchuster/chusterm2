# F0 — Fixture canônica e harness de QA

**Data:** 2026-07-13  
**Estado:** parcial, reproduzível no ambiente Docker local

## 1. Fixture canônica

A fixture vive em `core/lib/qa/canonical_fixture.rb`, é exposta pela task
`qa:seed` e possui teste de unidade dedicado. Ela recusa produção por padrão e
só admite o Compose local em modo production quando
`QA_FIXTURE_TARGET=local-compose`, a URL pública é local e o PostgreSQL aponta
para o serviço local.

Cobertura implementada:

- contas A, B e suspensa, com namespace determinístico;
- admin, operador, vendedor, gestor, gestor de conhecimento, custom role
  mínima, admin da conta B, usuário sem conta, usuário suspenso e super-admin;
- inbox API determinística por conta e CAPITÃO habilitado somente na conta A;
- pipeline comercial com Novo, Qualificação, Proposta, Negociação, Ganho e
  Perdido;
- motivo `Sem retorno`, deals open/won/lost/archived e contatos de lifecycle;
- 201 negócios por padrão e limite configurável de 1.000;
- colisões controladas entre namespaces/contas e soma financeira conhecida;
- reexecução idempotente sem duplicar os registros canônicos.

Seed local validado no namespace `f0`: conta A `55`, conta B `56`, conta
suspensa `57`, inboxes `80/81`, pipelines `23/24`, 201 deals na conta A e soma
de `4.040.100` centavos.

Ainda não coberto pela fixture: Evolution em sandbox, FAQ/documento
pronto-falho, conversas e mídias canônicas, webhook duplicado, relógio
controlável e limpeza pós-teste.

## 2. Harness Playwright

O projeto isolado está em `qa/e2e` e usa Playwright 1.61.1, Axe 4.12.1 e
TypeScript 7.0.2. O manifesto gerado contém 135 rotas e oito superfícies
internas. Há storage state para oito personas e autenticação com buckets de IP
TEST-NET-3 distintos, mantendo o Rack::Attack ligado.

Matriz configurada:

- Chromium, Firefox e WebKit desktop;
- 360×800, 768×1024, 1024×768, 1366×768 e 1920×1080;
- trace retido em falha, screenshot e vídeo somente em falha;
- health público, smoke autenticado e Axe do CRM.

## 3. Execuções comprovadas

| Verificação | Resultado |
|---|---|
| fixture specs | 4 exemplos, zero falhas |
| RuboCop da fixture | zero ocorrências |
| autenticação de oito personas + health + aplicação | 10/10 aprovados |
| TypeScript do harness | aprovado |
| health + smoke + Axe Chromium 1366 | 3/3 aprovados |
| Axe do CRM nos cinco viewports oficiais | 5/5 aprovados |
| violações Axe critical/serious no CRM após correções | zero |

A primeira execução Axe encontrou `button-name`, `html-has-lang`, `image-alt`,
`role-img-alt` e `select-name`. Foram corrigidos idioma do documento, nomes
acessíveis dos launchers e filtros, logo decorativo e avatar.

Também foi corrigida a entrega dos assets: o volume `core-vite-output` ocultava
o bundle da imagem. O build agora preserva uma cópia canônica em
`/app/public/vite-image`, e o Core a sincroniza no volume ao iniciar. O watcher
continua opt-in e pode atualizar o mesmo volume quando explicitamente ativado.

## 4. Pendências para o gate F0

- instalar e executar Firefox e WebKit;
- criar baseline visual autenticada das famílias de tela nos cinco viewports,
  light/dark e personas aplicáveis;
- cobrir loading, vazio, erro, offline, permissão e confirmação;
- implementar jornadas P0, incluindo cross-tenant e `E2E-P0-00` em duas
  execuções;
- comprovar acesso ao 201º deal e reconciliação de somas pela interface;
- publicar execução containerizada/CI e evidências sanitizadas;
- executar sandboxes Evolution, Google e LLM.

