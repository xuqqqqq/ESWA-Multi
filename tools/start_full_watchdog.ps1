$ErrorActionPreference = "Stop"

$workspace = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$watchScript = Join-Path $workspace "tools\watch_full_completion.ps1"
$pidFile = Join-Path $workspace "results\full_watchdog.pid"

New-Item -ItemType Directory -Force -Path (Join-Path $workspace "results") | Out-Null

if (Test-Path $pidFile) {
    $existingPid = Get-Content $pidFile -ErrorAction SilentlyContinue
    if ($existingPid -and (Get-Process -Id $existingPid -ErrorAction SilentlyContinue)) {
        Write-Host "Full watchdog is already running. PID=$existingPid"
        exit 0
    }
}

$process = Start-Process powershell -ArgumentList @(
    "-NoProfile",
    "-ExecutionPolicy", "BYPASS",
    "-File", "`"$watchScript`""
) -WindowStyle Hidden -PassThru

Set-Content -Path $pidFile -Value $process.Id -Encoding utf8
Write-Host "Started full watchdog. PID=$($process.Id)"
