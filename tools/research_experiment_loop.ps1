param(
    [ValidateSet("smoke", "quick", "paper", "full")]
    [string]$Mode = "quick"
)

$ErrorActionPreference = "Continue"

$workspace = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$stopFile = Join-Path $workspace "results\stop_research_loop.flag"
$logFile = Join-Path $workspace "results\research_loop.log"
$runner = Join-Path $workspace "tools\run_research_experiment.ps1"
$phaseFile = Join-Path $workspace "results\research_phase.txt"
$doneFile = Join-Path $workspace "results\${Mode}_experiment_done.txt"
$intervalSeconds = 300

New-Item -ItemType Directory -Force -Path (Join-Path $workspace "results") | Out-Null
if (Test-Path $stopFile) {
    Remove-Item $stopFile -Force
}

function Write-LoopLog {
    param([string]$Message)
    Add-Content -Path $logFile -Value $Message -Encoding utf8
}

$nextRun = Get-Date
while (-not (Test-Path $stopFile)) {
    $now = Get-Date
    if ($now -lt $nextRun) {
        $sleepSeconds = [Math]::Min(15, [Math]::Max(1, [int]($nextRun - $now).TotalSeconds))
        Start-Sleep -Seconds $sleepSeconds
        continue
    }

    $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-LoopLog "[$stamp] trigger mode=$Mode"
    try {
        & powershell -NoProfile -ExecutionPolicy Bypass -File $runner -Phase auto -Mode $Mode 2>&1 |
            ForEach-Object { Write-LoopLog ([string]$_) }

        if (($Mode -eq "full" -or $Mode -eq "paper") -and (Test-Path $phaseFile)) {
            $lastPhase = (Get-Content $phaseFile -ErrorAction SilentlyContinue | Select-Object -First 1)
            if ($lastPhase -eq "vehicle") {
                $doneMessage = "[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] $Mode experiment cycle complete"
                Set-Content -Path $doneFile -Value $doneMessage -Encoding utf8
                Write-LoopLog $doneMessage
                try {
                    msg * /time:60 "ESWA $Mode experiments completed. Results saved under results."
                }
                catch {
                    Write-LoopLog "Windows notification failed: $($_.Exception.Message)"
                }
                break
            }
        }
    }
    catch {
        Write-LoopLog $_.Exception.Message
    }

    do {
        $nextRun = $nextRun.AddSeconds($intervalSeconds)
    } while ($nextRun -le (Get-Date))
}

Write-LoopLog "[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] stopped"
