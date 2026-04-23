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
- Resolved-in: open — add to Idle-upkeep and dashboard-render sections of PROMPT.md.

### 2026-04-24 — Per-iteration worktrees fill the parent directory with dead `iter-*` folders

- Symptom: the parent of the repo accumulated dozens of `iter-*` / `autopilot-*` worktree folders after a few days of running, costing tens of GB and slowing IDE / indexer scans across the parent dir. Several folders pointed at branches that had already been merged and deleted.
- Root cause: a naive runner created a fresh worktree per iteration and never pruned them. `git worktree list` showed stale entries pointing at deleted branches; the disk kept the checkouts.
- Next time: runners should reuse ONE detached automation worktree (e.g. `..\<repo>-autopilot-runner\live`) rather than spawning a new one per iteration. If multiple concurrent runners are needed, name them deterministically (`live`, `evolution`, `qa`) — never timestamp-per-iter. On every post-merge cleanup, also run `git worktree prune` and delete any worktree whose branch is `: gone`.
- Resolved-in: open — documented in RUN.txt; `project.sh`/`project.ps1` `start` should default to a named reuse path.

### 2026-04-24 — Lite maintenance tasks paid full-PROMPT boot cost every iter

- Symptom: short doc-gardening / dashboard-refresh / validator-rerun iterations loaded the full `.autopilot/PROMPT.md` (IMMUTABLE blocks, probation check, mode dispatch, brainstorm rules, decision-PR workflow) even though the task read 1 file and wrote 1 line. Token burn per iter was ~10× the actual work.
- Root cause: only one prompt existed. The full boot is load-bearing for Active mode but pure overhead for small maintenance runs.
- Next time: for narrow maintenance loops, run with `AUTOPILOT_PROMPT_RELATIVE=.autopilot/PROMPT.lite.md` (or the runner's lite-mode flag). Lite prompt skips PITFALLS/EVOLUTION/FINDINGS reads, forbids PRs and self-evolution, keeps only HALT + IMMUTABLE + exit-contract + reschedule discipline. Escalate back to full `PROMPT.md` the moment the task needs a PR, a gate flip, or a decision.
- Resolved-in: open — PROMPT.lite.md seeded in autopilot-template 2026-04-24.

### 2026-04-24 — HISTORY.md grew to 50KB+ because rotation rule was advisory only

- Symptom: `.autopilot/HISTORY.md` reached 56KB / 1500+ lines in `codex-claude-relay`. Every boot read the full file, every idle-upkeep scan re-scanned it, and the operator dashboard inherited the bloat. Old entries past the 10th were never loaded usefully — they were pure token overhead.
- Root cause: PROMPT.md mentioned "HISTORY trims to last 10 entries (older → HISTORY-ARCHIVE.md)" in the "UX-is-terrible assumptions" section, but no actual rotation step existed. The rule was an assumption, not an executable behavior.
- Next time: rotation is now an explicit boot-time step (see the "HISTORY rotation" section in PROMPT.md). Thresholds: >50 entries OR >20KB for HISTORY, 100/40KB for the operator dashboard. One rotation commit per iter. Archive file is `HISTORY-ARCHIVE.md` / `대시보드-ARCHIVE.md`.
- Resolved-in: open — enforce via a pre-commit check on file size later if needed.

### 2026-04-24 — METRICS.jsonl dropped `ts` field in one downstream; schema drifted unmanaged

- Symptom: `codex-claude-relay/.autopilot/METRICS.jsonl` lines looked like `{"iter":117,"mode":"post-mvp-idle","cumulative_merges":31,...}` — no `ts`. The reschedule watchdog's staleness calculation (`LAST_RESCHEDULE` line 1 timestamp age) still worked, but any cross-iter time-series tool or `status: env-broken in 3 consecutive iters` halt condition couldn't reason about wall-clock gaps. Meanwhile `Unity card game` METRICS lines carried `mcp_calls`, `editmode_tests`, `screenshots`, and a long free-form `budget_exceeded` reason — a parallel extension with no shared naming convention.
- Root cause: IMMUTABLE:exit-contract Step 2 listed the required schema but did not address extension. Downstreams dropped required fields and added bespoke ones without a shared tier.
- Next time: see the new "METRICS schema convention" section in PROMPT.md. Tier 1 required (including `ts`), Tier 2 reserved names (`mvp_gates_passing`, `cumulative_merges`, `pending_review`, `idle_upkeep_streak`, `merged`, `mcp_calls`, `warnings`, `reschedule`), Tier 3 project extensions must use a project prefix. Never drop a Tier 1 field.
- Resolved-in: open — consider a `tools/Validate-Metrics.ps1` that greps the last 20 lines for Tier 1 presence.

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
- Resolved-in: open — template should ship `Test-ActiveAgentSession` helper that downstreams wrap around any self-update path.

### 2026-04-24 — Auto-retry without rollback amplifies the original breakage

- Symptom: Unity downstream (#279) observed the autopilot loop retry an `asmdef`-touching slice immediately after a failed compile. Each retry re-applied partial edits on top of an already-broken tree; by retry 3 the repo was in a worse state than the first failure and manual rollback required resolving conflicting stashes.
- Root cause: retry logic saw "last attempt failed → try again" without a mandatory rollback. Transient-flake failures benefit from retry, but structured-edit failures (codegen, asmdef shuffle, migration) do NOT — they leave half-applied state that poisons the next attempt.
- Next time: any auto-retry branch must be gated behind a verified rollback (`git reset --hard` to last known-good, or equivalent checkpoint) BEFORE the second attempt. If rollback fails or the prior state can't be proven clean, escalate to a blocker finding instead of retrying. Prefer one-shot execution for structured edits; reserve retry-with-backoff for network/I/O flakiness only.
- Resolved-in: open — template runners should offer an opt-in `AUTOPILOT_RETRY_REQUIRES_ROLLBACK=1` guard that short-circuits retry when rollback can't be verified.

### 2026-04-24 — Monolithic files that get edited repeatedly drain the token budget iter-over-iter

- Symptom: Unity downstream ran three back-to-back refactor PRs (#275 QA screenshot capture, #276 QA autoplay, #277 battle bootstrap/reward) whose sole purpose was "extract helpers from a growing file so future edits don't read the whole thing." Before the refactors, each iter touching `BattleManager.cs` (~600 lines) had to read and context-carry the full file even when editing one helper; after extraction into narrow siblings, the same edits cost ~1/5 the tokens.
- Root cause: when a file crosses ~400–500 lines AND is edited by the loop repeatedly, every subsequent iter pays the full read cost for a localized change. The growth is gradual, so the threshold is crossed silently and no single iter flags it.
- Next time: treat "file ≥500 lines AND edited by the loop in ≥3 of the last 10 iters" as a proactive refactor signal. Extract narrow-purpose helper siblings (one concern per file) before attempting the next feature edit. Downstreams have started calling these "token-saving seams" — helper seams whose justification is iter-cost, not runtime architecture. Budget the seam refactor as its own PR with no behavior delta; the behavior PR follows on the now-smaller surface.
- Resolved-in: open — template could surface a `project.sh hot-files` readout (files edited N+ times in last M iters, sorted by size) so downstreams see the candidates.

### 2026-04-24 — Loop re-discovers "what to do next" every iter instead of asking a pre-computed helper

- Symptom: Unity downstream's `.autopilot/project.ps1` grew a family of `codex-<intent>` commands (`codex-asmdef-plan`, `codex-asmdef-readiness`, `codex-asmdef-draft`, `codex-refactor-first-step`, `codex-next-target`, `codex-route`, `codex-workset`, `codex-close-readiness`, `codex-relay-dashboard`, `codex-relay-next`, `codex-relay-refresh`). Before these existed, each iter spent significant budget re-deriving "which file should I touch next" / "is this bucket ready for asmdef" / "what's the smallest read path for this target" from scratch by grep/glob. After the helpers, the same questions became one-line shell calls with deterministic output.
- Root cause: the template ships a generic runner contract (boot, probation, modes, exit) but no convention for project-local introspection helpers. Each downstream re-invents them, usually late, after paying the exploration cost several times.
- Next time: when a question is asked by the loop in ≥3 separate iters with the same answer shape, promote it to a `project.sh <intent>` helper. Generic candidates every downstream benefits from: `hot-files` (large+churning), `next-target` (single best refactor candidate), `close-readiness` (is current branch ready to land), `workset` (smallest read path for current diff), `route -Note <path>` (minimal read path for a target). The helper should be cheap (read-only, under a second) and emit a stable format the loop can parse. Note that the downstream naming uses `codex-*` — for peer-symmetric relays the helpers must be agent-agnostic (`plan`, `readiness`, `next-target`), not `codex-plan` / `claude-plan`.
- Resolved-in: open — template could ship a `project.example.sh` block documenting the recommended intent-helper family and peer-symmetric naming.

### 2026-04-24 — Debug-only smoke/override markers leak into production build paths

- Symptom: cardgame-dad-relay #17–#19 caught a smoke-test signal-override env-var (`CCR_MANAGER_SIGNAL_JSON_OVERRIDE`) being honored by Release builds of the Desktop manager. It was originally added so desktop smoke tests could inject a deterministic manager-signal JSON without the live relay running; nothing prevented a Release build from reading the same env var. An operator running the production Desktop with that var set would silently get spoofed manager state.
- Root cause: when a test-hook env var / CLI flag / file path is introduced, the default behavior of most runtimes is "honor it whenever it's set." Without explicit conditional compilation (`#if DEBUG` in C#, `if __debug__` in Python, `//go:build debug` in Go, `process.env.NODE_ENV !== 'production'` guard in Node, etc.) the override is a permanent backdoor — and "guard it later" reliably never happens.
- Next time: any smoke/test/override signal that bypasses normal governance must be wrapped in a conditional-compilation guard at the point of read, AND the project's `doctor`/preflight must statically verify the guard wraps each marker occurrence. The cardgame relay added a `Test-DebugOnlyOverrideGuard` function to its `project.ps1 doctor` that greps for the override token and fails if `#if DEBUG` is not within N lines above the hit. Generalize: every downstream introducing an override marker should add a symmetric guard-check — language-appropriate but same shape. Peer-symmetric relays must apply the guard to overrides on BOTH agent sides (no `if codex only`).
- Resolved-in: open — template could ship a generic `Verify-DebugOnlyMarker.ps1` helper parameterized by `(Path, Marker, GuardPattern, LookbackLines)` so downstream doctor scripts just register the markers they care about.

### 2026-04-24 — State aggregators let stale governance blocks mask terminal states

- Symptom: cardgame-dad-relay #15 caught a compact-manager-signal aggregator unconditionally reporting `governance_blocked` even when the underlying loop status had already reached `complete` or `session_already_integrated`. The operator dashboard kept showing "blocked: X" on sessions that were actually done, so auto-advance to the next slice never fired.
- Root cause: state aggregators that combine governance, loop status, liveness, etc. often treat the most-recent governance verdict as authoritative without checking whether the loop has crossed into a terminal state. Once a phase-N governance block lands, it stays "true" forever from the aggregator's point of view even after phase N+1/terminal completes cleanly.
- Next time: any aggregator that folds phase-scoped governance into a single dashboard verdict must enforce **terminal-state precedence**: if the loop has reached a terminal state (complete, integrated, done, merged), prior-phase blockers CANNOT downgrade the overall status back to `blocked`. Write this as a single explicit ordering — terminal first, blockers second — not a chain of defensive `elif` clauses that accidentally re-order. Add a unit-style fixture: "governance blocked + loop complete ⇒ overall=complete, not blocked."
- Resolved-in: open — template could ship a `Resolve-OverallStatus` convention documenting the precedence order.

### 2026-04-24 — IMMUTABLE identity assertions need runtime drift check, not just author-time

- Symptom: cardgame-dad-relay #6 added explicit runtime detection of `IMMUTABLE:repo-identity` drift because operators had been running the relay after renaming the repo or re-pointing the remote — nothing in the loop noticed. The relay happily published packets under the old identity while git and GitHub showed the new one, and the drift only surfaced days later when a reviewer spotted mismatched PR metadata.
- Root cause: IMMUTABLE blocks are enforced at author-time by pre-commit hooks (`protect.sh` / `protect.ps1`), but at runtime nothing re-reads the block and compares it against the live `git remote get-url origin` + `basename $(git rev-parse --show-toplevel)`. The hooks prevent bad commits; they do not prevent a correct commit from running against a repo whose shell has since been renamed or re-cloned elsewhere.
- Next time: any identity assertion pinned in an IMMUTABLE block (repo name, remote URL, expected branch, peer list) must also be verified at boot by a dedicated helper — e.g. `Get-*RepoIdentityStatus.ps1` in cardgame — that re-reads the block and compares it against the live runtime values. Surface the result in the compact operator signal as a first-class `identity_drift` status, not a silent ok. The governance aggregator should treat identity_drift as a block.
- Resolved-in: open — template could ship `Test-RepoIdentityDrift.ps1` parameterized by the IMMUTABLE block path and the expected-fields list.

### 2026-04-24 — Agent CLI version drift is silent until a contract bug surfaces

- Symptom: cardgame-dad-relay #20/#21 observed iterations where `claude --version` and `codex --version` had drifted multiple minor versions behind the npm-published latest. Some downstream bugs (tool-call schema mismatches, deprecated flag handling) turned out to be "already fixed upstream two releases ago" — but the loop had no visibility into the CLI version, so each iter re-debugged a resolved issue. Conversely, when one agent auto-updated ahead of the pinned peer, relay round-trips failed with shape mismatches that looked like relay bugs.
- Root cause: the runner probes `git`, `gh`, `dotnet`, language runtimes at boot via `doctor`, but not the agent CLIs themselves. Version is assumed stable across the session; in practice, operators run `npm update` between iters or the system package manager upgrades silently. There is no record of which CLI version authored each iter's commits — so post-hoc bisect can't distinguish "our code regressed" from "agent CLI regressed."
- Next time: the runner should capture agent CLI versions at boot and write them to METRICS (Tier 2 reserved: `claude_cli`, `codex_cli`) alongside each iter. The compact operator signal should surface an `agent_cli_drift` status (current/outdated/ahead vs npm latest) so operators decide whether to update. Peer-symmetric relays must probe BOTH agent CLIs — no codex-only tracking. Updates should go through the self-update guard from the 2026-04-24 agent-self-update entry (not a new backdoor).
- Resolved-in: open — template could ship `Get-AgentCliVersions.ps1` (returns `{current, latest, drift_status}` per agent) that downstreams wrap into their own `doctor`.
