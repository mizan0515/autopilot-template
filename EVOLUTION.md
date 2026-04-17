# EVOLUTION — self-mods to PROMPT.md (G9 audit log)

Appended every prompt-evolution PR + every probation result. Read on boot to check for active probation.

Format per evolution:
```
## YYYY-MM-DD-HHMM (iter N)
branch: dev/prompt-evolution-YYYYMMDD-HHMM
PR: <url or #>
friction_evidence:
  - <metric line from METRICS.jsonl> | <PITFALLS entry> | <OPERATOR line>
net_lines_added: N
baseline_metrics (5 iters pre-merge):
  avg_duration_s: N
  avg_files_read: N
  avg_bash_calls: N
probation_result: pass | reverted
  (if reverted) reason: <which metric regressed by what %>
```

Hard caps (enforced by PROMPT.md):
- ≤1 evolution per 10 iterations
- ≤40 net lines per commit
- ≤1 active probation
- Halt after 2 consecutive reverts
