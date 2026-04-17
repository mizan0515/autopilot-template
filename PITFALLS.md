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
