@echo off
rem Autopilot admin dashboard launcher.
rem Double-click to refresh status + open the Korean HTML dashboard.
rem
rem IMPORTANT: this file MUST be saved in CP949 (Korean ANSI), NOT UTF-8.
rem Korean Windows cmd.exe reads batch files as CP949 by default. A UTF-8
rem BOM gets interpreted as a command (shows up as garbled chars like
rem  癤?echo ), and UTF-8 bytes for  관리자.ps1  get decoded as  뙣?덉뼱?? .
rem If you edit this file, save as  ANSI  or  EUC-KR / CP949 , never UTF-8.

cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File ".\관리자.ps1" dashboard

if errorlevel 1 (
  echo.
  echo [!] 대시보드 열기에 실패했어요. 위 에러 메시지를 개발자에게 보여주세요.
  echo [!] Dashboard launch failed. Please show the error above to a developer.
  pause
)