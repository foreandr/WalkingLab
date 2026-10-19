param(
    [Parameter(Mandatory=$true)][string]$GodotPath,
    [string[]]$GameArgs = @()
)
$ErrorActionPreference = "Stop"
$logDir = Join-Path (Get-Location) "logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$stamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$prefix = "run_" + $stamp
$maxPartBytes = 4MB
$part = 1
$logFile = Join-Path $logDir ("{0}_part{1:D3}.log" -f $prefix,$part)
$writer = $null
$bytesWritten = 0L
$encoder = [System.Text.UTF8Encoding]::new($false)
function Open-Part {
    if ($null -ne $script:writer) { $script:writer.Flush(); $script:writer.Dispose() }
    $script:logFile = Join-Path $logDir ("{0}_part{1:D3}.log" -f $prefix,$script:part)
    $script:writer = [System.IO.StreamWriter]::new($script:logFile,$false,$encoder)
    $script:writer.AutoFlush = $false
    $script:bytesWritten = 0L
}
function Write-Log([string]$Line) {
    if ($null -eq $Line) { $Line = "" }
    # Split exceptionally long lines as well, so no part exceeds the cap.
    $offset = 0
    do {
        $take = [Math]::Min(16384, [Math]::Max(0,$Line.Length-$offset))
        $piece = if ($take -gt 0) { $Line.Substring($offset,$take) } else { "" }
        $encoded = $encoder.GetByteCount($piece) + 2
        if ($script:bytesWritten + $encoded -gt $maxPartBytes) {
            $script:part++
            Open-Part
        }
        $script:writer.WriteLine($piece)
        $script:bytesWritten += $encoded
        $offset += $take
    } while ($offset -lt $Line.Length)
}
$status = 1
try {
    Open-Part
    Write-Log ("WalkingLab run " + (Get-Date -Format "o"))
    Write-Log ("Godot executable: " + $GodotPath)
    if ($GameArgs.Count -eq 1 -and $GameArgs[0].Contains(" ")) {
        $GameArgs = @($GameArgs[0] -split '\s+' | Where-Object { $_ -ne "" })
    }
    if ($GameArgs.Count -gt 0) { Write-Log ("Godot user args: " + ($GameArgs -join " ")) }
    # Stream merged stdout/stderr directly into rotating logs: no buffering until exit.
    & $GodotPath --path (Get-Location).Path -- @GameArgs 2>&1 | ForEach-Object {
        Write-Log ($_.ToString())
    }
    $status = $LASTEXITCODE
} catch {
    if ($null -ne $script:writer) { Write-Log ("LOGGER ERROR: " + $_.ToString()) }
    $status = 1
} finally {
    if ($null -ne $script:writer) {
        Write-Log ("Run ended " + (Get-Date -Format "o") + " exit=" + $status)
        $script:writer.Flush()
        $script:writer.Dispose()
        $script:writer = $null
    }
}
Write-Host ("Saved " + $part + " rotated log part(s) for " + $prefix)
if ($status -ne 0) {
    Write-Host "Game exited with an error. Last 35 lines:"
    Get-Content -LiteralPath $logFile -Tail 35
}
try {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path (Get-Location) "scripts\sync_logs.ps1")
} catch {
    Write-Host ("Log synchronization failed: " + $_)
}
exit $status
