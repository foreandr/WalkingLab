@echo off
setlocal
cd /d "%~dp0"
title WalkingLab - Restart and Push Logs
echo.
echo [1/3] Closing the current WalkingLab game...
powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\close_old_instances.ps1"
if errorlevel 1 (
    echo Failed to close WalkingLab safely. Logs were not synchronized.
    pause
    exit /b 1
)
rem The detached logger may still be finishing its post-exit log upload.
rem sync_logs.ps1 serializes Git operations with the same mutex.
echo [2/3] Pushing latest logs and synchronizing code...
powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\sync_logs.ps1"
if errorlevel 1 (
    echo Log synchronization failed. The new game was not launched.
    echo Logs remain locally; resolve the Git error and retry.
    pause
    exit /b 1
)
echo [3/3] Starting a fresh WalkingLab run...
call "%~dp0RUN.bat" %*
exit /b %ERRORLEVEL%
