@echo off
REM ============================================================
REM StockFlow — run on a USB-connected phone (debug, hot reload)
REM Checks: adb present, phone plugged in, USB debugging allowed.
REM Hot reload: press r in this window. Quit: press q.
REM ============================================================
cd /d "%~dp0.."
setlocal

set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
if not exist "%ADB%" set "ADB=adb"

where flutter >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Flutter is not on PATH.
  pause & exit /b 1
)

echo [1/3] Checking for a connected phone...
"%ADB%" start-server >nul 2>nul
"%ADB%" devices | findstr /r "device$" >nul
if errorlevel 1 (
  "%ADB%" devices | findstr /r "unauthorized$" >nul
  if not errorlevel 1 (
    echo [ACTION NEEDED] Phone found but blocked - tap "Allow USB debugging" on the phone, then run this again.
  ) else (
    echo [ERROR] No phone detected. Plug it in via USB and enable USB debugging.
  )
  pause & exit /b 1
)
echo        Phone connected.

echo [2/3] Getting packages...
call flutter pub get || (pause & exit /b 1)

echo [3/3] Launching on the phone (debug build, hot reload with r)...
call flutter run
pause
