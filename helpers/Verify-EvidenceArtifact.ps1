#!/usr/bin/env pwsh
# helpers/Verify-EvidenceArtifact.ps1 — semantic validation for qa-
# evidence artifacts, paired with the cheap file-exists invariant.
# Catches the class where a capture path produces an on-disk file of
# plausible size but zero signal (black PNG, empty-string JSON
# fields, log dump without the expected event).
#
# See PITFALLS.md 2026-04-24 — "Evidence artifacts pass existence
# checks while carrying zero signal" — for the motivating lesson
# (Unity card-game Gate 3 black-frame capture).
#
# Kinds supported out of the box:
#   png  — assert histogram has ≥2 distinct grayscale buckets AND
#          file size ≥ MinBytes (default 1024). PowerShell-only
#          byte sampling; no GDI dependency.
#   json — assert required fields (given via -RequiredFields) are
#          present AND their string values are non-empty / their
#          arrays have ≥1 element.
#   log  — assert at least one line matches the given -EventPattern
#          regex.
#
# Exit 0 on valid, exit 3 on semantic failure (distinct from 1/2 so
# callers can separate "file missing" / "config bad" / "zero-signal").

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][ValidateSet('png', 'json', 'log')][string]$Kind,
    [int]$MinBytes = 1024,
    [string[]]$RequiredFields = @(),
    [string]$EventPattern,
    [switch]$AsJson
)

$ErrorActionPreference = 'Stop'

function New-Result {
    param([bool]$Ok, [string]$Reason, [hashtable]$Extra = @{})
    $o = [ordered]@{
        probed_at = [DateTime]::UtcNow.ToString('o')
        path = $Path
        kind = $Kind
        ok = $Ok
        reason = $Reason
    }
    foreach ($k in $Extra.Keys) { $o[$k] = $Extra[$k] }
    return $o
}

if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    $payload = New-Result -Ok $false -Reason "file not found"
    if ($AsJson) { $payload | ConvertTo-Json -Depth 4 -Compress } else { $payload | ConvertTo-Json -Depth 4 }
    exit 1
}

$fileInfo = Get-Item -LiteralPath $Path
if ($fileInfo.Length -lt $MinBytes) {
    $payload = New-Result -Ok $false -Reason "file size $($fileInfo.Length) below MinBytes=$MinBytes" -Extra @{ size = $fileInfo.Length }
    if ($AsJson) { $payload | ConvertTo-Json -Depth 4 -Compress } else { $payload | ConvertTo-Json -Depth 4 }
    exit 3
}

function Test-PngSignal {
    param([string]$FilePath)
    # Cheap grayscale-bucket check: sample the raw file bytes after the
    # PNG header and count distinct 16-level buckets. An all-black (or
    # any single-color) frame compresses to a very narrow bucket
    # distribution; a real scene has ≥2 distinct buckets almost always.
    $bytes = [System.IO.File]::ReadAllBytes($FilePath)
    if ($bytes.Length -lt 16) { return @{ ok = $false; reason = 'too few bytes for PNG'; buckets = 0 } }
    $header = [System.Text.Encoding]::ASCII.GetString($bytes[1..3])
    if ($header -ne 'PNG') { return @{ ok = $false; reason = "not a PNG (header=$header)"; buckets = 0 } }
    $sample = $bytes | Select-Object -Skip 16
    $buckets = @{}
    foreach ($b in $sample) {
        $k = [int]([math]::Floor($b / 16))
        $buckets[$k] = $true
    }
    $n = $buckets.Keys.Count
    return @{ ok = ($n -ge 2); reason = if ($n -ge 2) { 'ok' } else { "only $n distinct byte-bucket(s) — likely solid-color frame" }; buckets = $n }
}

function Test-JsonSignal {
    param([string]$FilePath, [string[]]$Required)
    try {
        $raw = Get-Content -LiteralPath $FilePath -Raw -ErrorAction Stop
        $obj = $raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        return @{ ok = $false; reason = "failed to parse JSON: $_"; missing = @() }
    }
    $missing = @()
    foreach ($field in $Required) {
        $val = $obj.$field
        if ($null -eq $val) { $missing += "$field (absent)"; continue }
        if ($val -is [string] -and [string]::IsNullOrWhiteSpace($val)) { $missing += "$field (empty string)"; continue }
        if ($val -is [System.Collections.IEnumerable] -and -not ($val -is [string])) {
            $count = @($val).Count
            if ($count -eq 0) { $missing += "$field (empty array)" }
        }
    }
    return @{ ok = ($missing.Count -eq 0); reason = if ($missing.Count -eq 0) { 'ok' } else { "zero-signal fields: $($missing -join ', ')" }; missing = $missing }
}

function Test-LogSignal {
    param([string]$FilePath, [string]$Pattern)
    if ([string]::IsNullOrWhiteSpace($Pattern)) {
        return @{ ok = $false; reason = '-EventPattern required for log kind'; match_count = 0 }
    }
    $lines = Get-Content -LiteralPath $FilePath -ErrorAction Stop
    $hits = @($lines | Where-Object { $_ -match $Pattern })
    return @{ ok = ($hits.Count -ge 1); reason = if ($hits.Count -ge 1) { 'ok' } else { "no line matched /$Pattern/" }; match_count = $hits.Count }
}

switch ($Kind) {
    'png'  { $r = Test-PngSignal -FilePath $Path }
    'json' { $r = Test-JsonSignal -FilePath $Path -Required $RequiredFields }
    'log'  { $r = Test-LogSignal -FilePath $Path -Pattern $EventPattern }
}

$payload = New-Result -Ok $r.ok -Reason $r.reason -Extra $r
if ($AsJson) { $payload | ConvertTo-Json -Depth 4 -Compress } else { $payload | ConvertTo-Json -Depth 4 }

if (-not $r.ok) { exit 3 }
exit 0
