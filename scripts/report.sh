#!/usr/bin/env bash
# Per-call tokens, cost and latency report from an agent's own log.
#   scripts/report.sh copilot [events.jsonl]
# Without a file it uses the newest session overall (Copilot CLI).
# Settings (environment): BUDGET_USD=0.50 BUDGET_MS=60000 PER_DAY=200 DAYS=22
set -euo pipefail
cd "$(dirname "$0")/.."
agent="${1:?usage: report.sh copilot [file]}"; file="${2:-}"
case "$agent" in
  copilot)
    [ -n "$file" ] || file="$(ls -t "${COPILOT_HOME:-$HOME/.copilot}"/session-state/*/events.jsonl | head -1)"
    filter=scripts/lib/copilot-calls.jq ;;
  *) echo "agent must be copilot" >&2; exit 2 ;;
esac
echo "Source: $agent log ($(basename "$(dirname "$file")")/$(basename "$file")); prices: $(jq -r '.fetched + ", " + .unit' scripts/lib/prices.json)"
echo
jq -s -c -f "$filter" "$file" | tr -d '\r' \
  | jq -r --slurpfile prices scripts/lib/prices.json \
      --argjson budget_usd "${BUDGET_USD:-0.50}" --argjson budget_ms "${BUDGET_MS:-60000}" \
      --argjson per_day "${PER_DAY:-200}" --argjson days "${DAYS:-22}" -L scripts/lib -f scripts/lib/report.jq | tr -d '\r'
