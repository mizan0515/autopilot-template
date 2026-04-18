# 오토파일럿 관리자 도구 (한국어)
# 비개발자도 사용할 수 있도록 만든 단일 메뉴 스크립트.
#
# 사용법: 파워셸에서 .\.autopilot\관리자.ps1 실행 (인자 없으면 메뉴, 인자 주면 바로 실행)
#   .\.autopilot\관리자.ps1            → 메뉴 표시
#   .\.autopilot\관리자.ps1 상태       → 상태만 1회 출력
#   .\.autopilot\관리자.ps1 정지       → HALT 파일 생성 (정지)
#   .\.autopilot\관리자.ps1 재개       → HALT 파일 삭제 (재개)

param([string]$Verb = '메뉴')

$ErrorActionPreference = 'Stop'
# $ap = 이 스크립트가 들어있는 폴더 (.autopilot 혹은 autopilot-template 루트)
# 상대경로 '.autopilot' 가정 대신 자기 위치를 기준으로 삼아 어디서 불러도 동작.
$ap = $PSScriptRoot
if (-not $ap) { $ap = (Get-Location).Path }
chcp 65001 > $null  # UTF-8 출력 (한글 깨짐 방지)
$OutputEncoding = [System.Text.Encoding]::UTF8

function 줄 { Write-Host ('─' * 60) }

function 상태읽기 {
  줄
  Write-Host '🤖 오토파일럿 상태 점검' -ForegroundColor Cyan
  줄

  # 1. HALT 파일 (정지 상태인지)
  if (Test-Path (Join-Path $ap 'HALT')) {
    Write-Host '⛔ 상태: 정지됨 (HALT 파일이 있음)' -ForegroundColor Yellow
    Write-Host '   재개하려면: .\.autopilot\관리자.ps1 재개'
    줄
    return
  }

  # 2. STATE.md status 줄 읽기
  $statePath = Join-Path $ap 'STATE.md'
  if (Test-Path $statePath) {
    $statusLine = Select-String -Path $statePath -Pattern '^status:' | Select-Object -First 1
    $iterLine   = Select-String -Path $statePath -Pattern '^iteration:' | Select-Object -First 1
    if ($statusLine) { Write-Host ('📋 ' + $statusLine.Line) }
    if ($iterLine)   { Write-Host ('🔢 ' + $iterLine.Line) }
  } else {
    Write-Host '⚠️  STATE.md 없음 — 아직 한 번도 안 돌았거나 설치가 잘못됨' -ForegroundColor Yellow
  }

  # 3. 재예약(다음 깨어남) 점검
  $nd = Join-Path $ap 'NEXT_DELAY'
  $lr = Join-Path $ap 'LAST_RESCHEDULE'
  if (-not (Test-Path $nd)) {
    Write-Host 'ℹ️  아직 첫 반복이 끝나지 않았어요. 조금 기다려 주세요.'
    줄; return
  }
  if (-not (Test-Path $lr)) {
    Write-Host '🚨 멈춤 의심: 다음 깨어남 기록(LAST_RESCHEDULE)이 없어요.' -ForegroundColor Red
    Write-Host '   → 클로드 코드 채팅에 다시 입력하세요:  /loop .autopilot/PROMPT.md'
    줄; return
  }
  $lines = @(Get-Content $lr)
  $line1 = if ($lines.Count -ge 1) { $lines[0].Trim() } else { '' }
  $line2 = if ($lines.Count -ge 2) { $lines[1].Trim() } else { '' }

  if ($line1 -like 'halted*' -or $line1 -like 'external-runner:*') {
    Write-Host "✅ 정상 (자동 깨어남 면제 상태: $line1)" -ForegroundColor Green
    줄; return
  }
  if ([string]::IsNullOrWhiteSpace($line2) -or $line2 -eq $line1) {
    Write-Host '🚨 멈춤 의심: 깨어남 증거가 부실해요 (1줄 기록 = 가짜 가능성).' -ForegroundColor Red
    Write-Host '   → 클로드 코드 채팅에 다시 입력하세요:  /loop .autopilot/PROMPT.md'
    줄; return
  }

  $delay = [int]((Get-Content $nd -Raw).Trim())
  try { $ts = [DateTimeOffset]::Parse($line1) }
  catch {
    Write-Host "⚠️  타임스탬프 해석 실패: $line1" -ForegroundColor Yellow
    줄; return
  }
  $age = [int]((Get-Date) - $ts.UtcDateTime).TotalSeconds
  $slack = 600
  $분지난 = [math]::Round($age / 60, 1)
  $예정분 = [math]::Round($delay / 60, 1)

  if ($age -gt ($delay + $slack)) {
    Write-Host "🚨 멈춤 확인: $분지난 분 전에 깨어났어야 했는데 안 깨어났어요." -ForegroundColor Red
    Write-Host "   (예정 간격 $예정분 분 + 여유 10분 초과)"
    Write-Host '   → 클로드 코드 채팅에 다시 입력하세요:  /loop .autopilot/PROMPT.md'
  } else {
    $남은분 = [math]::Round(($delay + $slack - $age) / 60, 1)
    Write-Host "✅ 정상 동작 중. 마지막 깨어남: $분지난 분 전, 다음 점검까지 약 $남은분 분 여유" -ForegroundColor Green
  }

  # 4. 최근 히스토리 3줄
  $hist = Join-Path $ap 'HISTORY.md'
  if (Test-Path $hist) {
    줄
    Write-Host '📜 최근 작업 (HISTORY.md 끝 부분):' -ForegroundColor Cyan
    Get-Content $hist -Tail 12 | ForEach-Object { Write-Host "   $_" }
  }
  줄
}

