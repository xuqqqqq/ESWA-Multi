$ErrorActionPreference = "Stop"

$workspace = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$loopScript = Join-Path $workspace "tools\experiment_loop.ps1"
$pidFile = Join-Path $workspace "results\auto_loop.pid"
$stopFile = Join-Path $workspace "results\stop_auto_loop.flag"

New-Item -ItemType Directory -Force -Path (Join-Path $workspace "results") | Out-Null
if (Test-Path $stopFile) {
    Remove-Item $stopFile -Force
}

if (Test-Path $pidFile) {
    $existingPid = Get-Content $pidFile -ErrorAction SilentlyContinue
    if ($existingPid -and (Get-Process -Id $existingPid -ErrorAction SilentlyContinue)) {
        Write-Host "5-minute experiment loop is already running. PID=$existingPid"
        exit 0
    }
}

$process = Start-Process powershell -ArgumentList @(
    "-NoProfile",
    "-ExecutionPolicy", "BYPASS",
    "-File", "`"$loopScript`""
) -WindowStyle Hidden -PassThru

Set-Content -Path $pidFile -Value $process.Id
Write-Host "Started 5-minute experiment loop. PID=$($process.Id)"
