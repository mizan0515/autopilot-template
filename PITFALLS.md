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

### 2026-04-24 — Wildcard Grep/Glob without path narrow explodes token budget on large repos

- Symptom: `rg` / `Grep` / `Glob` without a path argument in a repo with build caches (Unity `Library/`, `Temp/`, `Logs/`, node `node_modules/`, .NET `obj/`/`bin/`) returned megabytes of artifacts and blew per-iteration file-read/budget caps in a single call.
- Root cause: default search roots the whole working tree including cache dirs that are `.gitignore`'d but not search-ignored.
- Next time: before every code search, either pass an explicit source subdir (`src/`, `Assets/Scripts/`, `CodexClaudeRelay.Core/`, `Document/`, `.autopilot/`) OR use `--glob '!Library/'`-style excludes. If a search would span the whole repo, re-scope first. Apply to Read tool too — never Glob `**/*` without narrowing.
- Resolved-in: open — downstream repos should add a project-specific "search narrow list" to their own PITFALLS/PROJECT-RULES.

### 2026-04-24 — `project.sh doctor` green does not guarantee the live runtime path works

- Symptom: `doctor` returned `ok`, but the actual runtime call the task depended on (Unity MCP `refresh_unity`, DB ping, API probe) still failed — iterations were wasted planning QA against a dead runtime.
- Root cause: doctor is a coarse preflight (process alive? port open?), not a live-path smoke. A process can be up while the MCP bridge points at an older worktree, or a port can accept TCP without the service answering.
- Next time: treat doctor green as necessary-not-sufficient. Before planning a task that depends on a specific runtime endpoint, fire one real smoke call (the simplest no-op of the actual path) and record the response. If smoke fails, log a bridge blocker — do not schedule QA work against it.
- Resolved-in: open — add a `project.sh smoke` target that does a thin live-path probe per project, orthogonal to `doctor`.

### 2026-04-24 — PowerShell `Start-Process` splits spaced `-projectPath`/`-ArgumentList` into tokens

- Symptom: launching a tool with `-ArgumentList "-projectPath", "D:\foo bar\baz"` recorded the path as two tokens (`D:\foo` and `bar\baz`) in the tool's own log; the tool then looked up a non-existent path and exited 0 silently.
- Root cause: `Start-Process -ArgumentList` takes an array; any element containing a space is NOT auto-quoted when reassembled into the child command line.
- Next time: when a path (project root, config, log target) contains spaces, pass a single pre-quoted argument string: `Start-Process foo.exe '-projectPath "D:\foo bar\baz"'`. After launch, immediately read the child's own log (e.g. `Editor.log`, service startup log) and confirm the full path survived before proceeding.
- Resolved-in: open — downstream runners and `project.ps1` tasks should follow this pattern when invoking subprocesses with paths.

### 2026-04-24 — Korean / non-ASCII agent-facing Markdown renders as mojibake if editor drops BOM

- Symptom: `PROJECT-RULES.md`, `CLAUDE.md`, `Document/*.md` etc. rendered as `?묒쟾 ?먯닔` after a PowerShell fallback `Set-Content` write dropped the UTF-8 BOM. Agents then cited garbled terms back into code and UI labels.
- Root cause: on Windows, default PowerShell text writes in ANSI (cp949) unless `-Encoding utf8BOM` is specified. Some editors also strip BOM on save.
- Next time: before editing any contract / prompt / document file that contains Korean or other non-ASCII prose, (a) read the byte-level encoding first, (b) write with explicit UTF-8-with-BOM encoding, (c) run the repo's document validator (`tools/Validate-Documents.ps1` or equivalent) before commit. Exception: agent skill frontmatter files (`.agents/skills/**/SKILL.md`, `agents/openai.yaml`) must stay UTF-8 **without** BOM — loaders expect YAML at byte 0.
- Resolved-in: open — downstream projects should add a pre-commit encoding check for protected doc paths.

### 2026-04-24 — Dashboard / HISTORY rows repeat identically across idle-upkeep streak, burying signal

- Symptom: `.autopilot/대시보드.md` (or equivalent operator dashboard) grew 20+ nearly-identical `idle-upkeep streak=N · R-REVIEW 지속 · 변경 없음` rows. Scrolling past them to find the last real event cost operator time and agent read budget.
- Root cause: every iter appended a full status row even when nothing changed, treating the dashboard as a log rather than a state surface.
- Next time: during idle-upkeep (or any mode whose iter produced no new artifact/finding/PR), do not append a new dashboard row. Instead, update a single `(streak: idle-upkeep × N since iterM)` line in place, and bump N. Only append a fresh row when state actually changes (new PR, new finding, status transition, operator directive). HISTORY.md follows the same rule: collapse consecutive no-delta iters into one counter line.
- Resolved-in: PR #1 — upstream PROMPT.md Idle-upkeep section carries the streak-collapse rule (line 203) and the HISTORY-rotation / dashboard section cross-references it (line 272). Downstream wiring: codex-claude-relay PR #105, cardgame-dad-relay PR #36.

### 2026-04-24 — Per-iteration worktrees fill the parent directory with dead `iter-*` folders

