param(
    [ValidateSet("smoke", "quick", "paper", "full")]
    [string]$Mode = "quick"
)

$ErrorActionPreference = "Stop"

$workspace = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$loopScript = Join-Path $workspace "tools\research_experiment_loop.ps1"
$pidFile = Join-Path $workspace "results\research_loop.pid"
$stopFile = Join-Path $workspace "results\stop_research_loop.flag"

New-Item -ItemType Directory -Force -Path (Join-Path $workspace "results") | Out-Null
if (Test-Path $stopFile) {
    Remove-Item $stopFile -Force
}

if (Test-Path $pidFile) {
    $existingPid = Get-Content $pidFile -ErrorAction SilentlyContinue
    if ($existingPid -and (Get-Process -Id $existingPid -ErrorAction SilentlyContinue)) {
        Write-Host "5-minute research loop is already running. PID=$existingPid"
        exit 0
    }
}

$process = Start-Process powershell -ArgumentList @(
    "-NoProfile",
    "-ExecutionPolicy", "BYPASS",
    "-File", "`"$loopScript`"",
    "-Mode", $Mode
) -WindowStyle Hidden -PassThru

Set-Content -Path $pidFile -Value $process.Id -Encoding utf8
Write-Host "Started 5-minute research loop. PID=$($process.Id), Mode=$Mode"
