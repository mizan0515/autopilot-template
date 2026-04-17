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
