# .autopilot/runners/runner.ps1 — infinite Windows runner.
#
# Loop: create or refresh one reusable detached automation worktree -> submit
# PROMPT.md to the AI CLI -> remove the worktree if clean -> sleep NEXT_DELAY -> repeat.
# The runner is intentionally dumb. All reasoning lives in PROMPT.md.
#
# Pick an AI CLI by setting env var AUTOPILOT_AI = 'claude' | 'codex' | 'custom' (default: claude).
#   claude  -> `claude --print` reading the prompt on stdin
#   codex   -> `codex exec -C <run_root> -` (approvals honored by default)
#   custom  -> runs $env:AUTOPILOT_CMD verbatim with $env:AUTOPILOT_PROMPT_FILE set
#
# Env overrides:
#   AUTOPILOT_PROMPT_RELATIVE  path to prompt under repo root (default .autopilot\PROMPT.md)
#   AUTOPILOT_WORKTREE_DIR     base dir for the reusable automation worktree
#                              (default <parent>\<leaf>-autopilot-runner)
#   AUTOPILOT_CODEX_ARGS       extra args appended to codex exec. Downstreams that
#                              INTENTIONALLY want unattended runs can include
#                              '--dangerously-bypass-approvals-and-sandbox' here.
#                              The template deliberately does NOT default to that
#                              flag — bypassing approvals in an infinite loop must
#                              be an informed, per-project opt-in.

$ErrorActionPreference = 'Stop'
Set-Location (Resolve-Path (Join-Path $PSScriptRoot '..\..'))

$root = (Get-Location).Path
$ap = Join-Path $root '.autopilot'
$halt = Join-Path $ap 'HALT'
$delay = Join-Path $ap 'NEXT_DELAY'
$runnerStatePath = Join-Path $ap 'RUNNER-LIVE.json'
$promptRelative = if ($env:AUTOPILOT_PROMPT_RELATIVE) { $env:AUTOPILOT_PROMPT_RELATIVE } else { '.autopilot\PROMPT.md' }

function Get-WorktreeBase {
  if ($env:AUTOPILOT_WORKTREE_DIR) {
    return $env:AUTOPILOT_WORKTREE_DIR
  }
  $parent = Split-Path $root -Parent
  $leaf = Split-Path $root -Leaf
  return (Join-Path $parent "$leaf-autopilot-runner")
}

function Write-RunnerState {
  param(
    [string]$Phase,
    [string]$RunRoot = '',
    [string]$Note = '',
    [int]$LastExitCode = 0
  )

  $state = [ordered]@{
    ts = (Get-Date).ToString('o')
    ai = $ai
    phase = $Phase
    run_root = $RunRoot
    note = $Note
    last_exit_code = $LastExitCode
    worktree_base = (Get-WorktreeBase)
  }

  ($state | ConvertTo-Json -Depth 4) | Set-Content -Path $runnerStatePath -Encoding utf8
}

