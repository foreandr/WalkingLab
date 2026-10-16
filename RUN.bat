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
for %%F in ("Idle.fbx" "Idle (1).fbx" "Idle(1).fbx" "Action Idle To Fight Idle.fbx" "Fight Idle To Standing Idle.fbx") do (
    if not exist "assets\custom_idle\%%~F" (
        for %%D in ("%USERPROFILE%\Downloads" "%USERPROFILE%\Desktop" "%~dp0") do (
            if exist "%%~D\%%~F" (
                echo Importing %%~F from %%~D
                copy /Y "%%~D\%%~F" "assets\custom_idle\%%~F" >nul
                set "NEED_IMPORT=1"
            )
        )
    )
)
if not exist "assets\custom_idle\Idle (1).fbx" if exist "assets\custom_idle\Idle(1).fbx" (
    copy /Y "assets\custom_idle\Idle(1).fbx" "assets\custom_idle\Idle (1).fbx" >nul
    set "NEED_IMPORT=1"
)
if "%NEED_IMPORT%"=="1" (
    echo Importing idle and transition FBX motions...
    "%GODOT%" --headless --editor --path . --import
    if errorlevel 1 echo Warning: FBX import failed; check source compatibility.
)
echo [2/2] Launching game...
"%GODOT%" --path .
if errorlevel 1 (
    echo Game exited with an error.
    pause
    exit /b 1
)
