---
name: cost-report
description: Report tokens, cost and latency per call of an agent run, read from the agent's own log, with a monthly projection and the call that blows the budget. Use when asked what a run cost, how many tokens it used, or which call was too expensive.
version: 1.0.1
---

# Cost report

Read every number from the agent's own log. Never estimate a number you can read.

1. Say which agent you are reporting on and which model the run used.
2. Run the report script from the project root:
   - bash: `bash scripts/report.sh copilot [events.jsonl]`
   - PowerShell: `pwsh -NoProfile -File scripts/report.ps1 copilot [events.jsonl]`

   Without a file it uses the newest session. Settings: `BUDGET_USD=0.50 BUDGET_MS=60000 PER_DAY=200 DAYS=22`.
3. Show the three parts it prints: the per-call table (input, output, cache read, cache write, cost, ms), the per-request totals with the "over budget" flag and the costliest call, and the monthly projection.
4. Name the call that blows the budget and say why (a cold cache write, a large tool result, long generation).
5. Cost depends on cache state. Compare runs only in the same state, or compare token counts.

Prices come from `scripts/lib/prices.json` (source and date are in the file). If a model is missing from it, say so; do not guess a price.
