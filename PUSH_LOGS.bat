@echo off
setlocal
cd /d "%~dp0"
title WalkingLab - Push Logs
echo.
echo WalkingLab: uploading finished logs to GitHub...
echo Game will NOT be launched or closed.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\sync_logs.ps1"
set "SYNC_EXIT=%ERRORLEVEL%"
echo.
if not "%SYNC_EXIT%"=="0" (
    echo Log upload FAILED. Logs remain on this computer.
    echo Review the SYNC ERROR above and retry after resolving it.
    pause
    exit /b %SYNC_EXIT%
)
echo Logs synchronized successfully with origin/main.
echo.
pause
exit /b 0
