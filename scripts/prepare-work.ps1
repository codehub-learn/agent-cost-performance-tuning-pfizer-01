# Create the clean work folder the tuning runs happen in. Same as prepare-work.sh.
#   scripts/prepare-work.ps1 [-Instructions file]     # no argument = no instruction file (the clean baseline)
param([string]$Instructions = '')
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$OutputEncoding = [Text.UTF8Encoding]::new($false)
Set-Location (Join-Path $PSScriptRoot '..')
$work = '../triage-work'
if (Test-Path $work) { Remove-Item -Recurse -Force $work }
New-Item -ItemType Directory -Force "$work/logs" | Out-Null
$ids = jq -s -c . eval/subset10.txt
$lines = jq -c --argjson ids $ids 'select(.number|IN($ids[])) | {number,title,body}' eval/issues.jsonl
[IO.File]::WriteAllText("$((Resolve-Path $work).Path)/logs/triage-input.jsonl", (($lines -join "`n") + "`n"), [Text.UTF8Encoding]::new($false))
Copy-Item scripts/lib/triage-prompt.txt "$work/triage-prompt.txt"
if ($Instructions) { Copy-Item $Instructions "$work/AGENTS.md" }
"work folder: $((Resolve-Path $work).Path)  (input lines: $((Get-Content "$work/logs/triage-input.jsonl").Count), instruction file: $(if ($Instructions) { $Instructions } else { 'none' }))"
