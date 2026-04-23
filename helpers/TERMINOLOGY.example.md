# TERMINOLOGY.md — canonical/forbidden term pairs

Copy this file to your downstream repo root as `TERMINOLOGY.md` and
populate the table with any domain terms that keep drifting to a
legacy or similar-sounding variant. `helpers/Verify-Terminology.ps1`
reads it (JSON or this table form) and scans `git diff --cached` at
commit time.

## How it works

- Hook: pre-commit runs `pwsh tools/Verify-Terminology.ps1`.
- Exit 2 blocks the commit and prints each forbidden hit with the
  canonical replacement.
- Exit 0 passes.

## Table

| forbidden | canonical | note |
| --- | --- | --- |
| StageScore | MatchScore | card-game legacy term from mode-4 finalize path; keeps resurfacing |
| 예정비 | 수정비 | Korean maintenance action name — pair looks interchangeable to readers without context |
| adapter | connector | pick whichever your project standardized — delete this row if neither applies |

Add rows as you notice drift. Removing a row means "this pair is no
longer at risk." Do not comment out — delete.
