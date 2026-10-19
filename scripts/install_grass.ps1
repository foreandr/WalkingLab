param()
$ErrorActionPreference = "Stop"
$targetDir = Join-Path (Get-Location) "assets\external_grass"
$target = Join-Path $targetDir "kenney_grass.glb"
New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
if (Test-Path -LiteralPath $target) {
    $size = (Get-Item -LiteralPath $target).Length
    if ($size -gt 1000) { exit 0 }
}
$uri = "https://api.flockbay.com/bootstrap/library/models/v1/604b7da5b2f36ecc41cb75434c2295fb32b530ce9824ef9d9e9db969b94423a0/grass.glb"
$temp = "$target.partial"
try {
    Write-Host "[ASSET] Downloading Kenney Nature Kit grass (CC0)..."
    Invoke-WebRequest -UseBasicParsing -Uri $uri -OutFile $temp -TimeoutSec 40
    if ((Get-Item -LiteralPath $temp).Length -lt 1000) { throw "Downloaded grass model is unexpectedly small" }
    Move-Item -LiteralPath $temp -Destination $target -Force
    Set-Content -LiteralPath (Join-Path $targetDir ".new_import") -Value "1"
    Write-Host "[ASSET] Installed sourced grass model: $target"
} catch {
    Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
    Write-Warning ("Unable to download CC0 grass: " + $_.Exception.Message)
    exit 1
}
