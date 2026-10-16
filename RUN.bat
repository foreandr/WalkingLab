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
    echo Godot not found: %GODOT%
    pause
    exit /b 1
)
if not exist "assets\custom_idle" mkdir "assets\custom_idle"
set "NEED_IMPORT=0"
if not exist "assets\custom_idle\Idle.fbx" (
    for %%I in ("%USERPROFILE%\Downloads\Idle.fbx" "%USERPROFILE%\Desktop\Idle.fbx" "%~dp0Idle.fbx") do (
        if exist "%%~I" (
            echo Found your Idle.fbx: %%~I
            copy /Y "%%~I" "assets\custom_idle\Idle.fbx" >nul
            set "NEED_IMPORT=1"
        )
    )
)
if "%NEED_IMPORT%"=="1" (
    echo Importing your custom idle animation...
    "%GODOT%" --headless --editor --path . --import
    if errorlevel 1 echo Warning: custom idle import failed. Using safe standing pose.
)
echo [2/2] Launching game...
"%GODOT%" --path .
if errorlevel 1 (
    echo Game exited with an error.
    pause
    exit /b 1
)
