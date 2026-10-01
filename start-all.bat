@echo off
setlocal enabledelayedexpansion
title School Project - Full Stack Runner

echo ========================================================
echo   School Management System - Full Stack Startup
echo ========================================================
echo.

set "ROOT_DIR=%~dp0"
set "WORKER_DIR=%ROOT_DIR%cloudflare\worker"

echo [1/2] Starting Cloudflare Worker Backend (Port 8787)...
start "School Backend (Cloudflare Worker)" cmd.exe /k "cd /d "%WORKER_DIR%" && echo Starting Wrangler dev server on http://localhost:8787... && npx wrangler dev"

echo Waiting for Worker backend to be ready on http://127.0.0.1:8787...
set /a ATTEMPTS=0
:WAIT_LOOP
set /a ATTEMPTS+=1
timeout /t 2 /nobreak >nul
powershell -NoProfile -Command "try { $r = [System.Net.WebRequest]::Create('http://127.0.0.1:8787/docs').GetResponse(); exit 0 } catch { exit 1 }"
if !ERRORLEVEL! EQU 0 (
    goto BACKEND_READY
)
if !ATTEMPTS! GEQ 25 (
    echo [Notice] Backend is taking a while to initialize. Proceeding to frontend...
    goto START_FRONTEND
)
echo   Waiting for backend (%ATTEMPTS%/25)...
goto WAIT_LOOP

:BACKEND_READY
echo.
echo ========================================================
echo   [SUCCESS] Backend is live at http://127.0.0.1:8787
echo ========================================================
echo.

:START_FRONTEND
echo [2/2] Starting Flutter Web Frontend (Chrome)...
echo   Targeting API: http://localhost:8787/api
echo.
cd /d "%ROOT_DIR%"
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8787/api

endlocal
