# qa-evidence schema

The loop produces `<task-slug>-<YYYYMMDD-HHMM>.json` files here whenever an Active-mode task has UI, E2E, or end-user-visible behavior. No artifact = the task is not done, regardless of what HISTORY claims. This is the truthfulness tripwire.

```json
{
  "task_slug": "string",
  "iteration": 0,
  "started": "ISO-8601",
  "completed": "ISO-8601",
  "branch": "dev/<slug>-<YYYYMMDD>",
  "pr": "https://... or null",
  "steps": [
    { "step": "string — what was done", "result": "pass | fail | n/a", "evidence": "file:line | log excerpt | screenshot path" }
  ],
  "assertions": [
    { "claim": "string — what the loop says it achieved", "verified_by": "string — command output, diff, file hash" }
  ],
  "regressions_checked": ["string"],
  "unresolved": ["string — known remaining issues, empty array if none"]
}
```

Rules:
- No placeholder text. If a field is unknown, the task is not done.
- `assertions[].verified_by` must reference something inspectable *now* — a file path, a commit hash, a log line, not "I saw it pass".
- The file is committed as part of the same PR as the task.
- **Zero-user-visible changes (pure internal refactor, test-only, doc) still emit an artifact.** Set `steps[].result` appropriately and add `unresolved: ["ux_visible: false — internal change only"]` or an equivalent explicit note. The artifact-existence invariant ("no artifact = not done") is more valuable when it holds universally; exempting refactors weakens the tripwire.

Optional-but-encouraged fields (downstreams extend as needed — evidence: `D:\Unity\card game` schema):

- `console: { errors: <int>, warnings: <int>, excerpt: "string | filename" }` — if the runtime emits a structured console/log, record the counts. Useful beyond Unity for any build tool, test runner, or server log.
- `screenshots: [{ file, shows, critique }]` — for UI changes, commit peer PNGs and reference them. `critique` is honest self-review, not marketing copy.
- `regressions_checked: ["<flow | test | module>"]` — what else was re-verified to protect against collateral damage.
