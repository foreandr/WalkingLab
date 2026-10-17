$ErrorActionPreference = "Stop"
$projectRoot = [IO.Path]::GetFullPath((Get-Location).Path).TrimEnd('\')
$running = @(Get-CimInstance Win32_Process | Where-Object {
    $_.Name -match '^Godot.*\.exe$' -and
    $_.CommandLine -and
    $_.CommandLine.Contains($projectRoot) -and
    $_.CommandLine -match '(?i)(--path|--editor|--import)'
})
foreach ($process in $running) {
    Write-Host ("Closing previous WalkingLab process " + $process.ProcessId)
    Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
}
if ($running.Count -gt 0) { Start-Sleep -Milliseconds 900 }
