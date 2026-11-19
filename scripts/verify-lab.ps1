# Check that the lab is ready, without starting an agent or spending quota. Same as verify-lab.sh.
#   scripts/verify-lab.ps1 [-Stage 0-4]
# The stage is the number of the last release you have (default 4, everything). The agent is read from .lab-agent
# (written by release-course); in the build repo there is no such file and the sources are checked.
param([ValidateRange(0, 4)][int]$Stage = 4)
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$OutputEncoding = [Text.UTF8Encoding]::new($false)
Set-Location (Join-Path $PSScriptRoot '..')
. "$PSScriptRoot/lib/check.ps1"
function Ok($d) { Write-Host "  ok    $d" }
function Bad($d) { Write-Host "  FAIL  $d"; $script:CheckFailed = $true }
function Yes($cond, $d) { if ($cond) { Ok $d } else { Bad $d } }
function Count($files, $pattern) { ($files | ForEach-Object { (Select-String -Path $_ -Pattern $pattern -AllMatches -ErrorAction SilentlyContinue | Measure-Object).Count } | Measure-Object -Sum).Sum + 0 }
function Ge($n) { $Stage -ge $n }

$agent = if (Test-Path .lab-agent) { (Get-Content .lab-agent -Raw).Trim() } else { 'build' }
"Stage $Stage, agent: $agent"
if ($agent -eq 'copilot') {
  $SK = '.github/skills'; $AG = '.github/agents'; $AGX = '.agent.md'; $RULE = '.github/instructions/lean-instructions.instructions.md'; $RULEKEY = '^applyTo:'; $HOOK = '.github/hooks/budget-guard.json'
}

'Tools (versions are the ones the lab was tested with; a difference is a warning, not a failure)'
if ($true) {
  $gh = [regex]::Match((copilot --version 2>$null | Out-String), '\d+\.\d+\.\d+').Value
  if (-not $gh) { Bad 'copilot is not on the path' } elseif ($gh -eq '1.0.109') { Ok "Copilot CLI $gh (tested with 1.0.109)" } else { Warn "Copilot CLI $gh; tested with 1.0.109" }
}
foreach ($t in 'jq', 'node', 'git') { Yes ([bool](Get-Command $t -ErrorAction SilentlyContinue)) "$t on the path" }

"Released files (stage 0 to $Stage)"
$n = 0; $miss = $false
foreach ($line in Get-Content scripts/course-stages.txt) {
  if ($line -match '^\s*(#|$)') { continue }
  $line = $line -replace '[ ]*#@[a-z]+[ ]*$', ''
  $f = $line -split '[|]'
  if ([int]$f[0] -gt $Stage) { continue }
  $dst = if ($f.Count -gt 2 -and $f[2]) { $f[2] } else { $f[1] }
  $opt = if ($f.Count -gt 3) { $f[3] } else { '' }
  if ($agent -eq 'build') { if ($opt -eq 'generated') { continue }; $p = $f[1] }
  else { $p = $dst }
  $n++
  if (-not (Test-Path $p) -and $opt -ne 'optional') { Bad "missing $p"; $miss = $true }
}
if (-not $miss) { Ok "all $n files of stages 0 to $Stage are present" }
if ($agent -ne 'build') {
  $only = @('COURSE-GUIDE.md', 'COURSE-RATIONALE.md', 'docs', 'scripts/release-course.sh', 'scripts/release-course.ps1', 'scripts/snapshot-issues.sh')
  $only += '.github/skills/lab-build-protocol', '.github/skills/runbook-writer'
  foreach ($p in $only) {
    if (Test-Path $p) { Bad "instructor-only file is in the course folder: $p" }
  }
  Ok 'no instructor-only file in the course folder'
}

function Out-Tokens($lines) { $i = [array]::IndexOf($lines, ($lines | Where-Object { $_ -like '## Calls*' } | Select-Object -First 1)); if ($i -lt 0) { return 0 }; $row = $lines[($i + 1)..($lines.Count - 1)] | Where-Object { $_ -match '^\|\s*1\s*\|' } | Select-Object -First 1; if (-not $row) { return 0 }; [int](($row -split '\|')[5]) }
if (Ge 1) {
  'Agent logs (can the scripts still read what the agent writes?)'
  if ($true) {
    $croot = if ($env:COPILOT_HOME) { $env:COPILOT_HOME } else { "$env:USERPROFILE/.copilot" }
    $ef = Get-ChildItem "$croot/session-state/*/events.jsonl" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $ef) { Warn 'no Copilot CLI session yet; run copilot -p once and verify again' }
    else { $o = Out-Tokens (& scripts/report.ps1 copilot $ef.FullName 2>$null); if ($o -gt 0) { Ok "report reads the newest Copilot CLI session (output tokens $o)" } else { Warn 'report found no tokens in the newest Copilot CLI session (it may be a session without model calls)' } }
  }
}

