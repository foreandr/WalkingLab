# Source-authored assets: CC0 Quaternius UAL2 and CC0 AETHER-02 rig with a real Backflip clip.
# https://quaternius.com/packs/universalanimationlibrary2.html
# https://github.com/RamonLinares/atlas-09/blob/main/ASSET-LICENSE.md
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$folder = Join-Path $root 'assets\showcase'
New-Item -ItemType Directory -Force -Path $folder | Out-Null
$assets = @(
  @{ Name='UAL2_Standard.glb'; Url='https://raw.githubusercontent.com/Barbatos6669/elderforge/main/assets/animations/universal_animation_library_2/UAL2_Standard.glb'; MinBytes=3000000 },
  @{ Name='aether-02.glb'; Url='https://raw.githubusercontent.com/RamonLinares/atlas-09/main/public/models/aether-02.glb'; MinBytes=2500000 }
)
foreach ($asset in $assets) {
  $dest = Join-Path $folder $asset.Name
  if ((Test-Path -LiteralPath $dest) -and (Get-Item -LiteralPath $dest).Length -ge $asset.MinBytes) { continue }
  $temp = "$dest.part"
  try {
    Write-Host ('[SHOWCASE] Downloading licensed authored asset ' + $asset.Name)
    Invoke-WebRequest -UseBasicParsing -Uri $asset.Url -OutFile $temp -TimeoutSec 90
    if ((Get-Item -LiteralPath $temp).Length -lt $asset.MinBytes) { throw ('Truncated ' + $asset.Name) }
    Move-Item -LiteralPath $temp -Destination $dest -Force
    Set-Content -LiteralPath (Join-Path $folder '.new_import') -Value 'new animation import' -Encoding ascii
    Write-Host ('[SHOWCASE] Ready to import ' + $asset.Name)
  } catch {
    Write-Warning ('[SHOWCASE] Could not download ' + $asset.Name + ': ' + $_.Exception.Message)
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force }
  }
}
