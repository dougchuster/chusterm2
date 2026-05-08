# rebrand-ruby.ps1 — Substitui referências Chatwoot* em arquivos Ruby do Core
# Uso: .\scripts\rebrand-ruby.ps1

$coreDir = "core/app"
$libDir = "core/lib"
$configDir = "core/config"

$count = 0
$files = @(Get-ChildItem -Path $coreDir,$libDir,$configDir -Recurse -Include "*.rb" | Where-Object { $_.FullName -notmatch "spec|test|enterprise" })

# Patterns - order matters (longer/more specific first)
$patterns = @(
    @("ChatwootExceptionTracker", "ChusteRMExceptionTracker"),
    @("ChatwootCaptcha", "ChusteRMCaptcha"),
    @("ChatwootMarkdownRenderer", "ChusteRMMarkdownRenderer"),
    @("ChatwootHub", "ChusteRMHub"),
    @("ChatwootApp", "ChusteRMApp"),
    @("Chatwoot\.config", "ChusteRM.config"),
    @("Chatwoot\.mfa_enabled\?", "ChusteRM.mfa_enabled?"),
    @("chatwootConfig", "chustermConfig"),
    @("Chatwoot", "ChusteRM"),
    @("chatwoot", "chusterm"),
    @("CHATWOOT", "CHUSTERM")
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
            $relPath = $file.FullName.Replace((Get-Location).Path + '\', '').Replace('\', '/')
            $dir = [System.IO.Path]::GetDirectoryName($relPath)
            Write-Host "  ✅ $($file.Name) ($dir)"
            $count++
        }
    } catch {
        Write-Host "  ❌ Erro em $($file.Name): $_"
    }
}

Write-Host ""
Write-Host "============================================================"
Write-Host " Arquivos Ruby atualizados: $count"
Write-Host "============================================================"