$ErrorActionPreference = "Continue"

$workspace = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$resultsDir = Join-Path $workspace "results"
$pidFile = Join-Path $resultsDir "paper_autopilot_loop.pid"
$stopFile = Join-Path $resultsDir "stop_paper_autopilot_loop.flag"

New-Item -ItemType Directory -Force -Path $resultsDir | Out-Null
New-Item -ItemType File -Force -Path $stopFile | Out-Null

if (Test-Path $pidFile) {
    $existingPid = Get-Content $pidFile -ErrorAction SilentlyContinue
    if ($existingPid -and (Get-Process -Id $existingPid -ErrorAction SilentlyContinue)) {
        Stop-Process -Id $existingPid -Force
        Write-Host "Stopped paper autopilot loop. PID=$existingPid"
    }
    Remove-Item $pidFile -Force
}
else {
    Write-Host "Stop flag written. No PID file was found."
}