function 정지하기 {
  New-Item -ItemType File -Path (Join-Path $ap 'HALT') -Force | Out-Null
  Write-Host '⛔ HALT 파일을 만들었어요. 다음 반복에서 루프가 정지합니다.' -ForegroundColor Yellow
}

function 재개하기 {
  $h = Join-Path $ap 'HALT'
  if (Test-Path $h) {
    Remove-Item $h
    Write-Host '✅ HALT 파일을 지웠어요. 이제 클로드 코드에서 /loop를 다시 시작하세요:'
    Write-Host '   /loop .autopilot/PROMPT.md' -ForegroundColor Cyan
  } else {
    Write-Host 'ℹ️  HALT 파일이 원래 없었어요. 멈춰있다면 클로드 코드에서 /loop를 다시 입력하세요.'
  }
}

function 시작안내 {
  줄
  Write-Host '🚀 오토파일럿 시작 방법' -ForegroundColor Cyan
  줄
  Write-Host '클로드 코드(터미널 앱)를 열고 다음을 입력하세요:'
  Write-Host ''
  Write-Host '   /loop .autopilot/PROMPT.md' -ForegroundColor Green
  Write-Host ''
  Write-Host '그게 끝이에요. 이후로는 알아서 작업하고, 작업이 끝나면 자동으로'
  Write-Host '다시 시작합니다. PR 만들기·머지·브랜치 정리도 모두 자동입니다.'
  Write-Host ''
  Write-Host '정지: 이 스크립트로 [2] 정지  또는  .\.autopilot\관리자.ps1 정지'
  줄
}

function 메뉴 {
  while ($true) {
    상태읽기
    Write-Host ''
    Write-Host '무엇을 할까요?'
    Write-Host '  [1] 시작 방법 보기'
    Write-Host '  [2] 정지 (HALT 만들기)'
    Write-Host '  [3] 재개 (HALT 지우기)'
    Write-Host '  [4] 상태 새로고침'
    Write-Host '  [5] 웹 대시보드 열기 (HTML)'
    Write-Host '  [0] 종료'
    $sel = Read-Host '번호 입력'
    switch ($sel) {
      '1' { 시작안내; Read-Host '엔터 누르면 메뉴로 돌아갑니다' | Out-Null }
      '2' { 정지하기; Read-Host '엔터' | Out-Null }
      '3' { 재개하기; Read-Host '엔터' | Out-Null }
      '4' { continue }
      '5' { 대시보드 }
      '0' { return }
      default { Write-Host '0~4 중에서 골라주세요.'; Start-Sleep -Seconds 1 }
    }
  }
}

# ────────────────────────────────────────────────────────────────────
# 대시보드: JSON을 생성 → HTML 템플릿에 주입 → 브라우저 열기
# 비개발자 관리자가 한 장의 HTML만 보면 되도록 설계.
# ────────────────────────────────────────────────────────────────────

