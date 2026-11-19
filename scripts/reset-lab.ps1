# Put the lab back to a clean state between runs. Same as reset-lab.sh. Dry run by default: it lists what it would delete.
#   scripts/reset-lab.ps1            list what would be deleted
#   scripts/reset-lab.ps1 -Yes       delete it
#   scripts/reset-lab.ps1 -Yes -Data    also delete the data/mockito clone (fetch-data brings it back)
# Deletes only: the files and folders in logs/ (not .gitkeep) and the work folder ../triage-work.
# It never touches ~/.copilot, eval/, scripts/ or any tracked file.
param([switch]$Yes, [switch]$Data)
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
$targets = [Collections.Generic.List[string]]::new()
Get-ChildItem logs -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne '.gitkeep' } | ForEach-Object { $targets.Add("logs/$($_.Name)") }
if (Test-Path ../triage-work) {
  if ((Test-Path ../triage-work/triage-prompt.txt) -or (Test-Path ../triage-work/logs)) { $targets.Add('../triage-work') }
  else { Write-Host 'skipped ../triage-work: it does not look like the lab work folder' }
}
if ($Data -and (Test-Path data/mockito)) { $targets.Add('data/mockito') }
if ($targets.Count -eq 0) { 'Nothing to reset.'; exit 0 }
if (-not $Yes) { 'Would delete (dry run, add -Yes to delete):'; $targets | ForEach-Object { "  $_" }; exit 0 }
'Deleting:'
foreach ($t in $targets) { "  $t"; Remove-Item -Recurse -Force -LiteralPath $t }
New-Item -ItemType Directory -Force logs | Out-Null
if (-not (Test-Path logs/.gitkeep)) { New-Item -ItemType File logs/.gitkeep | Out-Null }
'Done. Run scripts/verify-lab.ps1 to check the lab.'
