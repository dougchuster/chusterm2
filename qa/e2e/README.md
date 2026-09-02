# QA E2E da Fase 0

Projeto Playwright isolado para a baseline autenticada do ChusteRM. Ele usa a
fixture Rails `Qa::CanonicalFixture`; nunca deve apontar para produção.

## Preparação local

```powershell
$env:QA_FIXTURE_PASSWORD='defina-uma-senha-local-forte'
$env:QA_FIXTURE_NAMESPACE='f0'
docker compose exec -T -e QA_FIXTURE_PASSWORD=$env:QA_FIXTURE_PASSWORD -e QA_FIXTURE_NAMESPACE=$env:QA_FIXTURE_NAMESPACE -e QA_FIXTURE_TARGET=local-compose core bundle exec rake qa:seed

Set-Location qa/e2e
pnpm install
pnpm install:browsers
pnpm test:smoke
```

Para a amostra de capacidade, rode o seeder com
`QA_FIXTURE_DEAL_COUNT=1000`. O padrão de 201 cobre a regressão de paginação do
201º negócio. Repetir o comando com o mesmo namespace atualiza os registros sem
duplicá-los.

Os arquivos de sessão ficam em `playwright/.auth/` e não são versionados. O
manifesto de rotas é regenerado de `docs/audit/INVENTARIO-ROTAS.md` antes das
suítes e incorpora também drawers, modais, abas, estados e ChannelFactory.
