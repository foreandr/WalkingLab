# Downloads original external CC0 weapon assets. No generated meshes.
# Called by RUN.bat; binary models are kept locally and ignored by Git.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$target = $PSScriptRoot
$kenney = Join-Path (Split-Path $target -Parent) 'kenney_weapons'
$changed = $false
New-Item -ItemType Directory -Force -Path $target | Out-Null

function Save-Asset([string]$Url, [string]$Destination) {
    if (Test-Path $Destination) { return }
    $parent = Split-Path $Destination -Parent
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    $temp = "$Destination.partial"
    try {
        Write-Host "Downloading original game asset: $(Split-Path $Destination -Leaf)"
        Invoke-WebRequest -Uri $Url -UseBasicParsing -OutFile $temp -TimeoutSec 12
        $bytes = [System.IO.File]::ReadAllBytes($temp)
        $extension = [System.IO.Path]::GetExtension($Destination).ToLowerInvariant()
        if ($extension -eq '.glb') {
            if ($bytes.Length -lt 20 -or [System.Text.Encoding]::ASCII.GetString($bytes,0,4) -ne 'glTF') {
                throw "Server returned something other than a GLB: $Url"
            }
        } elseif ($extension -eq '.png') {
            if ($bytes.Length -lt 16 -or $bytes[0] -ne 137 -or $bytes[1] -ne 80 -or $bytes[2] -ne 78 -or $bytes[3] -ne 71) {
                throw "Server returned something other than a PNG: $Url"
            }
        }
        Move-Item -Force $temp $Destination
        $script:changed = $true
    } catch {
        Write-Warning "Could not install $Destination : $_"
        Remove-Item -Force -ErrorAction SilentlyContinue $temp
    }
}

# The old experimental 3dassets.dev CDN is not reliably resolvable.
# Use the verified original Kenney source below instead of repeatedly
# attempting unreachable hosts at every game launch.
# Original Kenney models are fallback props. THEIR TEXTURES ARE NOT EMBEDDED.
# Preserve kit-relative 'Textures/colormap.png' separately for every kit:
# mini-arena and survival use different images with the same filename.
$kenneyBase = 'https://raw.githubusercontent.com/shorepine/kenney/main/3d'
foreach ($part in @(
    @{ Kit='mini-arena'; Model='weapon-sword.glb' },
    @{ Kit='survival'; Model='tool-axe.glb' },
    @{ Kit='weapon'; Model='knife_sharp.glb' }
)) {
    $folder = Join-Path $kenney $part.Kit
    Save-Asset "$kenneyBase/$($part.Kit)/$($part.Model)" (Join-Path $folder $part.Model)
    if ($part.Kit -ne 'weapon') {
        Save-Asset "$kenneyBase/$($part.Kit)/Textures/colormap.png" (Join-Path (Join-Path $folder 'Textures') 'colormap.png')
    }
}

if ($changed) {
    Set-Content -Path (Join-Path $target '.downloaded_now') -Value '1'
    Write-Host 'New weapon models or original textures installed; Godot reimport required.'
}
