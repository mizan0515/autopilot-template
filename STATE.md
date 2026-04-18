# .autopilot/STATE.md — live state, keep ≤60 lines. Loaded every iteration.

root: .
base: main
iteration: 0
status: initialized
active_task: null
# active_task schema when set:
#   slug: <kebab-case>
#   plan: [bullet, bullet]
#   started_iter: N
#   branch: dev/<slug>-<YYYYMMDD>

# Uncomment and fill in for your project:
# plan_docs:
#   - PLAN.md
#   - ROADMAP.md
# spec_docs:
#   - SPEC.md
# reference_docs:
#   - docs/capability-matrix.md

open_questions: []

# Auto-merge policy (full-autonomy default). The loop auto-squash-merges its own
# PRs via `gh pr merge --squash --delete-branch [--auto]` at the end of Active mode.
# Refuses auto-merge if the PR diff touches any of these paths:
protected_paths: []
#   - .github/workflows/
#   - .autopilot/hooks/
#   - infra/

# ─────────────────────────────────────────────────────────────────────
# 관리자 안내 (한국어):
# 이 파일은 루프가 관리합니다. 관리자는 이 파일을 직접 수정할 필요가 없어요.
# 루프가 판단이 필요하면 "🙋 결정 필요: ..." 제목의 한국어 PR을 엽니다.
# 관리자는 그 PR만 머지하세요. HALT, OPERATOR: 줄, 어떤 파일도 직접 만지지 않습니다.
# (HALT는 비상 정지 전용 — 대시보드 "정지" 버튼으로만 생성)
# ─────────────────────────────────────────────────────────────────────

# awaiting-decision 상태일 때 루프가 채우는 필드 (관리자는 건드리지 마세요):
# decision_slug: <slug>
# decision_pr:   <url>
# decision_branch: dev/decision-<slug>-<ts>

# (레거시) OPERATOR overrides — 이제는 결정 PR 머지를 통해 루프가 스스로 기록합니다.
# 관리자가 직접 추가하지 마세요. 레거시 호환을 위해 읽기 경로만 남아 있습니다.
