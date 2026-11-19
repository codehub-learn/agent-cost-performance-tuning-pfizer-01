#!/usr/bin/env bash
# Check that the lab is ready, without starting an agent or spending quota: tools, data, scorer, components, prompts, scripts.
#   scripts/verify-lab.sh [stage 0-4]
# The stage is the number of the last release you have (default 4, everything). Only what that stage brings is checked.
# The agent is read from .lab-agent (written by release-course); in the build repo there is no such file
# and the sources are checked.
cd "$(dirname "$0")/.."
source scripts/lib/check.sh

STAGE="${1:-4}"
case "$STAGE" in 0|1|2|3|4) ;; *) echo "Usage: scripts/verify-lab.sh [stage 0-4]" >&2; exit 2 ;; esac
AGENT=build; [ -f .lab-agent ] && AGENT="$(tr -d '\r\n' < .lab-agent)"
ge() { [ "$STAGE" -ge "$1" ]; }
echo "Stage $STAGE, agent: $AGENT"

if [ "$AGENT" = copilot ]; then
  SK=.github/skills; AG=.github/agents; AGX=.agent.md; RULE=.github/instructions/lean-instructions.instructions.md; RULEKEY='^applyTo:'; HOOK=.github/hooks/budget-guard.json
fi
existing() { local f; for f in "$@"; do [ -e "$f" ] && echo "$f"; done; }

echo "Tools (versions are the ones the lab was tested with; a difference is a warning, not a failure)"
if true; then
  gh_="$(copilot --version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)"
  if [ -z "$gh_" ]; then bad "copilot is not on the path"; elif [ "$gh_" = 1.0.109 ]; then ok "Copilot CLI $gh_ (tested with 1.0.109)"; else warn "Copilot CLI $gh_; tested with 1.0.109"; fi
fi
for t in jq node git; do command -v "$t" >/dev/null && ok "$t on the path" || bad "$t is not on the path"; done

echo "Released files (stage 0 to $STAGE)"
n=0; miss=0
while IFS='|' read -r st src dst opt; do
  case "$st" in ''|\#*) continue ;; esac
  [ "$st" -le "$STAGE" ] || continue
  dst="${dst:-$src}"
  if [ "$AGENT" = build ]; then
    [ "$opt" = generated ] && continue
    p="$src"
  else
    p="$dst"
  fi
  n=$((n + 1))
  if [ ! -e "$p" ] && [ "$opt" != optional ]; then bad "missing $p"; miss=1; fi
done < <(tr -d '\r' < scripts/course-stages.txt | sed -E 's/[[:space:]]*#@[a-z]+[[:space:]]*$//')
[ "$miss" = 0 ] && ok "all $n files of stages 0 to $STAGE are present"
if [ "$AGENT" != build ]; then
  ONLY=(COURSE-GUIDE.md COURSE-RATIONALE.md docs scripts/release-course.sh scripts/release-course.ps1 scripts/snapshot-issues.sh)
  ONLY+=(.github/skills/lab-build-protocol .github/skills/runbook-writer)
  for f in "${ONLY[@]}"; do
    [ -e "$f" ] && bad "instructor-only file is in the course folder: $f"
  done
  ok "no instructor-only file in the course folder"
fi

if ge 1; then
  echo "Agent logs (can the scripts still read what the agent writes?)"
  if true; then
    ef="$(ls -t "${COPILOT_HOME:-$HOME/.copilot}"/session-state/*/events.jsonl 2>/dev/null | head -1)"
    if [ -z "$ef" ]; then warn "no Copilot CLI session yet; run copilot -p once and verify again"
    else
      out="$(bash scripts/report.sh copilot "$ef" 2>/dev/null | awk -F'|' '/^## Calls/{f=1} f && $2+0>=1 {print $6+0; exit}')"
      [ "${out:-0}" -gt 0 ] 2>/dev/null && ok "report reads the newest Copilot CLI session (output tokens $out)" || warn "report found no tokens in the newest Copilot CLI session (it may be a session without model calls)"
    fi
  fi
fi

