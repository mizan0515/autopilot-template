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
'@
  }
}
