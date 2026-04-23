<#
.SYNOPSIS
  Soft tripwire for .autopilot/HISTORY.md and operator-dashboard bloat.

.DESCRIPTION
  PROMPT.md mandates rotation of HISTORY.md (>50 entries OR >20KB) and the
  operator dashboard (>100 entries OR >40KB) into sibling `-ARCHIVE.md`
  files. Real-usage downstreams let HISTORY reach 50KB+ because the rotation
  rule was advisory only. This helper is the failsafe: a pre-commit or
  doctor-path probe that warns (and optionally fails) when the thresholds
  are breached, prompting the agent to rotate on the next iter.

  Exit codes follow helpers/ convention:
    0  clean / under all thresholds
    1  missing input (HISTORY.md not present and -RequireHistory set)
    4  policy violation (over threshold) — soft by default; -Strict propagates

  By default the script only WARNS and still exits 0. Pass -Strict to surface
  exit 4 so a pre-commit hook can block the commit (only recommended if the
  downstream has an automated rotation step).

.PARAMETER HistoryPath
  Path to HISTORY.md. Defaults to .autopilot/HISTORY.md.

.PARAMETER DashboardPath
  Path to operator dashboard markdown. Defaults to .autopilot/대시보드.md.
  Skipped silently if absent (many downstreams ship only HTML/JSON dashboards).

.PARAMETER HistoryEntryThreshold
.PARAMETER HistoryByteThreshold
.PARAMETER DashboardEntryThreshold
.PARAMETER DashboardByteThreshold
  Override defaults (50 / 20KB / 100 / 40KB).

.PARAMETER EntryHeadingRegex
  Regex that identifies one iter entry. Default matches `^## ` or `^### `.

.PARAMETER Strict
  Propagate exit 4 on breach instead of warn-only.

.PARAMETER Json
  Emit a compact JSON summary on stdout regardless of thresholds. Useful
  for METRICS or dashboard refresh pipelines.

.EXAMPLE
  pwsh -File helpers/Test-HistorySize.ps1
  pwsh -File helpers/Test-HistorySize.ps1 -Strict -Json
#>
[CmdletBinding()]
param(
  [string]$HistoryPath = '.autopilot/HISTORY.md',
  [string]$DashboardPath = '.autopilot/대시보드.md',
  [int]$HistoryEntryThreshold = 50,
  [int]$HistoryByteThreshold = 20KB,
  [int]$DashboardEntryThreshold = 100,
  [int]$DashboardByteThreshold = 40KB,
  [string]$EntryHeadingRegex = '^#{2,3}\s',
  [switch]$Strict,
  [switch]$Json
)

$ErrorActionPreference = 'Stop'

function Measure-Surface {
  param([string]$Path, [int]$EntryCap, [int]$ByteCap, [string]$Regex)
  if (-not (Test-Path -LiteralPath $Path)) {
    return [pscustomobject]@{
      path = $Path; present = $false; entries = 0; bytes = 0
      over_entries = $false; over_bytes = $false; archive = $null
    }
  }
  $bytes = (Get-Item -LiteralPath $Path).Length
  $entries = 0
  try {
    $entries = (Select-String -LiteralPath $Path -Pattern $Regex -AllMatches `
                -ErrorAction Stop | Measure-Object).Count
  } catch {
    $entries = 0
  }
  $dir  = Split-Path -Parent $Path
  $leaf = [IO.Path]::GetFileNameWithoutExtension($Path)
  $archive = if ($dir) { Join-Path $dir "$leaf-ARCHIVE.md" } else { "$leaf-ARCHIVE.md" }
  [pscustomobject]@{
    path = $Path
    present = $true
    entries = $entries
    bytes = $bytes
    over_entries = ($entries -gt $EntryCap)
    over_bytes = ($bytes -gt $ByteCap)
    archive = $archive
  }
}

$history   = Measure-Surface -Path $HistoryPath   -EntryCap $HistoryEntryThreshold   -ByteCap $HistoryByteThreshold   -Regex $EntryHeadingRegex
$dashboard = Measure-Surface -Path $DashboardPath -EntryCap $DashboardEntryThreshold -ByteCap $DashboardByteThreshold -Regex $EntryHeadingRegex

$breaches = @()
foreach ($s in @($history, $dashboard)) {
  if (-not $s.present) { continue }
  if ($s.over_entries -or $s.over_bytes) {
    $breaches += $s
    Write-Warning ("{0}: entries={1} bytes={2} — rotate into {3} (over_entries={4}, over_bytes={5})" -f `
      $s.path, $s.entries, $s.bytes, $s.archive, $s.over_entries, $s.over_bytes)
  }
}

if ($Json) {
  [pscustomobject]@{
    history = $history
    dashboard = $dashboard
    breach_count = $breaches.Count
    strict = [bool]$Strict
  } | ConvertTo-Json -Compress -Depth 4
}

if ($breaches.Count -gt 0 -and $Strict) { exit 4 }
exit 0
