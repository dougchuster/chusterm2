# CRM Service (legado / apoio tecnico)

Este servico nao e o CRM oficial do ChusteRM.

A fonte unica de verdade do CRM juridico fica dentro do fork do Chatwoot em `core/`, usando `Contact`, `Conversation`, `Label`, `Attachment`, `CrmDeal`, `CrmActivity` e Captain.

Uso permitido:

- apoio tecnico temporario;
- compatibilidade com rotinas antigas;
- testes internos e experimentos;
- integracoes que leem ou encaminham dados para o `core/`.

Uso nao permitido:

- manter contatos, lifecycle, etiquetas, responsaveis ou deals como fonte primaria;
- criar uma experiencia de CRM paralela ao ChusteRM Core;
- fazer o Capitao depender deste servico antes de consultar o Core.

Qualquer melhoria nova de CRM deve ser implementada primeiro em `core/`.
