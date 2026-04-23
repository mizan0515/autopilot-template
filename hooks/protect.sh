#!/usr/bin/env bash
# .autopilot/hooks/protect.sh — pre-commit guard for PROMPT.md IMMUTABLE sections.
#
# Install:  ln -sf "$(pwd)/.autopilot/hooks/protect.sh" .git/hooks/pre-commit
# Or add invocation to your existing pre-commit.
#
# Rejects any commit that touches PROMPT.md AND alters content between
# [IMMUTABLE:BEGIN <name>] ... [IMMUTABLE:END <name>] markers, for any of the
# seven named protected blocks. Also rejects if any marker is removed.

set -euo pipefail

PROMPT=".autopilot/PROMPT.md"

# Not committing PROMPT.md? Nothing to do.
if ! git diff --cached --name-only | grep -qx "$PROMPT"; then
  exit 0
fi

# Skip on the very first commit (no HEAD yet) — initial scaffolding is allowed.
if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
  exit 0
fi

BLOCKS=(core-contract boot budget blast-radius halt cleanup-safety mvp-gate exit-contract wake-reschedule decision-pr-invariants)

tmp_base=$(mktemp); tmp_head=$(mktemp)
trap 'rm -f "$tmp_base" "$tmp_head"' EXIT

git show "HEAD:$PROMPT" > "$tmp_base" 2>/dev/null || { echo "protect.sh: cannot read HEAD:$PROMPT"; exit 1; }
git show ":$PROMPT"     > "$tmp_head"

for name in "${BLOCKS[@]}"; do
  begin="\[IMMUTABLE:BEGIN $name\]"
  end="\[IMMUTABLE:END $name\]"

  # Both markers must still exist in the new version.
  if ! grep -q "$begin" "$tmp_head" || ! grep -q "$end" "$tmp_head"; then
    echo "protect.sh: IMMUTABLE markers for '$name' are missing from $PROMPT"
    echo "  → commit rejected. Restore [IMMUTABLE:BEGIN $name] ... [IMMUTABLE:END $name]."
    exit 1
  fi

  base_block=$(awk "/$begin/,/$end/" "$tmp_base")
  head_block=$(awk "/$begin/,/$end/" "$tmp_head")

  if [ "$base_block" != "$head_block" ]; then
    echo "protect.sh: IMMUTABLE block '$name' was modified in $PROMPT"
    echo "  → commit rejected. These blocks are self-evolution-immutable."
    echo "  → if you genuinely need to change one, do it in a human commit outside the loop."
    exit 1
  fi
done

# ---------------------------------------------------------------------------
# MVP-GATES contract: the halt trigger depends on a parseable "Gate count: N"
# line in .autopilot/MVP-GATES.md. Reject any commit that would leave the
# file missing the line (or remove the file entirely).
# ---------------------------------------------------------------------------
MVPGATES=".autopilot/MVP-GATES.md"

if git diff --cached --name-only | grep -qx "$MVPGATES"; then
  if git diff --cached --diff-filter=D --name-only | grep -qx "$MVPGATES"; then
    echo "protect.sh: $MVPGATES deletion rejected — this file is the MVP halt trigger."
    echo "  → rescope via OPERATOR: mvp-rescope <rationale> in STATE.md instead."
    exit 1
  fi
  tmp_gates=$(mktemp); trap 'rm -f "$tmp_base" "$tmp_head" "$tmp_gates"' EXIT
  git show ":$MVPGATES" > "$tmp_gates"
  if ! grep -qE "^Gate count: [0-9]+" "$tmp_gates"; then
    echo "protect.sh: $MVPGATES must contain a parseable 'Gate count: <N>' line."
    echo "  → the [IMMUTABLE:mvp-gate] halt conditions depend on it."
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
# Hard cap: >20 file deletions per commit is always rejected, matching
# [IMMUTABLE:cleanup-safety] rule 5. Trailer-gated >5 check lives in a
# commit-msg hook (not enforced here).
# ---------------------------------------------------------------------------
deleted_count=$(git diff --cached --name-only --diff-filter=D | wc -l | tr -d ' ')
if [ "$deleted_count" -gt 20 ]; then
  echo "protect.sh: commit deletes $deleted_count files; hard cap is 20 per commit."
  echo "  → reject. Split into multiple cleanup PRs."
  exit 1
fi

exit 0
