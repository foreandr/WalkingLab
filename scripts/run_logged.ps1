param(
    [Parameter(Mandatory=$true)][string]$GodotPath,
    [string[]]$GameArgs = @(),
    [string[]]$GameArgs = @()
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
    # RUN.bat quotes the raw argument string so PowerShell cannot mistake
# --flight-benchmark for a PowerShell named parameter.
if ($GameArgs.Count -eq 1 -and $GameArgs[0].Contains(" ")) {
    $GameArgs = @($GameArgs[0] -split '\\s+' | Where-Object { $_ -ne "" })
}
if ($GameArgs.Count -gt 0) {
        ("Godot user args: " + ($GameArgs -join " ")) | Out-File -FilePath $logFile -Append -Encoding utf8
        & $GodotPath --path (Get-Location).Path -- @GameArgs *>> $logFile
    } else {
        & $GodotPath --path (Get-Location).Path -- @GameArgs *>> $logFile
    }
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
# The launcher exits immediately, so the logger owns the post-run upload.
# Upload the log even when the game reports a nonzero exit code.
try {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path (Get-Location) "scripts\\sync_logs.ps1") | Out-File -FilePath $logFile -Append -Encoding utf8
} catch {
    ("Log synchronization failed: " + $_) | Out-File -FilePath $logFile -Append -Encoding utf8
}
exit $status
