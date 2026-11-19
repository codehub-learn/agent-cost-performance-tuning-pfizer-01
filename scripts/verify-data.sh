#!/usr/bin/env bash
# Check the workload data: pinned commit, issue snapshot count, labels and checksum.
cd "$(dirname "$0")/.."
source scripts/lib/check.sh
check "workload commit" 10b31ba2a8252cf340bc154c9e05224802a84691 "$(git -C data/mockito rev-parse HEAD 2>/dev/null)"
check "issue snapshot lines" 30 "$(wc -l < eval/issues.jsonl | tr -d ' ')"
for l in bug:8 enhancement:8 question:7 docs:7; do
  check "issues labelled ${l%%:*}" "${l##*:}" "$(jq -r 'select(.label=="'"${l%%:*}"'")|.number' eval/issues.jsonl | wc -l | tr -d ' ')"
done
check "issues.jsonl sha256" "$(cut -d' ' -f1 eval/issues.sha256)" "$(sha256sum eval/issues.jsonl | cut -d' ' -f1)"
finish
