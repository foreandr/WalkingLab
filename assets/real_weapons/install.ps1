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

# Two fully self-contained, physically-based, game-ready sword scenes.
# These are higher-detail models than the old small Kenney prototypes.
Save-Asset 'https://cdn.3dassets.dev/assets/38880/v1/model.glb' (Join-Path $target 'arming_sword.glb')
Save-Asset 'https://cdn.3dassets.dev/assets/38881/v1/model.glb' (Join-Path $target 'knightly_sword.glb')

# The same CC0 medieval pack has individually published axes and daggers.
# Resolve their versioned URLs through the official pack manifest, not guesses.
function Find-Record($Node, [string]$Term, [int]$Depth = 0) {
    if ($null -eq $Node -or $Depth -gt 12 -or $Node -is [string] -or $Node -is [ValueType]) { return $null }
    if ($Node -is [System.Array]) {
        foreach ($item in $Node) {
            $result = Find-Record $item $Term ($Depth + 1)
            if ($null -ne $result) { return $result }
        }
        return $null
    }
    if ($Node -is [pscustomobject]) {
        $title = ''
        foreach ($key in @('name','title','display_name','slug')) {
            $prop = $Node.PSObject.Properties[$key]
            if ($null -ne $prop -and $null -ne $prop.Value) { $title += ' ' + [string]$prop.Value }
        }
        if ($title -match [regex]::Escape($Term)) { return $Node }
        foreach ($prop in $Node.PSObject.Properties) {
            $result = Find-Record $prop.Value $Term ($Depth + 1)
            if ($null -ne $result) { return $result }
        }
    }
    return $null
}

function Find-Model-URL($Node, [int]$Depth = 0) {
    if ($null -eq $Node -or $Depth -gt 8) { return $null }
    if ($Node -is [string]) {
        if ($Node -match '^https://cdn\.3dassets\.dev/assets/[0-9]+/v[0-9]+/model\.glb(\?.*)?$') {
            return $Node
        }
        return $null
    }
    if ($Node -is [System.Array]) {
        foreach ($item in $Node) {
            $result = Find-Model-URL $item ($Depth + 1)
            if ($null -ne $result) { return $result }
        }
    } elseif ($Node -is [pscustomobject]) {
        foreach ($prop in $Node.PSObject.Properties) {
            $result = Find-Model-URL $prop.Value ($Depth + 1)
            if ($null -ne $result) { return $result }
        }
    }
    return $null
}

$extras = @(
    @{ Name='Greatsword'; File='greatsword.glb' },
    @{ Name='Bearded Axe'; File='bearded_axe.glb' },
    @{ Name='Rondel Dagger'; File='rondel_dagger.glb' }
)
$missingExtras = @($extras | Where-Object { -not (Test-Path (Join-Path $target $_.File)) })
if ($missingExtras.Count -gt 0) {
    try {
        $manifest = Invoke-RestMethod -Uri 'https://3dassets.dev/api/v1/packs/swords-shields-and-melee-arms' -TimeoutSec 8
        foreach ($entry in $missingExtras) {
            $record = Find-Record $manifest $entry.Name
            if ($null -eq $record) {
                Write-Warning "Model not present in pack manifest: $($entry.Name)"
                continue
            }
            $url = Find-Model-URL $record
            if ($null -eq $url) {
                foreach ($key in @('id','asset_id')) {
                    $id = $record.PSObject.Properties[$key]
                    if ($null -ne $id -and [string]$id.Value -match '^[0-9]+$') {
                        $url = "https://cdn.3dassets.dev/assets/$($id.Value)/v1/model.glb"
                        break
                    }
                }
            }
            if ($null -eq $url) {
                Write-Warning "Pack manifest has no GLB URL for $($entry.Name)"
                continue
            }
            Save-Asset $url (Join-Path $target $entry.File)
        }
    } catch {
        Write-Warning "Optional full medieval pack unavailable; using corrected Kenney backups: $_"
    }
}

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
