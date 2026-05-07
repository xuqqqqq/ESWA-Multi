$ErrorActionPreference = "Continue"

$workspace = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$pidFile = Join-Path $workspace "results\research_loop.pid"
$stopFile = Join-Path $workspace "results\stop_research_loop.flag"

New-Item -ItemType Directory -Force -Path (Join-Path $workspace "results") | Out-Null
New-Item -ItemType File -Force -Path $stopFile | Out-Null

if (Test-Path $pidFile) {
    $existingPid = Get-Content $pidFile -ErrorAction SilentlyContinue
    if ($existingPid -and (Get-Process -Id $existingPid -ErrorAction SilentlyContinue)) {
        Stop-Process -Id $existingPid -Force
        Write-Host "Stopped 5-minute research loop. PID=$existingPid"
    } else {
        Write-Host "No running research loop found for PID=$existingPid"
    }
    Remove-Item $pidFile -Force
} else {
    Write-Host "No research loop PID file found."
}
