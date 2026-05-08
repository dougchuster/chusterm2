# Melhorias da Pagina de Contatos: Categorias, Listas e Campanhas

> Status: implementacao iniciada
> Criado em: 2026-05-06
> Escopo: `/app/accounts/:account_id/contacts`
> Ultima atualizacao: 2026-05-06

## Atualizacao de Produto - 2026-05-06

- A visao `Ativo` foi removida do menu de Contatos para evitar confusao com atendimento/kanban.
- Foi adicionada a entrada `Contatos > Categorias`.
- Categorias agora devem ser organizadas por tipo operacional: `Setor juridico`, `Localidade`, `Campanhas e listas`, `Origem`, `Restricoes` e `Outras categorias`.
- `Lead` e `Cliente` nao devem ser tratados como varias categorias; eles continuam como relacionamento unico do contato.
- `Area juridica` deixa de ser busca livre e passa a ser representada como `Setor juridico`, usando categorias do tipo `area`.
- Temperatura do lead, como quente/morno/frio, deve aparecer no atendimento com base no score CRM, sem obrigar a criar varias categorias de Lead.

## 1. Objetivo

Transformar a pagina de Contatos em uma central profissional de segmentacao, importacao e preparo de campanhas.

O contato deve poder participar de varias categorias ao mesmo tempo. Exemplo:

- Contato: Douglas Chuster
- Categorias: `DF`, `Previdenciario`, `Re-marketing`

Isso permite criar campanhas e filtros como:

- Todos os contatos de `DF`.
- Clientes de `Previdenciario`.
- Leads de `DF` + `Re-marketing`.
- Excluir quem tem `Opt-out` ou `Nao chamar`.

## 2. Problemas Atuais

- A tela esta focada em filtros soltos, mas nao comunica bem a ideia de listas/categorias.
- "Lista", "Etiqueta" e "Setor juridico" aparecem como conceitos separados, mas o usuario precisa de uma segmentacao mais simples.
- Nao existe uma area principal clara para navegar por categorias.
- A importacao de contatos precisa permitir criar categorias na hora.
- Os cards de contato ainda parecem mais uma lista operacional do que uma central de CRM/campanhas.
- A preparacao de campanhas exige uma audiencia mais previsivel, com inclusao e exclusao de categorias.

## 3. Conceito Principal

### Categoria

Categoria e um marcador reutilizavel para segmentar contatos. Um contato pode ter zero, uma ou varias categorias.

Exemplos:

- Localidade: `DF`, `GO`, `SP`
- Setor juridico: `Previdenciario`, `Trabalhista`, `Familia`
- Campanha: `Re-marketing`, `Indicado`, `Black Friday Juridico`
- Origem: `Instagram`, `WhatsApp`, `Landing Page`

`Lead` e `Cliente` devem continuar como relacionamento unico do contato, nao como varias categorias paralelas. Temperatura comercial (`Lead quente`, `Lead morno`, `Lead frio`) deve aparecer no atendimento pelo score CRM.

### Lista Inteligente

Lista inteligente e uma visualizacao gerada por filtros e categorias.

Exemplos:

- `DF + Previdenciario`
- `Re-marketing + Cliente`
- `Lead sem responsavel + Trabalhista`

### Segmento de Campanha

Segmento de campanha e uma audiencia salva que pode ser usada em WhatsApp, SMS ou Email.

Exemplo:

- Incluir categorias: `DF`, `Previdenciario`
- Excluir categorias: `Nao chamar`, `Opt-out`
- Relacionamento: `Lead`
- Responsavel: `Todos`

## 4. Experiencia Esperada na Pagina

### 4.1 Cabecalho

O topo da pagina deve mostrar:

- Titulo: `Contatos`
- Subtitulo: total de contatos, leads, clientes e contatos sem categoria.
- Busca global por nome, telefone, email e categoria.
- Botao principal: `Importar contatos`
- Botao secundario: `Nova categoria`
- Menu: `Exportar`, `Criar campanha`, `Limpar filtros`

### 4.2 Navegacao por Categorias

A area principal deve ter uma navegacao clara por categorias:

- `Todos`
- `Sem categoria`
- `DF`
- `Previdenciario`
- `Re-marketing`
- `Trabalhista`
- `Familia`
- `Criar categoria`

