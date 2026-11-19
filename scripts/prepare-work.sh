#!/usr/bin/env bash
# Create the clean work folder the tuning runs happen in: the label-free issue input, and optionally one instruction file variant.
# It sits next to the project (not inside it) so the project's own AGENTS.md is not loaded into the run.
#   scripts/prepare-work.sh [instruction-file]     # no argument = no instruction file (the clean baseline)
# Result: ../triage-work with logs/triage-input.jsonl and, if given, AGENTS.md (a copy of the variant).
set -euo pipefail
cd "$(dirname "$0")/.."
work="../triage-work"
rm -rf "$work"; mkdir -p "$work/logs"
ids="$(jq -s -c . eval/subset10.txt)"
jq -c --argjson ids "$ids" 'select(.number|IN($ids[])) | {number,title,body}' eval/issues.jsonl > "$work/logs/triage-input.jsonl"
cp scripts/lib/triage-prompt.txt "$work/triage-prompt.txt"
if [ -n "${1:-}" ]; then cp "$1" "$work/AGENTS.md"; fi
echo "work folder: $(cd "$work" && pwd)  (input lines: $(wc -l < "$work/logs/triage-input.jsonl" | tr -d ' '), instruction file: ${1:-none})"
