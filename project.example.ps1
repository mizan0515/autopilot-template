# .autopilot/project.ps1 — project-specific command wrapper (Windows).
# Copy to .autopilot/project.ps1 in your project and customize.
# Every verb must write status and exit non-zero on failure.

param([string]$Verb = 'help')

$ErrorActionPreference = 'Stop'

switch ($Verb) {
  'doctor' {
    foreach ($cmd in 'git','gh') {
      if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) { Write-Error "missing: $cmd"; exit 1 }
    }
    # Add project checks:
    #   if (-not (Get-Command dotnet)) { exit 1 }
    #   if (-not (Get-Command node))   { exit 1 }
    Write-Host 'ok'
  }

  'test' {
    # Project test + build + lint. Must exit non-zero on red.
    # Examples:
    #   dotnet build; dotnet test
    #   npm test; npm run lint
    Write-Error 'project.ps1 test: customize me'
    exit 1
  }

  'audit' {
    # Dependency / vuln audit for Idle-upkeep. Exit 0; findings to stdout or cache file.
    Write-Host 'project.ps1 audit: customize me'
  }

  'start' {
    & powershell -NoProfile -ExecutionPolicy Bypass -File '.autopilot\runners\runner.ps1'
  }

  'stop' {
    New-Item -ItemType File -Path '.autopilot\HALT' -Force | Out-Null
    Write-Host 'HALT file created. Loop will exit at next boot.'
  }

  'resume' {
    Remove-Item '.autopilot\HALT' -ErrorAction SilentlyContinue
    Write-Host 'HALT removed. Loop may resume on next runner wake-up.'
  }

  'check-reschedule' {
    # Detect "said it but didn't tool-call it" ScheduleWakeup failures.
    # Three checks (any fails -> exit 2):
    #   1. LAST_RESCHEDULE exists and has 2 lines (1-line = narration-only forgery).
    #   2. Line 2 (raw tool response) is non-empty and not identical to line 1.
    #   3. Line 1 timestamp age < NEXT_DELAY + 600s slack.
    $ap = '.autopilot'
    $nd = Join-Path $ap 'NEXT_DELAY'
    $lr = Join-Path $ap 'LAST_RESCHEDULE'
    if (-not (Test-Path $nd)) { Write-Host "no NEXT_DELAY yet — loop hasn't completed an iteration"; exit 0 }
    if (-not (Test-Path $lr)) { Write-Warning 'NEXT_DELAY exists but LAST_RESCHEDULE missing — exit-contract step 5/6 likely skipped'; exit 2 }
    $lines = @(Get-Content $lr)
    $line1 = if ($lines.Count -ge 1) { $lines[0].Trim() } else { '' }
    $line2 = if ($lines.Count -ge 2) { $lines[1].Trim() } else { '' }
    if ($line1 -like 'halted*' -or $line1 -like 'external-runner:*') { Write-Host "legitimate skip on line 1 — no reschedule expected ($line1)"; exit 0 }
    if ([string]::IsNullOrWhiteSpace($line2) -or $line2 -eq $line1) {
      Write-Warning 'LAST_RESCHEDULE is 1-line or line-2 forged — narration-only sentinel, ScheduleWakeup likely not tool-called'
      Write-Host '  -> per [IMMUTABLE:wake-reschedule] section 2, this is a failed reschedule.'
      exit 2
    }
    $delay = [int]((Get-Content $nd -Raw).Trim())
    try { $ts = [DateTimeOffset]::Parse($line1) } catch { Write-Warning "could not parse LAST_RESCHEDULE line 1='$line1'"; exit 2 }
    $age = [int]((Get-Date) - $ts.UtcDateTime).TotalSeconds
    $slack = 600
    if ($age -gt ($delay + $slack)) {
      Write-Warning "reschedule overdue — line1=$line1 age=${age}s NEXT_DELAY=${delay}s (slack ${slack}s)"
      Write-Host '  -> loop likely stuck. re-anchor with /loop or runner.ps1.'
      exit 2
    }
    Write-Host "ok: line1=$line1 line2=$line2 age=${age}s NEXT_DELAY=${delay}s"
  }

  default {
    @'
project.ps1 — autopilot project wrapper

Verbs:
  doctor   Fast env health check. Exit 0 = OK, nonzero = env-broken.
  test     Run project tests + build + lint. Exit 0 = green, nonzero = red.
  audit    Dependency/vuln audit for Idle-upkeep.
  start    Start the loop via runner.ps1.
  stop     Create .autopilot\HALT (polite stop).
  resume   Remove .autopilot\HALT.
  check-reschedule  Verify LAST_RESCHEDULE is fresh vs NEXT_DELAY. Exit 2 if overdue.
'@
  }
}
