$ErrorActionPreference = "Stop"
$folder = Join-Path (Get-Location) "assets\stadium"
$target = Join-Path $folder "bleachers.glb"
New-Item -ItemType Directory -Force -Path $folder | Out-Null
if ((Test-Path $target) -and (Get-Item $target).Length -gt 10000) { exit 0 }
$uri = "https://www.innerscene.com/api/library/bleachers-three-row-sports-equipment-7221c461/download"
try {
 Invoke-WebRequest -Uri $uri -OutFile $target -UseBasicParsing -TimeoutSec 90
 if ((Get-Item $target).Length -lt 10000) { throw "Stand model download was incomplete" }
 Set-Content (Join-Path $folder ".new_import") "1"
 Write-Host "[STADIUM] Downloaded authored CC0 three-row bleachers."
} catch {
 Remove-Item $target -ErrorAction SilentlyContinue
 Write-Warning ("Unable to install authored stadium seating: " + $_.Exception.Message)
}
