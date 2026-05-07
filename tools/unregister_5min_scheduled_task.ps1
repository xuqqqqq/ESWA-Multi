$ErrorActionPreference = "Continue"

$taskName = "IHGA_5min_Experiment"
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($task) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "Unregistered scheduled task: $taskName"
}
else {
    Write-Host "Scheduled task not found: $taskName"
}
