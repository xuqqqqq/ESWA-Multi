$ErrorActionPreference = "Continue"

$workspace = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$stopFile = Join-Path $workspace "results\stop_auto_loop.flag"
$logFile = Join-Path $workspace "results\auto_loop.log"
$runner = Join-Path $workspace "tools\run_auto_experiment.ps1"
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
    Write-LoopLog "[$stamp] trigger"
    try {
        & powershell -NoProfile -ExecutionPolicy Bypass -File $runner 2>&1 |
            ForEach-Object { Write-LoopLog ([string]$_) }
    }
    catch {
        Write-LoopLog $_.Exception.Message
    }

    do {
        $nextRun = $nextRun.AddSeconds($intervalSeconds)
    } while ($nextRun -le (Get-Date))
}

Write-LoopLog "[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] stopped"
