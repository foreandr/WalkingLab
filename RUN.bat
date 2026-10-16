@echo off
setlocal
cd /d "%~dp0"
title WalkingLab
echo [1/2] Pulling latest changes...
git pull --ff-only origin main
if errorlevel 1 (
 echo Git pull failed.
 pause
 exit /b 1
)
set "GODOT=C:\Users\forea\Documents\Codex\2026-10-16\okay\work\godot\Godot_v4.7.2-stable_win64_console.exe"
if not exist "%GODOT%" (
 echo Godot not found at %GODOT%
 pause
 exit /b 1
)
if not exist "assets\custom_idle" mkdir "assets\custom_idle"
set "IDLE_NEW=0"
if not exist "assets\custom_idle\Idle.fbx" (
    if exist "%USERPROFILE%\Downloads\Idle.fbx" (
        copy /Y "%USERPROFILE%\Downloads\Idle.fbx" "assets\custom_idle\Idle.fbx" >nul
        set "IDLE_NEW=1"
    )
)
if "%IDLE_NEW%"=="1" (
    echo Importing real standing idle animation...
    "%GODOT%" --headless --editor --path . --import
    if errorlevel 1 echo Warning: Idle.fbx import failed.
)
echo [2/2] Launching game...
"%GODOT%" --path .
if errorlevel 1 (
 echo Game exited with an error.
 pause
 exit /b 1
)
