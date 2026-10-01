@echo off
title Stop School Project Services
echo Stopping any running backend (workerd) and Flutter processes...
taskkill /F /IM workerd.exe 2>nul
echo Done. Services stopped.
timeout /t 2 >nul
