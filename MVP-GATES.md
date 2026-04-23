# MVP-GATES — completion scorecard

Gate count: 0

Each gate is an OBSERVABLE completion criterion for this project's MVP. A
gate flips to `[x]` only when pointed at a runnable artifact (test name,
log path, PR number, validator output, screenshot + qa-evidence JSON).

States:
- `[x]` — done with cited evidence
- `[~]` — partial / in-progress
- `[ ]` — not started or regressed

Evidence formats accepted (project picks a subset at seed time):
- `.autopilot/qa-evidence/<slug>-<timestamp>.json` (schema in qa-evidence/SCHEMA.md)
- `logs/*.jsonl` event line (quote ≤3 lines)
- `tools/Validate-*.ps1` output snippet (PASS/FAIL tail)
- Green test name from `project.sh test`
- Commit SHA that introduced the capability
- PR number + merge commit

Regression protocol: a `[x]` gate reverts to `[~]`/`[ ]` only with cited
evidence (commit sha + failing test / validator / missing artifact). Silent
reversion is a rule break rejected on next boot.

Rescope protocol: gate count may not decrease without
`OPERATOR: mvp-rescope <rationale>` in STATE.md.

---

## Flip digest (quick view)

| Gate | State | Latest flip | Evidence one-liner |
|------|-------|-------------|--------------------|
| G1 | `[ ]` | — | — |

---

## G1 — <replace with observable criterion one-liner>
- [ ] <describe the observable behavior a reviewer can run and see pass>
- Evidence: <what artifact must exist when this flips — log path, test name,
  PR number, qa-evidence JSON>
- (flip history appended here when the gate changes state, newest last)

---

(Seed with real gates during project kickoff. Update `Gate count:` to the
actual total. Pre-commit hook rejects any commit where the line is missing
or not parseable.)