function New-IterationWorktree {
  $base = Get-WorktreeBase
  New-Item -ItemType Directory -Path $base -Force | Out-Null

  git fetch origin main --prune | Out-Null
  git worktree prune | Out-Null

  $runRoot = Join-Path $base 'live'
  if (Test-Path $runRoot) {
    try {
      git worktree remove --force $runRoot | Out-Null
    } catch {
      Remove-Item -LiteralPath $runRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
  git worktree add --detach $runRoot origin/main | Out-Null
  return $runRoot
}

function Finalize-IterationWorktree {
  param([string]$RunRoot)

  if (-not (Test-Path $RunRoot)) {
    return 'missing'
  }

  $status = (git -C $RunRoot status --porcelain 2>$null)
  if ($LASTEXITCODE -ne 0) {
    return 'status-failed'
  }

  if ($status) {
    return 'retained-dirty'
  }

  git worktree remove --force $RunRoot | Out-Null
  $parent = Split-Path $RunRoot -Parent
  if ($parent -and (Test-Path $parent) -and -not (Get-ChildItem $parent -Force -ErrorAction SilentlyContinue | Select-Object -First 1)) {
    Remove-Item -LiteralPath $parent -Force -ErrorAction SilentlyContinue
  }
  return 'removed-clean'
}

$ai = if ($env:AUTOPILOT_AI) { $env:AUTOPILOT_AI } else { 'claude' }
Write-Host "[autopilot] AI = $ai"
Write-Host "[autopilot] worktree base = $(Get-WorktreeBase)"
Write-Host "[autopilot] prompt = $promptRelative"
Write-RunnerState -Phase 'startup' -Note 'runner starting'

while ($true) {
  if (Test-Path $halt) {
    Write-Host "[autopilot] HALT file present. Stopping runner."
    Write-RunnerState -Phase 'halted' -Note 'HALT file present; runner stopped'
    break
  }

  $iterStart = Get-Date
  $runRoot = $null
  $aiExitCode = 0
  Write-Host "[autopilot] iteration start $($iterStart.ToString('o'))"

  try {
    $runRoot = New-IterationWorktree
    $prompt = Join-Path $runRoot $promptRelative
    if (-not (Test-Path $prompt)) {
      throw "Missing $prompt"
    }

    Write-RunnerState -Phase 'running' -RunRoot $runRoot -Note 'executing one iter in detached automation worktree'

    switch ($ai) {
      'codex' {
        $extraArgs = @()
        if ($env:AUTOPILOT_CODEX_ARGS) {
          $parseErrors = $null
          $extraArgs = [System.Management.Automation.PSParser]::Tokenize($env:AUTOPILOT_CODEX_ARGS, [ref]$parseErrors) |
            Where-Object { $_.Type -in 'CommandArgument', 'String' } |
            ForEach-Object { $_.Content }
        }
        $codexArgs = @('exec', '-C', $runRoot, '-') + $extraArgs
        Get-Content -Raw $prompt | codex @codexArgs
        $aiExitCode = $LASTEXITCODE
      }
      'claude' {
        Get-Content -Raw $prompt | claude --print
        $aiExitCode = $LASTEXITCODE
      }
      'custom' {
        $env:AUTOPILOT_PROMPT_FILE = $prompt
        Push-Location $runRoot
        try {
          Invoke-Expression $env:AUTOPILOT_CMD
          $aiExitCode = $LASTEXITCODE
        } finally {
          Pop-Location
        }
      }
      default {
        throw "Unknown AUTOPILOT_AI=$ai"
      }
    }
  } catch {
    $aiExitCode = 1
    Write-Warning "[autopilot] AI call failed: $_"
    Write-RunnerState -Phase 'error' -RunRoot $runRoot -Note "$_" -LastExitCode $aiExitCode
  }

  $finalState = if ($runRoot) { Finalize-IterationWorktree -RunRoot $runRoot } else { 'no-worktree' }
  $sleepPhase = 'sleeping'
  $sleepNote = ''

  switch ($finalState) {
    'removed-clean' {
      $sleepPhase = 'sleeping'
      $sleepNote = 'iter clean; automation worktree removed'
    }
    'retained-dirty' {
      $sleepPhase = 'retained-dirty'
      $sleepNote = 'automation worktree retained (uncommitted changes); user worktree untouched'
    }
    default {
      $sleepPhase = 'sleeping'
      $sleepNote = "worktree finalize state: $finalState"
    }
  }

  $sleepFor = 900
  if (Test-Path $delay) {
    $raw = (Get-Content $delay -Raw).Trim()
    if ($raw -match '^\d+$') {
      $sleepFor = [int]$raw
      if ($sleepFor -lt 60)   { $sleepFor = 60 }
      if ($sleepFor -gt 3600) { $sleepFor = 3600 }
    }
  }

  $dur = [int]((Get-Date) - $iterStart).TotalSeconds
  Write-Host "[autopilot] iter took ${dur}s; sleeping ${sleepFor}s"
  Write-RunnerState -Phase $sleepPhase -RunRoot $runRoot -Note "$sleepNote; last iter ${dur}s; sleeping ${sleepFor}s" -LastExitCode $aiExitCode
  Start-Sleep -Seconds $sleepFor
}