function 대시보드데이터수집 {
  $now = Get-Date
  $data = [ordered]@{
    updated_at       = $now.ToUniversalTime().ToString('o')
    updated_at_local = $now.ToString('yyyy-MM-dd HH:mm:ss')
    status           = '(STATE.md 없음)'
    mode             = $null
    iteration        = $null
    iteration_hint   = ''
    hero_class       = 'ok'
    action_title     = '✅ 없습니다. 지금은 기다리면 됩니다.'
    action_body_html = '오토파일럿이 알아서 다음 작업을 시작합니다. 아무것도 안 하셔도 됩니다.'
    wake_summary     = '—'
    wake_hint        = ''
    progress_pct     = 0
    history_lines    = @()
  }

  # HALT 우선 판정
  if (Test-Path (Join-Path $ap 'HALT')) {
    $data.hero_class       = 'halted'
    $data.action_title     = '⛔ 정지된 상태입니다. 재개하려면 직접 켜셔야 합니다.'
    $data.action_body_html = 'PowerShell에서 <code>.\.autopilot\관리자.ps1 재개</code> 를 실행한 뒤, 클로드 코드 채팅에 <code>/loop .autopilot/PROMPT.md</code> 를 입력하세요.'
    $data.status           = '정지됨 (HALT)'
  }

  # STATE.md
  $sp = Join-Path $ap 'STATE.md'
  if (Test-Path $sp) {
    $statusLine = Select-String -Path $sp -Pattern '^status:' | Select-Object -First 1
    $iterLine   = Select-String -Path $sp -Pattern '^iteration:' | Select-Object -First 1
    if ($statusLine -and -not (Test-Path (Join-Path $ap 'HALT'))) {
      $data.status = ($statusLine.Line -replace '^status:\s*','').Trim()
    }
    if ($iterLine) {
      $n = ($iterLine.Line -replace '^iteration:\s*','').Trim()
      if ($n -match '^\d+$') {
        $data.iteration = [int]$n
        $data.iteration_hint = "$n 번째 반복 중"
        # 진행도 바: 단순히 (iter mod 20) / 20 * 100 — 심리적 피드백용, 실제 완료율 아님
        $data.progress_pct = [math]::Round(([int]$n % 20) / 20 * 100)
      }
    }
  }

  # 재예약 판정 (HALT 아닐 때만 덮어씀)
  if (-not (Test-Path (Join-Path $ap 'HALT'))) {
    $nd = Join-Path $ap 'NEXT_DELAY'
    $lr = Join-Path $ap 'LAST_RESCHEDULE'
    if (-not (Test-Path $nd)) {
      $data.wake_summary = '⏳ 아직 첫 반복 진행 중'
      $data.wake_hint    = '조금만 기다려 주세요.'
    } elseif (-not (Test-Path $lr)) {
      $data.hero_class       = 'stuck'
      $data.action_title     = '🚨 멈췄습니다. 다시 켜주세요.'
      $data.action_body_html = '클로드 코드 채팅에 <code>/loop .autopilot/PROMPT.md</code> 를 다시 입력해 주세요.'
      $data.wake_summary     = '증거 파일 없음'
      $data.wake_hint        = 'LAST_RESCHEDULE 파일이 없습니다.'
    } else {
      $lines = @(Get-Content $lr)
      $line1 = if ($lines.Count -ge 1) { $lines[0].Trim() } else { '' }
      $line2 = if ($lines.Count -ge 2) { $lines[1].Trim() } else { '' }
      if ($line1 -like 'halted*' -or $line1 -like 'external-runner:*') {
        $data.wake_summary = '면제 상태'; $data.wake_hint = $line1
      } elseif ([string]::IsNullOrWhiteSpace($line2) -or $line2 -eq $line1) {
        $data.hero_class       = 'stuck'
        $data.action_title     = '🚨 증거가 부실합니다 (위조 의심).'
        $data.action_body_html = '깨어남 증거 파일의 두 번째 줄이 비어있어요. 클로드 코드 채팅에 <code>/loop .autopilot/PROMPT.md</code> 를 다시 입력해 주세요.'
        $data.wake_summary     = '1줄 기록 (위조 가능)'
        $data.wake_hint        = '정상 기록은 2줄이어야 합니다.'
      } else {
        try {
          $ts = [DateTimeOffset]::Parse($line1)
          $delayRaw = (Get-Content $nd -Raw).Trim()
          $delay = if ($delayRaw -match '^\d+$') { [int]$delayRaw } else { 900 }
          $age = [int]((Get-Date) - $ts.UtcDateTime).TotalSeconds
          $slack = 600
          $minAgo = [math]::Round($age/60, 1)
          $expectedMin = [math]::Round($delay/60, 1)
          if ($age -gt ($delay + $slack)) {
            $data.hero_class       = 'stuck'
            $data.action_title     = "🚨 $minAgo 분 전에 깨어났어야 하는데 멈춰있어요."
            $data.action_body_html = '클로드 코드 채팅에 <code>/loop .autopilot/PROMPT.md</code> 를 다시 입력해 주세요.'
            $data.wake_summary     = "$minAgo 분 전 (지연 중)"
            $data.wake_hint        = "예정 간격 $expectedMin 분 + 여유 10분을 초과했어요."
          } else {
            $remaining = [math]::Round(($delay + $slack - $age) / 60, 1)
            $data.hero_class       = 'ok'
            $data.action_title     = '✅ 없습니다. 지금은 기다리면 됩니다.'
            $data.action_body_html = "오토파일럿이 약 <b>$remaining 분</b> 안에 다음 작업을 시작합니다. 커밋·PR·머지까지 알아서 합니다."
            $data.wake_summary     = "$minAgo 분 전 (정상)"
            $data.wake_hint        = "다음 점검까지 약 $remaining 분 여유"
          }
        } catch {
          $data.wake_summary = '(타임스탬프 해석 실패)'
          $data.wake_hint    = $line1
        }
      }
    }
  }

  # HISTORY 마지막 12줄 — 반드시 [string[]] 로 강제 (PSObject 유출 시 JSON 5MB 폭증)
  $hist = Join-Path $ap 'HISTORY.md'
  if (Test-Path $hist) {
    $data.history_lines = [string[]](@(Get-Content $hist -Tail 12) | ForEach-Object { [string]$_ })
  }

  return $data
}

