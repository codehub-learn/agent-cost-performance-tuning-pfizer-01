# Check the workload data: pinned commit, issue snapshot count, labels and checksum.
Set-Location (Join-Path $PSScriptRoot '..')
. "$PSScriptRoot/lib/check.ps1"
Check 'workload commit' '10b31ba2a8252cf340bc154c9e05224802a84691' (git -C data/mockito rev-parse HEAD 2>$null)
$issues = Get-Content eval/issues.jsonl | ForEach-Object { $_ | ConvertFrom-Json }
Check 'issue snapshot lines' 30 $issues.Count
foreach ($l in 'bug:8', 'enhancement:8', 'question:7', 'docs:7') {
  $name, $n = $l -split ':'
  Check "issues labelled $name" $n (@($issues | Where-Object label -eq $name).Count)
}
Check 'issues.jsonl sha256' ((Get-Content eval/issues.sha256 -Raw).Trim() -split '\s+')[0] ((Get-FileHash eval/issues.jsonl -Algorithm SHA256).Hash.ToLower())
Finish-Checks
