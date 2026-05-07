$ErrorActionPreference = "Continue"

$workspace = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$resultsDir = Join-Path $workspace "results"
$phaseFile = Join-Path $resultsDir "research_phase.txt"
$lockFile = Join-Path $resultsDir "research_experiment.lock"
$loopPidFile = Join-Path $resultsDir "research_loop.pid"
$watchPidFile = Join-Path $resultsDir "full_watchdog.pid"
$stopFile = Join-Path $resultsDir "stop_research_loop.flag"
$doneFile = Join-Path $resultsDir "full_experiment_done.txt"
$logFile = Join-Path $resultsDir "research_loop.log"

New-Item -ItemType Directory -Force -Path $resultsDir | Out-Null

function Write-WatchLog {
    param([string]$Message)
    Add-Content -Path $logFile -Value $Message -Encoding utf8
}

Write-WatchLog "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] full watchdog started"

while ($true) {
    Start-Sleep -Seconds 30
    if (Test-Path $doneFile) {
        break
    }
    if (-not (Test-Path $phaseFile)) {
        continue
    }
    if (Test-Path $lockFile) {
        continue
    }

    $lastPhase = (Get-Content $phaseFile -ErrorAction SilentlyContinue | Select-Object -First 1)
    if ($lastPhase -ne "vehicle") {
        continue
    }

    $doneMessage = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] full experiment cycle complete"
    Set-Content -Path $doneFile -Value $doneMessage -Encoding utf8
    Write-WatchLog $doneMessage
    New-Item -ItemType File -Force -Path $stopFile | Out-Null

    if (Test-Path $loopPidFile) {
        $loopPid = Get-Content $loopPidFile -ErrorAction SilentlyContinue
        if ($loopPid -and (Get-Process -Id $loopPid -ErrorAction SilentlyContinue)) {
            Stop-Process -Id $loopPid -Force
            Write-WatchLog "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] stopped research loop PID=$loopPid"
        }
    }

    try {
        msg * /time:60 "ESWA full experiments completed. Results saved under results."
    }
    catch {
        Write-WatchLog "Windows notification failed: $($_.Exception.Message)"
    }
    break
}

if (Test-Path $watchPidFile) {
    Remove-Item $watchPidFile -Force
}
