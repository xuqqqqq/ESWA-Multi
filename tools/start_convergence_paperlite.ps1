$ErrorActionPreference = "Stop"

$workspace = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$script = Join-Path $workspace "tools\run_convergence_paperlite.ps1"
$resultsDir = Join-Path $workspace "results"
$pidFile = Join-Path $resultsDir "convergence_paperlite.pid"
New-Item -ItemType Directory -Force -Path $resultsDir | Out-Null

if (Test-Path $pidFile) {
    $existingPid = Get-Content $pidFile -ErrorAction SilentlyContinue
    if ($existingPid -and (Get-Process -Id $existingPid -ErrorAction SilentlyContinue)) {
        Write-Host "Convergence paper-lite run is already active. PID=$existingPid"
        exit 0
    }
}

$process = Start-Process powershell.exe -ArgumentList @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", "`"$script`""
) -WindowStyle Hidden -PassThru

Set-Content -Path $pidFile -Value $process.Id -Encoding utf8
Write-Host "Started convergence paper-lite run. PID=$($process.Id)"
