@echo off
REM ============================================================
REM StockFlow — build the release APK and install it on the phone
REM Checks: adb present, phone plugged in and authorized.
REM Replaces the app in place (data kept). Launches it at the end.
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

echo [1/4] Checking for a connected phone...
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

echo [2/4] Building release APK (takes a few minutes)...
call flutter build apk --release || (echo [ERROR] Build failed. & pause & exit /b 1)

echo [3/4] Installing on the phone...
"%ADB%" install -r "build\app\outputs\flutter-apk\app-release.apk" || (echo [ERROR] Install failed. & pause & exit /b 1)

echo [4/4] Launching StockFlow...
"%ADB%" shell am force-stop com.stockflow.stockflow >nul 2>nul
"%ADB%" shell monkey -p com.stockflow.stockflow -c android.intent.category.LAUNCHER 1 >nul 2>nul

echo.
echo DONE - the latest StockFlow is on the phone and running.
pause
