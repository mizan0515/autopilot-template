@echo off
REM 관리자 대시보드 열기 — 더블클릭 한 번으로 상태 갱신 + HTML 오픈
REM PowerShell 스크립트를 호출해 OPERATOR-LIVE.ko.html 을 새로 렌더하고 기본 브라우저로 띄웁니다.
chcp 65001 > nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0관리자.ps1" 대시보드
if errorlevel 1 (
  echo.
  echo [!] 대시보드 열기에 실패했어요. 위 에러 메시지를 개발자에게 보여주세요.
  pause
)
