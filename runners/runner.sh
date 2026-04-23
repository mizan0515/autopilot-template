#!/usr/bin/env bash
# .autopilot/runners/runner.sh — infinite Unix runner.
#
# Loop: create or refresh one reusable detached automation worktree ->
# submit PROMPT.md -> clean up if the worktree is clean -> sleep NEXT_DELAY
# -> repeat. The runner is dumb; all reasoning is in PROMPT.md.
#
# Pick an AI CLI: AUTOPILOT_AI=claude|codex|custom (default: claude)
#   claude -> `claude --print` reading from the prompt on stdin
#   codex  -> `codex exec -C <run_root> -` (approvals honored by default)
#   custom -> executes "$AUTOPILOT_CMD", with $AUTOPILOT_PROMPT_FILE exported
#
# Env overrides:
#   AUTOPILOT_PROMPT_RELATIVE  path to prompt under repo root (default .autopilot/PROMPT.md)
#   AUTOPILOT_WORKTREE_DIR     base dir for the reusable automation worktree
#                              (default <parent>/<leaf>-autopilot-runner)
#   AUTOPILOT_CODEX_ARGS       extra args appended to codex exec. Downstreams
#                              that INTENTIONALLY want unattended runs can set
#                              this to include '--dangerously-bypass-approvals-and-sandbox'
#                              — the template deliberately does NOT default to
#                              that flag. Turning off approvals in an infinite
#                              loop should be an informed, per-project opt-in.

set -uo pipefail
cd "$(dirname "$0")/../.."

resolve_cmd() {
  local name="$1"
  command -v "$name" 2>/dev/null || command -v "${name}.exe" 2>/dev/null || command -v "${name}.cmd" 2>/dev/null
}

ROOT="$PWD"
AP="$ROOT/.autopilot"
HALT="$AP/HALT"
DELAY="$AP/NEXT_DELAY"
RUNNER_STATE="$AP/RUNNER-LIVE.json"
PROMPT_RELATIVE="${AUTOPILOT_PROMPT_RELATIVE:-.autopilot/PROMPT.md}"

get_worktree_base() {
  if [ -n "${AUTOPILOT_WORKTREE_DIR:-}" ]; then
    printf '%s\n' "$AUTOPILOT_WORKTREE_DIR"
    return
  fi
  parent="$(dirname "$ROOT")"
  leaf="$(basename "$ROOT")"
  printf '%s\n' "$parent/$leaf-autopilot-runner"
}

write_runner_state() {
  local phase="$1"
  local run_root="${2:-}"
  local note="${3:-}"
  local last_exit="${4:-0}"
  cat >"$RUNNER_STATE" <<EOF
{
  "ts": "$(date -Is)",
  "ai": "$AI",
  "phase": "$phase",
  "run_root": "${run_root//\\/\\\\}",
  "note": "${note//\"/\\\"}",
  "last_exit_code": $last_exit,
  "worktree_base": "$(get_worktree_base | sed 's/\\/\\\\/g')"
}
EOF
}

new_iteration_worktree() {
  local base
  base="$(get_worktree_base)"
  mkdir -p "$base"
  git fetch origin main --prune >/dev/null
  git worktree prune >/dev/null
  local run_root="$base/live"
  if [ -d "$run_root" ]; then
    git worktree remove --force "$run_root" >/dev/null 2>&1 || rm -rf "$run_root"
  fi
  git worktree add --detach "$run_root" origin/main >/dev/null
  printf '%s\n' "$run_root"
}

finalize_iteration_worktree() {
  local run_root="$1"
  if [ ! -d "$run_root" ]; then
    printf 'missing\n'
    return
  fi
  if [ -n "$(git -C "$run_root" status --porcelain 2>/dev/null)" ]; then
    printf 'retained-dirty\n'
    return
  fi
  git worktree remove --force "$run_root" >/dev/null
  local parent
  parent="$(dirname "$run_root")"
  rmdir "$parent" >/dev/null 2>&1 || true
  printf 'removed-clean\n'
}

AI="${AUTOPILOT_AI:-claude}"
CODEX_CMD="$(resolve_cmd codex || true)"
CLAUDE_CMD="$(resolve_cmd claude || true)"

echo "[autopilot] AI=$AI"
echo "[autopilot] worktree base=$(get_worktree_base)"
echo "[autopilot] prompt=$PROMPT_RELATIVE"
write_runner_state "startup" "" "runner starting" 0

while :; do
  if [ -f "$HALT" ]; then
    echo "[autopilot] HALT present. Stopping."
    write_runner_state "halted" "" "HALT file present; runner stopped" 0
    break
  fi

  iter_start=$(date +%s)
  run_root=""
  ai_exit=0
  echo "[autopilot] iter start $(date -Is)"

  run_root="$(new_iteration_worktree)"
  prompt="$run_root/$PROMPT_RELATIVE"
  [ -f "$prompt" ] || { echo "Missing $prompt" >&2; ai_exit=1; }

  if [ $ai_exit -eq 0 ]; then
    write_runner_state "running" "$run_root" "executing one iter in detached automation worktree" 0
    case "$AI" in
      codex)
        [ -n "$CODEX_CMD" ] || { echo "codex command not found" >&2; exit 2; }
        if [ -n "${AUTOPILOT_CODEX_ARGS:-}" ]; then
          # shellcheck disable=SC2086
          cat "$prompt" | "$CODEX_CMD" exec -C "$run_root" - $AUTOPILOT_CODEX_ARGS
        else
          cat "$prompt" | "$CODEX_CMD" exec -C "$run_root" -
        fi
        ai_exit=$?
        ;;
      claude)
        [ -n "$CLAUDE_CMD" ] || { echo "claude command not found" >&2; exit 2; }
        cat "$prompt" | "$CLAUDE_CMD" --print
        ai_exit=$?
        ;;
      custom)
        AUTOPILOT_PROMPT_FILE="$prompt" bash -c "$AUTOPILOT_CMD"
        ai_exit=$?
        ;;
      *)
        echo "Unknown AUTOPILOT_AI=$AI" >&2
        ai_exit=2
        ;;
    esac
  fi

  final_state="$(finalize_iteration_worktree "$run_root")"
  case "$final_state" in
    removed-clean)
      sleep_phase="sleeping"
      sleep_note="iter clean; automation worktree removed"
      ;;
    retained-dirty)
      sleep_phase="retained-dirty"
      sleep_note="automation worktree retained (uncommitted changes); user worktree untouched"
      ;;
    *)
      sleep_phase="sleeping"
      sleep_note="worktree finalize state: $final_state"
      ;;
  esac
  write_runner_state "$sleep_phase" "$run_root" "$sleep_note" "$ai_exit"

  sleep_for=900
  if [ -f "$DELAY" ]; then
    raw="$(tr -d '[:space:]' < "$DELAY")"
    if [[ "$raw" =~ ^[0-9]+$ ]]; then
      sleep_for="$raw"
      [ "$sleep_for" -lt 60 ] && sleep_for=60
      [ "$sleep_for" -gt 3600 ] && sleep_for=3600
    fi
  fi

  dur=$(( $(date +%s) - iter_start ))
  echo "[autopilot] iter took ${dur}s; sleeping ${sleep_for}s"
  write_runner_state "$sleep_phase" "$run_root" "last iter ${dur}s; sleeping ${sleep_for}s" "$ai_exit"
  sleep "$sleep_for"
done
