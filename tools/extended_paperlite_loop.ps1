$ErrorActionPreference = "Continue"

$workspace = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$runner = Join-Path $workspace "tools\run_extended_paperlite_step.ps1"
$resultsDir = Join-Path $workspace "results"
$stopFile = Join-Path $resultsDir "stop_extended_paperlite_loop.flag"
$doneFile = Join-Path $resultsDir "extended_paperlite_done.txt"
$logFile = Join-Path $resultsDir "extended_paperlite_loop.log"
$intervalSeconds = 300

New-Item -ItemType Directory -Force -Path $resultsDir | Out-Null
if (Test-Path $stopFile) {
    Remove-Item $stopFile -Force
}

function Write-LoopLog {
    param([string]$Message)
    Add-Content -Path $logFile -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message" -Encoding utf8
}

$nextRun = Get-Date
Write-LoopLog "started interval_seconds=$intervalSeconds"
while (-not (Test-Path $stopFile) -and -not (Test-Path $doneFile)) {
    $now = Get-Date
    if ($now -lt $nextRun) {
        $sleepSeconds = [Math]::Min(15, [Math]::Max(1, [int]($nextRun - $now).TotalSeconds))
        Start-Sleep -Seconds $sleepSeconds
        continue
    }

    Write-LoopLog "trigger"
    try {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner 2>&1 |
            ForEach-Object { Write-LoopLog ([string]$_) }
    }
    catch {
        Write-LoopLog "ERROR $($_.Exception.Message)"
    }

    do {
        $nextRun = $nextRun.AddSeconds($intervalSeconds)
    } while ($nextRun -le (Get-Date))
}

if (Test-Path $doneFile) {
    Write-LoopLog "done file detected; exiting"
}
else {
    Write-LoopLog "stop file detected; exiting"
}
