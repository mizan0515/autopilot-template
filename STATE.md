# .autopilot/STATE.md — live state, keep ≤60 lines. Loaded every iteration.

root: .
base: main
iteration: 0
status: initialized
active_task: null
# active_task schema when set:
#   slug: <kebab-case>
#   plan: [bullet, bullet]
#   started_iter: N
#   branch: dev/<slug>-<YYYYMMDD>

# Uncomment and fill in for your project:
# plan_docs:
#   - PLAN.md
#   - ROADMAP.md
# spec_docs:
#   - SPEC.md
# reference_docs:
#   - docs/capability-matrix.md

open_questions: []

# Auto-merge policy (full-autonomy default). The loop auto-squash-merges its own
# PRs via `gh pr merge --squash --delete-branch [--auto]` at the end of Active mode.
# Refuses auto-merge if the PR diff touches any of these paths:
protected_paths: []
#   - .github/workflows/
#   - .autopilot/hooks/
#   - infra/

# OPERATOR overrides — any line here starting with `OPERATOR:` wins over PROMPT.md.
# Examples:
#   OPERATOR: halt
#   OPERATOR: halt evolution
#   OPERATOR: focus on <task>
#   OPERATOR: allow evolution <rationale>
#   OPERATOR: allow push to main for <task>   (single use, delete after)
#   OPERATOR: require human review            (disables auto-merge; PRs wait for human)