Cada categoria deve exibir:

- Nome
- Cor
- Quantidade de contatos
- Tipo: localidade, setor juridico, campanha, origem ou livre
- Ultima campanha enviada
- Taxa de opt-out, se existir

### 4.3 Painel de Segmentacao

Ao selecionar uma categoria, a tela deve mostrar:

- Contatos daquela categoria.
- Outras categorias combinadas.
- Filtros adicionais: Lead/Cliente, responsavel, etapa, setor juridico, origem.
- Botao `Salvar como segmento`.
- Botao `Criar campanha com esta audiencia`.

### 4.4 Cards ou Tabela de Contatos

O usuario deve poder alternar entre:

- Visao compacta em tabela.
- Visao em cards CRM.

Cada contato deve mostrar:

- Nome
- Telefone e email
- Lead/Cliente
- Responsavel
- Categorias em chips
- Ultima conversa
- Ultima campanha
- Status de opt-out
- Acoes rapidas: editar, adicionar categoria, remover categoria, abrir ficha, iniciar conversa

## 5. Fluxo de Importacao

### 5.1 Upload

O usuario deve poder subir CSV/XLSX com contatos.

Campos esperados:

- `nome`
- `telefone`
- `email`
- `relacionamento`
- `categorias`
- `responsavel`
- `origem`
- `setor_juridico`

### 5.2 Criar Categorias na Hora

Durante a importacao, o usuario pode:

- Selecionar categorias existentes.
- Criar novas categorias.
- Aplicar categorias a todos os contatos importados.
- Ler categorias por coluna do arquivo.
- Separar varias categorias por virgula, ponto e virgula ou pipe.

Exemplo de coluna:

```csv
categorias
DF;Previdenciario;Re-marketing
GO;Trabalhista
SP;Familia;Pos-venda
```

### 5.3 Preview Antes de Confirmar

Antes de importar, mostrar:

- Total de contatos.
- Novos contatos.
- Duplicados.
- Categorias novas que serao criadas.
- Categorias existentes que serao usadas.
- Contatos com telefone invalido.
- Contatos sem nome.

### 5.4 Regras de Duplicidade

Opcoes:

- Atualizar contato existente e adicionar novas categorias.
- Ignorar duplicados.
- Criar novo registro, se permitido.

Padrao recomendado:

- Atualizar por telefone normalizado.
- Preservar categorias antigas.
- Adicionar categorias novas.

## 6. Modelo de Dados Recomendado

### Caminho Rapido

Usar `Label` como base inicial para categorias, com metadados:

- `category_kind`: `location`, `legal_area`, `campaign`, `origin`, `custom`
- `display_title`
- `color`
- `description`
- `is_contact_category: true`

Vantagens:

- Reaproveita associacao existente entre contatos e labels.
- Reaproveita filtros e campanhas por etiqueta.
- Entrega mais rapido.

### Caminho Profissional

Criar entidades proprias:

- `contact_categories`
- `contact_category_memberships`

Campos de `contact_categories`:

- `account_id`
- `name`
- `slug`
- `kind`
- `color`
- `description`
- `created_by_id`
- `contacts_count`
- `archived_at`

Campos de `contact_category_memberships`:

- `account_id`
- `contact_id`
- `contact_category_id`
- `source`
- `created_by_id`

Recomendacao:

1. Comecar usando `Label` com metadados.
2. Criar uma camada de API chamada `ContactCategory`.
3. Se a base crescer muito, migrar para tabelas dedicadas sem mudar a UI.

## 7. APIs Necessarias

### Categorias

- `GET /api/v1/accounts/:account_id/contact_categories`
- `POST /api/v1/accounts/:account_id/contact_categories`
- `PATCH /api/v1/accounts/:account_id/contact_categories/:id`
- `DELETE /api/v1/accounts/:account_id/contact_categories/:id`

### Contatos

- `POST /api/v1/accounts/:account_id/contacts/:id/categories`
- `DELETE /api/v1/accounts/:account_id/contacts/:id/categories/:category_id`
- `POST /api/v1/accounts/:account_id/contacts/bulk_categories`

### Importacao

- `POST /api/v1/accounts/:account_id/contacts/import_preview`
- `POST /api/v1/accounts/:account_id/contacts/import`