function 대시보드 {
  $tpl = Join-Path $ap 'OPERATOR-TEMPLATE.ko.html'
  if (-not (Test-Path $tpl)) {
    Write-Host "⚠️  대시보드 템플릿이 없어요: $tpl" -ForegroundColor Yellow
    Write-Host '   템플릿 저장소(autopilot-template)에서 OPERATOR-TEMPLATE.ko.html 을 복사해 주세요.'
    return
  }
  $data = 대시보드데이터수집
  $json = $data | ConvertTo-Json -Depth 5 -Compress
  # </script> 방지 (JSON 안에 포함될 경우 브라우저 파싱 깨짐)
  $json = $json -replace '</', '<\/'

  # 단순 문자열 치환 (Regex 아님 — JSON 안의 특수문자가 regex로 해석되지 않게)
  $template = Get-Content -Raw $tpl
  $html = $template.Replace('{{JSON_DATA}}', $json)

  $jsonOut = Join-Path $ap 'OPERATOR-LIVE.ko.json'
  $htmlOut = Join-Path $ap 'OPERATOR-LIVE.ko.html'
  $data | ConvertTo-Json -Depth 5 | Out-File -Encoding UTF8 $jsonOut
  $html | Out-File -Encoding UTF8 $htmlOut

  Write-Host "✅ 대시보드 갱신 완료: $htmlOut" -ForegroundColor Green
  Start-Process $htmlOut
}

switch ($Verb) {
  '메뉴'      { 메뉴 }
  '상태'      { 상태읽기 }
  'status'    { 상태읽기 }
  '정지'      { 정지하기 }
  'stop'      { 정지하기 }
  '재개'      { 재개하기 }
  'resume'    { 재개하기 }
  '시작'      { 시작안내 }
  'start'     { 시작안내 }
  '대시보드'  { 대시보드 }
  'dashboard' { 대시보드 }
  default     { Write-Host "모르는 명령: $Verb"; Write-Host '사용 가능: 메뉴 / 상태 / 정지 / 재개 / 시작 / 대시보드' }
}
