# .autopilot/runners/runner.ps1 — infinite Windows runner.
#
# Loop: submit PROMPT.md to the AI CLI → wait for exit → sleep NEXT_DELAY → repeat.
# The runner is intentionally dumb. All reasoning lives in PROMPT.md.
#
# ⚠️  WORKTREE HYGIENE (2026-04-18 lesson):
#   DO NOT create a new `iter-<N>` worktree on every iteration — that pollutes the
#   parent folder with dozens of stale worktrees that the loop never cleans up and
#   eventually makes the filesystem unmanageable. If you customize this runner to
#   use `git worktree`, create ONE live worktree (e.g. `../<project>.autopilot-live`)
#   once and REUSE it every iter. Worktree-per-iter is a known template anti-pattern.
#
# Pick an AI CLI by setting env var AUTOPILOT_AI = 'claude' | 'codex' | 'custom'.
#   claude  -> uses `claude` (Claude Code CLI) with `/loop` or direct prompt submission
#   codex   -> uses `codex exec --file .autopilot/PROMPT.md`
#   custom  -> runs $env:AUTOPILOT_CMD verbatim, with $env:AUTOPILOT_PROMPT_FILE set to PROMPT.md path

$ErrorActionPreference = 'Stop'
Set-Location (Resolve-Path (Join-Path $PSScriptRoot '..\..'))   # repo root

$root    = (Get-Location).Path
$ap      = Join-Path $root '.autopilot'
$prompt  = Join-Path $ap 'PROMPT.md'
$halt    = Join-Path $ap 'HALT'
$delay   = Join-Path $ap 'NEXT_DELAY'

if (-not (Test-Path $prompt)) { Write-Error "Missing $prompt"; exit 1 }

$ai = if ($env:AUTOPILOT_AI) { $env:AUTOPILOT_AI } else { 'claude' }
Write-Host "[autopilot] AI = $ai"
Write-Host "[autopilot] PROMPT = $prompt"

while ($true) {
    if (Test-Path $halt) {
        Write-Host "[autopilot] HALT file present. Stopping runner."
        break
    }

    $iterStart = Get-Date
    Write-Host "[autopilot] iteration start $($iterStart.ToString('o'))"

    try {
        switch ($ai) {
            'claude' {
                # Claude Code headless: read prompt, pipe as message. Requires `claude` in PATH.
                # Swap --print for --no-session-persistence if you want stricter statelessness.
                Get-Content -Raw $prompt | claude --print
            }
            'codex' {
                codex exec --file $prompt
            }
            'custom' {
                $env:AUTOPILOT_PROMPT_FILE = $prompt
                Invoke-Expression $env:AUTOPILOT_CMD
            }
            default { Write-Error "Unknown AUTOPILOT_AI=$ai"; exit 2 }
        }
    } catch {
        Write-Warning "[autopilot] AI call failed: $_"
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
    Start-Sleep -Seconds $sleepFor
}
