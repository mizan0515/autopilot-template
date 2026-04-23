#!/usr/bin/env pwsh
# helpers/Test-GeneratedFilesIgnored.ps1 — run each registered generator
# in a clean workspace, then assert `git status --porcelain` stays
# empty afterward. Catches the class where a generator emits a new
# file extension not covered by .gitignore and leaks into downstream
# `git status` one file-class at a time.
#
# See PITFALLS.md 2026-04-24 — "Runtime-generated artifacts leak into
# git status one file-extension at a time" — for the motivating
# lesson (cardgame-dad-relay #24 retrofitted .html/.json/.txt serially).
#
# Config file (GENERATORS.json) at repo root or .autopilot/GENERATORS.json:
#   {
#     "generators": [
#       {
#         "name": "operator-live-dashboard",
#         "command": "pwsh",
#         "args": ["-NoProfile", "-File", "tools/Write-OperatorLive.ps1"],
#         "expected_touch_globs": [".autopilot/OPERATOR-LIVE.ko.*"]
#       },
#       {
#         "name": "compact-status",
#         "command": "pwsh",
#         "args": ["-NoProfile", "-File", "tools/Write-CompactStatus.ps1"],
#         "expected_touch_globs": ["profiles/*/generated-*"]
#       }
#     ]
#   }
#
# For each generator:
#   1. record git status --porcelain baseline (must be empty, else exit 2)
#   2. run the command
#   3. diff git status --porcelain against baseline
#   4. any new path that is NOT matched by git check-ignore is a leak
#
# Exit 0 clean, exit 2 dirty baseline or config miss, exit 4 leak found.

[CmdletBinding()]
param(
    [string]$ConfigPath,
    [string]$Root = (Get-Location).Path,
    [switch]$AsJson
)

$ErrorActionPreference = 'Stop'

function Resolve-Config {
    param([string]$Explicit, [string]$RepoRoot)
    if ($Explicit -and (Test-Path $Explicit)) { return (Resolve-Path $Explicit).Path }
    foreach ($name in @('GENERATORS.json', '.autopilot/GENERATORS.json')) {
        $candidate = Join-Path $RepoRoot $name
        if (Test-Path $candidate) { return $candidate }
    }
    return $null
}

function Get-PorcelainPaths {
    param([string]$RepoRoot)
    $lines = & git -C $RepoRoot status --porcelain 2>$null
    if (-not $lines) { return @() }
    $paths = @()
    foreach ($line in @($lines)) {
        if ($line.Length -lt 4) { continue }
        $paths += $line.Substring(3).Trim()
    }
    return $paths
}

function Test-PathIgnored {
    param([string]$RepoRoot, [string]$RelPath)
    # git check-ignore exits 0 if the path is ignored, 1 if not.
    & git -C $RepoRoot check-ignore --quiet -- "$RelPath" 2>$null
    return ($LASTEXITCODE -eq 0)
}

$configFile = Resolve-Config -Explicit $ConfigPath -RepoRoot $Root
if (-not $configFile) {
    $payload = [ordered]@{ ok = $false; reason = 'no GENERATORS.json found'; leaks = @() }
    if ($AsJson) { $payload | ConvertTo-Json -Depth 4 -Compress } else { $payload | ConvertTo-Json -Depth 4 }
    exit 2
}

try { $config = Get-Content -LiteralPath $configFile -Raw | ConvertFrom-Json }
catch {
    $payload = [ordered]@{ ok = $false; reason = "config parse error: $_"; leaks = @() }
    if ($AsJson) { $payload | ConvertTo-Json -Depth 4 -Compress } else { $payload | ConvertTo-Json -Depth 4 }
    exit 2
}

$baseline = Get-PorcelainPaths -RepoRoot $Root
if ($baseline.Count -gt 0) {
    $payload = [ordered]@{
        ok = $false
        reason = 'git status --porcelain is not empty before generator run; refuse to test leakage against a dirty baseline'
        baseline = $baseline
        leaks = @()
    }
    if ($AsJson) { $payload | ConvertTo-Json -Depth 4 -Compress } else { $payload | ConvertTo-Json -Depth 4 }
    exit 2
}

$allLeaks = @()
$ranCount = 0
foreach ($gen in $config.generators) {
    $name = [string]$gen.name
    $cmd = [string]$gen.command
    $genArgs = @($gen.args | ForEach-Object { [string]$_ })
    try {
        Push-Location $Root
        & $cmd @genArgs 2>&1 | Out-Null
        $ranCount++
    }
    catch {
        $allLeaks += [pscustomobject]@{ generator = $name; leak = "command failed: $_"; ignored = $false }
        continue
    }
    finally { Pop-Location }
    $after = Get-PorcelainPaths -RepoRoot $Root
    foreach ($p in $after) {
        $ignored = Test-PathIgnored -RepoRoot $Root -RelPath $p
        if (-not $ignored) {
            $allLeaks += [pscustomobject]@{ generator = $name; leak = $p; ignored = $false }
        }
    }
}

$payload = [ordered]@{
    probed_at = [DateTime]::UtcNow.ToString('o')
    config = $configFile
    generators_run = $ranCount
    generators_total = @($config.generators).Count
    ok = ($allLeaks.Count -eq 0)
    leaks = $allLeaks
}

if ($AsJson) { $payload | ConvertTo-Json -Depth 4 -Compress } else { $payload | ConvertTo-Json -Depth 4 }

if ($allLeaks.Count -gt 0) { exit 4 }
exit 0
