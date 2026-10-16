@echo off
setlocal
cd /d "%~dp0"
title WalkingLab
echo [1/3] Pulling latest changes...
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
echo [2/3] Checking actual boxing animations...
if not exist "assets\boxing" mkdir "assets\boxing"
set "NEED_IMPORT=0"
for %%A in (Fight_Idle Lead_Jab Cross_Punch Hook_Punch Right_Hook) do (
    if not exist "assets\boxing\%%A.glb" (
        echo Fetching %%A...
        curl.exe --fail --location --silent --show-error --output "assets\boxing\%%A.glb" "https://raw.githubusercontent.com/MisterYI/deevid-mixamo-assets/main/anim/%%A.glb"
        if errorlevel 1 (
            echo Warning: Could not download %%A.
            if exist "assets\boxing\%%A.glb" del "assets\boxing\%%A.glb"
        ) else (
            set "NEED_IMPORT=1"
        )
    )
)
if "%NEED_IMPORT%"=="1" (
    echo Importing newly fetched 3D motion clips...
    "%GODOT%" --headless --editor --path . --import --quit
    if errorlevel 1 (
        echo WARNING: Asset import reported errors. Trying to launch anyway.
    )
)
echo [3/3] Launching game...
"%GODOT%" --path .
if errorlevel 1 (
    echo Game exited with an error.
    pause
    exit /b 1
)
