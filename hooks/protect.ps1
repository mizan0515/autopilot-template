# .autopilot/hooks/protect.ps1 — PowerShell port of protect.sh for Windows dev boxes
# Install via a bootstrap pre-commit.cmd in .git/hooks that invokes this with -File.

$ErrorActionPreference = 'Stop'
$prompt = '.autopilot/PROMPT.md'

$staged = git diff --cached --name-only
if ($staged -notcontains $prompt) { exit 0 }

try { git rev-parse --verify HEAD | Out-Null } catch { exit 0 }

$blocks = 'core-contract','boot','budget','blast-radius','halt','exit-contract','wake-reschedule','decision-pr-invariants'

$baseText = git show "HEAD:$prompt"
$headText = git show ":$prompt"

foreach ($name in $blocks) {
    $beginPattern = [regex]::Escape("[IMMUTABLE:BEGIN $name]")
    $endPattern   = [regex]::Escape("[IMMUTABLE:END $name]")

    if ($headText -notmatch $beginPattern -or $headText -notmatch $endPattern) {
        Write-Host "protect.ps1: IMMUTABLE markers for '$name' are missing from $prompt"
        Write-Host "  -> commit rejected."
        exit 1
    }

    $rx = "(?s)$beginPattern.*?$endPattern"
    $baseBlock = [regex]::Match($baseText, $rx).Value
    $headBlock = [regex]::Match($headText, $rx).Value

    if ($baseBlock -ne $headBlock) {
        Write-Host "protect.ps1: IMMUTABLE block '$name' was modified in $prompt"
        Write-Host "  -> commit rejected."
        exit 1
    }
}

exit 0
