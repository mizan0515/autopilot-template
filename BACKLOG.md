# BACKLOG — prioritized task list, loop auto-promotes top item to active_task

Format per line: `- [P<n>] <short title> — <one-line why/acceptance>`
Optional tag suffix: ` [brainstorm]` / ` [upkeep]` / ` [evolution]` / ` [drift-fix]`

Priority levels:
- P1 — next to ship. Loop auto-promotes the top P1 to active_task on boot if none set.
- P2 — queued; promoted when P1 empty.
- P3 — nice-to-have; used by Brainstorm mode as seed.

Conventions:
- Top of file = highest priority. Newly-auto-promoted [brainstorm] items land at the bottom of their priority band.
- Max 5 [brainstorm] items at a time. Loop refuses to add a 6th.
- When an item completes, move it to HISTORY.md (3-bullet entry), not back to BACKLOG.

## P1

## P2

## P3
