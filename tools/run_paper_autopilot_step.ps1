$ErrorActionPreference = "Stop"

$workspace = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $workspace

$resultsDir = Join-Path $workspace "results"
$logFile = Join-Path $resultsDir "paper_autopilot_loop.log"
New-Item -ItemType Directory -Force -Path $resultsDir | Out-Null

function Write-AutopilotLog {
    param([string]$Message)
    Add-Content -Path $logFile -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message" -Encoding utf8
}

try {
    Write-AutopilotLog "review step started"
    & python "tools\paper_autopilot_review.py" 2>&1 | ForEach-Object {
        Write-AutopilotLog ([string]$_)
        Write-Host $_
    }
    if ($LASTEXITCODE -ne 0) {
        throw "paper_autopilot_review.py exited with code $LASTEXITCODE"
    }
    Write-AutopilotLog "review step complete"
}
catch {
    Write-AutopilotLog "ERROR $($_.Exception.Message)"
    throw
}
