param(
    [ValidateSet("auto", "vehicle", "algorithm", "ablation", "sensitivity", "model", "priority")]
    [string]$Phase = "auto",
    [ValidateSet("smoke", "quick", "paper", "full")]
    [string]$Mode = "quick"
)

$ErrorActionPreference = "Stop"

$workspace = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $workspace

$resultsDir = Join-Path $workspace "results"
$historyLog = Join-Path $resultsDir "research_task_history.log"
$lockFile = Join-Path $resultsDir "research_experiment.lock"
$phaseFile = Join-Path $resultsDir "research_phase.txt"
$staleLockMinutes = 180
$phases = @("algorithm", "ablation", "sensitivity", "model", "priority", "vehicle")

New-Item -ItemType Directory -Force -Path $resultsDir | Out-Null
Add-Content -Path $historyLog -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] start phase=$Phase mode=$Mode" -Encoding utf8

if (Test-Path $lockFile) {
    $ageMinutes = ((Get-Date) - (Get-Item $lockFile).LastWriteTime).TotalMinutes
    if ($ageMinutes -lt $staleLockMinutes) {
        Write-Host "Another research experiment is running or the lock is still fresh. Skipping this trigger."
        Add-Content -Path $historyLog -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] skipped lock_age_minutes=$([Math]::Round($ageMinutes, 2))" -Encoding utf8
        exit 0
    }
    Remove-Item $lockFile -Force
}

New-Item -ItemType File -Force -Path $lockFile | Out-Null

$matlab = "E:\matlab\bin\matlab.exe"
if (-not (Test-Path $matlab)) {
    throw "MATLAB not found at $matlab"
}

function Get-NextPhase {
    param([string[]]$PhaseList, [string]$StateFile)
    if (-not (Test-Path $StateFile)) {
        return $PhaseList[0]
    }
    $last = (Get-Content $StateFile -ErrorAction SilentlyContinue | Select-Object -First 1)
    $idx = [Array]::IndexOf($PhaseList, $last)
    if ($idx -lt 0) {
        return $PhaseList[0]
    }
    return $PhaseList[($idx + 1) % $PhaseList.Count]
}

function Run-MatlabBatch {
    param([string]$Command)
    Write-Host "MATLAB: $Command"
    & $matlab -batch $Command
    if ($LASTEXITCODE -ne 0) {
        throw "MATLAB exited with code $LASTEXITCODE"
    }
}

try {
    $actualPhase = $Phase
    if ($actualPhase -eq "auto") {
        $actualPhase = Get-NextPhase -PhaseList $phases -StateFile $phaseFile
    }

    switch ($actualPhase) {
        "algorithm" {
            Run-MatlabBatch "outputFile=runAlgorithmComparison('$Mode'); disp(outputFile);"
        }
        "ablation" {
            Run-MatlabBatch "outputs=runAblationStudy('$Mode'); disp(outputs.summaryFile);"
        }
        "sensitivity" {
            Run-MatlabBatch "outputFile=runRevisedSensitivityResume('$Mode'); disp(outputFile);"
        }
        "model" {
            Run-MatlabBatch "outputFile=runModelComparison('$Mode'); disp(outputFile);"
        }
        "priority" {
            Run-MatlabBatch "outputFile=runPriorityAnalysis('$Mode'); disp(outputFile);"
        }
        "vehicle" {
            Run-MatlabBatch "outputFile=runVehicleSensitivity('$Mode'); disp(outputFile);"
        }
    }

    python tools\analyze_research_results.py
    if ($LASTEXITCODE -ne 0) {
        throw "analyze_research_results.py exited with code $LASTEXITCODE"
    }

    if ($Phase -eq "auto") {
        Set-Content -Path $phaseFile -Value $actualPhase -Encoding utf8
    }
    Add-Content -Path $historyLog -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] complete phase=$actualPhase mode=$Mode" -Encoding utf8
}
finally {
    if (Test-Path $lockFile) {
        Remove-Item $lockFile -Force
    }
}
