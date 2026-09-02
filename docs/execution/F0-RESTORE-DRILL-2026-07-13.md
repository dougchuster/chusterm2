# F0 - Backup e ensaio de restauracao

**Data:** 2026-07-13  
**Branch/HEAD:** `main` / `f5f0dde`  
**Worktree:** misto e nao commitado; preservado conforme `WORKTREE-LEDGER.md`  
**Resultado:** aprovado no host local; copia externa ao host ainda pendente

## 1. Backup produzido

Comando executado na raiz do projeto:

```powershell
.\scripts\backup.ps1
```

Destino local: `backups/2026-07-13_183127/`.

- 13 arquivos;
- 197,7 MB;
- oito dumps PostgreSQL;
- snapshot Redis;
- `core-storage`;
- `evolution-instances`;
- `evolution-store`;
- snapshot compactado do codigo-fonte.

Todos os dumps passaram em `gzip -t`. Todos os arquivos `tar.gz` passaram em
leitura integral com `tar tzf`.

## 2. Checksums SHA-256

| Artefato | Bytes | SHA-256 |
|---|---:|---|
| `postgres/chusterm.sql.gz` | 387 | `2769EB37441FCC3E79D3013149F3B9F426FC59CE09C3809CDDA434806F3EB2AA` |
| `postgres/chusterm_ai.sql.gz` | 11.392 | `E0A0AA4D183A3B937395C04698E439400C1A78E1D1472985439CE7D07EC1B0BF` |
| `postgres/chusterm_core.sql.gz` | 819.617 | `AA9704F7A8E569FF8E62AEF91124B7CCF1524ED823C4E116D87BCC40CFC01B74` |
| `postgres/chusterm_core_test.sql.gz` | 29.869 | `55324CA3A94785698AA7AE3A628292FCBA5E645B630F6C2C78C74A4831638BAA` |
| `postgres/chusterm_crm.sql.gz` | 7.389 | `DB6A7656AE991F331C50D0F91AB256F555FACD92B987B327BA6AF2B9B914CDD0` |
| `postgres/chusterm_identity.sql.gz` | 1.240 | `9DF528EFF7CE843336BA0121C48A1E5A74FF231D428AC39D6BD829BFC6F1FD95` |
| `postgres/ChusteRM_test.sql.gz` | 38.502 | `5EC86F404B3989142CFDBE233BF1833F6D39BF93B453988F954B6D2AC95DAC80` |
| `postgres/evolution_api.sql.gz` | 349.641 | `7C43639EAE4E53ACB8BD39DA9741F8459C83451061CEC06CD9DA2FBCC9FBA54E` |
| `redis/dump.rdb` | 656.973 | `BB1D5AE9096CFFA79BF1C0381FB70B8AF9BA4A4B081C85273131DB020EDD0CEE` |
| `source.tar.gz` | 201.811.120 | `8D5E675C8254D8539B516E67AE9A83FE428F19059C2FAA2428B28F22C52CA275` |
| `volumes/core-storage.tar.gz` | 3.591.684 | `098DB3F4D5F16D8BBF4954F0DA0734D78449C24A94E9302B51BF8F8D20360340` |
| `volumes/evolution-instances.tar.gz` | 172 | `B3ABFDDBA0748E59625B9D1506B902E0F6C13B7DE8DED446691A7D45556F01EA` |
| `volumes/evolution-store.tar.gz` | 87 | `83BD4E8E6390C74D9C89EDFAD591E7E461E730BBBBD5D91FEB42D31FFB5D2A8E` |

## 3. Restauracao PostgreSQL

O dump `chusterm_core.sql.gz` foi restaurado na base descartavel
`chusterm_restore_drill_20260713_1836`. A restauracao usou
`ON_ERROR_STOP=1`. A base e o arquivo temporario no container foram removidos
ao final.

| Tabela | Origem | Restaurada |
|---|---:|---:|
| `accounts` | 1 | 1 |
| `captain_assistants` | 3 | 3 |
| `contacts` | 37 | 37 |
| `conversations` | 4 | 4 |
| `crm_deals` | 6 | 6 |
| `inboxes` | 4 | 4 |
| `messages` | 36 | 36 |
| `users` | 2 | 2 |

Resultado: `RESTORE_COUNTS_MATCH`.

## 4. Restauracao Redis

`redis-check-rdb` confirmou checksum valido, 638 chaves lidas e uma chave ja
expirada. O RDB foi carregado em um container e volume descartaveis:

- DB 0: 630 chaves;
- DB 1: 1 chave;
- DB 2: 2 chaves;
- DB 3: 4 chaves;
- total ativo restaurado: 637 chaves.

Resultado: `REDIS_RDB_RESTORE_RECONCILED`. A comparacao com o Redis vivo nao
e um oraculo estavel, pois filas e caches continuaram recebendo chaves depois
do snapshot.

## 5. Restauracao de volumes

Cada arquivo foi extraido em um volume Docker descartavel. Diretorios e
SHA-256 de todos os arquivos foram comparados com o volume de origem.

| Volume | Entradas no manifesto | Resultado |
|---|---:|---|
| `chusterm_core-storage` | 98 | identico |
| `chusterm_evolution-instances` | 3 | identico |
| `chusterm_evolution-store` | 1 | identico |

Todos os volumes descartaveis foram removidos ao final.

## 6. Pendencia operacional

O backup esta fora dos volumes Docker, mas continua no mesmo computador. O
Gate F0 somente deve considerar a estrategia de desastre completa depois que
uma copia criptografada for enviada a um destino externo autorizado e tiver
retencao/expiracao documentadas.
