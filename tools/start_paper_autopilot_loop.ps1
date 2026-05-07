param(
    [int]$IntervalSeconds = 300
)

$ErrorActionPreference = "Stop"

$workspace = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$loopScript = Join-Path $workspace "tools\paper_autopilot_loop.ps1"
$resultsDir = Join-Path $workspace "results"
$pidFile = Join-Path $resultsDir "paper_autopilot_loop.pid"
$stopFile = Join-Path $resultsDir "stop_paper_autopilot_loop.flag"

New-Item -ItemType Directory -Force -Path $resultsDir | Out-Null
if (Test-Path $stopFile) {
    Remove-Item $stopFile -Force
}

if (Test-Path $pidFile) {
    $existingPid = Get-Content $pidFile -ErrorAction SilentlyContinue
    if ($existingPid -and (Get-Process -Id $existingPid -ErrorAction SilentlyContinue)) {
        Write-Host "Paper autopilot loop is already running. PID=$existingPid"
        exit 0
    }
}

$process = Start-Process powershell.exe -ArgumentList @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", "`"$loopScript`"",
    "-IntervalSeconds", "$IntervalSeconds"
) -WindowStyle Hidden -PassThru

Set-Content -Path $pidFile -Value $process.Id -Encoding utf8
Write-Host "Started paper autopilot loop. PID=$($process.Id), interval_seconds=$IntervalSeconds"
