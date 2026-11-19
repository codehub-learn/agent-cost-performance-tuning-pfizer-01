#!/usr/bin/env bash
# PreToolUse hook for Copilot CLI: blocks the next tool call when the CURRENT request (since the last user prompt) has
# already spent more than the budget. Exit code 2 denies the call; the reason goes to stderr.
#   BUDGET_USD (default 0.50)   BUDGET_MS (default 60000)
# Fails open (allows the call, warns on stderr) when the log cannot be read yet or jq fails.
cd "$(dirname "$0")/../.." || exit 0
in="$(cat)"
tp=""; file=""
if [ -z "$tp" ]; then
  sid="$(jq -r '.sessionId // empty' <<<"$in" 2>/dev/null | tr -d '\r')"
  agent=copilot; file="${COPILOT_HOME:-$HOME/.copilot}/session-state/$sid/events.jsonl"
fi
[ -f "$file" ] || exit 0
if ! out="$(jq -s -c -f "scripts/lib/$agent-calls.jq" "$file" | tr -d '\r' \
    | jq -r -L scripts/lib --slurpfile prices scripts/lib/prices.json -f scripts/lib/guard.jq | tr -d '\r')"; then
  echo "budget-guard: could not read $agent log, allowing the call" >&2; exit 0
fi
cost="${out% *}"; ms="${out#* }"
budget_usd="${BUDGET_USD:-0.50}"; budget_ms="${BUDGET_MS:-60000}"
if awk -v c="$cost" -v b="$budget_usd" 'BEGIN{exit !(c>b)}'; then
  echo "budget-guard: this request has spent \$$cost, over the \$$budget_usd budget. Stop and report to the user." >&2; exit 2
fi
if awk -v m="$ms" -v b="$budget_ms" 'BEGIN{exit !(m>b)}'; then
  echo "budget-guard: this request has taken ${ms} ms, over the ${budget_ms} ms budget. Stop and report to the user." >&2; exit 2
fi
exit 0
