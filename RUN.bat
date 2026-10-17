@echo off
setlocal
cd /d "%~dp0"
title WalkingLab
rem Release previous game/log handles before Git touches logs.
powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\close_old_instances.ps1"
echo [1/2] Synchronizing prior logs and latest game code...
powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\sync_logs.ps1"
if errorlevel 1 (
 echo Git synchronization needs attention. No files were discarded.
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
rem Copy idle FBXs using simple CMD commands; avoid pipes inside parenthesized loops.
for %%F in ("%USERPROFILE%\Downloads\*Idle*.fbx" "%USERPROFILE%\Desktop\*Idle*.fbx") do (
    if exist "%%~fF" (
        if not exist "assets\custom_idle\%%~nxF" (
            copy /Y "%%~fF" "assets\custom_idle\%%~nxF" >nul
            set "IDLE_NEW=1"
        )
    )
)
rem The original supplied airborne flight animation.
for %%F in ("%USERPROFILE%\Downloads\Flying (1).fbx" "%USERPROFILE%\Desktop\Flying (1).fbx") do (
    if exist "%%~fF" (
        if not exist "assets\custom_idle\Flying (1).fbx" (
            echo Found flight animation: %%~nxF
            copy /Y "%%~fF" "assets\custom_idle\Flying (1).fbx" >nul
            set "IDLE_NEW=1"
        )
    )
)
rem Import the user's original jumping and landing Mixamo animations.
for %%D in ("%USERPROFILE%\Downloads" "%USERPROFILE%\Desktop" "%~dp0") do (
    for %%F in ("Jumping Up.fbx" "Landing.fbx" "Hard Landing.fbx") do (
        if exist "%%~D\%%~F" (
            if not exist "assets\custom_idle\%%~F" (
                copy /Y "%%~D\%%~F" "assets\custom_idle\%%~F" >nul
                set "IDLE_NEW=1"
                echo Found animation: %%~F
            )
        )
    )
)
rem One supplied unskinned jab clip; copy locally before Godot imports.
for %%D in ("%USERPROFILE%\Downloads" "%USERPROFILE%\Desktop" "%~dp0") do (
    if exist "%%~D\Punching.fbx" (
        if not exist "assets\custom_idle\Punching.fbx" (
            echo Found left jab: %%~D\Punching.fbx
            copy /Y "%%~D\Punching.fbx" "assets\custom_idle\Punching.fbx" >nul
            set "IDLE_NEW=1"
        )
    )
)
rem Import newly supplied combat animation FBXs from Downloads, Desktop or game folder.
for %%D in ("%USERPROFILE%\Downloads" "%USERPROFILE%\Desktop" "%~dp0") do (
    for %%F in ("Punching (1).fbx" "Punching(2).fbx" "Reaction.fbx" "Reaction (1).fbx" "Medium Hit To Head.fbx" "Medium Hit To Head (1).fbx" "Light Hit To Head.fbx" "Light Hit To Head (1).fbx" "Big Kidney Hit.fbx" "Big Kidney Hit (1).fbx" "Dying.fbx" "Dying (1).fbx" "Dying (2).fbx" "Dying (3).fbx" "Stunned.fbx") do (
        if exist "%%~D\%%~F" (
            if not exist "assets\custom_idle\%%~F" (
                copy /Y "%%~D\%%~F" "assets\custom_idle\%%~F" >nul
                set "IDLE_NEW=1"
                echo Found combat animation: %%~F
            )
        )
    )
)
rem Install the original Kenney particle texture used by the MIT Godot fire scene.
rem No procedural fire meshes/textures. Asset stays cached locally.
if not exist "assets\external_vfx" mkdir "assets\external_vfx"
if not exist "assets\external_vfx\fire_01.png" (
    echo Downloading original Kenney fire effect texture...
    powershell -NoProfile -Command "try { Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/marinho/godot-visual-effects/main/addons/kenney_particle_pack/fire_01.png' -OutFile 'assets\external_vfx\fire_01.png' -ErrorAction Stop; exit 0 } catch { Write-Warning $_; exit 1 }"
    if exist "assets\external_vfx\fire_01.png" set "IDLE_NEW=1"
)
rem Install original third-party weapon models AND kit-specific original textures.
rem Correctly imported Kenney weapons require their own Textures\colormap.png.
rem Detailed sword assets come from the CC0 Swords, Shields and Melee Arms pack.
powershell -NoProfile -ExecutionPolicy Bypass -File "assets\real_weapons\install.ps1"
if errorlevel 1 echo Warning: a weapon installer step failed; existing assets remain usable.
if exist "assets\real_weapons\.downloaded_now" (
    del /Q "assets\real_weapons\.downloaded_now"
    set "IDLE_NEW=1"
)
if "%IDLE_NEW%"=="1" (
    echo Importing downloaded 3D assets and Mixamo idle animations...
    "%GODOT%" --headless --editor --path . --import
    if errorlevel 1 echo Warning: one or more FBX imports failed.
)
echo [2/2] Launching game with timestamped logging...
powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\close_old_instances.ps1"
rem Start logger detached and return to PowerShell immediately.
rem Closing the game window triggers log upload; no batch job remains to confirm.
start "" /min powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Minimized -File "scripts\run_logged.ps1" -GodotPath "%GODOT%"
exit /b 0
