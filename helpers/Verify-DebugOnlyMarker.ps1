#!/usr/bin/env pwsh
# helpers/Verify-DebugOnlyMarker.ps1 — assert that every occurrence of
# a "debug-only" override marker in source is wrapped by a preceding
# `#if DEBUG` / `#ifdef DEBUG` / `// @debug-only` guard within a
# configurable line lookback window. Catches the class where a
# smoke-only override (env-var escape hatch, manager-signal override,
# throttle bypass) silently leaks into release builds.
#
# See PITFALLS.md 2026-04-24 — debug-override guard — for the
# motivating lesson from cardgame-dad-relay #17/#18/#19.
#
# Config file (DEBUG-ONLY-MARKERS.json) drives the check:
#   {
#     "pairs": [
#       { "path": "Relay/Main.xaml.cs", "marker": "CCR_MANAGER_SIGNAL_JSON_OVERRIDE", "lookback": 12 },
#       { "path": "Tools/QA/Inspect/*.cs", "marker": "QA_FORCE_GATE_PASS", "lookback": 8 }
#     ],
#     "guard_patterns": [ "^\\s*#if DEBUG\\b", "^\\s*//\\s*@debug-only" ]
#   }
#
# Exit 0 on all-guarded; exit 4 on any unguarded hit (distinct from
# 1 missing-file / 2 config / 3 semantic-signal codes used by sibling
# helpers).

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
    foreach ($name in @('DEBUG-ONLY-MARKERS.json', '.autopilot/DEBUG-ONLY-MARKERS.json')) {
        $candidate = Join-Path $RepoRoot $name
        if (Test-Path $candidate) { return $candidate }
    }
    return $null
}

function Test-MarkerGuarded {
    param(
        [string]$FilePath,
        [string]$Marker,
        [int]$Lookback,
        [string[]]$GuardPatterns
    )
    $lines = @(Get-Content -LiteralPath $FilePath -ErrorAction Stop)
    $violations = @()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if (-not $lines[$i].Contains($Marker)) { continue }
        $guarded = $false
        $start = [math]::Max(0, $i - $Lookback)
        for ($j = $start; $j -lt $i; $j++) {
            foreach ($pat in $GuardPatterns) {
                if ($lines[$j] -match $pat) { $guarded = $true; break }
            }
            if ($guarded) { break }
        }
        if (-not $guarded) {
            $violations += [pscustomobject]@{
                file = $FilePath
                line = $i + 1
                marker = $Marker
                excerpt = $lines[$i].Trim()
            }
        }
    }
    return $violations
}

$configFile = Resolve-Config -Explicit $ConfigPath -RepoRoot $Root
if (-not $configFile) {
    $payload = [ordered]@{ ok = $false; reason = 'no DEBUG-ONLY-MARKERS.json found'; violations = @() }
    if ($AsJson) { $payload | ConvertTo-Json -Depth 4 -Compress } else { $payload | ConvertTo-Json -Depth 4 }
    exit 2
}

try {
    $config = Get-Content -LiteralPath $configFile -Raw | ConvertFrom-Json
}
catch {
    $payload = [ordered]@{ ok = $false; reason = "config parse error: $_"; violations = @() }
    if ($AsJson) { $payload | ConvertTo-Json -Depth 4 -Compress } else { $payload | ConvertTo-Json -Depth 4 }
    exit 2
}

$guardPatterns = @()
if ($config.guard_patterns) { $guardPatterns = @($config.guard_patterns) }
if ($guardPatterns.Count -eq 0) {
    $guardPatterns = @('^\s*#if\s+DEBUG\b', '^\s*//\s*@debug-only\b')
}

$allViolations = @()
$scanned = 0
foreach ($pair in $config.pairs) {
    $pattern = [string]$pair.path
    $marker = [string]$pair.marker
    $lookback = if ($pair.lookback) { [int]$pair.lookback } else { 12 }
    $files = @()
    if ($pattern.Contains('*') -or $pattern.Contains('?')) {
        $files = Get-ChildItem -Path (Join-Path $Root $pattern) -File -ErrorAction SilentlyContinue
    }
    else {
        $full = Join-Path $Root $pattern
        if (Test-Path $full -PathType Leaf) { $files = @(Get-Item -LiteralPath $full) }
    }
    if ($files.Count -eq 0) {
        $allViolations += [pscustomobject]@{
            file = $pattern
            line = 0
            marker = $marker
            excerpt = 'path glob did not match any file'
        }
        continue
    }
    foreach ($f in $files) {
        $scanned++
        $allViolations += Test-MarkerGuarded -FilePath $f.FullName -Marker $marker -Lookback $lookback -GuardPatterns $guardPatterns
    }
}

$payload = [ordered]@{
    probed_at = [DateTime]::UtcNow.ToString('o')
    config = $configFile
    files_scanned = $scanned
    pairs = @($config.pairs).Count
    ok = ($allViolations.Count -eq 0)
    violations = $allViolations
}

if ($AsJson) { $payload | ConvertTo-Json -Depth 4 -Compress } else { $payload | ConvertTo-Json -Depth 4 }

if ($allViolations.Count -gt 0) { exit 4 }
exit 0
