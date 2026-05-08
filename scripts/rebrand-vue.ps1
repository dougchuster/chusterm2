# rebrand-vue.ps1 — Substitui variáveis chatwoot* em arquivos .vue e .js do dashboard
# Uso no PowerShell: .\scripts\rebrand-vue.ps1

$dashboardDir = "core/app/javascript/dashboard"
$sharedDir = "core/app/javascript/shared"
$helpersDir = "core/app/javascript/dashboard/helper"

$count = 0
$files = @(Get-ChildItem -Path $dashboardDir,$sharedDir -Recurse -Include "*.vue","*.js" -Exclude "specs","specs.js","*spec.*")

# Patterns to replace (specific first)
$patterns = @(
    @("chatwootConfig", "chustermConfig"),
    @("ChatwootConfig", "ChusteRMConfig"),
    @("chatwootSDK", "chustermSDK"),
    @("chatwootSettings", "chustermSettings"),
    @("ChusteRMSettings", "ChusteRMSettings"),
    @("latestChatwootVersion", "latestChusteRMVersion"),
    @("latest_chatwoot_version", "latest_chusterm_version"),
    @("isOnChatwootCloud", "isOnChusteRMCloud"),
    @("isOnChatwootCloud\.value", "isOnChusteRMCloud.value"),
    @("isAChatwootInstance", "isAChusteRMInstance"),
    @("chatwootInboxToken", "chustermInboxToken"),
    @("isChatwootCloud", "isChusteRMCloud"),
    @("chatwoot\.com", "chusterm.com"),
    @("Chatwoot reset", "ChusteRM reset"),
    @("CHATWOOT_RESET", "CHUSTERM_RESET"),
    @("initializeChatwootEvents", "initializeChusteRMEvents"),
    @("chatwoot-events", "chusterm-events")
)

foreach ($file in $files) {
    try {
        $content = Get-Content $file.FullName -Raw -Encoding UTF8
        $original = $content

        foreach ($pair in $patterns) {
            $content = $content -replace $pair[0], $pair[1]
        }

        if ($content -ne $original) {
            Set-Content -Path $file.FullName -Value $content -Encoding UTF8 -NoNewline
            Write-Host "  ✅ $($file.Name) ($($file.DirectoryName.Substring($file.DirectoryName.LastIndexOf('\') + 1)))"
            $count++
        }
    } catch {
        Write-Host "  ❌ Erro em $($file.Name): $_"
    }
}

Write-Host ""
Write-Host "============================================================"
Write-Host " Arquivos Vue/JS atualizados: $count"
Write-Host "============================================================"