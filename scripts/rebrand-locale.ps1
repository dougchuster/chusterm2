# rebrand-locale.ps1 — Substitui referências de Chatwoot para ChusteRM nos arquivos de locale
# Uso no PowerShell: .\scripts\rebrand-locale.ps1

$localeDir = "core/app/javascript/dashboard/i18n/locale/pt_BR"

$count = 0
$files = Get-ChildItem -Path $localeDir -Filter "*.json"

foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw -Encoding UTF8
    $original = $content
    $fileChanged = $false

    # Use specific order to avoid overlap issues
    # Longer/more specific patterns first
    $patterns = @(
        @("app\.chatwoot\.com", "app.chusterm.com"),
        @("www\.chatwoot\.com", "www.chusterm.com"),
        @("chatwoot\.help", "chusterm.help"),
        @("chatwoot\.com", "chusterm.com"),
        @("Chatwoot", "ChusteRM"),
        @("chatwoot", "chusterm")
    )

    foreach ($pair in $patterns) {
        $content = $content -replace $pair[0], $pair[1]
    }

    if ($content -ne $original) {
        Set-Content -Path $file.FullName -Value $content -Encoding UTF8 -NoNewline
        Write-Host "  ✅ $($file.Name)"
        $count++
    }
}

Write-Host ""
Write-Host "============================================================"
Write-Host " Arquivos atualizados: $count"
Write-Host "============================================================"