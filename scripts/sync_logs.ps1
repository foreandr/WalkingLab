$ErrorActionPreference = "Stop"
function Invoke-Git([string[]]$GitArgs) {
    & git.exe @GitArgs
    if ($LASTEXITCODE -ne 0) { throw ("git.exe " + ($GitArgs -join " ") + " exited " + $LASTEXITCODE) }
}
try {
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
