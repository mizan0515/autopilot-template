@echo off
rem Autopilot admin dashboard launcher.
rem Double-click to refresh status + open the Korean HTML dashboard.
rem
rem Note: this file is saved as UTF-8 WITH BOM so cmd.exe parses the
rem Korean filename "관리자.ps1" correctly on Korean Windows (CP949 default).
rem If you see garbled text errors, check that the BOM (EF BB BF) is still
rem present at the very start of this file.

cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File ".\관리자.ps1" dashboard

if errorlevel 1 (
  echo.
  echo [!] 대시보드 열기에 실패했어요. 위 에러 메시지를 개발자에게 보여주세요.
  echo [!] Dashboard launch failed. Please show the error above to a developer.
  pause
)
