$ErrorActionPreference = "Continue"

$workspace = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$runner = Join-Path $workspace "tools\run_auto_experiment.ps1"
$logDir = Join-Path $workspace "results"
$logFile = Join-Path $logDir "scheduled_task_stdout.log"
$lockFile = Join-Path $logDir "auto_experiment.lock"

New-Item -ItemType Directory -Force -Path $logDir | Out-Null
Add-Content -Path $logFile -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] scheduled wrapper start"

try {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner 2>&1 |
        ForEach-Object { Add-Content -Path $logFile -Value $_ }
    Add-Content -Path $logFile -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] scheduled wrapper complete exit=$LASTEXITCODE"
}
catch {
    Add-Content -Path $logFile -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] scheduled wrapper error: $($_.Exception.Message)"
}
finally {
    if (Test-Path $lockFile) {
        $ageMinutes = ((Get-Date) - (Get-Item $lockFile).LastWriteTime).TotalMinutes
        if ($ageMinutes -gt 10) {
            Remove-Item $lockFile -Force
            Add-Content -Path $logFile -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] removed stale lock"
        }
    }
}
