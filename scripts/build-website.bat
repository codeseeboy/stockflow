@echo off
REM ============================================================
REM StockFlow — build the website (admin console) for deployment
REM Output goes to build\web, which Vercel serves as-is.
REM After building: commit build\web and push - Vercel picks it up.
REM ============================================================
cd /d "%~dp0.."

where flutter >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Flutter is not on PATH.
  pause & exit /b 1
)

echo [1/2] Getting packages...
call flutter pub get || (pause & exit /b 1)

echo [2/2] Building the website (release)...
call flutter build web --release || (echo [ERROR] Build failed. & pause & exit /b 1)

echo.
echo DONE - website built to build\web.
echo Next: commit and push so Vercel deploys it:
echo    git add build/web ^&^& git commit -m "chore: rebuild website" ^&^& git push
pause
