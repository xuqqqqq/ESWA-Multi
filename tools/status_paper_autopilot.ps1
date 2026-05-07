$ErrorActionPreference = "Continue"

$workspace = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$resultsDir = Join-Path $workspace "results"

function Show-PidStatus {
    param([string]$Name, [string]$PidFile)
    if (Test-Path $PidFile) {
        $pidValue = Get-Content $PidFile -ErrorAction SilentlyContinue
        $proc = $null
        if ($pidValue) {
            $proc = Get-Process -Id $pidValue -ErrorAction SilentlyContinue
        }
        if ($proc) {
            Write-Host "${Name}: running PID=$pidValue CPU=$([Math]::Round($proc.CPU, 1))"
        }
        else {
            Write-Host "${Name}: stale pid file PID=$pidValue"
        }
    }
    else {
        Write-Host "${Name}: not running"
    }
}

Show-PidStatus "paper_autopilot_loop" (Join-Path $resultsDir "paper_autopilot_loop.pid")
Show-PidStatus "convergence_paperlite" (Join-Path $resultsDir "convergence_paperlite.pid")

$matlabs = Get-Process matlab -ErrorAction SilentlyContinue
if ($matlabs) {
    Write-Host "matlab processes:"
    $matlabs | Select-Object Id,CPU,StartTime | Format-Table -AutoSize
}
else {
    Write-Host "matlab processes: none"
}

foreach ($file in @(
    "paper_autopilot_review.md",
    "convergence_paperlite.log",
    "paper_autopilot_loop.log"
)) {
    $path = Join-Path $resultsDir $file
    if (Test-Path $path) {
        Write-Host ""
        Write-Host "== $file =="
        Get-Content $path -Tail 12
    }
}
