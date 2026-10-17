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
rem Import the user's sole ground jump animation, exactly as supplied.
for %%F in ("%USERPROFILE%\Downloads\Jump(2).fbx" "%USERPROFILE%\Desktop\Jump(2).fbx") do (
    if exist "%%~fF" (
        if not exist "assets\custom_idle\Jump(2).fbx" (
            echo Found selected jump animation: %%~nxF
            copy /Y "%%~fF" "assets\custom_idle\Jump(2).fbx" >nul
            set "IDLE_NEW=1"
        )
    )
)
rem Check the selected jump FBX without parenthesized echo blocks.
if not exist "assets\custom_idle\Jump(2).fbx" goto :missing_jump_asset
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
echo [2/2] Launching game...
"%GODOT%" --path .
if errorlevel 1 (
 echo Game exited with an error.
 pause
 exit /b 1
)

exit /b 0

:missing_jump_asset
echo.
echo [ERROR] Missing required jump animation asset.
echo Save the supplied FBX file to Downloads or Desktop.
echo Filename must match Jump(2).fbx exactly.
echo Then run RUN.bat again.
echo.
pause
exit /b 1
