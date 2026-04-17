# FINDINGS — Idle-upkeep pass results

Appended by Idle-upkeep mode. Each finding has a severity and optional proposed action.

Promotion rules (enforced by PROMPT.md §Mode: Idle-upkeep):
- `severity: high` → auto-promoted to active_task on the NEXT iteration
- `severity: med` + concrete proposed-action + no operator comment after 1 cycle → auto-promoted
- `severity: low` / `info` → remain logged, re-evaluated on next upkeep pass

Two-pass minimum between discovery and implementation (discover in pass N → implement in pass N+1+).

Format:
```
## YYYY-MM-DD (iter N)
- severity: high | med | low | info
  area: packages | todo-trend | churn | coverage | web-prior-art | validator
  finding: <one line>
  proposed-action: <one line, concrete>
  source: <url | file:line | command output fragment>
```
