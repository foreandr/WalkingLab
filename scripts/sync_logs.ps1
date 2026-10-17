$ErrorActionPreference = "Stop"
function Invoke-Git([string[]]$GitArgs) {
    & git.exe @GitArgs
    if ($LASTEXITCODE -ne 0) { throw ("git.exe " + ($GitArgs -join " ") + " exited " + $LASTEXITCODE) }
}
try {
    # A forcibly interrupted Git operation can leave the index lock behind.
    # Never remove a lock while any Git executable is running.
    $lock = Join-Path (Get-Location) ".git\\index.lock"
    if (Test-Path -LiteralPath $lock) {
        $deadline = (Get-Date).AddSeconds(8)
        while ((Test-Path -LiteralPath $lock) -and (Get-Date) -lt $deadline) {
            Start-Sleep -Milliseconds 500
        }
        if (Test-Path -LiteralPath $lock) {
            $gitRunning = @(Get-CimInstance Win32_Process -Filter "Name = 'git.exe' OR Name = 'git-remote-https.exe'" -ErrorAction Stop)
            if ($gitRunning.Count -gt 0) {
                throw "Git index is locked while a Git process is running. Close the other process and retry."
            }
            $age = ((Get-Date) - (Get-Item -LiteralPath $lock).LastWriteTime).TotalSeconds
            if ($age -lt 8) { throw "Git lock is new; refusing to delete it. Retry shortly." }
            Remove-Item -LiteralPath $lock -Force -ErrorAction Stop
            Write-Host "Cleared abandoned Git index lock."
        }
    }
    Invoke-Git @("stash","push","-m","WalkingLab automatic backup before sync")
    if (Test-Path "logs") {
        Invoke-Git @("add","--","logs")
        & git.exe diff --cached --quiet -- logs
        if ($LASTEXITCODE -eq 1) {
            Invoke-Git @("commit","-m","WalkingLab player debug run logs","--","logs")
        } elseif ($LASTEXITCODE -ne 0) {
            throw "Unable to inspect staged logs"
        }
    }
    for ($attempt=1; $attempt -le 3; $attempt++) {
        Invoke-Git @("fetch","origin","main")
        Invoke-Git @("rebase","origin/main")
        $ahead = (& git.exe rev-list --count origin/main..HEAD).Trim()
        if ($LASTEXITCODE -ne 0) { throw "Unable to inspect local commits" }
        if ([int]$ahead -eq 0) { exit 0 }
        & git.exe push origin HEAD:main
        if ($LASTEXITCODE -eq 0) { exit 0 }
        Write-Host "Push raced another update. Retrying..."
    }
    throw "Log push failed three times; logs are retained locally."
} catch {
    Write-Host ("SYNC ERROR: " + $_.Exception.Message)
    exit 1
}