### Campanhas

- `POST /api/v1/accounts/:account_id/campaigns/audience_preview`
- `POST /api/v1/accounts/:account_id/contact_segments`

## 8. Regras de Campanha

Na criacao da campanha, o usuario deve conseguir montar audiencia por:

- Incluir uma ou varias categorias.
- Excluir uma ou varias categorias.
- Relacionamento: Lead, Cliente ou Todos.
- Etapa do ciclo de vida.
- Responsavel.
- Ultima atividade.
- Opt-out.

Operadores:

- `QUALQUER categoria`: contato tem pelo menos uma das categorias escolhidas.
- `TODAS categorias`: contato precisa ter todas as categorias escolhidas.
- `EXCLUIR categorias`: remove contatos que tenham categorias bloqueadas.

Exemplo:

- Incluir todas: `DF`, `Previdenciario`
- Incluir qualquer: `Re-marketing`, `WhatsApp ativo`
- Excluir: `Nao chamar`, `Opt-out`

## 9. UI Proposta

### Layout

```text
Contatos
Resumo: 1.248 contatos | 812 leads | 436 clientes | 84 sem categoria

[Buscar...] [Importar contatos] [Nova categoria] [Criar campanha]

Categorias
[Todos] [Sem categoria] [DF 120] [Previdenciario 340] [Re-marketing 210] [+]

Segmentacao ativa
Categorias: DF + Previdenciario
Relacionamento: Todos
Responsavel: Todos
[Salvar segmento] [Criar campanha]

Lista de contatos
Nome | Telefone | Relacao | Categorias | Responsavel | Ultima campanha | Acoes
```

### Estados Vazios

- Sem contatos: mostrar CTA para importar.
- Sem categorias: mostrar CTA para criar categoria.
- Categoria sem contatos: mostrar CTA para importar contatos nessa categoria.

### Acoes em Massa

- Adicionar categoria.
- Remover categoria.
- Mudar responsavel.
- Marcar como Lead/Cliente.
- Criar campanha.
- Exportar CSV.

## 10. Fases de Implementacao

### Fase 1 - Fundacao

- Criar conceito de categoria de contato usando labels/metadados.
- Criar endpoints de listagem e criacao de categorias.
- Criar bulk assign/remove.
- Ajustar serializacao de contato para retornar categorias.

### Fase 2 - Importacao

- Adicionar modal de importacao com categorias.
- Criar preview de importacao.
- Permitir criar categorias no fluxo.
- Adicionar coluna `categorias` no CSV.

### Fase 3 - UI Principal

- Recriar cabecalho da pagina de contatos.
- Adicionar barra de categorias.
- Melhorar cards/tabela.
- Adicionar chips de categorias por contato.
- Adicionar painel lateral de detalhes rapido.

### Fase 4 - Campanhas

- Criar audience builder por categoria.
- Criar preview de audiencia.
- Permitir salvar segmento.
- Permitir criar campanha direto da lista.

### Fase 5 - Qualidade

- Testes de importacao.
- Testes de filtros combinados.
- Testes de campanha por categoria.
- Validacao visual em desktop e mobile.
- Validacao tema claro e escuro.

## 11. Criterios de Aceite

- Um contato pode ter varias categorias.
- O usuario pode criar categoria na hora da importacao.
- O usuario pode criar categoria manualmente na pagina de contatos.
- A pagina mostra contatos agrupados/filtrados por categoria.
- A campanha consegue usar categorias como audiencia.
- A campanha consegue excluir categorias.
- Importacao preserva categorias antigas e adiciona novas.
- Busca encontra contatos por nome, telefone, email e categoria.
- Bulk action adiciona/remove categorias em varios contatos.
- UI funciona em tema claro e escuro.

## 12. Categorias Demo

Categorias iniciais para teste:

