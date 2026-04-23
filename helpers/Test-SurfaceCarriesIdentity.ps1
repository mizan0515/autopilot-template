#!/usr/bin/env pwsh
# helpers/Test-SurfaceCarriesIdentity.ps1 — enumerate every machine-
# readable output surface (dashboards, signal JSON, terminal writeback,
# operator HTML, manager status) and fail if any of them omits the
# expected `repo_identity` fingerprint. Catches the serial-retrofit
# class where identity is declared once in an IMMUTABLE block but
# surfaces carry it only after N PRs retrofit one at a time.
#
# See PITFALLS.md 2026-04-24 — "Repo identity belongs on every
# machine-readable output surface" — and cardgame-dad-relay #7-#11
# for the motivating five-PR retrofit chain.
#
# Config file (SURFACES.json) at repo root or .autopilot/SURFACES.json:
#   {
#     "expected_identity_marker": "repo_identity",
#     "surfaces": [
#       { "path": "profiles/card-game/generated-status.json", "kind": "json",
#         "required_fields": ["repo_identity", "repo_identity.remote_origin"] },
#       { "path": "profiles/card-game/generated-status.md", "kind": "text",
#         "required_pattern": "repo_identity:\\s*\\S+" },
#       { "path": ".autopilot/OPERATOR-LIVE.ko.html", "kind": "text",
#         "required_pattern": "repo[-_]identity" }
#     ]
#   }
#
# Exit 0 all surfaces carry identity; exit 1 missing file; exit 2 config
# miss; exit 3 identity marker absent from one or more surfaces.

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
    foreach ($name in @('SURFACES.json', '.autopilot/SURFACES.json')) {
        $candidate = Join-Path $RepoRoot $name
        if (Test-Path $candidate) { return $candidate }
    }
    return $null
}

function Test-JsonSurface {
    param([string]$FilePath, [string[]]$RequiredFields)
    try { $obj = Get-Content -LiteralPath $FilePath -Raw | ConvertFrom-Json -ErrorAction Stop }
    catch { return @{ ok = $false; reason = "JSON parse error: $_"; missing = @() } }
    $missing = @()
    foreach ($field in $RequiredFields) {
        $parts = $field -split '\.'
        $cur = $obj
        $found = $true
        foreach ($p in $parts) {
            if ($null -eq $cur) { $found = $false; break }
            $cur = $cur.$p
            if ($null -eq $cur) { $found = $false; break }
        }
        if (-not $found) { $missing += $field; continue }
        if ($cur -is [string] -and [string]::IsNullOrWhiteSpace($cur)) { $missing += "$field (empty)" }
    }
    return @{ ok = ($missing.Count -eq 0); reason = if ($missing.Count -eq 0) { 'ok' } else { "missing: $($missing -join ', ')" }; missing = $missing }
}

function Test-TextSurface {
    param([string]$FilePath, [string]$Pattern)
    $text = Get-Content -LiteralPath $FilePath -Raw -ErrorAction Stop
    if ($text -match $Pattern) {
        return @{ ok = $true; reason = 'ok'; pattern = $Pattern }
    }
    return @{ ok = $false; reason = "pattern /$Pattern/ not found"; pattern = $Pattern }
}

$configFile = Resolve-Config -Explicit $ConfigPath -RepoRoot $Root
if (-not $configFile) {
    $payload = [ordered]@{ ok = $false; reason = 'no SURFACES.json found'; failures = @() }
    if ($AsJson) { $payload | ConvertTo-Json -Depth 4 -Compress } else { $payload | ConvertTo-Json -Depth 4 }
    exit 2
}

try { $config = Get-Content -LiteralPath $configFile -Raw | ConvertFrom-Json }
catch {
    $payload = [ordered]@{ ok = $false; reason = "config parse: $_"; failures = @() }
    if ($AsJson) { $payload | ConvertTo-Json -Depth 4 -Compress } else { $payload | ConvertTo-Json -Depth 4 }
    exit 2
}

$failures = @()
$checked = 0
foreach ($surface in $config.surfaces) {
    $relPath = [string]$surface.path
    $kind = [string]$surface.kind
    $full = Join-Path $Root $relPath
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        $failures += [pscustomobject]@{ surface = $relPath; kind = $kind; failure = 'file not found' }
        continue
    }
    $checked++
    $r = switch ($kind) {
        'json' { Test-JsonSurface -FilePath $full -RequiredFields @($surface.required_fields) }
        'text' { Test-TextSurface -FilePath $full -Pattern ([string]$surface.required_pattern) }
        default { @{ ok = $false; reason = "unknown kind '$kind'" } }
    }
    if (-not $r.ok) {
        $failures += [pscustomobject]@{ surface = $relPath; kind = $kind; failure = $r.reason }
    }
}

$anyMissingFile = ($failures | Where-Object { $_.failure -eq 'file not found' }).Count -gt 0
$anyIdentityGap = ($failures | Where-Object { $_.failure -ne 'file not found' }).Count -gt 0

$payload = [ordered]@{
    probed_at = [DateTime]::UtcNow.ToString('o')
    config = $configFile
    surfaces_checked = $checked
    surfaces_total = @($config.surfaces).Count
    ok = ($failures.Count -eq 0)
    failures = $failures
}

if ($AsJson) { $payload | ConvertTo-Json -Depth 4 -Compress } else { $payload | ConvertTo-Json -Depth 4 }

if ($anyMissingFile) { exit 1 }
if ($anyIdentityGap) { exit 3 }
exit 0
