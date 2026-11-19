# Per-call tokens, cost and latency report from an agent's own log. Same as report.sh.
#   scripts/report.ps1 copilot [events.jsonl]
# Settings (environment): BUDGET_USD=0.50 BUDGET_MS=60000 PER_DAY=200 DAYS=22
param([Parameter(Mandatory)][string]$Agent, [string]$File = '')
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$OutputEncoding = [Text.UTF8Encoding]::new($false)
Set-Location (Join-Path $PSScriptRoot '..')
$home_ = $env:USERPROFILE
$known = @()
$known += 'copilot'
if ($Agent -notin $known) { throw "agent must be one of: $($known -join ', ')" }
if ($Agent -eq 'copilot') {
if (-not $File) {
  $root = if ($env:COPILOT_HOME) { $env:COPILOT_HOME } else { "$home_/.copilot" }
  $File = (Get-ChildItem "$root/session-state/*/events.jsonl" | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
}
$filter = 'scripts/lib/copilot-calls.jq'
}
function Setting($name, $default) { $v = [Environment]::GetEnvironmentVariable($name); if ($v) { $v } else { $default } }
$p = Get-Content scripts/lib/prices.json -Raw | ConvertFrom-Json
"Source: $Agent log ($(Split-Path (Split-Path $File) -Leaf)/$(Split-Path $File -Leaf)); prices: $($p.fetched), $($p.unit)"
''
$rows = jq -s -c -f $filter $File
$tmp = New-TemporaryFile
[IO.File]::WriteAllText($tmp, ($rows -join "`n"), [Text.UTF8Encoding]::new($false))
jq -r --slurpfile prices scripts/lib/prices.json `
  --argjson budget_usd (Setting 'BUDGET_USD' '0.50') --argjson budget_ms (Setting 'BUDGET_MS' '60000') `
  --argjson per_day (Setting 'PER_DAY' '200') --argjson days (Setting 'DAYS' '22') `
  -L scripts/lib -f scripts/lib/report.jq $tmp
Remove-Item $tmp
