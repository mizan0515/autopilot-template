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

  check-reschedule)
    # Detect the "said it but didn't tool-call it" ScheduleWakeup failure mode.
    # Three checks (any fails → exit 2):
    #   1. LAST_RESCHEDULE exists and has 2 lines (1-line = narration-only forgery).
    #   2. Line 2 (raw tool response) is non-empty and not identical to line 1.
    #   3. Line 1 timestamp age < NEXT_DELAY + 600s slack.
    # Exit 0 if loop healthy or halted; exit 2 if overdue/forged; exit 0 if no iter yet.
    ap=".autopilot"
    if [ ! -f "$ap/NEXT_DELAY" ]; then echo "no NEXT_DELAY yet — loop hasn't completed an iteration"; exit 0; fi
    if [ ! -f "$ap/LAST_RESCHEDULE" ]; then echo "WARN: NEXT_DELAY exists but LAST_RESCHEDULE missing — exit-contract step 5/6 likely skipped"; exit 2; fi
    line1=$(sed -n '1p' "$ap/LAST_RESCHEDULE")
    line2=$(sed -n '2p' "$ap/LAST_RESCHEDULE")
    case "$line1" in
      halted*|"external-runner:"*) echo "legitimate skip on line 1 — no reschedule expected ($line1)"; exit 0 ;;
    esac
    if [ -z "$line2" ] || [ "$line2" = "$line1" ]; then
      echo "WARN: LAST_RESCHEDULE is 1-line or line-2 forged — narration-only sentinel, ScheduleWakeup likely not tool-called"
      echo "  → per [IMMUTABLE:wake-reschedule] §2, this is a failed reschedule."
      exit 2
    fi
    delay=$(cat "$ap/NEXT_DELAY" | tr -cd '0-9')
    ts_epoch=$(date -d "$line1" +%s 2>/dev/null || python3 -c "import sys,datetime;print(int(datetime.datetime.fromisoformat(sys.argv[1].strip().replace('Z','+00:00')).timestamp()))" "$line1" 2>/dev/null || echo 0)
    now_epoch=$(date +%s)
    age=$(( now_epoch - ts_epoch ))
    slack=600
    if [ "$ts_epoch" -eq 0 ]; then echo "WARN: could not parse LAST_RESCHEDULE line 1='$line1'"; exit 2; fi
    if [ "$age" -gt $(( delay + slack )) ]; then
      echo "WARN: reschedule overdue — line1=$line1 age=${age}s NEXT_DELAY=${delay}s (slack ${slack}s)"
      echo "  → loop likely stuck. re-anchor with /loop or runner.sh."
      exit 2
    fi
    echo "ok: line1=$line1 line2=$line2 age=${age}s NEXT_DELAY=${delay}s"
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
  check-reschedule  Verify LAST_RESCHEDULE is fresh vs NEXT_DELAY. Exit 2 if overdue.
EOF
    ;;
esac
