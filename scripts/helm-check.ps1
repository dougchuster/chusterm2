param(
  [string]$ProjectRoot = "."
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Section {
  param([string]$Title)
  Write-Host ""
  Write-Host "=== $Title ==="
}

function Assert-Ok {
  param(
    [bool]$Condition,
    [string]$SuccessMessage,
    [string]$FailureMessage
  )

  if ($Condition) {
    Write-Host "[OK]  $SuccessMessage"
    return $true
  }

  Write-Host "[ERR] $FailureMessage"
  return $false
}

$checks = @()

Push-Location $ProjectRoot
try {
  Write-Section "Docker Compose status"
  $composePs = docker compose ps --format json | ConvertFrom-Json

  if (-not $composePs) {
    throw "Nenhum servico encontrado no docker compose."
  }

  foreach ($svc in $composePs) {
    $isUp = $svc.State -eq "running"
    $isHealthy = ($svc.Health -eq "") -or ($svc.Health -eq "healthy")
    $checks += Assert-Ok -Condition ($isUp -and $isHealthy) `
      -SuccessMessage "$($svc.Service) em estado $($svc.State) health=$($svc.Health)" `
      -FailureMessage "$($svc.Service) com problema: state=$($svc.State) health=$($svc.Health)"
  }

  Write-Section "HTTP endpoints"
  $endpoints = @(
    @{ Name = "Core health"; Url = "http://localhost:3010/health"; Expected = 200 },
    @{ Name = "Mailhog UI"; Url = "http://localhost:8025"; Expected = 200 },
    @{ Name = "Evolution API"; Url = "http://localhost:8085"; Expected = 200 }
  )

  foreach ($ep in $endpoints) {
    try {
      $status = (Invoke-WebRequest -Uri $ep.Url -UseBasicParsing -TimeoutSec 15).StatusCode
      $checks += Assert-Ok -Condition ($status -eq $ep.Expected) `
        -SuccessMessage "$($ep.Name) respondeu HTTP $status" `
        -FailureMessage "$($ep.Name) respondeu HTTP $status (esperado $($ep.Expected))"
    }
    catch {
      $checks += Assert-Ok -Condition $false `
        -SuccessMessage "$($ep.Name) respondeu" `
        -FailureMessage "$($ep.Name) falhou: $($_.Exception.Message)"
    }
  }

  Write-Section "Postgres and Redis"
  docker exec chusterm-postgres-1 pg_isready -U chusterm | Out-Null
  $checks += Assert-Ok -Condition ($LASTEXITCODE -eq 0) `
    -SuccessMessage "Postgres aceitando conexoes" `
    -FailureMessage "Postgres nao respondeu ao pg_isready"

  $redisPing = docker exec chusterm-redis-1 redis-cli -a chusterm_redis_pass ping
  $checks += Assert-Ok -Condition (($LASTEXITCODE -eq 0) -and ($redisPing -match "PONG")) `
    -SuccessMessage "Redis respondeu PONG" `
    -FailureMessage "Redis nao respondeu PONG"

  Write-Section "Rails integrity"
  docker exec chusterm-core-1 bundle exec rails runner "puts ActiveRecord::Base.connection.migration_context.needs_migration? ? 'PENDING' : 'OK'"
  $checks += Assert-Ok -Condition ($LASTEXITCODE -eq 0) `
    -SuccessMessage "Rails runner executado sem erros" `
    -FailureMessage "Falha ao executar rails runner"

  Write-Section "Summary"
  $total = $checks.Count
  $passed = ($checks | Where-Object { $_ -eq $true }).Count
  $failed = $total - $passed

  Write-Host "Checks aprovados: $passed/$total"

  if ($failed -gt 0) {
    Write-Host "Falhas detectadas: $failed"
    exit 1
  }

  Write-Host "Sistema saudavel."
}
finally {
  Pop-Location
}
