# Autopilot Template

A **runner-agnostic, AI-agnostic, single-prompt, infinitely self-improving** dev loop scaffold. Copy `.autopilot/` into any project, point a runner at it, and let it run.

---

## 🇰🇷 비개발자용 빠른 안내 (한국어)

영어 안내가 부담스러운 운영자용 한국어 요약입니다. 이 한 섹션만 봐도 매일 운영 가능합니다.

### 한 번만 설치 (개발자에게 부탁)
프로젝트에 `.autopilot/` 폴더가 이미 있다면 건너뛰세요. 없으면 개발자에게 "이 README의 Install 섹션대로 깔아 달라"고 한 번만 요청.

### 매일 쓰는 법 — **딱 한 번의 더블클릭**

윈도우 탐색기에서 `.autopilot\관리자 대시보드 열기.cmd` **더블클릭**. 그게 전부입니다.

열린 HTML 화면 맨 위 **"👉 관리자님이 지금 해주실 일"** 카드만 보세요:

| 화면에 뜨는 것 | 해야 할 일 |
|---|---|
| ✅ **없습니다. 지금은 기다리면 됩니다.** | 아무것도 안 하셔도 됩니다. 알아서 돕니다. |
| 🚨 **멈췄습니다 / 증거가 부실합니다** | 클로드 코드 채팅에 `/loop .autopilot/PROMPT.md` 한 줄 다시 입력. |
| ⛔ **정지된 상태입니다** | 아래 "재개" 절차 참고. |

화면은 자동 갱신되지 않습니다. 새로 보려면 **같은 .cmd 다시 더블클릭**. 오토파일럿 자체도 매 반복 끝에 이 화면을 스스로 갱신합니다 (`.cmd` 없이도 최신 상태 유지).

### CLI로 하고 싶으면 (선택)

| 하고 싶은 일 | 윈도우 (PowerShell) | 맥/리눅스 |
|---|---|---|
| **메뉴 열기** | `.\.autopilot\관리자.ps1` | `bash .autopilot/관리자.sh` |
| **HTML 대시보드만** | `.\.autopilot\관리자.ps1 대시보드` | (윈도우 전용) |
| **텍스트 상태만** | `.\.autopilot\관리자.ps1 상태` | `bash .autopilot/관리자.sh 상태` |

### 시작하는 법
1. **클로드 코드** 앱(터미널)을 엽니다.
2. 채팅창에 다음 한 줄을 입력하고 엔터:
   ```
   /loop .autopilot/PROMPT.md
   ```
3. 끝. 이후 작업·커밋·PR 만들기·머지·브랜치 정리까지 **모두 자동**입니다. 사람이 PR을 손으로 누를 필요가 없습니다 (단, 깃허브 저장소 보호 규칙으로 막혀있다면 그건 풀어줘야 합니다).

### 멈춘 것 같을 때
관리자.ps1/sh의 `상태`가 🚨를 보여주면, 시키는 대로 클로드 코드 채팅에 `/loop .autopilot/PROMPT.md` 한 줄만 다시 입력하면 됩니다. 그게 전부입니다.

### 자주 묻는 질문
- **PR을 제가 직접 머지해야 하나요?** 아니요. 자동 머지(`gh pr merge --squash --delete-branch --auto`)가 기본 동작입니다. 단, 안전을 위해 사람 승인을 강제하고 싶다면 `.autopilot/STATE.md`에 `OPERATOR: require human review` 줄을 추가하세요.
- **느려요. 30분이나 기다려요.** 이미 60초로 단축됐습니다 (`PROMPT.md` Pacing 섹션). 그래도 느리면 `.autopilot/STATE.md`에 `OPERATOR: pace 60`을 추가하세요.
- **갑자기 멈췄어요.** 99%는 자동 재예약(ScheduleWakeup) 누락입니다. `상태` 명령이 진단해주고 복구 방법(`/loop` 재입력)을 직접 알려줍니다.
- **개발자에게 보여줄 로그는 어디 있나요?** `.autopilot/HISTORY.md` (최근 10개), `.autopilot/METRICS.jsonl` (모든 반복), `.autopilot/PITFALLS.md` (실수 기록).

---

## Design principles

