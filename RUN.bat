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
rem Add any Mixamo FBX with Idle in its filename (excluding transitional clips).
rem Keeps downloaded FBXs on the user's machine; do not redistribute.
for %%F in ("%USERPROFILE%\Downloads\*Idle*.fbx" "%USERPROFILE%\Downloads\*idle*.fbx" "%USERPROFILE%\Desktop\*Idle*.fbx" "%USERPROFILE%\Desktop\*idle*.fbx") do (
    if exist "%%~fF" (
        echo(%%~nxF | findstr /i /c:" to " /c:"transition" >nul
        if errorlevel 1 (
            if not exist "assets\custom_idle\%%~nxF" (
                echo Found Mixamo idle: %%~nxF
                copy /Y "%%~fF" "assets\custom_idle\%%~nxF" >nul
                set "IDLE_NEW=1"
            )
        )
    )
)
if "%IDLE_NEW%"=="1" (
    echo Importing native Mixamo idle animations...
    "%GODOT%" --headless --editor --path . --import
    if errorlevel 1 echo Warning: one or more FBX imports failed.
)
echo [2/2] Launching game...
"%GODOT%" --path .
if errorlevel 1 (
 echo Game exited with an error.
 pause
 exit /b 1
)