echo "Data"
if bash scripts/verify-data.sh >/dev/null 2>&1; then ok "verify-data passes"; else bad "verify-data fails (run scripts/verify-data.sh for details)"; fi
check "subset size" 10 "$(wc -l < eval/subset10.txt | tr -d ' ')"
check "subset issues found in the snapshot" 10 "$(jq -s -r --slurpfile s eval/subset10.txt '[.[] | select(.number | IN($s[]))] | length' eval/issues.jsonl)"

if ge 2; then
  echo "Scorer"
  t="$(mktemp)"; jq -c '{number,label}' eval/issues.jsonl | tr -d '\r' > "$t"
  check "true labels score 10/10 on the subset" "Accuracy: 10/10 = 100%" "$(bash scripts/score.sh "$t" | sed -n 2p)"
  check "true labels score 30/30 on all issues" "Accuracy: 30/30 = 100%" "$(bash scripts/score.sh "$t" all | sed -n 2p)"
  : > "$t"; check "an empty answer scores 0/10" "Accuracy: 0/10 = 0%" "$(bash scripts/score.sh "$t" | sed -n 2p)"
  rm -f "$t"
fi

echo "Components"
SKILLS=("1 cost-report" "2 triage-issues" "3 latency-report")
for pair in "${SKILLS[@]}"; do
  set -- $pair; ge "$1" || continue; s="$2"
  check "skill $s has name = folder" "$s" "$(sed -n 's/^name: *//p' "$SK/$s/SKILL.md" 2>/dev/null | head -1 | tr -d '\r')"
  [ -f "$SK/$s/CHANGELOG.md" ] && ok "skill $s has a changelog" || bad "skill $s has no CHANGELOG.md"
done
if ge 2; then
  grep -q "$RULEKEY" "$RULE" 2>/dev/null && ok "rule lean-instructions is scoped ($RULE)" || bad "rule lean-instructions is missing or not scoped ($RULE)"
  for v in bloated trimmed minimal; do [ -f "eval/variants/$v.md" ] && ok "variant $v" || bad "missing variant $v"; done
fi
if ge 4; then
  for a in triage-small triage-large; do [ -f "$AG/$a$AGX" ] && ok "agent $a" || bad "missing agent $AG/$a$AGX"; done
fi
if ge 1; then
  JSONS="$HOOK"
  for j in $JSONS; do
    jq empty "$j" 2>/dev/null && ok "valid JSON: $j" || bad "invalid or missing JSON: $j"
  done
fi

echo "Prompts and scripts"
check "prompt files" $((3 * STAGE)) "$(find prompts -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"
for pair in "1 " "2 -none" "2 -readme" "2 -capped" "2 -open" "3 -seq" "3 -par" "4 -conf"; do
  set -- $pair; ge "$1" || continue; p="${2:-}"
  [ -f "scripts/lib/triage-prompt$p.txt" ] && ok "triage prompt$p" || bad "missing scripts/lib/triage-prompt$p.txt"
done
PAIRS=("0 fetch-data" "0 verify-data" "0 verify-lab" "0 reset-lab" "1 prepare-work" "1 report" "2 score" "2 run-variant" "3 run-stream" "3 latency" "4 route")
for pair in "${PAIRS[@]}"; do
  set -- $pair; ge "$1" || continue; n="$2"
  { [ -f "scripts/$n.sh" ] && [ -f "scripts/$n.ps1" ]; } && ok "script pair $n" || bad "script pair $n is incomplete (.sh and .ps1)"
done

echo "Rules"
leak="$(existing eval/variants/*.md scripts/lib/triage-prompt*.txt "$SK/triage-issues/SKILL.md" "$AG"/triage-*"$AGX" "$RULE")"
if [ -n "$leak" ]; then check "scored issue numbers in variants, prompts, skills, agents and rule" 0 "$(grep -w -c -f eval/subset10.txt $leak | awk -F: '{s+=$NF} END{print s+0}')"; fi
docs="$(existing docs/lab-runbook.md LAB-GUIDE.md prompts "$SK/triage-issues" "$SK/cost-report" "$SK/latency-report" "$AG" "$(dirname "$RULE")")"
check "em dashes in the guide, prompts and components" 0 "$(LC_ALL=C grep -r -c -P '\xe2\x80\x94' $docs 2>/dev/null | awk -F: '{s+=$NF} END{print s+0}')"
finish
