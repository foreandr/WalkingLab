# Installs the CC0 Quaternius Universal Animation Library 2 (Standard, in-place).
# Publisher: https://quaternius.com/packs/universalanimationlibrary2.html
# Mirror contains original standard GLB and the source CC0 license file.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$folder = Join-Path $root 'assets\showcase'
New-Item -ItemType Directory -Force -Path $folder | Out-Null
$dest = Join-Path $folder 'UAL2_Standard.glb'
if ((Test-Path -LiteralPath $dest) -and (Get-Item -LiteralPath $dest).Length -gt 3000000) { exit 0 }
$temp = "$dest.part"
$url = 'https://raw.githubusercontent.com/Barbatos6669/elderforge/main/assets/animations/universal_animation_library_2/UAL2_Standard.glb'
try {
    Write-Host '[SHOWCASE] Downloading authored Quaternius UAL2 CC0 animation pack...'
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $temp -TimeoutSec 90
    if ((Get-Item -LiteralPath $temp).Length -lt 3000000) { throw 'UAL2_Standard.glb is unexpectedly small' }
    Move-Item -LiteralPath $temp -Destination $dest -Force
    Set-Content -LiteralPath (Join-Path $folder '.new_import') -Value 'new animation import' -Encoding ascii
    Write-Host '[SHOWCASE] UAL2 saved; Godot will import it before the demo starts.'
} catch {
    Write-Warning ('[SHOWCASE] UAL2 download failed; using already committed UAL1 clips. ' + $_.Exception.Message)
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force }
}
