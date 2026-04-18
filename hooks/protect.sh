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

BLOCKS=(core-contract boot budget blast-radius halt exit-contract wake-reschedule)

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

exit 0
