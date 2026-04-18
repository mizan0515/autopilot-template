#!/usr/bin/env bash
# 오토파일럿 관리자 도구 (한국어, Unix/macOS/Linux)
# 비개발자도 사용할 수 있도록 만든 단일 메뉴 스크립트.
#
# 사용법:
#   bash .autopilot/관리자.sh           → 메뉴 표시
#   bash .autopilot/관리자.sh 상태      → 상태만 1회 출력
#   bash .autopilot/관리자.sh 정지      → HALT 파일 생성
#   bash .autopilot/관리자.sh 재개      → HALT 파일 삭제

set -u
ap=".autopilot"
verb="${1:-메뉴}"

줄() { printf '─%.0s' {1..60}; echo; }

상태읽기() {
  줄
  echo "🤖 오토파일럿 상태 점검"
  줄

  if [ -f "$ap/HALT" ]; then
    echo "⛔ 상태: 정지됨 (HALT 파일이 있음)"
    echo "   재개하려면: bash .autopilot/관리자.sh 재개"
    줄; return
  fi

  if [ -f "$ap/STATE.md" ]; then
    grep -E '^status:|^iteration:' "$ap/STATE.md" | head -5 | sed 's/^/📋 /'
  else
    echo "⚠️  STATE.md 없음 — 아직 한 번도 안 돌았거나 설치가 잘못됨"
  fi

  if [ ! -f "$ap/NEXT_DELAY" ]; then
    echo "ℹ️  아직 첫 반복이 끝나지 않았어요. 조금 기다려 주세요."
    줄; return
  fi
  if [ ! -f "$ap/LAST_RESCHEDULE" ]; then
    echo "🚨 멈춤 의심: 다음 깨어남 기록(LAST_RESCHEDULE)이 없어요."
    echo "   → 클로드 코드 채팅에 다시 입력하세요:  /loop .autopilot/PROMPT.md"
    줄; return
  fi

  line1=$(sed -n '1p' "$ap/LAST_RESCHEDULE")
  line2=$(sed -n '2p' "$ap/LAST_RESCHEDULE")

  case "$line1" in
    halted*|external-runner:*)
      echo "✅ 정상 (자동 깨어남 면제 상태: $line1)"; 줄; return ;;
  esac

  if [ -z "$line2" ] || [ "$line2" = "$line1" ]; then
    echo "🚨 멈춤 의심: 깨어남 증거가 부실해요 (1줄 기록 = 가짜 가능성)."
    echo "   → 클로드 코드 채팅에 다시 입력하세요:  /loop .autopilot/PROMPT.md"
    줄; return
  fi

  delay=$(tr -cd '0-9' < "$ap/NEXT_DELAY")
  ts_epoch=$(date -d "$line1" +%s 2>/dev/null \
    || python3 -c "import sys,datetime;print(int(datetime.datetime.fromisoformat(sys.argv[1].strip().replace('Z','+00:00')).timestamp()))" "$line1" 2>/dev/null \
    || echo 0)
  now_epoch=$(date +%s)
  age=$(( now_epoch - ts_epoch ))
  slack=600
  분지난=$(( age / 60 ))
  예정분=$(( delay / 60 ))

  if [ "$ts_epoch" -eq 0 ]; then
    echo "⚠️  타임스탬프 해석 실패: $line1"; 줄; return
  fi
  if [ "$age" -gt $(( delay + slack )) ]; then
    echo "🚨 멈춤 확인: ${분지난}분 전에 깨어났어야 했는데 안 깨어났어요."
    echo "   (예정 간격 ${예정분}분 + 여유 10분 초과)"
    echo "   → 클로드 코드 채팅에 다시 입력하세요:  /loop .autopilot/PROMPT.md"
  else
    남은=$(( (delay + slack - age) / 60 ))
    echo "✅ 정상 동작 중. 마지막 깨어남: ${분지난}분 전, 다음 점검까지 약 ${남은}분 여유"
  fi

  if [ -f "$ap/HISTORY.md" ]; then
    줄
    echo "📜 최근 작업 (HISTORY.md 끝 부분):"
    tail -12 "$ap/HISTORY.md" | sed 's/^/   /'
  fi
  줄
}

정지하기() {
  touch "$ap/HALT"
  echo "⛔ HALT 파일을 만들었어요. 다음 반복에서 루프가 정지합니다."
}

재개하기() {
  if [ -f "$ap/HALT" ]; then
    rm -f "$ap/HALT"
    echo "✅ HALT 파일을 지웠어요. 이제 클로드 코드에서 /loop를 다시 시작하세요:"
    echo "   /loop .autopilot/PROMPT.md"
  else
    echo "ℹ️  HALT 파일이 원래 없었어요. 멈춰있다면 클로드 코드에서 /loop를 다시 입력하세요."
  fi
}

시작안내() {
  줄
  echo "🚀 오토파일럿 시작 방법"
  줄
  echo "클로드 코드(터미널 앱)를 열고 다음을 입력하세요:"
  echo ""
  echo "   /loop .autopilot/PROMPT.md"
  echo ""
  echo "그게 끝이에요. 이후로는 알아서 작업하고, 작업이 끝나면 자동으로"
  echo "다시 시작합니다. PR 만들기·머지·브랜치 정리도 모두 자동입니다."
  echo ""
  echo "정지: 이 스크립트로 [2] 정지  또는  bash .autopilot/관리자.sh 정지"
  줄
}

메뉴() {
  while true; do
    상태읽기
    echo ""
    echo "무엇을 할까요?"
    echo "  [1] 시작 방법 보기"
    echo "  [2] 정지 (HALT 만들기)"
    echo "  [3] 재개 (HALT 지우기)"
    echo "  [4] 상태 새로고침"
    echo "  [0] 종료"
    read -r -p "번호 입력: " sel
    case "$sel" in
      1) 시작안내; read -r -p "엔터로 메뉴로" _ ;;
      2) 정지하기; read -r -p "엔터" _ ;;
      3) 재개하기; read -r -p "엔터" _ ;;
      4) continue ;;
      0) return ;;
      *) echo "0~4 중에서 골라주세요."; sleep 1 ;;
    esac
  done
}

case "$verb" in
  메뉴|menu)       메뉴 ;;
  상태|status)     상태읽기 ;;
  정지|stop)       정지하기 ;;
  재개|resume)     재개하기 ;;
  시작|start)      시작안내 ;;
  *) echo "모르는 명령: $verb"; echo "사용 가능: 메뉴 / 상태 / 정지 / 재개 / 시작" ;;
esac
