# =============================================================================
# ChusteRM - Backup Completo
# Uso: .\scripts\backup.ps1
# Salva em: ./backups/YYYY-MM-DD_HHMMSS/
# =============================================================================

$ErrorActionPreference = "Stop"

$timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
$backupRoot = Join-Path $PSScriptRoot "..\backups\$timestamp"
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null

Write-Host ""
Write-Host "==> Backup ChusteRM iniciado: $timestamp" -ForegroundColor Cyan
Write-Host "    Destino: $backupRoot" -ForegroundColor Gray
Write-Host ""

# -----------------------------------------------------------------------------
# 1. PostgreSQL — dump de todos os bancos
# -----------------------------------------------------------------------------
Write-Host "[1/4] PostgreSQL..." -ForegroundColor Yellow

$pgDir = Join-Path $backupRoot "postgres"
New-Item -ItemType Directory -Path $pgDir -Force | Out-Null

$dbs = @(
    docker compose exec -T postgres psql -U chusterm -Atc `
        "SELECT datname FROM pg_database WHERE datistemplate = false AND datname <> 'postgres' ORDER BY datname"
) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

if ($LASTEXITCODE -ne 0 -or $dbs.Count -eq 0) {
    throw "Nao foi possivel descobrir os bancos PostgreSQL para backup."
}

foreach ($db in $dbs) {
    Write-Host "      -> $db"
    # Dump dentro do container
    docker compose exec -T postgres sh -c "pg_dump -U chusterm $db | gzip > /tmp/$db.sql.gz"
    if ($LASTEXITCODE -ne 0) { throw "Falha no dump PostgreSQL de $db." }
    # Copia para o host
    docker compose cp "postgres:/tmp/$db.sql.gz" "$pgDir\$db.sql.gz"
    if ($LASTEXITCODE -ne 0) { throw "Falha ao copiar o dump PostgreSQL de $db." }
    # Remove temporário
    docker compose exec -T postgres rm -f "/tmp/$db.sql.gz"
}

Write-Host "    OK" -ForegroundColor Green

# -----------------------------------------------------------------------------
# 2. Redis — snapshot RDB
# -----------------------------------------------------------------------------
Write-Host "[2/4] Redis..." -ForegroundColor Yellow

$redisDir = Join-Path $backupRoot "redis"
New-Item -ItemType Directory -Path $redisDir -Force | Out-Null

docker compose exec -T redis redis-cli -a chusterm_redis_pass BGSAVE | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Falha ao solicitar snapshot do Redis." }
Start-Sleep -Seconds 3
docker compose cp "redis:/data/dump.rdb" "$redisDir\dump.rdb"
if ($LASTEXITCODE -ne 0) { throw "Falha ao copiar o snapshot do Redis." }

Write-Host "    OK" -ForegroundColor Green

# -----------------------------------------------------------------------------
# 3. Volumes Docker (evolution-instances, evolution-store)
# -----------------------------------------------------------------------------
Write-Host "[3/4] Volumes Docker..." -ForegroundColor Yellow

$volumesDir = Join-Path $backupRoot "volumes"
New-Item -ItemType Directory -Path $volumesDir -Force | Out-Null
# Usa caminho absoluto para bind mount no docker run
$volumesDirAbs = (Resolve-Path $volumesDir).Path.Replace('\', '/')

$volumes = @{
    "chusterm_evolution-instances" = "evolution-instances.tar.gz"
    "chusterm_evolution-store"     = "evolution-store.tar.gz"
    "chusterm_core-storage"        = "core-storage.tar.gz"
}

foreach ($vol in $volumes.GetEnumerator()) {
    Write-Host "      -> $($vol.Key)"
    docker run --rm `
        -v "$($vol.Key):/data:ro" `
        -v "${volumesDirAbs}:/out" `
        alpine sh -c "tar czf /out/$($vol.Value) -C /data ."
    if ($LASTEXITCODE -ne 0) { throw "Falha no backup do volume $($vol.Key)." }
}

Write-Host "    OK" -ForegroundColor Green

# -----------------------------------------------------------------------------
# 4. Código-fonte (excluindo node_modules, tmp, log, .git, backups)
# -----------------------------------------------------------------------------
Write-Host "[4/4] Código-fonte..." -ForegroundColor Yellow

$sourceDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path.Replace('\', '/')
$backupRootAbs = (Resolve-Path $backupRoot).Path.Replace('\', '/')

docker run --rm `
    -v "${sourceDir}:/src:ro" `
    -v "${backupRootAbs}:/out" `
    alpine sh -c "tar czf /out/source.tar.gz -C /src --exclude=./core/node_modules --exclude=./core/tmp --exclude=./core/log --exclude=./core/public/vite --exclude=./.git --exclude=./backups --exclude=./services/orchestrator/node_modules ."
if ($LASTEXITCODE -ne 0) { throw "Falha no backup do codigo-fonte." }

Write-Host "    OK" -ForegroundColor Green

# -----------------------------------------------------------------------------
# Resumo
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "==> Backup concluido com sucesso!" -ForegroundColor Green
Write-Host ""

$items = Get-ChildItem -Recurse $backupRoot -File
$totalSize = ($items | Measure-Object -Property Length -Sum).Sum / 1MB
Write-Host ("    Arquivos : {0}" -f $items.Count)
Write-Host ("    Tamanho  : {0:N1} MB" -f $totalSize)
Write-Host "    Pasta    : $backupRoot"
Write-Host ""
