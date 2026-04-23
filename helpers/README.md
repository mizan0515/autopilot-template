# helpers/

Reusable enforcement scripts harvested from real downstream lessons.
Each helper is self-contained PowerShell (no external module deps),
emits stable JSON on stdout, and uses distinct exit codes so doctor
paths can separate failure modes.

## Exit code convention

| Code | Meaning                                               |
|------|-------------------------------------------------------|
| 0    | clean / pass                                          |
| 1    | missing required input (file, CLI)                    |
| 2    | config problem (missing config file, parse error)     |
| 3    | semantic-signal failure (zero-signal artifact)        |
| 4    | policy violation (unguarded marker, forbidden term)   |

Helpers are **soft tripwires by default** — callers decide whether to
propagate exit into doctor halt (`-Strict`), or warn-only.

## Helper index

| Helper                            | Motivating lesson                                               | Config                           |
|-----------------------------------|-----------------------------------------------------------------|----------------------------------|
| `Get-AgentCliVersions.ps1`        | Agent CLI version drift goes silent until a contract bug fires  | (none — npm + --version probes)  |
| `Test-RepoIdentityDrift.ps1`      | Copied-template repo_identity disagrees with live git remote    | reads `IMMUTABLE:repo-identity`  |
| `Verify-Terminology.ps1`          | Domain terms regress to similar-sounding wrong variants         | `TERMINOLOGY.md` or `.json`      |
| `Verify-EvidenceArtifact.ps1`     | qa-evidence files pass exists-check while carrying zero signal  | per-call `-Kind` / `-RequiredFields` |
| `Verify-DebugOnlyMarker.ps1`      | Smoke-only overrides leak into release builds                   | `DEBUG-ONLY-MARKERS.json`        |

## Installation pattern

Downstream repos copy the script(s) they need into their own
`tools/` (or `.autopilot/helpers/`) directory. The `helpers/` tree
here is the single upstream source of truth; copy once, treat as
local. Do NOT reach across to this template at runtime.

Typical doctor wiring (PowerShell caller):

```powershell
# soft: warn but continue
& tools/Get-AgentCliVersions.ps1 -AsJson | Out-File metrics/agent-cli.json

# hard: fail doctor on drift
& tools/Test-RepoIdentityDrift.ps1 -Strict
if ($LASTEXITCODE -ne 0) { Write-Error 'repo identity drift'; exit 1 }
```

## Adding a new helper

A new helper belongs here when all are true:

1. The lesson that motivates it is captured in `PITFALLS.md` with a
   `Resolved-in: open — template could ship ...` line pointing at the
   helper's name.
2. The check is **config-driven** or **argument-driven** — no
   project-specific paths or markers hardcoded in the script body.
3. At least one downstream hits the class. Speculative helpers accrete
   without usage.
4. Exit codes follow the table above (new codes extend, do not
   collide).

After landing the helper: update this index row, flip the `Resolved-in`
line in `PITFALLS.md` from `open` to the PR URL.
