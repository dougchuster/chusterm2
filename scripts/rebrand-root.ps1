# rebrand-root.ps1 — Rebrand dos arquivos raiz do Core (README, LICENSE, AGENTS.md, etc)
$files = @(
    "core/README.md",
    "core/AGENTS.md", 
    "core/CONTRIBUTING.md",
    "core/SECURITY.md",
    "core/CODE_OF_CONDUCT.md",
    "core/LICENSE",
    "core/CLAUDE.md",
    "core/app.json",
    "core/.devcontainer/devcontainer.json",
    "core/public/brand-assets/logo-dark.svg",
    "core/public/brand-assets/logo-light.svg"
)

$patterns = @(
    @("ChatwootExceptionTracker", "ChusteRMExceptionTracker"),
    @("ChatwootCaptcha", "ChusteRMCaptcha"),
    @("ChatwootMarkdownRenderer", "ChusteRMMarkdownRenderer"),
    @("ChatwootHub", "ChusteRMHub"),
    @("ChatwootApp", "ChusteRMApp"),
    @("chatwoot\.com", "chusterm.com"),
    @("chatwootConfig", "chustermConfig"),
    @("Chatwoot", "ChusteRM"),
    @("chatwoot", "chusterm"),
    @("CHATWOOT", "CHUSTERM")
)

$count = 0

foreach ($file in $files) {
    if (-not (Test-Path $file)) { continue }
    
    try {
        $content = Get-Content $file.FullName -Raw -Encoding UTF8
        $original = $content
        
        foreach ($pair in $patterns) {
            if ($content -is [string]) {
                $content = $content -replace $pair[0], $pair[1]
            }
        }
        
        if ($content -ne $original) {
            Set-Content -Path $file -Value $content -Encoding UTF8 -NoNewline
            Write-Host "  ✅ $file"
            $count++
        }
    } catch {
        Write-Host "  ❌ Erro em $file"
    }
}

Write-Host ""
Write-Host "============================================================"
Write-Host " Arquivos root atualizados: $count"
Write-Host "============================================================"