'Data'
pwsh -NoProfile -File scripts/verify-data.ps1 *> $null; Yes ($LASTEXITCODE -eq 0) 'verify-data passes'
Check 'subset size' 10 (Get-Content eval/subset10.txt | Where-Object { $_.Trim() }).Count
Check 'subset issues found in the snapshot' 10 ([int](jq -s --slurpfile s eval/subset10.txt '[.[] | select(.number | IN($s[]))] | length' eval/issues.jsonl))

if (Ge 2) {
  'Scorer'
  $t = New-TemporaryFile
  [IO.File]::WriteAllText($t, ((jq -c '{number,label}' eval/issues.jsonl) -join "`n") + "`n", [Text.UTF8Encoding]::new($false))
  Check 'true labels score 10/10 on the subset' 'Accuracy: 10/10 = 100%' ((& scripts/score.ps1 $t)[1])
  Check 'true labels score 30/30 on all issues' 'Accuracy: 30/30 = 100%' ((& scripts/score.ps1 $t -All)[1])
  [IO.File]::WriteAllText($t, '', [Text.UTF8Encoding]::new($false))
  Check 'an empty answer scores 0/10' 'Accuracy: 0/10 = 0%' ((& scripts/score.ps1 $t)[1])
  Remove-Item $t -ErrorAction SilentlyContinue
}

'Components'
$skills = @(@(1, 'cost-report'), @(2, 'triage-issues'), @(3, 'latency-report'))
foreach ($pair in $skills) {
  if (-not (Ge $pair[0])) { continue }; $s = $pair[1]
  $nm = (Select-String -Path "$SK/$s/SKILL.md" -Pattern '^name:\s*(.+)$' -ErrorAction SilentlyContinue | Select-Object -First 1).Matches.Groups[1].Value.Trim()
  Check "skill $s has name = folder" $s $nm
  Yes (Test-Path "$SK/$s/CHANGELOG.md") "skill $s has a changelog"
}
if (Ge 2) {
  Yes ([bool](Select-String -Path $RULE -Pattern $RULEKEY -ErrorAction SilentlyContinue)) "rule lean-instructions is scoped ($RULE)"
  foreach ($v in 'bloated', 'trimmed', 'minimal') { Yes (Test-Path "eval/variants/$v.md") "variant $v" }
}
if (Ge 4) {
  foreach ($a in 'triage-small', 'triage-large') { Yes (Test-Path "$AG/$a$AGX") "agent $a" }
}
if (Ge 1) {
  $jsons = @($HOOK)
  foreach ($j in $jsons) { if (Test-Path $j) { jq empty $j 2>$null; Yes ($LASTEXITCODE -eq 0) "valid JSON: $j" } else { Bad "invalid or missing JSON: $j" } }
}

'Prompts and scripts'
Check 'prompt files' (3 * $Stage) @(Get-ChildItem prompts -Recurse -Filter *.md -ErrorAction SilentlyContinue).Count
foreach ($pair in @(@(1, ''), @(2, '-none'), @(2, '-readme'), @(2, '-capped'), @(2, '-open'), @(3, '-seq'), @(3, '-par'), @(4, '-conf'))) {
  if (-not (Ge $pair[0])) { continue }; $p = $pair[1]
  Yes (Test-Path "scripts/lib/triage-prompt$p.txt") "triage prompt$p"
}
$pairs = @(@(0, 'fetch-data'), @(0, 'verify-data'), @(0, 'verify-lab'), @(0, 'reset-lab'), @(1, 'prepare-work'), @(1, 'report'), @(2, 'score'), @(2, 'run-variant'), @(3, 'run-stream'), @(3, 'latency'), @(4, 'route'))
foreach ($pair in $pairs) {
  if (-not (Ge $pair[0])) { continue }; $nm = $pair[1]
  Yes ((Test-Path "scripts/$nm.sh") -and (Test-Path "scripts/$nm.ps1")) "script pair $nm"
}

'Rules'
$ids = (Get-Content eval/subset10.txt | Where-Object { $_.Trim() }) -join '|'
$leakFiles = @(@(Get-ChildItem eval/variants/*.md, scripts/lib/triage-prompt*.txt, "$SK/triage-issues/SKILL.md", "$AG/triage-*$AGX", $RULE -ErrorAction SilentlyContinue))
if ($leakFiles.Count) { Check 'scored issue numbers in variants, prompts, skills, agents and rule' 0 (Count $leakFiles "\b($ids)\b") }
$dash = [string][char]0x2014
$docDirs = @('prompts', "$SK/triage-issues", "$SK/cost-report", "$SK/latency-report", $AG, (Split-Path $RULE))
$docFiles = @(Get-Item docs/lab-runbook.md, LAB-GUIDE.md -ErrorAction SilentlyContinue) + @(Get-ChildItem $docDirs -Recurse -File -ErrorAction SilentlyContinue)
Check 'em dashes in the guide, prompts and components' 0 (Count $docFiles ([regex]::Escape($dash)))
Finish-Checks
