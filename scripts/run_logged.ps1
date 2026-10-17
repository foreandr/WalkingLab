param(
    [Parameter(Mandatory=$true)][string]$GodotPath
)
$ErrorActionPreference = "Stop"
$logDir = Join-Path (Get-Location) "logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$stamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logFile = Join-Path $logDir ("run_" + $stamp + ".log")
Write-Host ("Game running; recording to " + $logFile)
("WalkingLab run " + (Get-Date -Format "o")) | Out-File -FilePath $logFile -Encoding utf8
("Godot executable: " + $GodotPath) | Out-File -FilePath $logFile -Append -Encoding utf8
try {
    & $GodotPath --path . *>> $logFile
    $status = $LASTEXITCODE
} catch {
    $_ | Out-File -FilePath $logFile -Append
    $status = 1
}
("Run ended " + (Get-Date -Format "o") + " exit=" + $status) | Out-File -FilePath $logFile -Append -Encoding utf8
Write-Host ("Saved console trace: " + $logFile)
if ($status -ne 0) {
    Write-Host "Game exited with an error. Last 35 lines:"
    Get-Content $logFile -Tail 35
}
exit $status
