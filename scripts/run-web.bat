@echo off
REM ============================================================
REM StockFlow — preview the app WITHOUT a phone (runs in Chrome)
REM Double-click this file, or run it from a terminal.
REM Hot reload: press r in this window. Quit: press q.
REM ============================================================
cd /d "%~dp0.."

where flutter >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Flutter is not on PATH. Install Flutter or open a terminal where "flutter" works.
  pause & exit /b 1
)

echo [1/2] Getting packages...
call flutter pub get || (pause & exit /b 1)

echo [2/2] Launching in Chrome (this is also how the website behaves)...
call flutter run -d chrome
pause
