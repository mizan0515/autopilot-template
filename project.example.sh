#!/usr/bin/env bash
# .autopilot/project.sh — project-specific command wrapper.
#
# This file is the ONLY place in the autopilot template that knows your
# project's build/test/audit tooling. The loop calls it via stable verbs so
# PROMPT.md stays runner- AND stack-agnostic.
#
# Copy this to `.autopilot/project.sh` in your project and customize.
# Every verb must print status and exit non-zero on failure.

set -euo pipefail
verb="${1:-help}"

case "$verb" in
  doctor)
    # Fast env health check (≤60s, no external network).
    # Exit 0 = env OK; non-zero = env broken (loop will back off 1800s).
    command -v git   >/dev/null || { echo "missing: git"; exit 1; }
    command -v gh    >/dev/null || { echo "missing: gh"; exit 1; }
    # Add project-specific checks here:
    #   command -v node    >/dev/null
    #   command -v dotnet  >/dev/null
    #   command -v python3 >/dev/null
    echo "ok"
    ;;

  test)
    # Project's test + build + lint in one shot. Must exit non-zero on ANY red.
    # Examples:
    #   npm test && npm run lint
    #   pytest && ruff check .
    #   dotnet build && dotnet test
    echo "project.sh test: customize me" >&2
    exit 1
    ;;

  audit)
    # Dependency / vulnerability audit. Consumed by Idle-upkeep mode.
    # Examples:
    #   npm audit --json > .autopilot/.audit-cache.json
    #   pip-audit --format json > .autopilot/.audit-cache.json
    #   dotnet list package --outdated --vulnerable > .autopilot/.audit-cache.txt
    echo "project.sh audit: customize me" >&2
    exit 0
    ;;

  start)
    # Start the loop (dispatches to the runner the operator picks).
    # Discoverable via `ls .autopilot/project.sh` — part of the bad-UX assumption.
    exec bash .autopilot/runners/runner.sh
    ;;

  stop)
    # Polite stop — touches HALT, loop exits on next boot.
    touch .autopilot/HALT
    echo "HALT file created. Loop will exit at next boot."
    ;;

  resume)
    rm -f .autopilot/HALT
    echo "HALT removed. Loop may resume on next runner wake-up."
    ;;

  help|*)
    cat <<EOF
project.sh — autopilot project wrapper

Verbs:
  doctor   Fast env health check (≤60s). Exit 0 = OK, nonzero = env-broken.
  test     Run project tests + build + lint. Exit 0 = green, nonzero = red.
  audit    Dependency/vuln audit for Idle-upkeep. Exit 0 always; findings in stdout.
  start    Start the loop via the PowerShell/bash runner.
  stop     Create .autopilot/HALT (polite stop).
  resume   Remove .autopilot/HALT.
EOF
    ;;
esac
