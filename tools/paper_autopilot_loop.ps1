param(
    [int]$IntervalSeconds = 300
)

$ErrorActionPreference = "Continue"

$workspace = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$resultsDir = Join-Path $workspace "results"
$stepScript = Join-Path $workspace "tools\run_paper_autopilot_step.ps1"
$pidFile = Join-Path $resultsDir "paper_autopilot_loop.pid"
$stopFile = Join-Path $resultsDir "stop_paper_autopilot_loop.flag"
$logFile = Join-Path $resultsDir "paper_autopilot_loop.log"

New-Item -ItemType Directory -Force -Path $resultsDir | Out-Null
Set-Content -Path $pidFile -Value $PID -Encoding utf8
Add-Content -Path $logFile -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] loop started interval_seconds=$IntervalSeconds pid=$PID" -Encoding utf8

while (-not (Test-Path $stopFile)) {
    try {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $stepScript
    }
    catch {
        Add-Content -Path $logFile -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] loop step error $($_.Exception.Message)" -Encoding utf8
    }

    for ($i = 0; $i -lt $IntervalSeconds; $i++) {
        if (Test-Path $stopFile) {
            break
        }
        Start-Sleep -Seconds 1
    }
}

Add-Content -Path $logFile -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] loop stopped" -Encoding utf8
if (Test-Path $pidFile) {
    Remove-Item $pidFile -Force
}