1. **Stateless prompt, stateful files.** `PROMPT.md` is re-submitted verbatim every wake-up. All continuity lives in sibling files (`STATE.md`, `HISTORY.md`, `PITFALLS.md`, ...). No conversation memory required → works with any AI CLI.
2. **Runner-agnostic.** The "loop" part (sleep + resubmit) is done by a separate runner: PowerShell, bash cron, GitHub Actions, Windows Task Scheduler, or anything else. The prompt never calls runner-specific APIs.
3. **AI-agnostic.** The prompt names tools generically ("file read/write", "shell exec", "web search if available"). Claude Code, Codex, OpenAI API, Gemini, local models — all work.
4. **Immune system.** Six `[IMMUTABLE:*]` blocks in PROMPT.md cover the safety contract: `core-contract`, `boot`, `budget`, `blast-radius`, `halt`, `exit-contract`. A pre-commit hook refuses any commit that alters them. The loop can evolve its own prompt (G9-style) only in mutable sections, on a separate branch, with post-merge probation + auto-revert on metric regression.
5. **Assumes bad operator UX.** Single kill switch (`touch .autopilot/HALT`). Single config file (`STATE.md` ≤60 lines). Auto-heals missing STATE. `OPERATOR:` override lines in STATE always win. HISTORY is ≤10 entries × 3 bullets.
6. **No grind.** Hard per-iteration budget (8 reads / 15 shell / 90 min / 1 PR). Budget overrun → terse handoff, not more retries. This protects against the 122× cost-explosion retry-loop anti-pattern.

## What the loop does

Every iteration picks exactly one mode and exits:

| Mode | Trigger | Output |
|------|---------|--------|
| **Active** | `active_task` set, or top P1 in BACKLOG | One commit-worthy slice + PR + auto-squash-merge + branch cleanup, HISTORY entry |
| **Idle-upkeep** | nothing better to do (max 1 per 4 iters) | Repo health scan + ≤3 web queries → FINDINGS.md |
| **Brainstorm** | BACKLOG <3 items, no upkeep last 2 iters | 5–10 ideas across 6 axes → BRAINSTORM.md, top-1 to BACKLOG |
| **Self-evolution** | Friction pattern in METRICS, or operator directive | Prompt-evolution PR with probation + auto-revert |
| **Halt** | `.autopilot/HALT` exists | Status-only write to STATE, exit |

The loop also **autonomously maintains plan and spec docs**: every Active/Upkeep pass it reads the docs listed in STATE `plan_docs:` and `spec_docs:`, detects drift from the code, fixes small drift in-line, and auto-promotes large drift to an active task. Infinite improvement = backlog auto-refill (Brainstorm) + backlog auto-drain (Active) + doc self-sync + prompt self-evolution, all bounded by budgets and guardrails.

## Install into a project

```bash
# From the target project repo root:
cp -r /path/to/autopilot-template .autopilot

# Make scripts executable (Unix)
chmod +x .autopilot/hooks/protect.sh .autopilot/runners/runner.sh .autopilot/관리자.sh

# Pick a project wrapper (customize test/audit/doctor for your stack):
mv .autopilot/project.example.sh  .autopilot/project.sh      # Unix
# OR
mv .autopilot/project.example.ps1 .autopilot/project.ps1     # Windows

# Install the protect hook (prevents self-evolution touching IMMUTABLE blocks):
ln -sf "$(pwd)/.autopilot/hooks/protect.sh" .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

# Gitignore the runtime-only files:
cat .autopilot/.gitignore >> .gitignore

# Configure STATE.md — set `root:`, `base:`, list plan/spec docs if any.
$EDITOR .autopilot/STATE.md

# Seed BACKLOG.md with at least one P1 task so the first iteration has work.
$EDITOR .autopilot/BACKLOG.md
```

## Run the loop — pick one of two modes

The same `PROMPT.md` drives both modes. Pick whichever fits your workflow; you can switch any time.

### Mode A — Claude Code `/loop` (in-session, dynamic pacing) ★ recommended for Claude Code users

One interactive Claude Code session keeps running; Claude self-paces via `ScheduleWakeup` using the `NEXT_DELAY` value the prompt writes each turn. No external scheduler, no API key plumbing, no cron.

