#!/usr/bin/env pwsh
# helpers/Verify-Terminology.ps1 — scan staged diff (or arbitrary files)
# for forbidden-variant terms that keep drifting back from legacy
# codebase context. Config-driven via TERMINOLOGY.md / TERMINOLOGY.json
# so downstreams register their own canonical/forbidden pairs.
#
# See PITFALLS.md 2026-04-24 — "Domain terminology regresses to
# similar-sounding wrong terms unless grep-pinned" — for the
# motivating lesson from Unity card-game (MatchScore vs StageScore,
# 수정비 vs 예정비).
#
# Default mode: scan `git diff --cached` (pre-commit hook usage).
# -Path mode: scan specific files or a directory tree.
#
# Exit codes:
#   0 — no forbidden variants found
#   2 — forbidden variant found (distinct from 1 so hooks can tell
#       a config error apart from a real drift hit)
#
# Intended installation:
#   cp helpers/Verify-Terminology.ps1 <downstream>/tools/
#   cp helpers/TERMINOLOGY.example.md <downstream>/TERMINOLOGY.md
#   add a .githooks/pre-commit line: pwsh tools/Verify-Terminology.ps1

[CmdletBinding()]
param(
    [string]$ConfigPath,
    [string[]]$Path,
    [switch]$Staged,
    [switch]$AsJson
)

$ErrorActionPreference = 'Stop'

function Resolve-ConfigPath {
    param([string]$Explicit, [string]$RepoRoot)
    if ($Explicit -and (Test-Path $Explicit)) { return (Resolve-Path $Explicit).Path }
    foreach ($name in @('TERMINOLOGY.json', 'TERMINOLOGY.md')) {
        $candidate = Join-Path $RepoRoot $name
        if (Test-Path $candidate) { return $candidate }
    }
    return $null
}

function Parse-TerminologyConfig {
    # Accepts either JSON or a simple markdown table with columns
    # | forbidden | canonical | note |.
    # Returns an array of { forbidden; canonical; note } hashtables.
    param([string]$ConfigFile)
    if (-not $ConfigFile) { return @() }
    $ext = [System.IO.Path]::GetExtension($ConfigFile).ToLowerInvariant()
    $raw = Get-Content -LiteralPath $ConfigFile -Raw -ErrorAction Stop
    if ($ext -eq '.json') {
        $data = $raw | ConvertFrom-Json
        return @($data.pairs | ForEach-Object {
            [pscustomobject]@{
                forbidden = [string]$_.forbidden
                canonical = [string]$_.canonical
                note = [string]$_.note
            }
        })
    }
    $pairs = @()
    foreach ($line in ($raw -split "`r?`n")) {
        if ($line -notmatch '^\s*\|') { continue }
        if ($line -match '^\s*\|\s*-+') { continue }
        if ($line -match '^\s*\|\s*forbidden\s*\|') { continue }
        $cols = @($line -split '\|' | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 })
        if ($cols.Count -lt 2) { continue }
        $pairs += [pscustomobject]@{
            forbidden = $cols[0]
            canonical = $cols[1]
            note = if ($cols.Count -ge 3) { $cols[2] } else { '' }
        }
    }
    return $pairs
}

function Get-ScanText {
    param(
        [string[]]$Paths,
        [switch]$StagedDiff
    )
    if ($StagedDiff) {
        $diff = & git diff --cached --unified=0 2>$null
        return [string]::Join("`n", @($diff))
    }
    $chunks = @()
    foreach ($p in $Paths) {
        if (Test-Path $p -PathType Container) {
            $files = Get-ChildItem -LiteralPath $p -Recurse -File -ErrorAction SilentlyContinue
            foreach ($f in $files) {
                try { $chunks += (Get-Content -LiteralPath $f.FullName -Raw -ErrorAction Stop) } catch {}
            }
        }
        elseif (Test-Path $p -PathType Leaf) {
            try { $chunks += (Get-Content -LiteralPath $p -Raw -ErrorAction Stop) } catch {}
        }
    }
    return [string]::Join("`n", $chunks)
}

$repoRoot = (& git rev-parse --show-toplevel 2>$null | Select-Object -First 1)
if (-not $repoRoot) { $repoRoot = (Get-Location).Path }
$resolvedConfig = Resolve-ConfigPath -Explicit $ConfigPath -RepoRoot $repoRoot
$pairs = Parse-TerminologyConfig -ConfigFile $resolvedConfig

if (-not $Path -and -not $Staged) { $Staged = $true }

$scanText = Get-ScanText -Paths $Path -StagedDiff:$Staged

$hits = @()
foreach ($pair in $pairs) {
    if ([string]::IsNullOrWhiteSpace($pair.forbidden)) { continue }
    $pattern = [regex]::Escape($pair.forbidden)
    $matches = [regex]::Matches($scanText, $pattern)
    if ($matches.Count -gt 0) {
        $hits += [pscustomobject]@{
            forbidden = $pair.forbidden
            canonical = $pair.canonical
            note = $pair.note
            occurrences = $matches.Count
        }
    }
}

$payload = [ordered]@{
    probed_at = [DateTime]::UtcNow.ToString('o')
    config = $resolvedConfig
    pairs_checked = $pairs.Count
    mode = if ($Staged) { 'staged-diff' } else { 'paths' }
    hits = $hits
}

if ($AsJson) {
    $payload | ConvertTo-Json -Depth 4 -Compress
}
else {
    $payload | ConvertTo-Json -Depth 4
}

if ($hits.Count -gt 0) { exit 2 }
exit 0
