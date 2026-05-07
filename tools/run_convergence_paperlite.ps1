$ErrorActionPreference = "Stop"

$workspace = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $workspace

$resultsDir = Join-Path $workspace "results"
$logFile = Join-Path $resultsDir "convergence_paperlite.log"
$lockFile = Join-Path $resultsDir "convergence_paperlite.lock"
$doneFile = Join-Path $resultsDir "convergence_paperlite_done.txt"
$pidFile = Join-Path $resultsDir "convergence_paperlite.pid"
New-Item -ItemType Directory -Force -Path $resultsDir | Out-Null

function Write-ConvergenceLog {
    param([string]$Message)
    Add-Content -Path $logFile -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message" -Encoding utf8
}

if (Test-Path $lockFile) {
    Write-ConvergenceLog "skip existing lock"
    exit 0
}

New-Item -ItemType File -Force -Path $lockFile | Out-Null

$matlabExe = "E:\matlab\bin\matlab.exe"
if (-not (Test-Path $matlabExe)) {
    $matlabExe = "matlab"
}

try {
    Write-ConvergenceLog "paper-lite convergence started"
    & $matlabExe -batch "runConvergenceTrace('paper_lite');" 2>&1 | ForEach-Object {
        Write-ConvergenceLog ([string]$_)
    }
    if ($LASTEXITCODE -ne 0) {
        throw "MATLAB exited with code $LASTEXITCODE"
    }

    Write-ConvergenceLog "generating convergence assets"
    & python "tools\generate_convergence_assets.py" 2>&1 | ForEach-Object {
        Write-ConvergenceLog ([string]$_)
    }
    if ($LASTEXITCODE -ne 0) {
        throw "generate_convergence_assets.py exited with code $LASTEXITCODE"
    }

    Write-ConvergenceLog "refreshing autopilot review"
    & python "tools\paper_autopilot_review.py" 2>&1 | ForEach-Object {
        Write-ConvergenceLog ([string]$_)
    }
    if ($LASTEXITCODE -ne 0) {
        throw "paper_autopilot_review.py exited with code $LASTEXITCODE"
    }

    Set-Content -Path $doneFile -Value "completed $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Encoding utf8
    Write-ConvergenceLog "paper-lite convergence complete"
}
catch {
    Write-ConvergenceLog "ERROR $($_.Exception.Message)"
    throw
}
finally {
    if (Test-Path $lockFile) {
        Remove-Item $lockFile -Force
    }
    if (Test-Path $pidFile) {
        $existingPid = Get-Content $pidFile -ErrorAction SilentlyContinue
        if ($existingPid -eq "$PID") {
            Remove-Item $pidFile -Force
        }
    }
}