| Categoria | Tipo | Cor sugerida | Uso |
| --- | --- | --- | --- |
| DF | Localidade | Azul | Contatos do Distrito Federal |
| GO | Localidade | Verde | Contatos de Goias |
| Previdenciario | Setor juridico | Roxo | Leads de INSS, BPC, aposentadoria |
| Trabalhista | Setor juridico | Laranja | Leads trabalhistas |
| Familia | Setor juridico | Rosa | Divorcio, pensao, guarda |
| Re-marketing | Campanha | Ciano | Pessoas para reativacao |
| Pos-venda | Campanha | Esmeralda | Clientes para relacionamento posterior |
| Indicacao | Origem/canal | Amarelo | Contatos vindos por indicacao |
| WhatsApp ativo | Origem/canal | Indigo | Contatos com interacao recente |
| Nao chamar | Restricao | Cinza | Excluir de campanhas |

## 13. Contatos Demo

Base demo com 20 contatos e multiplas categorias por contato.

| Nome | Telefone | Email | Relacionamento | Categorias |
| --- | --- | --- | --- | --- |
| Douglas Chuster | +556199135861 | douglas.demo@chusterm.local | Cliente | DF;Previdenciario;Re-marketing;Pos-venda |
| Mariana Costa | +5561981112200 | mariana.costa@demo.local | Lead | DF;Previdenciario;Indicacao;WhatsApp ativo |
| Rafael Almeida | +5561981112201 | rafael.almeida@demo.local | Lead | DF;Trabalhista;Re-marketing |
| Patricia Gomes | +5561981112202 | patricia.gomes@demo.local | Cliente | GO;Familia;Pos-venda |
| Bruno Fernandes | +5561981112203 | bruno.fernandes@demo.local | Lead | DF;Familia;Indicacao |
| Renata Lima | +5561981112204 | renata.lima@demo.local | Lead | GO;Previdenciario;WhatsApp ativo |
| Carlos Eduardo | +5561981112205 | carlos.eduardo@demo.local | Cliente | DF;Trabalhista;Pos-venda;Re-marketing |
| Aline Martins | +5561981112206 | aline.martins@demo.local | Lead | DF;Previdenciario;Re-marketing |
| Joao Pedro | +5561981112207 | joao.pedro@demo.local | Lead | GO;Trabalhista;Indicacao |
| Fernanda Rocha | +5561981112208 | fernanda.rocha@demo.local | Cliente | DF;Familia;Pos-venda;WhatsApp ativo |
| Lucas Ribeiro | +5561981112209 | lucas.ribeiro@demo.local | Lead | DF;Previdenciario;WhatsApp ativo |
| Camila Nunes | +5561981112210 | camila.nunes@demo.local | Lead | GO;Familia;Re-marketing |
| Thiago Moreira | +5561981112211 | thiago.moreira@demo.local | Cliente | DF;Trabalhista;Pos-venda |
| Beatriz Santos | +5561981112212 | beatriz.santos@demo.local | Lead | DF;Previdenciario;Indicacao;Re-marketing |
| Felipe Castro | +5561981112213 | felipe.castro@demo.local | Lead | GO;Trabalhista;WhatsApp ativo |
| Natalia Barbosa | +5561981112214 | natalia.barbosa@demo.local | Cliente | DF;Familia;Pos-venda |
| Diego Lopes | +5561981112215 | diego.lopes@demo.local | Lead | DF;Previdenciario;Nao chamar |
| Juliana Pires | +5561981112216 | juliana.pires@demo.local | Lead | GO;Previdenciario;Re-marketing |
| Marcelo Vieira | +5561981112217 | marcelo.vieira@demo.local | Cliente | DF;Trabalhista;Pos-venda;WhatsApp ativo |
| Larissa Teixeira | +5561981112218 | larissa.teixeira@demo.local | Lead | DF;Familia;Indicacao;Re-marketing |

## 14. CSV Demo

