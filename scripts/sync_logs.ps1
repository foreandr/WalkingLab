$ErrorActionPreference = "Stop"
function Git([string[]]$Arguments) {
    & git @Arguments
    if ($LASTEXITCODE -ne 0) { throw ("git " + ($Arguments -join " ") + " failed (" + $LASTEXITCODE + ")") }
}
try {
    # Preserve tracked local file edits, without touching local animation assets.
    Git @("stash","push","-m","WalkingLab automatic backup before sync")
    if (Test-Path "logs") {
        Git @("add","--","logs")
        & git diff --cached --quiet -- logs
        if ($LASTEXITCODE -eq 1) {
            Git @("commit","-m","WalkingLab player debug run logs","--","logs")
        } elseif ($LASTEXITCODE -ne 0) {
            throw "Cannot inspect staged logs"
        }
    }
    # Log commits can make local main diverge. Rebase before every push.
    for ($attempt=1; $attempt -le 3; $attempt++) {
        Git @("fetch","origin","main")
        Git @("rebase","origin/main")
        & git rev-list --count origin/main..HEAD
        if ($LASTEXITCODE -ne 0) { throw "Cannot inspect unpushed commits" }
        $ahead = (& git rev-list --count origin/main..HEAD).Trim()
        if ([int]$ahead -eq 0) { exit 0 }
        & git push origin HEAD:main
        if ($LASTEXITCODE -eq 0) { exit 0 }
        Write-Host "Remote updated concurrently; retrying sync ($attempt of 3)..."
    }
    throw "Could not push logs after three attempts; saved locally for next run."
} catch {
    Write-Host ("SYNC ERROR: " + $_.Exception.Message)
    exit 1
}
