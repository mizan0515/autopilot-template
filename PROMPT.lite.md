# AUTOPILOT LITE — low-context maintenance runner prompt

Use this prompt ONLY for short maintenance loops where the full
`.autopilot/PROMPT.md` boot cost is not justified. Exists because real-usage
downstream loops showed that Codex-style low-context runners and small
doc-gardening tasks don't need the full product-planning boot sequence, and
paying it wastes tokens on every wake-up.

## When to use

Suitable tasks:
- doc sync / dashboard refresh
- narrow repository audits (one directory, one concern)
- small agent-infra maintenance under `.autopilot/`
- short validation or cleanup loops that do not reinterpret MVP direction
- overnight doc-gardening where deep context would be wasted

Do NOT use this prompt for:
- feature implementation across multiple domains
- tasks that must reinterpret MVP direction or operator policy
- anything that would touch `[IMMUTABLE:...]` blocks in `.autopilot/PROMPT.md`
- branch-creating PR slices — those must use full `PROMPT.md`

When in doubt, use the full prompt.

## Read order

1. `.autopilot/STATE.md`
2. `PROJECT-RULES.md` (or equivalent root contract if present)
3. Only the exact additional files needed for the chosen task

Skip everything else — no PITFALLS, no EVOLUTION, no FINDINGS on the lite
path. If the task turns out to need them, abort this lite run and relaunch
with the full `PROMPT.md`.

## Rules

- Treat live files as source of truth (never trust prior conversation memory).
- Before any meaningful file write, stop if `.autopilot/HALT` exists.
- Never edit inside `[IMMUTABLE:BEGIN ...]` / `[IMMUTABLE:END ...]` blocks.
- Respect `protected_paths:` and branch discipline from `.autopilot/STATE.md`.
- Use the smallest possible context and the narrowest useful verification.
- Do NOT open PRs from this prompt. Commit directly to a maintenance branch
  and hand off. If a change needs a PR, switch to the full `PROMPT.md`.
- Do NOT self-evolve `.autopilot/PROMPT.md` from this prompt — evolution
  requires the full budget/probation stack in the main prompt.

## Execution contract

1. Pick one small, well-scoped maintenance task.
2. Read only the files required for it.
3. Make the smallest coherent change.
4. Run one narrow verification step (one test, one validator, one linter).
5. If documentation or dashboard output is directly affected, sync it in the
   same run — don't leave drift for the next iter.
6. Report what changed, what was verified, and what remains blocked.
7. Write `NEXT_DELAY` and exit. Self-reschedule rules from the full prompt's
   `[IMMUTABLE:exit-contract]` + `[IMMUTABLE:wake-reschedule]` still apply —
   lite does not relax the reschedule discipline.

## Recommended invocations

- Set `AUTOPILOT_PROMPT_RELATIVE=.autopilot/PROMPT.lite.md` before
  `project.ps1 start` / `project.sh start` for a lite-mode runner.
- One-shot Codex: `Get-Content -Raw .autopilot\PROMPT.lite.md | codex exec -C .`
- Good nightly cadence: short doc-gardening, validator re-runs, dashboard
  refresh, cleanup-candidate scanning.