```csv
nome,telefone,email,relacionamento,categorias
Douglas Chuster,+556199135861,douglas.demo@chusterm.local,Cliente,"DF;Previdenciario;Re-marketing;Pos-venda"
Mariana Costa,+5561981112200,mariana.costa@demo.local,Lead,"DF;Previdenciario;Indicacao;WhatsApp ativo"
Rafael Almeida,+5561981112201,rafael.almeida@demo.local,Lead,"DF;Trabalhista;Re-marketing"
Patricia Gomes,+5561981112202,patricia.gomes@demo.local,Cliente,"GO;Familia;Pos-venda"
Bruno Fernandes,+5561981112203,bruno.fernandes@demo.local,Lead,"DF;Familia;Indicacao"
Renata Lima,+5561981112204,renata.lima@demo.local,Lead,"GO;Previdenciario;WhatsApp ativo"
Carlos Eduardo,+5561981112205,carlos.eduardo@demo.local,Cliente,"DF;Trabalhista;Pos-venda;Re-marketing"
Aline Martins,+5561981112206,aline.martins@demo.local,Lead,"DF;Previdenciario;Re-marketing"
Joao Pedro,+5561981112207,joao.pedro@demo.local,Lead,"GO;Trabalhista;Indicacao"
Fernanda Rocha,+5561981112208,fernanda.rocha@demo.local,Cliente,"DF;Familia;Pos-venda;WhatsApp ativo"
Lucas Ribeiro,+5561981112209,lucas.ribeiro@demo.local,Lead,"DF;Previdenciario;WhatsApp ativo"
Camila Nunes,+5561981112210,camila.nunes@demo.local,Lead,"GO;Familia;Re-marketing"
Thiago Moreira,+5561981112211,thiago.moreira@demo.local,Cliente,"DF;Trabalhista;Pos-venda"
Beatriz Santos,+5561981112212,beatriz.santos@demo.local,Lead,"DF;Previdenciario;Indicacao;Re-marketing"
Felipe Castro,+5561981112213,felipe.castro@demo.local,Lead,"GO;Trabalhista;WhatsApp ativo"
Natalia Barbosa,+5561981112214,natalia.barbosa@demo.local,Cliente,"DF;Familia;Pos-venda"
Diego Lopes,+5561981112215,diego.lopes@demo.local,Lead,"DF;Previdenciario;Nao chamar"
Juliana Pires,+5561981112216,juliana.pires@demo.local,Lead,"GO;Previdenciario;Re-marketing"
Marcelo Vieira,+5561981112217,marcelo.vieira@demo.local,Cliente,"DF;Trabalhista;Pos-venda;WhatsApp ativo"
Larissa Teixeira,+5561981112218,larissa.teixeira@demo.local,Lead,"DF;Familia;Indicacao;Re-marketing"
```

## 15. Proximo Passo Recomendado

Implementar primeiro o caminho rapido usando `Label` como categoria de contato:

1. Criar endpoint de categorias filtrando labels de contato.
2. Criar componente de barra de categorias na pagina de contatos.
3. Ajustar importacao para aceitar coluna `categorias`.
4. Mostrar chips de categorias no card/tabela.
5. Conectar campanhas para filtrar por categorias com incluir/excluir.

## 16. Implementacao Executada - Caminho Rapido

Status em 2026-05-06:

- [x] `Label` usado como categoria de contato.
- [x] Categorias adicionais suportadas: `location`, `campaign`, `custom` e `restriction`.
- [x] Importacao aceita coluna `categorias`.
- [x] Modal de importacao permite aplicar categorias adicionais a todos os contatos importados.
- [x] Pagina de contatos exibe painel/barra de categorias com contagem.
- [x] Pagina de contatos permite criar nova categoria.
- [x] Categoria selecionada filtra a listagem.
- [x] Atalho `Criar campanha` leva para campanhas com a audiencia atual na query.
- [x] Cards exibem categorias como chips com nome amigavel.
- [x] Criada task demo `crm:seed_contact_categories_demo`.
- [x] Task executada na conta 1, retornando 10 categorias e 20 contatos demo.
- [x] API dedicada `contact_categories` criada sobre `Label`.
- [x] Endpoints REST de categorias criados.
- [x] Acoes em massa `bulk_assign` e `bulk_remove` criadas.
- [x] Smoke autenticado da API executado em `localhost:3010`.
- [x] UI da pagina de contatos conectada a API `contact_categories`.
- [x] Criacao manual de categoria na UI usa o endpoint novo.
- [x] Acao em massa de adicionar categoria usa `bulk_assign`.
- [x] Acao em massa para remover contatos da categoria ativa usa `bulk_remove`.

Pendencias tecnicas para o proximo bloco:

- [ ] Criar preview real de importacao com categorias novas/existentes.
- [ ] Criar builder de audiencia com incluir/excluir categorias.
- [ ] Salvar segmentos de campanha reutilizaveis.
- [ ] Validar visualmente desktop/mobile e tema claro/escuro.
