# rebrand-ruby-full.ps1 — Substitui Chatwoot→ChusteRM em TODOS os arquivos do Core
# Inclui .rb, .erb, .yml, .yaml, .json, .md, .css, .scss
# Uso: .\scripts\rebrand-ruby-full.ps1

$patterns = @(
    @("ChatwootExceptionTracker", "ChusteRMExceptionTracker"),
    @("ChatwootCaptcha", "ChusteRMCaptcha"),
    @("ChatwootMarkdownRenderer", "ChusteRMMarkdownRenderer"),
    @("ChatwootHub", "ChusteRMHub"),
    @("ChatwootApp", "ChusteRMApp"),
    @("Chatwoot\.config", "ChusteRM.config"),
    @("Chatwoot\.mfa_enabled\?", "ChusteRM.mfa_enabled?"),
    @("chatwoot\.com", "chusterm.com"),
    @("chatwootConfig", "chustermConfig"),
    @("Chatwoot", "ChusteRM"),
    @("chatwoot", "chusterm"),
    @("CHATWOOT", "CHUSTERM")
)

$extensions = @("*.rb","*.erb","*.yml","*.yaml","*.md","*.css","*.scss","*.txt","*.json")
$excludeDirs = @("node_modules",".git","vendor","coverage","dist","build","enterprise")

$count = 0
$baseDirs = @("core/app","core/lib","core/config","core/public","core/swagger")

foreach ($dir in $baseDirs) {
    if (-not (Test-Path $dir)) { continue }

    foreach ($ext in $extensions) {
        $files = Get-ChildItem -Path $dir -Recurse -Include $ext | Where-Object {
            $path = $_.FullName
            $skip = $false
            foreach ($excl in $excludeDirs) {
                if ($path -match [regex]::Escape($excl)) { $skip = $true; break }
            }
            -not $skip
        }

        foreach ($file in $files) {
            try {
                $content = Get-Content $file.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
                if (-not $content) { continue }
                $original = $content

                foreach ($pair in $patterns) {
                    $content = $content -replace $pair[0], $pair[1]
                }

                if ($content -ne $original) {
                    Set-Content -Path $file.FullName -Value $content -Encoding UTF8 -NoNewline
                    $relPath = $file.FullName.Replace((Get-Location).Path + '\', '').Replace('\', '/')
                    Write-Host "  ✅ $relPath"
                    $count++
                }
            } catch {
                # Silently skip files that can't be read
            }
        }
    }
}

Write-Host ""
Write-Host "============================================================"
Write-Host " Arquivos atualizados: $count"
Write-Host "============================================================"