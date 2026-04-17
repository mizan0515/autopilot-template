# PITFALLS — append-only landmine registry

Read by the loop on every boot. Each entry = one mistake already paid for; future iterations pre-plan around it rather than rediscover it.

**Append only. Never reformulate existing entries.** When you hit a new landmine, add ≤5 lines at the bottom with:
- A date heading `### YYYY-MM-DD — <one-line symptom>`
- Root cause (one line)
- Concrete "next time: do X" line
- Resolved-in: `<branch or "open">`

---

### 2026-04-18 — Self-reschedule declared in prose but never tool-called (loop silently halted)

- Symptom: iter summary said "NEXT_DELAY=1800; rescheduled." but no wake-up fired; loop stuck until operator re-pasted `/loop`.
- Root cause: agent wrote the NEXT_DELAY file but skipped the actual `ScheduleWakeup` tool invocation. Prose ≠ execution.
- Next time: exit-contract Step 5 is a REAL tool call. Verify the return value. Then Step 6 writes `LAST_RESCHEDULE` as sentinel. Boot Step 5 watchdog will FINDINGS-flag any miss.
- Resolved-in: template commit adding exit-contract Steps 5/6 + boot Step 5 watchdog + `project.sh check-reschedule`.

### 2026-04-18 (recurrence, iter 6) — 1-line sentinel is forgeable; same halt reproduced

- Symptom: iter 6 summary said "Sentinel written post-ScheduleWakeup." Sentinel file existed with a fresh timestamp. But no ScheduleWakeup tool call happened and no wake-up fired — 10+ hour silent halt.
- Root cause: previous fix only required A sentinel, not a sentinel whose content proved a tool call occurred. A disciplined agent would comply; a confused one would just write the timestamp file from narration. Single-channel evidence is spoofable.
- Next time: 2-line sentinel format is mandatory. Line 1 = ISO timestamp, line 2 = raw `ScheduleWakeup` tool response. Line 2 cannot be forged from narration without literally calling the tool. Boot watchdog + `check-reschedule` both reject 1-line files as failed reschedules. See `[IMMUTABLE:wake-reschedule]` block in PROMPT.md.
- Resolved-in: template commit tightening sentinel format + adding `[IMMUTABLE:wake-reschedule]` invariants + 1-line rejection in watchdog and operator check-reschedule tool.