```
# In an interactive Claude Code session at the repo root:
/loop .autopilot/PROMPT.md
```

If your `/loop` build doesn't accept a file argument, run `/loop` and paste the contents of `.autopilot/PROMPT.md` when prompted. Stop with `touch .autopilot/HALT` (graceful) or Ctrl+C (hard).

> **Dynamic-mode gotcha (observed 2026-04-18, recurred same day):** In Mode A the agent self-paces by **calling the `ScheduleWakeup` tool** — writing "rescheduled" in prose does not schedule anything. If the tool call is skipped, the loop silently halts. The template enforces this via dual-channel evidence: exit-contract Step 5 (real tool call), Step 6 (2-line `LAST_RESCHEDULE` sentinel where line 2 = the tool's raw response, forgery-resistant), `[IMMUTABLE:wake-reschedule]` invariants, and boot Step 5 watchdog that flags 1-line or stale sentinels as high-severity FINDINGS. If the loop appears stuck, run `bash .autopilot/project.sh check-reschedule` (or `.\project.ps1 check-reschedule`) — exit 2 = not-rescheduled, re-anchor with `/loop`.

**Use this when:** you're already using Claude Code interactively, you want zero infra, you want Claude's dynamic pacing (60s–3600s) honored.

### Mode B — Infinite prompt queue (external runner, any AI)

An external runner re-submits `PROMPT.md` forever on a schedule. Works with Claude Code headless, Codex, OpenAI API, Gemini, local models — anything with a CLI. This is the "put the same prompt in a queue and loop" variant.

Pick one runner:

| Runner | File | When to use |
|--------|------|-------------|
| Windows PowerShell | `runners/runner.ps1` | Local Windows, honors `NEXT_DELAY` |
| Unix shell | `runners/runner.sh` | Local Linux/macOS, honors `NEXT_DELAY` |
| Unix cron | `runners/cron.example` | Fixed cadence, `NEXT_DELAY` ignored |
| GitHub Actions | `runners/github-actions.yml` | Cloud cron, survives machine reboots |
| Windows Task Scheduler | `runners/task-scheduler.xml` | Local Windows, runs at login/boot |

```powershell
# PowerShell example:
$env:AUTOPILOT_AI = 'claude'     # or 'codex', or 'custom' with AUTOPILOT_CMD
.\.autopilot\runners\runner.ps1
```

```bash
# Unix example:
AUTOPILOT_AI=claude bash .autopilot/runners/runner.sh
```

```bash
# GitHub Actions:
cp .autopilot/runners/github-actions.yml .github/workflows/autopilot.yml
# add ANTHROPIC_API_KEY (or your AI provider's secret) to repo secrets, enable Actions
```

```powershell
# Windows Task Scheduler:
# edit paths in runners\task-scheduler.xml first
schtasks /Create /XML .autopilot\runners\task-scheduler.xml /TN "Autopilot"
```

**Use this when:** you want it running unattended (overnight, on a server, in CI), you're not using Claude Code interactively, or you want a non-Claude model to drive the loop.

### Mode A vs Mode B at a glance

| | Mode A (`/loop`) | Mode B (runner queue) |
|---|---|---|
| Requires interactive session | yes | no |
| AI model | Claude Code only | any CLI/API |
| Pacing | dynamic (`ScheduleWakeup`) | `NEXT_DELAY` on local runners, fixed on cron/CI |
| Infra | none | runner + (for CI) API key |
| Stops when you close the terminal | yes | no (for CI/Task Scheduler) |
| Cost model | Claude Code session | per-call API billing |

## Operator controls

| Control | What it does |
|---------|--------------|
| `touch .autopilot/HALT` | Loop exits at next boot. |
| `rm .autopilot/HALT` | Loop resumes at next runner wake-up. |
| Add `OPERATOR: halt` to STATE.md | Same as HALT. |
| Add `OPERATOR: focus on X` to STATE.md | Forces X as active task next iteration. |
| Add `OPERATOR: halt evolution` to STATE.md | Disables self-evolution; other modes keep running. |
| Add `OPERATOR: allow evolution <reason>` to STATE.md | Permits a single evolution commit. |
| Add `OPERATOR: require human review` to STATE.md | Disables auto-merge; PRs wait for a human. |
| Add paths to `protected_paths:` in STATE.md | PRs touching these paths refuse to auto-merge. |
| Edit BACKLOG.md directly | Items you add are picked up on the next boot. |
| `bash .autopilot/project.sh stop` / `.ps1 stop` | Polite stop (touches HALT). |
| Delete `.autopilot/LOCK` | Only if a crashed instance left stale lock >90 min old (the loop does this itself). |

## Files at a glance

```
.autopilot/
├── PROMPT.md               # the only prompt; submitted verbatim every wake-up
├── STATE.md                # live state, ≤60 lines (edit freely between iters)
├── BACKLOG.md              # prioritized task list
├── HISTORY.md              # last 10 iterations (3 bullets each)
├── HISTORY-ARCHIVE.md      # older entries
├── PITFALLS.md             # append-only landmine registry
├── BRAINSTORM.md           # Brainstorm mode log
├── FINDINGS.md             # Idle-upkeep pass results
├── EVOLUTION.md            # self-mod audit log + probation state
├── METRICS.jsonl           # one JSON line per iteration
├── LOCK                    # concurrency guard (runtime-only, gitignored)
├── HALT                    # kill switch (runtime-only, gitignored; create to halt)
├── NEXT_DELAY              # integer 60–3600; runner reads for next sleep
├── .gitignore              # ignores runtime-only files
├── hooks/
│   ├── protect.sh          # pre-commit: IMMUTABLE section guard
│   └── protect.ps1         # same, PowerShell
├── qa-evidence/
│   └── SCHEMA.md           # truthfulness artifact schema for UI/E2E tasks
├── project.example.sh      # rename to project.sh; customize doctor/test/audit
├── project.example.ps1     # rename to project.ps1; customize
└── runners/
    ├── runner.sh           # Unix infinite runner
    ├── runner.ps1          # Windows infinite runner
    ├── github-actions.yml  # CI cron runner
    ├── cron.example        # Linux crontab example
    └── task-scheduler.xml  # Windows Task Scheduler definition
```

## First-iteration smoke test

```bash
# Dry-run: run the prompt once and stop (create HALT after).
touch .autopilot/HALT
AUTOPILOT_AI=claude bash .autopilot/runners/runner.sh
# Runner exits immediately because HALT is present.
rm .autopilot/HALT

# Real first iter (seed a trivial P1 first so it has work):
echo '- [P1] smoke-test — append one line to .autopilot/smoketest.log' >> .autopilot/BACKLOG.md
AUTOPILOT_AI=claude bash .autopilot/runners/runner.sh
# Let it run one iteration, Ctrl+C during sleep to stop.
```

Expect: a branch `dev/smoke-test-<today>` pushed, a PR opened, HISTORY.md with one entry, METRICS.jsonl with one line, NEXT_DELAY written.

## Migration from relay-app-mvp loop

The `prototypes/relay-app-mvp/AUTONOMOUS-DEV-PROMPT-COPY.txt` is a relay-specific ancestor. This template generalizes it:

| relay-app-mvp concept | autopilot equivalent |
|-----------------------|----------------------|
| AUTONOMOUS-DEV-PROMPT-COPY.txt | `.autopilot/PROMPT.md` |
| DEV-PROGRESS.md / DEV-PROGRESS-ARCHIVE.md | `STATE.md` + `HISTORY.md` + `HISTORY-ARCHIVE.md` |
| KNOWN-PITFALLS.md | `PITFALLS.md` |
| IDLE-FINDINGS.md | `FINDINGS.md` |
| BRAINSTORM-LOG.md | `BRAINSTORM.md` |
| LOOP-METRICS.jsonl | `METRICS.jsonl` |
| audits/qa-evidence-*.json | `qa-evidence/<slug>-<ts>.json` |
| G1–G9 guardrails | `[IMMUTABLE:*]` blocks in PROMPT.md |
| loop.lock | `.autopilot/LOCK` |
| Step 5f post-merge cleanup | Active mode workflow step 8 |
| dev/prompt-evolution-* | same convention |
| `project-specific bash here` | `.autopilot/project.sh` / `project.ps1` |
