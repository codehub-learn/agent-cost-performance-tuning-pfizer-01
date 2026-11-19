# PreToolUse hook (PowerShell variant of budget-guard.sh). Exit code 2 denies the call in Copilot CLI.
#   BUDGET_USD (default 0.50)   BUDGET_MS (default 60000)
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '../..')
$in = [Console]::In.ReadToEnd() | ConvertFrom-Json
$userHome = $env:USERPROFILE
$file = $null
if (-not $in.transcript_path) {
  $root = if ($env:COPILOT_HOME) { $env:COPILOT_HOME } else { "$userHome/.copilot" }
  $agent = 'copilot'; $file = "$root/session-state/$($in.sessionId)/events.jsonl"
}
if (-not $file -or -not (Test-Path $file)) { exit 0 }
try {
  $rows = jq -s -c -f "scripts/lib/$agent-calls.jq" $file
  $tmp = New-TemporaryFile
  [IO.File]::WriteAllText($tmp, ($rows -join "`n"), [Text.UTF8Encoding]::new($false))
  $out = (jq -r -L scripts/lib --slurpfile prices scripts/lib/prices.json -f scripts/lib/guard.jq $tmp)
  Remove-Item $tmp
  $cost, $ms = ($out -split ' ')
  if ($LASTEXITCODE -ne 0 -or -not $cost) { throw 'jq failed' }
} catch {
  [Console]::Error.WriteLine("budget-guard: could not read $agent log, allowing the call"); exit 0
}
$budgetUsd = if ($env:BUDGET_USD) { [double]$env:BUDGET_USD } else { 0.50 }
$budgetMs = if ($env:BUDGET_MS) { [double]$env:BUDGET_MS } else { 60000 }
$inv = [Globalization.CultureInfo]::InvariantCulture
if ([double]::Parse($cost, $inv) -gt $budgetUsd) {
  [Console]::Error.WriteLine("budget-guard: this request has spent `$$cost, over the `$$budgetUsd budget. Stop and report to the user."); exit 2
}
if ([double]::Parse($ms, $inv) -gt $budgetMs) {
  [Console]::Error.WriteLine("budget-guard: this request has taken $ms ms, over the $budgetMs ms budget. Stop and report to the user."); exit 2
}
exit 0
