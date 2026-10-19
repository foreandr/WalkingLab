$ErrorActionPreference = "Stop"
$dir = Join-Path (Get-Location) "assets\external_grass"
$target = Join-Path $dir "Grass001_Color.jpg"
if (Test-Path -LiteralPath $target) { exit 0 }
New-Item -ItemType Directory -Path $dir -Force | Out-Null
$archive = Join-Path $dir "Grass001_1K-JPG.zip"
$downloadUrl = "https://ambientcg.com/get?file=Grass001_1K-JPG.zip"
try {
    Invoke-WebRequest -UseBasicParsing -Uri $downloadUrl -OutFile $archive -TimeoutSec 90
    $unpack = Join-Path $dir "_grass_unpack"
    Expand-Archive -LiteralPath $archive -DestinationPath $unpack -Force
    $candidate = Get-ChildItem -LiteralPath $unpack -Recurse -Filter "*Color.jpg" -File | Select-Object -First 1
    if ($null -eq $candidate) { throw "No colour map in the CC0 grass archive" }
    Copy-Item -LiteralPath $candidate.FullName -Destination $target -Force
    Set-Content -LiteralPath (Join-Path $dir ".new_import") -Value "1"
    Write-Host "[GRASS_TEXTURE] Installed ambientCG Grass001 CC0 texture"
} catch {
    Write-Warning ("Grass texture unavailable, using existing textured-ground fallback: " + $_.Exception.Message)
} finally {
    Remove-Item -LiteralPath $archive -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Join-Path $dir "_grass_unpack") -Recurse -Force -ErrorAction SilentlyContinue
}
