param(
    [ValidateSet("smoke", "quick", "paper", "full")]
    [string]$Mode = "quick"
)

$ErrorActionPreference = "Stop"

$workspace = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$runner = Join-Path $workspace "tools\run_research_experiment.ps1"

& powershell -NoProfile -ExecutionPolicy Bypass -File $runner -Phase auto -Mode $Mode
exit $LASTEXITCODE
