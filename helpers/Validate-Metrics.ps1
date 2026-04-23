#!/usr/bin/env pwsh
# helpers/Validate-Metrics.ps1 — scan the tail of METRICS.jsonl and
# assert each line carries the Tier 1 required fields. Catches the
# class where a downstream silently drops a required field (e.g.
# `ts` disappearing from codex-claude-relay's METRICS) — any cross-
# iter time-series tool then breaks without a visible error.
#
# See PITFALLS.md 2026-04-24 — "METRICS.jsonl dropped `ts` field" —
# for the motivating lesson.
#
# Tier convention (per PROMPT.md METRICS schema section):
#   Tier 1 required     — always present, never drop
#   Tier 2 reserved     — shared reserved names (optional but no
#                         project-prefix conflicts)
#   Tier 3 project      — must use a project-name prefix
#
# Default Tier 1 set: ts, iter, mode. Override via -Tier1Fields.
#
# Exit codes:
#   0 — all checked lines carry Tier 1
#   1 — METRICS.jsonl not found
#   2 — one or more lines fail JSON parse
#   3 — Tier 1 field missing on at least one line
#   4 — Tier 3 field present without project prefix (strict mode)

[CmdletBinding()]
param(
    [string]$Path = '.autopilot/METRICS.jsonl',
    [string[]]$Tier1Fields = @('ts', 'iter', 'mode'),
    [string[]]$Tier2Reserved = @('mvp_gates_passing', 'cumulative_merges', 'pending_review', 'idle_upkeep_streak', 'merged', 'mcp_calls', 'warnings', 'reschedule', 'claude_cli', 'codex_cli'),
    [string]$ProjectPrefix,
    [int]$TailLines = 20,
    [switch]$Strict,
    [switch]$AsJson
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    $payload = [ordered]@{ ok = $false; reason = "METRICS file not found: $Path"; violations = @() }
    if ($AsJson) { $payload | ConvertTo-Json -Depth 4 -Compress } else { $payload | ConvertTo-Json -Depth 4 }
    exit 1
}

$lines = @(Get-Content -LiteralPath $Path -ErrorAction Stop)
$tail = if ($lines.Count -le $TailLines) { $lines } else { $lines[($lines.Count - $TailLines)..($lines.Count - 1)] }

$violations = @()
$parseFails = 0
$lineNoBase = $lines.Count - $tail.Count + 1

for ($i = 0; $i -lt $tail.Count; $i++) {
    $lineNo = $lineNoBase + $i
    $text = $tail[$i]
    if ([string]::IsNullOrWhiteSpace($text)) { continue }
    try { $obj = $text | ConvertFrom-Json -ErrorAction Stop }
    catch {
        $parseFails++
        $violations += [pscustomobject]@{ line = $lineNo; kind = 'parse'; detail = "$_" }
        continue
    }
    $keys = @($obj.PSObject.Properties.Name)
    foreach ($req in $Tier1Fields) {
        if ($keys -notcontains $req) {
            $violations += [pscustomobject]@{ line = $lineNo; kind = 'missing_tier1'; detail = $req }
        }
    }
    if ($Strict -and $ProjectPrefix) {
        foreach ($k in $keys) {
            if ($Tier1Fields -contains $k) { continue }
            if ($Tier2Reserved -contains $k) { continue }
            if (-not $k.StartsWith($ProjectPrefix)) {
                $violations += [pscustomobject]@{ line = $lineNo; kind = 'tier3_no_prefix'; detail = "$k (expected prefix '$ProjectPrefix')" }
            }
        }
    }
}

$hasMissing = ($violations | Where-Object { $_.kind -eq 'missing_tier1' }).Count -gt 0
$hasTier3 = ($violations | Where-Object { $_.kind -eq 'tier3_no_prefix' }).Count -gt 0

$payload = [ordered]@{
    probed_at = [DateTime]::UtcNow.ToString('o')
    path = $Path
    checked_lines = $tail.Count
    total_lines = $lines.Count
    tier1_fields = $Tier1Fields
    violations = $violations
    ok = ($violations.Count -eq 0)
}

if ($AsJson) { $payload | ConvertTo-Json -Depth 4 -Compress } else { $payload | ConvertTo-Json -Depth 4 }

if ($parseFails -gt 0) { exit 2 }
if ($hasMissing) { exit 3 }
if ($hasTier3) { exit 4 }
exit 0
