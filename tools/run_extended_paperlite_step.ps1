$ErrorActionPreference = "Stop"

$workspace = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $workspace

$resultsDir = Join-Path $workspace "results"
$logFile = Join-Path $resultsDir "extended_paperlite_auto.log"
$lockFile = Join-Path $resultsDir "extended_paperlite_auto.lock"
$indexFile = Join-Path $resultsDir "extended_paperlite_auto_index.txt"
$doneFile = Join-Path $resultsDir "extended_paperlite_done.txt"
$staleLockMinutes = 240

New-Item -ItemType Directory -Force -Path $resultsDir | Out-Null

function Write-AutoLog {
    param([string]$Message)
    Add-Content -Path $logFile -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message" -Encoding utf8
}

if (Test-Path $lockFile) {
    $ageMinutes = ((Get-Date) - (Get-Item $lockFile).LastWriteTime).TotalMinutes
    if ($ageMinutes -lt $staleLockMinutes) {
        Write-AutoLog "skip fresh lock age_minutes=$([Math]::Round($ageMinutes, 2))"
        exit 0
    }
    Remove-Item $lockFile -Force
    Write-AutoLog "removed stale lock age_minutes=$([Math]::Round($ageMinutes, 2))"
}

New-Item -ItemType File -Force -Path $lockFile | Out-Null

$matlabExe = "E:\matlab\bin\matlab.exe"
if (-not (Test-Path $matlabExe)) {
    $matlabExe = "matlab"
}

function Run-MatlabBatch {
    param([string]$Command)
    Write-AutoLog "MATLAB $Command"
    & $matlabExe -batch $Command 2>&1 | ForEach-Object { Write-AutoLog ([string]$_) }
    if ($LASTEXITCODE -ne 0) {
        throw "MATLAB exited with code $LASTEXITCODE"
    }
}

function Run-CheckedCommand {
    param([string]$Command, [string[]]$Arguments)
    Write-AutoLog "$Command $($Arguments -join ' ')"
    & $Command @Arguments 2>&1 | ForEach-Object { Write-AutoLog ([string]$_) }
    if ($LASTEXITCODE -ne 0) {
        throw "$Command exited with code $LASTEXITCODE"
    }
}

try {
    $cases = @(
        "C101-25", "C102-25", "C103-25",
        "r101-25", "r102-25", "r103-25",
        "rc101-25", "rc102-25", "rc103-25"
    )
    $repeats = @(1, 2, 3)
    $perExperiment = $cases.Count * $repeats.Count
    $algorithmStart = 0
    $modelStart = $perExperiment
    $priorityStep = $perExperiment * 2
    $summaryStep = $priorityStep + 1
    $doneStep = $summaryStep + 1

    $index = 0
    if (Test-Path $indexFile) {
        $rawIndex = (Get-Content -Path $indexFile -ErrorAction SilentlyContinue | Select-Object -First 1)
        if ($rawIndex -match '^\d+$') {
            $index = [int]$rawIndex
        }
    }

    if ($index -ge $doneStep) {
        Write-AutoLog "already complete index=$index"
        exit 0
    }

    if ($index -lt $modelStart) {
        $localIndex = $index - $algorithmStart
        $case = $cases[[Math]::Floor($localIndex / $repeats.Count)]
        $repeat = $repeats[$localIndex % $repeats.Count]
        Write-AutoLog "task index=$index type=algorithm case=$case repeat=$repeat"
        Run-MatlabBatch "runAlgorithmComparison('extended_paper_lite','$case',$repeat);"
    }
    elseif ($index -lt $priorityStep) {
        $localIndex = $index - $modelStart
        $case = $cases[[Math]::Floor($localIndex / $repeats.Count)]
        $repeat = $repeats[$localIndex % $repeats.Count]
        Write-AutoLog "task index=$index type=model case=$case repeat=$repeat"
        Run-MatlabBatch "runModelComparison('extended_paper_lite','$case',$repeat);"
    }
    elseif ($index -eq $priorityStep) {
        Write-AutoLog "task index=$index type=priority_strategy"
        Run-MatlabBatch "runPriorityStrategyComparison('extended_quick');"
    }
    elseif ($index -eq $summaryStep) {
        Write-AutoLog "task index=$index type=summarize_compile"
        Run-CheckedCommand "python" @("tools\generate_extended_benchmark_assets.py", "--mode", "extended_paper_lite")
        Run-CheckedCommand "python" @("tools\generate_priority_strategy_assets.py", "--mode", "extended_paper_lite")
        Run-CheckedCommand "python" @("tools\update_manuscript_extended_tables.py")
        Push-Location (Join-Path $workspace "latex")
        try {
            Run-CheckedCommand "latexmk" @("-pdf", "-interaction=nonstopmode", "-halt-on-error", "-jobname=manuscript_extended_paperlite", "manuscript.tex")
        }
        finally {
            Pop-Location
        }
    }

    $nextIndex = $index + 1
    Set-Content -Path $indexFile -Value $nextIndex -Encoding utf8
    Write-AutoLog "complete index=$index next=$nextIndex"

    if ($nextIndex -ge $doneStep) {
        Set-Content -Path $doneFile -Value "completed $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Encoding utf8
        Write-AutoLog "all tasks complete"
    }
}
catch {
    Write-AutoLog "ERROR $($_.Exception.Message)"
    throw
}
finally {
    if (Test-Path $lockFile) {
        Remove-Item $lockFile -Force
    }
}
