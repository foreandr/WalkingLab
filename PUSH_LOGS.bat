@echo off
setlocal
cd /d "%~dp0"
title WalkingLab - Close and Push Logs
echo.
echo [1/2] Closing the current WalkingLab game...
powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\close_old_instances.ps1"
if errorlevel 1 (
    echo Failed to close WalkingLab safely. Logs were not synchronized.
    pause
    exit /b 1
)
echo [2/2] Pushing latest logs and synchronizing code...
powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\sync_logs.ps1"
if errorlevel 1 (
    echo Log synchronization failed. Logs remain locally.
    pause
    exit /b 1
)
echo.
echo Logs synchronized. WalkingLab will NOT restart.
exit /b 0
