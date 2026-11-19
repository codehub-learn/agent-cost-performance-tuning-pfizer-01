# Instrumenting the agent to log tokens, latency and cost per call

Goal: read tokens, latency and cost for every model call from the agent's own log, and check one row by hand.

Copilot CLI already writes what is needed: an events file per session (`~/.copilot/session-state/<session>/events.jsonl`). `scripts/report` turns it into a table. The `cost-report` skill wraps it.

## Steps

1. Make a small run so there is something to read. With the work folder that `prepare-work` builds (not verified by the build; this uses quota, model Haiku 5.5, cap 30 AI credits). Run the prompt from `../triage-work`:

   ```bash
   bash scripts/prepare-work.sh
   cd ../triage-work
   copilot -p "$(cat triage-prompt.txt)" --model claude-haiku-5.5 --max-ai-credits 30
   cd ../agent-cost-performance-tuning
   ```

   ```powershell
   pwsh -NoProfile -File scripts/prepare-work.ps1
   Set-Location ../triage-work
   copilot -p (Get-Content -Raw triage-prompt.txt) --model claude-haiku-5.5 --max-ai-credits 30
   Set-Location ../agent-cost-performance-tuning
   ```

   The run is stored as a session folder under `~/.copilot/session-state/`; the newest one is the run you just made.

2. Prompt for the agent:

   ```
   Use the cost-report skill on the log file <path of the log from step 1>. Report tokens, cost and latency per call, the totals per request, and the call that costs the most. Say which agent and model it was.
   ```

   Or run the script yourself:

   ```bash
   bash scripts/report.sh copilot       # newest Copilot CLI session; pass an events.jsonl path to pick another
   ```

   ```powershell
   pwsh -NoProfile -File scripts/report.ps1 copilot      # newest Copilot CLI session; pass an events.jsonl path to pick another
   ```

## Expected answer

The report has three parts: a per-call table (model, input, output, cache read, cache write, cost, ms), a per-request table (calls, totals, `over budget` yes or no, the costliest call) and a monthly projection. A labels-only triage run makes 2 calls: call 1 reads the input file (a tool call), call 2 writes the answer. For the author's baseline:

| Call | Input | Output | Cache read | Cache write | Cost | ms |
|---|---|---|---|---|---|---|
| 1 | 2 | 87 | 0 | 31,053 | $0.0039 | 949 |
| 2 | 2 | 340 | 31,053 | 5,798 | $0.0012 | 2,016 |

Your numbers differ (cache state, output length), but the shape holds: call 1 is the expensive one on a cold cache, because it writes the prefix.

## Check yourself

- Recompute one row with the price file (see `01-tokens-to-money.md`). The script and your hand calculation must agree to the printed precision.
- Tokens and cost come from the log; the agent must not say "about" for a number the table prints.
- Where the log exposes less, the report says so; do not fill the gap with a guess.
- Not verified by the build: which Copilot CLI fields a given run exposes.
