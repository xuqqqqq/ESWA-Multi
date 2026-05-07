$ErrorActionPreference = "Continue"

$workspace = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$resultsDir = Join-Path $workspace "results"
$pidFile = Join-Path $resultsDir "convergence_paperlite.pid"

if (Test-Path $pidFile) {
    $existingPid = Get-Content $pidFile -ErrorAction SilentlyContinue
    if ($existingPid -and (Get-Process -Id $existingPid -ErrorAction SilentlyContinue)) {
        Stop-Process -Id $existingPid -Force
        Write-Host "Stopped convergence paper-lite run. PID=$existingPid"
    }
    Remove-Item $pidFile -Force
}
else {
    Write-Host "No convergence paper-lite PID file was found."
}
