#!/usr/bin/env bash
# .autopilot/runners/runner.sh — infinite Unix runner.
#
# Loop: submit PROMPT.md → wait → sleep NEXT_DELAY → repeat.
# The runner is dumb; all reasoning is in PROMPT.md.
#
# Pick an AI CLI: AUTOPILOT_AI=claude|codex|custom (default: claude)
#   claude -> `claude --print` reading from PROMPT.md on stdin
#   codex  -> `codex exec --file .autopilot/PROMPT.md`
#   custom -> executes "$AUTOPILOT_CMD", with $AUTOPILOT_PROMPT_FILE exported

set -uo pipefail
cd "$(dirname "$0")/../.."       # repo root

AP=".autopilot"
PROMPT="$AP/PROMPT.md"
HALT="$AP/HALT"
DELAY="$AP/NEXT_DELAY"

[ -f "$PROMPT" ] || { echo "Missing $PROMPT" >&2; exit 1; }

AI="${AUTOPILOT_AI:-claude}"
echo "[autopilot] AI=$AI"
echo "[autopilot] PROMPT=$PROMPT"

while :; do
  if [ -f "$HALT" ]; then
    echo "[autopilot] HALT present. Stopping."
    break
  fi

  ITER_START=$(date +%s)
  echo "[autopilot] iter start $(date -Is)"

  case "$AI" in
    claude)  cat "$PROMPT" | claude --print ;;
    codex)   codex exec --file "$PROMPT" ;;
    custom)  AUTOPILOT_PROMPT_FILE="$PROMPT" bash -c "$AUTOPILOT_CMD" ;;
    *)       echo "Unknown AUTOPILOT_AI=$AI" >&2; exit 2 ;;
  esac
  ec=$?
  [ $ec -ne 0 ] && echo "[autopilot] AI exit=$ec (continuing)"

  SLEEP=900
  if [ -f "$DELAY" ]; then
    raw=$(tr -d '[:space:]' < "$DELAY")
    if [[ "$raw" =~ ^[0-9]+$ ]]; then
      SLEEP=$raw
      [ $SLEEP -lt 60 ]   && SLEEP=60
      [ $SLEEP -gt 3600 ] && SLEEP=3600
    fi
  fi

  DUR=$(( $(date +%s) - ITER_START ))
  echo "[autopilot] iter took ${DUR}s; sleeping ${SLEEP}s"
  sleep "$SLEEP"
done
