$ErrorActionPreference = "Continue"

$workspace = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$stopFile = Join-Path $workspace "results\stop_auto_loop.flag"
$pidFile = Join-Path $workspace "results\auto_loop.pid"

New-Item -ItemType Directory -Force -Path (Join-Path $workspace "results") | Out-Null
New-Item -ItemType File -Force -Path $stopFile | Out-Null

if (Test-Path $pidFile) {
    $existingPid = Get-Content $pidFile -ErrorAction SilentlyContinue
    if ($existingPid -and (Get-Process -Id $existingPid -ErrorAction SilentlyContinue)) {
        Stop-Process -Id $existingPid -Force
        Write-Host "Stopped 5-minute experiment loop. PID=$existingPid"
    }
    Remove-Item $pidFile -Force
}
else {
    Write-Host "Stop flag written. No PID file was found."
}