- Symptom: the parent of the repo accumulated dozens of `iter-*` / `autopilot-*` worktree folders after a few days of running, costing tens of GB and slowing IDE / indexer scans across the parent dir. Several folders pointed at branches that had already been merged and deleted.
- Root cause: a naive runner created a fresh worktree per iteration and never pruned them. `git worktree list` showed stale entries pointing at deleted branches; the disk kept the checkouts.
- Next time: runners should reuse ONE detached automation worktree (e.g. `..\<repo>-autopilot-runner\live`) rather than spawning a new one per iteration. If multiple concurrent runners are needed, name them deterministically (`live`, `evolution`, `qa`) — never timestamp-per-iter. On every post-merge cleanup, also run `git worktree prune` and delete any worktree whose branch is `: gone`.
- Resolved-in: open — documented in RUN.txt; `project.sh`/`project.ps1` `start` should default to a named reuse path.

### 2026-04-24 — Lite maintenance tasks paid full-PROMPT boot cost every iter

- Symptom: short doc-gardening / dashboard-refresh / validator-rerun iterations loaded the full `.autopilot/PROMPT.md` (IMMUTABLE blocks, probation check, mode dispatch, brainstorm rules, decision-PR workflow) even though the task read 1 file and wrote 1 line. Token burn per iter was ~10× the actual work.
- Root cause: only one prompt existed. The full boot is load-bearing for Active mode but pure overhead for small maintenance runs.
- Next time: for narrow maintenance loops, run with `AUTOPILOT_PROMPT_RELATIVE=.autopilot/PROMPT.lite.md` (or the runner's lite-mode flag). Lite prompt skips PITFALLS/EVOLUTION/FINDINGS reads, forbids PRs and self-evolution, keeps only HALT + IMMUTABLE + exit-contract + reschedule discipline. Escalate back to full `PROMPT.md` the moment the task needs a PR, a gate flip, or a decision.
- Resolved-in: PR #26 — PROMPT.lite.md seeded and PROMPT.md now carries a "Lite-mode reentry criteria" section (≤2 reads, ≤1 write, no PR, no IMMUTABLE touch, no MVP/decision/evolution). Runners honor `AUTOPILOT_PROMPT_RELATIVE`; downstream `-Lite`/`AUTOPILOT_LITE=1` wiring tracked as separate per-repo PRs.

### 2026-04-24 — HISTORY.md grew to 50KB+ because rotation rule was advisory only

- Symptom: `.autopilot/HISTORY.md` reached 56KB / 1500+ lines in `codex-claude-relay`. Every boot read the full file, every idle-upkeep scan re-scanned it, and the operator dashboard inherited the bloat. Old entries past the 10th were never loaded usefully — they were pure token overhead.
- Root cause: PROMPT.md mentioned "HISTORY trims to last 10 entries (older → HISTORY-ARCHIVE.md)" in the "UX-is-terrible assumptions" section, but no actual rotation step existed. The rule was an assumption, not an executable behavior.
- Next time: rotation is now an explicit boot-time step (see the "HISTORY rotation" section in PROMPT.md). Thresholds: >50 entries OR >20KB for HISTORY, 100/40KB for the operator dashboard. One rotation commit per iter. Archive file is `HISTORY-ARCHIVE.md` / `대시보드-ARCHIVE.md`.
- Resolved-in: PR #29 — `helpers/Test-HistorySize.ps1` ships in autopilot-template (soft-by-default, `-Strict` exit 4). Downstream pre-commit wiring: codex-claude-relay PR #106, cardgame-dad-relay PR #38 (warn-only, non-blocking).

### 2026-04-24 — METRICS.jsonl dropped `ts` field in one downstream; schema drifted unmanaged

- Symptom: `codex-claude-relay/.autopilot/METRICS.jsonl` lines looked like `{"iter":117,"mode":"post-mvp-idle","cumulative_merges":31,...}` — no `ts`. The reschedule watchdog's staleness calculation (`LAST_RESCHEDULE` line 1 timestamp age) still worked, but any cross-iter time-series tool or `status: env-broken in 3 consecutive iters` halt condition couldn't reason about wall-clock gaps. Meanwhile `Unity card game` METRICS lines carried `mcp_calls`, `editmode_tests`, `screenshots`, and a long free-form `budget_exceeded` reason — a parallel extension with no shared naming convention.
- Root cause: IMMUTABLE:exit-contract Step 2 listed the required schema but did not address extension. Downstreams dropped required fields and added bespoke ones without a shared tier.
- Next time: see the new "METRICS schema convention" section in PROMPT.md. Tier 1 required (including `ts`), Tier 2 reserved names (`mvp_gates_passing`, `cumulative_merges`, `pending_review`, `idle_upkeep_streak`, `merged`, `mcp_calls`, `warnings`, `reschedule`), Tier 3 project extensions must use a project prefix. Never drop a Tier 1 field.
- Resolved-in: PR #22 — `helpers/Validate-Metrics.ps1` ships in autopilot-template; default tails last 20 lines and asserts Tier 1 (`ts`, `iter`, `mode`), with optional `-Strict -ProjectPrefix` for Tier 3 naming enforcement. Exit 3 on missing Tier 1.

### 2026-04-24 — Template `runners/` scripts diverged from real-usage runners by ~4×

- Symptom: `D:\autopilot-template\runners\runner.sh` is 48 lines (naive submit-wait-sleep). `D:\Unity\card game\.autopilot\runners\runner.sh` is ~209 lines and adds: reusable detached automation worktree (solves the per-iter-worktree bloat pitfall), `RUNNER-LIVE.json` phase/health state file, `AUTOPILOT_PROMPT_RELATIVE` env for lite-prompt switching, `AUTOPILOT_WORKTREE_DIR` override, `project.ps1` integration, cross-platform `resolve_cmd` for `.exe`/`.cmd` fallback. Same gap in `runner.ps1` (2.9K vs 6.2K). Downstream users who took the template runner got none of this and have to re-discover each feature independently.
- Root cause: the template's runners were seeded minimally and never back-ported from real-usage evolution. `RUN.txt` documents the reuse-worktree convention in prose but the runner scripts don't implement it.
- Next time: port the Unity runner scripts' proven features into template `runners/runner.sh` and `runners/runner.ps1`. Keep them AI-agnostic (the `AUTOPILOT_AI=claude|codex|custom` branch stays) but add: (a) reuse-worktree logic keyed on `AUTOPILOT_WORKTREE_DIR` with a default of `<parent>/<leaf>-autopilot-runner`, (b) `RUNNER-LIVE.json` emit on each phase transition, (c) `AUTOPILOT_PROMPT_RELATIVE` honored, (d) `.exe`/`.cmd` fallback on Windows. Defer this to a dedicated slice — it's a real code change, not a doc edit.
- Resolved-in: `runners/runner.sh` and `runners/runner.ps1` ported 2026-04-24. Deliberately did NOT copy Unity's default `--dangerously-bypass-approvals-and-sandbox` flag — see next entry.

### 2026-04-24 — Unity's runner defaults codex to `--dangerously-bypass-approvals-and-sandbox`

- Symptom: `D:\Unity\card game\.autopilot\runners\runner.sh` line 117-119 always passes `--dangerously-bypass-approvals-and-sandbox` to `codex exec`. This is fine for an informed single-project consent (Unity operator opted in), but propagating that default to the upstream template would push the flag to every downstream that seeds from us, making unattended sandbox-bypass loops the norm.
- Root cause: Unity needed unattended runs and hardcoded the flag directly in the runner. No env-gating separated the one-project consent from a general-purpose template default.
- Next time: the template's ported `runner.sh` (and the pending `runner.ps1`) MUST default to approvals-honored (`codex exec -C <root> -`) and expose `AUTOPILOT_CODEX_ARGS` as the opt-in knob. Downstream projects that want unattended runs set `AUTOPILOT_CODEX_ARGS='--dangerously-bypass-approvals-and-sandbox'` in their own `RUN.txt` / scheduler config. That keeps the dangerous choice a per-project decision, not a template inheritance.
- Resolved-in: template `runners/runner.sh` and `runners/runner.ps1` 2026-04-24 (opt-in via env).

### 2026-04-24 — Template `qa-evidence/SCHEMA.md` was too minimal; real usage evolved it substantially

- Symptom: the template seed had 4 fields (steps/assertions/regressions/unresolved). `D:\Unity\card game\.autopilot\qa-evidence\SCHEMA.md` evolved to include `console`, `ux_critique`, a `screenshots[]` array with per-image `critique` + `player_intent_clear`, and (critically) an explicit rule that zero-UX-visible changes *still* produce an artifact. Meanwhile the two DAD-v2 relays didn't even have a `qa-evidence/` dir — so behavior-visible runtime changes could merge with zero evidence trail.
- Root cause: the template seeded a minimal schema and never back-ported lessons from real usage. Downstreams either reinvented the structure (Unity) or skipped it entirely (relays).
- Next time: the upstream template schema now documents the artifact-existence invariant universally (refactors included), and seeds two optional-but-encouraged blocks (`console`, `screenshots[]`, `regressions_checked[]`). Downstreams inherit and extend with a domain-specific block: Unity adds `unity{...}` and `ux_critique{...}`; the DAD-v2 relays add `dotnet{...}`, `validators[]`, and a mandatory `peer_symmetry{...}` block (new pattern: any agent-identity slice must prove no role-conditional branch was introduced). Generalize this as: every downstream gets one mandatory domain block whose contents are its particular tripwires.
- Resolved-in: template SCHEMA.md enriched 2026-04-24; `codex-claude-relay` and `cardgame-dad-relay` qa-evidence dirs seeded 2026-04-24 with peer-symmetry block.

### 2026-04-24 — `git log --since="N days ago"` / relative dates give different commit sets across wake-ups

- Symptom: a loop iteration that queried `git log --since="1 week ago"` and compared it to the result from a prior wake-up got different sets, even though no new commits landed in between. Conclusions drawn from "what merged recently" were silently wrong.
- Root cause: relative date expressions (`1 week ago`, `yesterday`, `last Friday`) resolve against the *current* wall clock. Wake-ups happen at arbitrary times, so the same relative expression names different windows on each call. Evidence: `D:\Unity\card game\.autopilot\PITFALLS.md` entry 2026-04-17.
- Next time: always use absolute ISO dates (`--since="2026-04-10"`) or commit hashes (`origin/main@{N.hours.ago}` is equivalent to relative dates — also avoid) when a loop iteration compares to prior-iter results. If you need "since the last merge," use the merge's commit hash; if you need "since the last boot," record an ISO timestamp in STATE.md at boot and query against that. Relative dates are fine for one-shot human shell use; they are a landmine inside a persistent loop.
- Resolved-in: open — consider a hook on `bash` tool calls that rejects `--since="[^0-9]"` patterns in autopilot contexts, but for now the rule is prose-only.

### 2026-04-24 — Multi-instance runtime bridges need active-instance check before every tool call, not just once

- Symptom: Unity MCP tool calls silently hit the wrong Unity Editor instance, or failed with `No Unity Editor instances found` after a prior `doctor` reported ok. Evidence was captured against the wrong worktree; subsequent iterations wasted cycles blaming feature regressions that were actually runtime-routing bugs. See `D:\Unity\card game\.autopilot\PITFALLS.md` entries 2026-04-17 (active instance), 2026-04-19 (older-worktree pointer).
- Root cause: stateful runtime bridges (Unity MCP, browser sessions via Chrome MCP, remote-desktop automation, a DB connection pool bound to a specific schema) multiplex across instances. The binding is negotiated once and then silently remains pinned — often to a stale target — while the agent assumes it still points at the intended instance.
- Next time: for any tool family that talks to a stateful external runtime, verify the active instance immediately before a batch of calls whose correctness depends on runtime state. Verify by (a) asking the bridge which instance it's talking to (`mcpforunity://instances`, `request_access` tier, browser session URL) AND (b) cross-checking the OS/process layer where possible (`tasklist` / `ps` for the running binary, `Application.dataPath` for Unity). Doctor-class preflight is necessary but not sufficient; the smoke check must probe the actual call path. If the bridge is pinned to the wrong instance, record a bridge blocker instead of re-running the tool "one more time."
- Resolved-in: open — generic version of the existing "doctor green ≠ live runtime works" pitfall, focused specifically on the multi-instance binding failure mode.

### 2026-04-24 — Auto-generated sibling artifacts (JSON/txt alongside screenshots) land with broken UTF-8 when the capture path uses ANSI

- Symptom: Unity's `Capture Event/RelicReward/MatchResult Screenshot` tools wrote the sibling JSON with mojibake in the Korean fields (`header_text`, `outcome_text`, etc.) even though the PNG was correct. Evidence: `D:\Unity\card game\.autopilot\PITFALLS.md` entries 2026-04-19/20 (three recurring instances). The artifact was then linked in HISTORY/STATE/dashboard as if valid, poisoning downstream consumers.
- Root cause: the capture tool writes the JSON via whatever text encoding its host writer defaults to (cp949 on Windows PowerShell), not UTF-8. Binary-adjacent structured text is an encoding blind spot — the screenshot itself doesn't care, so the broken JSON ships next to a correct-looking PNG and the combo looks legitimate.
- Next time: for any tool that auto-generates a structured text file next to a binary, treat the sibling text artifact as suspect by default. Immediately after the capture call, read the sibling file back as bytes, confirm the expected fields are valid UTF-8 (a `json.loads` or equivalent round-trip is enough), and repair in the same iteration if broken. Never link an auto-generated artifact from HISTORY/STATE/qa-evidence without this verification step. This generalizes beyond Unity: any native tool emitting JSON on Windows is a candidate.
- Resolved-in: open — consider a generic `Verify-SiblingArtifact.ps1` that any downstream project can invoke post-capture.

### 2026-04-24 — Agent self-update from inside a live session kills the session

- Symptom: `npm install -g @openai/codex@latest` (or equivalent Claude self-update) invoked by a running loop iteration terminated the very Codex process driving the loop. `cardgame-dad-relay` #22 caught this after a peer-tool updater ran inside a Codex-hosted shell: the updater stopped `codex*` processes as a prereq and the session died mid-iteration. Same shape applies to Claude Code updating itself from a Claude-hosted shell.
- Root cause: package-manager global installs on Windows often must stop the currently-running binary before replacing it; when the caller IS that binary, self-termination is guaranteed.
- Next time: any updater script targeting the hosting agent's own binary must (a) detect the active session via agent-specific env vars (`CODEX_THREAD_ID`, `CODEX_SHELL`, `CODEX_INTERNAL_ORIGINATOR_OVERRIDE` for Codex; analogous for Claude) and (b) refuse to self-update unless an explicit opt-in flag is passed. Peer-symmetric policy: detect BOTH agents with symmetric strategy code — no `if codex only` branch. Log `status: blocked_self_update` with a reason instead of silently exiting 0.
- Resolved-in: PR #21 — `helpers/Test-ActiveAgentSession.ps1` ships peer-symmetric env-var registry for claude + codex; exit 5 when any agent is active so self-update paths block themselves.

### 2026-04-24 — Auto-retry without rollback amplifies the original breakage

- Symptom: Unity downstream (#279) observed the autopilot loop retry an `asmdef`-touching slice immediately after a failed compile. Each retry re-applied partial edits on top of an already-broken tree; by retry 3 the repo was in a worse state than the first failure and manual rollback required resolving conflicting stashes.
- Root cause: retry logic saw "last attempt failed → try again" without a mandatory rollback. Transient-flake failures benefit from retry, but structured-edit failures (codegen, asmdef shuffle, migration) do NOT — they leave half-applied state that poisons the next attempt.
- Next time: any auto-retry branch must be gated behind a verified rollback (`git reset --hard` to last known-good, or equivalent checkpoint) BEFORE the second attempt. If rollback fails or the prior state can't be proven clean, escalate to a blocker finding instead of retrying. Prefer one-shot execution for structured edits; reserve retry-with-backoff for network/I/O flakiness only.
- Resolved-in: open — template runners should offer an opt-in `AUTOPILOT_RETRY_REQUIRES_ROLLBACK=1` guard that short-circuits retry when rollback can't be verified.

### 2026-04-24 — Monolithic files that get edited repeatedly drain the token budget iter-over-iter

- Symptom: Unity downstream ran three back-to-back refactor PRs (#275 QA screenshot capture, #276 QA autoplay, #277 battle bootstrap/reward) whose sole purpose was "extract helpers from a growing file so future edits don't read the whole thing." Before the refactors, each iter touching `BattleManager.cs` (~600 lines) had to read and context-carry the full file even when editing one helper; after extraction into narrow siblings, the same edits cost ~1/5 the tokens.
- Root cause: when a file crosses ~400–500 lines AND is edited by the loop repeatedly, every subsequent iter pays the full read cost for a localized change. The growth is gradual, so the threshold is crossed silently and no single iter flags it.
- Next time: treat "file ≥500 lines AND edited by the loop in ≥3 of the last 10 iters" as a proactive refactor signal. Extract narrow-purpose helper siblings (one concern per file) before attempting the next feature edit. Downstreams have started calling these "token-saving seams" — helper seams whose justification is iter-cost, not runtime architecture. Budget the seam refactor as its own PR with no behavior delta; the behavior PR follows on the now-smaller surface.
- Resolved-in: PR #25 — `helpers/Get-HotFiles.ps1` ships in autopilot-template; default 30-day lookback, MinEdits=3, sorted by current file size, JSON payload so downstreams can wire the readout into their `audit` or dashboard.

### 2026-04-24 — Loop re-discovers "what to do next" every iter instead of asking a pre-computed helper

- Symptom: Unity downstream's `.autopilot/project.ps1` grew a family of `codex-<intent>` commands (`codex-asmdef-plan`, `codex-asmdef-readiness`, `codex-asmdef-draft`, `codex-refactor-first-step`, `codex-next-target`, `codex-route`, `codex-workset`, `codex-close-readiness`, `codex-relay-dashboard`, `codex-relay-next`, `codex-relay-refresh`). Before these existed, each iter spent significant budget re-deriving "which file should I touch next" / "is this bucket ready for asmdef" / "what's the smallest read path for this target" from scratch by grep/glob. After the helpers, the same questions became one-line shell calls with deterministic output.
- Root cause: the template ships a generic runner contract (boot, probation, modes, exit) but no convention for project-local introspection helpers. Each downstream re-invents them, usually late, after paying the exploration cost several times.
- Next time: when a question is asked by the loop in ≥3 separate iters with the same answer shape, promote it to a `project.sh <intent>` helper. Generic candidates every downstream benefits from: `hot-files` (large+churning), `next-target` (single best refactor candidate), `close-readiness` (is current branch ready to land), `workset` (smallest read path for current diff), `route -Note <path>` (minimal read path for a target). The helper should be cheap (read-only, under a second) and emit a stable format the loop can parse. Note that the downstream naming uses `codex-*` — for peer-symmetric relays the helpers must be agent-agnostic (`plan`, `readiness`, `next-target`), not `codex-plan` / `claude-plan`.
- Resolved-in: open — template could ship a `project.example.sh` block documenting the recommended intent-helper family and peer-symmetric naming.

### 2026-04-24 — Debug-only smoke/override markers leak into production build paths

- Symptom: cardgame-dad-relay #17–#19 caught a smoke-test signal-override env-var (`CCR_MANAGER_SIGNAL_JSON_OVERRIDE`) being honored by Release builds of the Desktop manager. It was originally added so desktop smoke tests could inject a deterministic manager-signal JSON without the live relay running; nothing prevented a Release build from reading the same env var. An operator running the production Desktop with that var set would silently get spoofed manager state.
- Root cause: when a test-hook env var / CLI flag / file path is introduced, the default behavior of most runtimes is "honor it whenever it's set." Without explicit conditional compilation (`#if DEBUG` in C#, `if __debug__` in Python, `//go:build debug` in Go, `process.env.NODE_ENV !== 'production'` guard in Node, etc.) the override is a permanent backdoor — and "guard it later" reliably never happens.
- Next time: any smoke/test/override signal that bypasses normal governance must be wrapped in a conditional-compilation guard at the point of read, AND the project's `doctor`/preflight must statically verify the guard wraps each marker occurrence. The cardgame relay added a `Test-DebugOnlyOverrideGuard` function to its `project.ps1 doctor` that greps for the override token and fails if `#if DEBUG` is not within N lines above the hit. Generalize: every downstream introducing an override marker should add a symmetric guard-check — language-appropriate but same shape. Peer-symmetric relays must apply the guard to overrides on BOTH agent sides (no `if codex only`).
- Resolved-in: PR #17 — `helpers/Verify-DebugOnlyMarker.ps1` + `DEBUG-ONLY-MARKERS.example.json` ship in autopilot-template; config-driven `(path-glob, marker, lookback)` triples, exit 4 on violation.

### 2026-04-24 — State aggregators let stale governance blocks mask terminal states

- Symptom: cardgame-dad-relay #15 caught a compact-manager-signal aggregator unconditionally reporting `governance_blocked` even when the underlying loop status had already reached `complete` or `session_already_integrated`. The operator dashboard kept showing "blocked: X" on sessions that were actually done, so auto-advance to the next slice never fired.
- Root cause: state aggregators that combine governance, loop status, liveness, etc. often treat the most-recent governance verdict as authoritative without checking whether the loop has crossed into a terminal state. Once a phase-N governance block lands, it stays "true" forever from the aggregator's point of view even after phase N+1/terminal completes cleanly.
- Next time: any aggregator that folds phase-scoped governance into a single dashboard verdict must enforce **terminal-state precedence**: if the loop has reached a terminal state (complete, integrated, done, merged), prior-phase blockers CANNOT downgrade the overall status back to `blocked`. Write this as a single explicit ordering — terminal first, blockers second — not a chain of defensive `elif` clauses that accidentally re-order. Add a unit-style fixture: "governance blocked + loop complete ⇒ overall=complete, not blocked."
- Resolved-in: open — template could ship a `Resolve-OverallStatus` convention documenting the precedence order.

### 2026-04-24 — IMMUTABLE identity assertions need runtime drift check, not just author-time

- Symptom: cardgame-dad-relay #6 added explicit runtime detection of `IMMUTABLE:repo-identity` drift because operators had been running the relay after renaming the repo or re-pointing the remote — nothing in the loop noticed. The relay happily published packets under the old identity while git and GitHub showed the new one, and the drift only surfaced days later when a reviewer spotted mismatched PR metadata.
- Root cause: IMMUTABLE blocks are enforced at author-time by pre-commit hooks (`protect.sh` / `protect.ps1`), but at runtime nothing re-reads the block and compares it against the live `git remote get-url origin` + `basename $(git rev-parse --show-toplevel)`. The hooks prevent bad commits; they do not prevent a correct commit from running against a repo whose shell has since been renamed or re-cloned elsewhere.
- Next time: any identity assertion pinned in an IMMUTABLE block (repo name, remote URL, expected branch, peer list) must also be verified at boot by a dedicated helper — e.g. `Get-*RepoIdentityStatus.ps1` in cardgame — that re-reads the block and compares it against the live runtime values. Surface the result in the compact operator signal as a first-class `identity_drift` status, not a silent ok. The governance aggregator should treat identity_drift as a block.
- Resolved-in: PR #13 — `helpers/Test-RepoIdentityDrift.ps1` parses `IMMUTABLE:repo-identity` from the usual locations and compares to live git remote + branch; soft tripwire by default, `-Strict` for doctor enforcement.

### 2026-04-24 — Agent CLI version drift is silent until a contract bug surfaces

- Symptom: cardgame-dad-relay #20/#21 observed iterations where `claude --version` and `codex --version` had drifted multiple minor versions behind the npm-published latest. Some downstream bugs (tool-call schema mismatches, deprecated flag handling) turned out to be "already fixed upstream two releases ago" — but the loop had no visibility into the CLI version, so each iter re-debugged a resolved issue. Conversely, when one agent auto-updated ahead of the pinned peer, relay round-trips failed with shape mismatches that looked like relay bugs.
- Root cause: the runner probes `git`, `gh`, `dotnet`, language runtimes at boot via `doctor`, but not the agent CLIs themselves. Version is assumed stable across the session; in practice, operators run `npm update` between iters or the system package manager upgrades silently. There is no record of which CLI version authored each iter's commits — so post-hoc bisect can't distinguish "our code regressed" from "agent CLI regressed."
- Next time: the runner should capture agent CLI versions at boot and write them to METRICS (Tier 2 reserved: `claude_cli`, `codex_cli`) alongside each iter. The compact operator signal should surface an `agent_cli_drift` status (current/outdated/ahead vs npm latest) so operators decide whether to update. Peer-symmetric relays must probe BOTH agent CLIs — no codex-only tracking. Updates should go through the self-update guard from the 2026-04-24 agent-self-update entry (not a new backdoor).
- Resolved-in: PR #12 — `helpers/Get-AgentCliVersions.ps1` ships with a peer-symmetric agent registry; returns `{agent, current, latest, drift_status}` per agent.

### 2026-04-24 — Compact-status fields ship without paired human-readable reasons

- Symptom: cardgame-dad-relay #13 had to add `loop_reason` to the compact manager signal after operators repeatedly opened a bug ticket for "status: waiting" or "status: blocked" with no way to tell WHY. The enum-only status was machine-readable but forced the operator to dig through relay logs, loop artifacts, or the Desktop console to get a one-line explanation of the current state. Several iterations were spent guiding the operator to the right log — cost that the relay could have eliminated at the source.
- Root cause: compact status fields are designed as enums for the UI to render consistently. Designers add the enum and consider the field complete. The reason string is treated as "operator can find that elsewhere if they need it" — but in practice the operator needs it 100% of the time a non-default state appears, and the lookup path is never cheap.
- Next time: whenever a new compact-status field is added (`overall_status`, `next_action`, `relay_status`, `agent_cli_drift`, etc.), ship a paired `<field>_reason` string in the SAME signal payload. Always present, default to `''`, populated with a one-sentence human-readable explanation whenever the field is not in its default state. The UI contract is: never render a non-default state without the reason. This is cheap at emit-time (the code generating the state already knows why) and saves several iterations of operator back-and-forth per week.
- Resolved-in: open — template could document a "status-with-reason" pair convention in the compact signal schema section so downstreams adopt it from the start rather than retrofitting.

### 2026-04-24 — IMMUTABLE identity gets retrofitted surface-by-surface after the fact

- Symptom: cardgame-dad-relay merged five back-to-back PRs in ~30 minutes (#7 admission+runbook, #8 startup output, #9 terminal writeback, #10 post-completion visibility, #11 manager status) each propagating the repo-identity field through one more user-facing surface. The identity itself already existed in an IMMUTABLE block; every new surface had been added earlier without an identity-carrying discipline, so retrofit was serial and expensive.
- Root cause: identity is declared once in an IMMUTABLE block, but there is no contract obligating every new output surface (dashboards, log lines, compact signals, terminal writes, PR metadata) to carry it. Each surface author decides independently. When operators later need the identity visible — because of repo-clone drift, multi-relay confusion, or cross-repo PR review — the gap is uniform across all surfaces and fixing it is O(surfaces).
- Next time: treat identity as a **default field on every output surface**, not a retrofit. When a new compact signal schema, dashboard block, or operator-facing log is added, include `repo_identity` (or the IMMUTABLE-equivalent fingerprint: repo name + remote origin hash + expected branch) as a required field unless an explicit "identity-not-applicable" justification is in the surface's design note. Enforce via a contract test: parse every known surface's schema, assert `repo_identity` present or justification documented. Peer-symmetric relays must carry identity through BOTH agent sides' status surfaces — no codex-only dashboard with identity and claude-only without.
- Resolved-in: PR #23 — `helpers/Test-SurfaceCarriesIdentity.ps1` + `SURFACES.example.json` ship in autopilot-template; enumerates registered surfaces (JSON fields or text patterns) and exits 3 on any surface missing the identity marker.

### 2026-04-24 — Agents reflexively fill "intentionally absent" negative space

- Symptom: Unity downstream PITFALLS 2026-04-17 "`UI prefabs in Assets/Prefabs/UI/` are intentionally empty" and "`Document/temp plan/` is intentionally untracked" exist because agents repeatedly tried to add UI prefabs (after seeing empty dirs) and tried to track temp-plan files (after seeing them untracked). The previous fix was prose docs; agents read the repo, not the docs. Same shape across downstreams: any deliberately-empty dir, deliberately-absent file, or deliberately-gitignored tree looks to an LLM like a gap to close.
- Root cause: LLM priors treat "empty" / "missing" / "untracked" as deficiencies to repair. Without a locally-visible marker at the site of the negative space, the reflex fires and a PR adds the thing back. Prose-only documentation in a PITFALLS/README elsewhere does not fire at the relevant moment because the agent's attention is on the empty dir, not the unrelated markdown.
- Next time: mark negative space at its own location with a machine-readable breadcrumb. Patterns: `ANTI-ARTIFACTS.md` inside any intentionally-empty directory (a one-liner explaining why it stays empty + link to the PITFALLS entry); `.gitkeep` with an adjacent `README-why-empty.md`; a `# INTENTIONALLY-EMPTY` comment banner at the top of placeholder files. Pre-commit hook: grep staged additions for "creates file in directory containing ANTI-ARTIFACTS.md" and refuse unless the commit message includes `NEGATIVE-SPACE-OVERRIDE: <reason>`. Same hook should block un-gitignoring of marked-absent trees.
- Resolved-in: open — template could ship an `ANTI-ARTIFACTS.md.example` + hook snippet that downstreams drop into any directory they want to keep empty.

### 2026-04-24 — Domain terminology regresses to similar-sounding wrong terms unless grep-pinned

- Symptom: Unity downstream PITFALLS 2026-04-17 has two recurring regressions — `MatchScore` gets swapped for the legacy `StageScore` on mode-4 finalize paths, and the Korean maintenance action name `수정비` keeps getting rewritten as `예정비` (both pre-existed in the codebase and look interchangeable to a reader without context). Each iter that touched the area cost some budget re-establishing which variant is canonical. The downstream fix was a PITFALLS note; drift still returned.
- Root cause: LLMs resolve "which of these similar terms is correct here?" by similarity-attraction to prior training data and local context, not by canonical repo truth. When two terms both exist in the codebase — one legacy, one current — the model has roughly 50/50 odds of picking the wrong one in a new edit. A PITFALLS note elsewhere fires only if the author reads it first. Pre-commit grep is the only layer that catches every instance.
- Next time: for any project with a domain-term canonicalization rule (`MatchScore` not `StageScore`; `수정비` not `예정비`; `connector` not `adapter`; etc.), ship a pre-commit `Test-TerminologyDrift` check that scans staged diffs for the forbidden variants and fails with a pointer to the canonical form. The check is config-driven — a `TERMINOLOGY.md` (or JSON) table of `forbidden → canonical` pairs — so downstreams register new pins over time without touching hook code. Catching at commit time is free; catching at review time is paid work per reviewer per iter.
- Resolved-in: PR #15 — `helpers/Verify-Terminology.ps1` + `TERMINOLOGY.example.md` ship in autopilot-template; exit 2 on hit, config-driven.

### 2026-04-24 — Evidence artifacts pass existence checks while carrying zero signal

- Symptom: Unity downstream FINDINGS 2026-04-18 iter 5/6 logged Gate 3 (`map-route-intent-clarity`) blocked not because the map UI was wrong but because the capture path produced a black game-view frame or a non-representative scene-view grid. The PNGs existed, had plausible file sizes, and satisfied the artifact-existence invariant in `qa-evidence/SCHEMA.md`. Multiple iterations were spent on evidence-plumbing before anyone noticed the attached screenshots were semantically empty. Gate 3 could not flip until a dedicated `Tools/QA/Inspect/Capture ZoneMap Screenshot` seam landed that produced a non-black, representative frame.
- Root cause: "file exists and is N bytes" is the cheap invariant and the one SCHEMA.md enforces. Semantic validation ("this PNG is not entirely one color", "this JSON's `outcome_text` is not empty", "this log line matches the expected event shape") is expensive per-artifact-type and therefore skipped. Absent that layer, a broken capture path poisons every gate evidence-set downstream of it.
- Next time: for each evidence-artifact kind the project gates on (screenshots, structured JSON, log dumps, packet diffs), pair the existence check with a minimal semantic validator run inline at capture time — not after the gate fails. Examples: PNG → assert histogram has ≥2 distinct colors AND a minimum entropy bar; JSON → assert required fields are non-empty strings, not just present keys; log dump → assert expected event shape appears ≥1×. On validation failure, refuse to link the artifact into qa-evidence — emit a "capture path broken" finding instead. Costs one cheap check at emit time; saves the entire gate-retry loop.
- Resolved-in: PR #16 — `helpers/Verify-EvidenceArtifact.ps1 -Kind png|json|log` ships in autopilot-template; exit 3 on zero-signal artifact, per-kind semantic checks (PNG byte-bucket, JSON required-fields, log regex).

### 2026-04-24 — Runtime-generated artifacts leak into git status one file-extension at a time

- Symptom: cardgame-dad-relay #24 (`chore: gitignore live operator dashboard and generated status .txt files`) added three new `.gitignore` rules for outputs emitted by generators the template already ships: the operator HTML dashboard (`.autopilot/OPERATOR-LIVE.ko.html`), its companion JSON, and a `.txt` sibling of files already ignored as `generated-*.json` + `generated-*.md`. The generators and their existing `.gitignore` entries landed in earlier PRs; each new output format emitted by those same generators required a separate downstream patch once operators noticed the leak in `git status`.
- Root cause: template `.gitignore` rules were written per-file-extension as each was observed (`generated-*.json` first, then `*.md`, then `*.txt`). A generator that writes an N-extension set leaks (N − 1) files the first time it runs in a new downstream because the template only anticipated the extension(s) present when the rule was last authored. Adding a new output extension to a generator is a silent breakage for every consumer's `git status` until someone notices and patches locally.
- Next time: when a template-owned script or runner writes runtime output, the `.gitignore` entry should match a directory or a file-class pattern (`.autopilot/OPERATOR-LIVE.*`, `profiles/*/generated-*`) rather than a fixed extension. Adding a new output extension to the generator in the same PR that introduced it is the cheap fix; retrofitting per-extension `.gitignore` lines downstream is the expensive one. A `Test-GeneratedFilesIgnored.ps1` smoke helper — run the generator once in a clean clone, assert `git status --porcelain` stays empty afterward — catches the class at template-smoke time instead of waiting for operator noise.
- Resolved-in: PR #19 — `helpers/Test-GeneratedFilesIgnored.ps1` + `GENERATORS.example.json` ship in autopilot-template; runs each registered generator from a clean git status and fails with exit 4 if any touched path is not covered by `.gitignore`.

### 2026-04-24 — Model upgrade inflates Bash/Read output tokens without a shared limit

- Symptom: Unity card-game #282 (`chore(claude): commit shared project settings with token-savings env`) committed `.claude/settings.json` with `BASH_MAX_OUTPUT_LENGTH=30000` and `CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS=25000` because Opus 4.7 consumes ~1.5× the tokens Opus 4.6 did on identical Bash and Read tool results. Without shared project-level limits, every developer's context silently inflates after the upgrade, and per-developer `.claude/settings.local.json` overrides drift between machines.
- Root cause: Claude Code respects two env vars for tool-output caps, but the defaults are generous and the failure mode is silent (no warning, just more tokens billed / faster context saturation). A model change is the trigger, but the fix is environmental — and environmental fixes default to `settings.local.json` which is git-ignored, so they do not propagate across the team.
- Next time: when a project depends on Claude Code, commit a shared `.claude/settings.json` with at least `BASH_MAX_OUTPUT_LENGTH` and `CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS` set to project-appropriate values. Leave `.claude/settings.local.json` git-ignored for per-developer overrides. Any time the model family moves (4.6 → 4.7 in this case), revisit the caps — caps that were generous on the old model become wasteful on the new one. A template-side `.claude/settings.example.json` with documented defaults and a PROMPT.md note about "after a model upgrade, audit your output caps" shortcuts the next migration.
- Resolved-in: PR #24 — `.claude/settings.example.json` ships in autopilot-template with documented Bash/Read output caps (BASH_MAX_OUTPUT_LENGTH=30000, CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS=25000) + cross-reference in PITFALLS for re-audit after model upgrades.
