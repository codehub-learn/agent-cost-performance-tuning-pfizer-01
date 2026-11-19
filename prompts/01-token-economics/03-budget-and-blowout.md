# Setting a cost-and-latency budget per request and finding which call blows it

Goal: set a budget per request, find the call that exceeds it, and make a guard that stops the next call once the budget is spent. The boundary is a hook and a spend cap, never a prompt.

## Find the call that blows the budget

```
Use the cost-report skill with BUDGET_USD=0.003 and BUDGET_MS=2500 on the log file <path of the triage run from topic 02>. Which request is over budget, and which call in it is the costliest? Say why that call is expensive.
```

The same through the script:

Not verified by the build:

```bash
BUDGET_USD=0.003 BUDGET_MS=2500 bash scripts/report.sh copilot
```

```powershell
$env:BUDGET_USD = '0.003'; $env:BUDGET_MS = '2500'; pwsh -NoProfile -File scripts/report.ps1 copilot
Remove-Item Env:BUDGET_USD, Env:BUDGET_MS
```

## Stop a run when the budget is spent

The guard is a PreToolUse hook (`scripts/hooks/budget-guard.sh` and `.ps1`). It reads the agent's own log and exits with code 2 to deny the next tool call when the current request is over `BUDGET_USD` or `BUDGET_MS`.

1. The hook is already registered in `.github/hooks/budget-guard.json` of your course folder. Start `copilot` there and answer yes when it asks to trust the folder.
2. Set a budget you will cross, start the agent from the course folder, ask for a task with several tool calls, and watch the next call get blocked:

   ```bash
   export BUDGET_USD=0.001
   copilot
   ```

   ```powershell
   $env:BUDGET_USD = '0.001'
   copilot
   ```

   When done, remove the variable:

   ```bash
   unset BUDGET_USD
   ```

   ```powershell
   Remove-Item Env:BUDGET_USD
   ```
3. Also set the spend cap of the run itself. The guard checks between tool calls; the cap bounds the whole run. Headless runs take `--max-ai-credits` (minimum 30):

   ```bash
   copilot -p "$(cat prompt.txt)" --model claude-haiku-5.5 --max-ai-credits 30
   ```

   ```powershell
   copilot -p (Get-Content -Raw prompt.txt) --model claude-haiku-5.5 --max-ai-credits 30
   ```

Test the guard without an agent, on the newest session (not verified by the build):

```bash
sid=$(basename "$(dirname "$(ls -t ~/.copilot/session-state/*/events.jsonl | head -1)")")
printf '{"sessionId":"%s"}' "$sid" | bash scripts/hooks/budget-guard.sh; echo $?                      # 0
printf '{"sessionId":"%s"}' "$sid" | BUDGET_USD=0.0001 bash scripts/hooks/budget-guard.sh; echo $?   # 2
```

```powershell
$sid = (Get-ChildItem "$HOME/.copilot/session-state/*/events.jsonl" | Sort-Object LastWriteTime -Descending | Select-Object -First 1).Directory.Name
$json = @{ sessionId = $sid } | ConvertTo-Json -Compress
$json | pwsh -NoProfile -File scripts/hooks/budget-guard.ps1; $LASTEXITCODE                                  # 0
$env:BUDGET_USD = '0.0001'
$json | pwsh -NoProfile -File scripts/hooks/budget-guard.ps1; $LASTEXITCODE                                  # 2
Remove-Item Env:BUDGET_USD
```

## Expected answer

- With the cold-cache baseline tokens of topic 1 and `BUDGET_USD=0.003`, call 1 ($0.0039, a cold cache write of 31,053 tokens) is the call that blows the budget; call 2 ($0.0012) is under it. The request total $0.0051 is over. Your run will differ in the numbers (a warm cache makes call 1 much cheaper) but the costliest call is usually the first on a cold cache.
- The guard prints `budget-guard: this request has spent $<cost>, over the $<budget> budget. Stop and report to the user.` and exits 2 (measured: $0.0012 against a $0.0001 budget).
- The agent must report the block, not look for a way around it.

## Check yourself

- Not verified by the build: the hook firing inside a live Copilot CLI run, and the behaviour of `--max-ai-credits` when the cap is hit. Both are manual checks.
- The guard fails open (allows the call, warns) when it cannot read the log; the run-level cap is the hard limit.
