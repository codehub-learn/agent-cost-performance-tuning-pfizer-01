# Lab guide: AI Agent Cost and Performance Tuning

This copy of the guide is for **GitHub Copilot CLI**, the agent your course uses.

Use this guide to do the lab, and to do it again on your own. You measure and tune the coding agent itself on a real job: triaging real issues of the open-source project `mockito/mockito` (is an issue a bug, an enhancement, a question or a docs request?). The agent reads one file of 30 real issues and answers with a label for each; the maintainers' own labels are the answer key. There is no database, no server and no MCP server to start.

The point is not the triage. The triage is a small, repeatable job that lets you read what an agent run really costs, change one thing, and see what the change did to the cost, the time and the quality. By the end you can answer three questions about any agent setup: what does one request cost, where does the time go, and which model is enough.

The course folder grows as the class moves on. You start with the setup files; the files for each section arrive with `git pull` when your instructor releases them. [Files you receive](#files-you-receive-with-each-release) explains what each batch is for.

## Syllabus

| Thematic unit | Topics |
|---|---|
| **Section 1. Token Economics of an Agent Run** | **Topic 1**<br>• Turning token counts into money: per-model pricing, cost per request, projected monthly spend<br><br>**Topic 2**<br>• Instrumenting the agent to log tokens, latency and cost per call<br><br>**Topic 3**<br>• Setting a cost and latency budget per request and finding which call blows it |
| **Section 2. Cutting Token Cost Without Losing Quality** | **Topic 4**<br>• Trimming the instruction file and the examples against a measured quality baseline<br><br>**Topic 5**<br>• Controlling retrieved context: how much the agent may read, and what it costs<br><br>**Topic 6**<br>• Prompt caching for the stable prefix |
| **Section 3. Latency Tuning** | **Topic 7**<br>• Measuring where wall-clock time goes: wait for the first token, generation, tool calls<br><br>**Topic 8**<br>• Streaming and early cancellation<br><br>**Topic 9**<br>• Running independent calls in parallel instead of one after another |
| **Section 4. Right-Sizing the Model** | **Topic 10**<br>• The same task on a small and a large model: quality, cost and latency side by side<br><br>**Topic 11**<br>• When the smaller, cheaper model wins<br><br>**Topic 12**<br>• A routing rule: cheap model first, a larger model only when the answer is uncertain |

## How to read this guide

Only the lines marked **Run** and **Paste** are things you execute. Each topic starts with **Why** (the reason for the exercise) and **What happens** (what the command or prompt does), so you know what you are about to start.

| Label | Meaning |
|---|---|
| **Why** | the question this topic answers and why it matters in real work |
| **What happens** | what the script or prompt does, what it reads and writes, and whether it uses quota |
| **Run** | a command for a terminal, in the course folder |
| **Paste** | a prompt for the agent; the text is in the named `prompts/` file |
| **Check** | what to look at before you trust a result |

Each topic has one file in `prompts/`: the goal, the prompts, the exact commands, the expected answer and a short "check yourself" list. The numbers in those files are the author's. Yours will differ in the last digit and in seconds; the shape of the result should be the same.

Your agent:

| | GitHub Copilot CLI |
|---|---|
| Start the agent in the course folder | `copilot` |
| First start | answer **yes** to trust the folder |
| Which model a session uses | `/model` |
| List the skills | `/skills` |
| List the agents | `/agent` |
| Where the numbers come from | the session events file, `~/.copilot/session-state/<session>/events.jsonl` |
| Spend cap for a headless run | `--max-ai-credits 30` |
| Reload after new files arrive | restart `copilot` |

## Rules of this lab

- **Read a number, never estimate it.** Tokens, cost and time come from the agent's own log (`scripts/report`). If an answer states a figure without a source, ask where it comes from. An agent that says "about 3,000 tokens" for a number the log prints is guessing.
- **Every run has a spend cap, and you know its model before it starts.** The scripts set both; if you start a run by hand, set both. A run without a cap can cost far more than you meant.
- **Compare only inside the same cache state.** A run more than 5 minutes after the previous one pays the cache write again. Run three times and use the median.
- **A prompt is never the boundary.** A prompt that says "read at most two files" is a request. Limits come from deny rules, hooks and spend caps, which you meet in sections 1 and 2.
- The agent suggests, you decide. Nothing is posted to GitHub; the issues are a fixed local sample.

## Before you start

| Need | Check |
|---|---|
| Git | `git --version` |
| Node.js (the script that reads some logs, and the budget guard, run on it) | `node --version` |
| `jq` (the scripts use it to read the logs) | `jq --version` |
| GitHub Copilot CLI, logged in | `copilot --version` |
| Network for the first clone (about 9 MB) | |

Tested with Copilot CLI 1.0.109, jq 1.8.1, Node 24. Newer versions are expected to work; `verify-lab` warns about a difference and checks that the scripts can still read the agent's log.

The runs use real quota but little of it: the whole course costs very little, and every run has a cap of 30 AI credits.

---

## Setup (before the first section)

### Step 1: Get the course folder and the data

**Why:** everybody must triage the same issues from the same code, otherwise your numbers cannot be compared with the expected ones. The Mockito repository is cloned into `data/mockito` at one fixed commit, and the 30 issues with the maintainers' labels are fixed in `eval/`.

**What happens:** `fetch-data` makes a shallow clone of Mockito at the pinned commit (about 9 MB, no line-ending conversion). `verify-data` checks the commit, the number of issues and labels, and the checksum of `eval/issues.jsonl`. Neither uses quota.

**Run** (bash):

```bash
git clone <course-repo-url> agent-tuning-lab
cd agent-tuning-lab
bash scripts/fetch-data.sh
bash scripts/verify-data.sh
```

**Run** (PowerShell):

```powershell
git clone <course-repo-url> agent-tuning-lab
cd agent-tuning-lab
pwsh -File scripts/fetch-data.ps1
pwsh -File scripts/verify-data.ps1
```

**Check:** `verify-data` ends with `ALL CHECKS PASSED`. Running the scripts again is harmless.

### Step 2: Check the lab

**Why:** a failing check now is cheaper than a confusing result later.

**What happens:** `verify-lab` lists every file that should be there for the releases you have, checks the tool versions, tests that `scripts/report` can still read your agent's log, and tests that the scorer gives 100% for the true labels and 0% for an empty answer. It uses no quota. It takes the number of the last release you have (0 to 4).

**Run:**

```bash
bash scripts/verify-lab.sh 0
```

```powershell
pwsh -NoProfile -File scripts/verify-lab.ps1 -Stage 0
```

**Check:** the last line is `ALL CHECKS PASSED`. A version warning is fine. A failure on "report found no tokens" means your agent's log format changed; tell your instructor before you go on.

---

## Section 1. Token Economics of an Agent Run

Goal: know what one call, one request and one month cost, read it from the agent's own log, and find the call that breaks a budget.

**First:** When your instructor says release 1 is out: pull it, verify it, then restart the agent.

```bash
git pull
bash scripts/verify-lab.sh 1
```

```powershell
git pull
pwsh -NoProfile -File scripts/verify-lab.ps1 -Stage 1
```

**Check:** the skill `cost-report` is listed (`/skills`). `scripts/report`, `scripts/prepare-work` and `scripts/hooks/budget-guard` are there.

### Topic 1: Tokens to money

**Why:** an agent bill is the sum of four kinds of tokens at four different prices: new input, output, cache reads and cache writes. If you cannot price a call by hand, you cannot tell whether a number in a report is right.

**What happens:** you give the agent real token counts from an earlier run and the price file `scripts/lib/prices.json` (USD per million tokens, with the source and the date inside). It must compute the cost of each call, of the request, and of a month at 200 requests a day, and show the price it used for each token type. You then price the same tokens on a larger model.

**Paste:** `prompts/01-token-economics/01-tokens-to-money.md`.

**Check:**
- Your numbers match the expected answer in the file to the last digit.
- The cache write is the biggest term of the first call. A cache read is 12.5 times cheaper than a cache write on Haiku.
- A figure the agent states without a price from the file is an estimate; ask which price it used.

### Topic 2: Per-call tokens, cost and latency

**Why:** you cannot tune what you cannot see. Both agents already write down every model call; the work is reading it.

**What happens:** `prepare-work` builds a clean work folder next to the course folder (`../triage-work`) with the issue file and the triage prompt, and without the course's own `AGENTS.md`, so the run carries nothing you did not choose. You make one small headless run there (this uses quota, model Haiku 5.5, cap $0.50). `scripts/report` then reads the agent's log and prints one row per model call, the totals per request, and a monthly projection. The `cost-report` skill does the same inside the agent.

**Run** the commands in `prompts/01-token-economics/02-instrument-per-call.md`:

```bash
bash scripts/prepare-work.sh
bash scripts/report.sh copilot <events-file>
```

```powershell
pwsh -NoProfile -File scripts/prepare-work.ps1
pwsh -NoProfile -File scripts/report.ps1 copilot <events-file>
```

**Check:**
- One row per model call; call 1 costs the most on a cold cache because it writes the prefix to the cache.
- Recompute one row with the price file. The script and your hand calculation agree to the printed precision.
- Without a file, `report` reads the newest session, which is probably your current one. Pass the path of the triage run.

### Topic 3: A budget per request

**Why:** an agent that loops or reads too much can spend your money before you notice. A report tells you after the fact; a budget stops it.

**What happens:** `BUDGET_USD` and `BUDGET_MS` mark a request as over budget in the report, and name the call that blew it. The budget guard goes further: it is a hook that runs before every tool call, reads the agent's own log, and refuses the next call (exit code 2) once the current request has spent more than the budget. The spend cap of the run itself is the hard limit; the guard acts between tool calls.

**Run** the commands in `prompts/01-token-economics/03-budget-and-blowout.md`: set a tiny budget, read the report, then enable the guard and watch it block.

The guard is already registered in `.github/hooks/budget-guard.json`. Start `copilot` in the course folder and answer yes when it asks to trust the folder.

**Check:**
- With a budget of $0.003, call 1 is the call over budget and the request total is over.
- With a tiny budget the guard exits 2 and prints that the request is over budget. The agent must report the block, not look for a way around it.
- The guard allows the call (and warns) when it cannot read the log. That is why the spend cap exists as well.

---

## Section 2. Cutting Token Cost Without Losing Quality

**First:** release 2 is out: pull it, verify it, then restart the agent.

```bash
git pull
bash scripts/verify-lab.sh 2
```

```powershell
git pull
pwsh -NoProfile -File scripts/verify-lab.ps1 -Stage 2
```

**Check:** the skill `triage-issues` and the rule `lean-instructions` are present; `scripts/score` and `scripts/run-variant` are there.

Goal: fewer tokens at the same accuracy. Quality is the share of issues labelled like the maintainers did, on a fixed 10-issue subset, scored by `scripts/score`. A cheaper run that scores lower is not a saving.

### Topic 4: Trim the instruction file

**Why:** an instruction file is paid for on every request. Long guidelines and a dozen worked examples feel safe, but you only know they help if the score shows it.

**What happens:** `run-variant` makes a clean work folder, copies one instruction file variant into it as `AGENTS.md` (`bloated`: 9.1 KB with 12 examples, `trimmed`: 0.7 KB, `minimal`: 0.2 KB, or `none`), runs the triage headless on Haiku 5.5 with `copilot -p` (with no variant, no custom instructions are loaded), scores the answer, reads the cost from the agent's log, and appends one line to `logs/variants.tsv`. With `3` it does this three times. It uses quota.

**Run** the four variants three times each, as in `prompts/02-cutting-token-cost/01-trim-prompt-and-examples.md`:

```bash
for v in bloated trimmed minimal none; do bash scripts/run-variant.sh $v 3; done
```

```powershell
foreach ($v in 'bloated', 'trimmed', 'minimal', 'none') { pwsh -NoProfile -File scripts/run-variant.ps1 $v -Runs 3 }
```

**Paste** the prompt from the file to have the agent read `logs/variants.tsv`.

**Check:**
- The median accuracy is the same for all four; the bloated file only adds input tokens and cost.
- One issue of difference between two runs is noise. Do not conclude from one run.

### Topic 5: Control retrieved context

**Why:** letting the agent read project docs feels like it should help. This measures what it costs and whether it helps, then limits it with a boundary that holds.

There are four retrieval modes, each with its own prompt file: `none` (no lookup), `readme` (one file), `capped` (two files, 60 lines each) or `open` (anything). A prompt that says "at most two files" is only a request, so the run denies the shell with `--deny-tool`.

**Run** the four modes, as in `prompts/02-cutting-token-cost/02-control-retrieved-context.md`:

```bash
for m in none readme capped open; do bash scripts/run-variant.sh none 3 $m; done
```

```powershell
foreach ($m in 'none', 'readme', 'capped', 'open') { pwsh -NoProfile -File scripts/run-variant.ps1 none -Runs 3 -Mode $m }
```

**Check:**
- `open` costs about ten times `none` and does not raise the accuracy, because the label needs the issue text, not the docs.
- Input tokens add up every call, including cache reads, so many calls inflate them.
- In the `capped` runs the agent also used the shell although only Read was allowed: `--allowedTools` pre-approves, it does not forbid.

### Topic 6: Prompt caching

**Why:** the part of a request that never changes (system prompt, instruction file, tool definitions) can be read from a cache at one tenth of the price. This shows how much that is worth and when it stops being true.

**What happens:** `run-variant` runs the same variant three times in a row. The first run writes the prefix to the cache; the later ones read it. Copilot CLI has no switch to turn caching off, so this topic observes the cache instead of switching it. It uses quota.

**Run** the commands in `prompts/02-cutting-token-cost/03-prompt-caching.md`.

**Check:**
- The warm run is about two thirds cheaper than the uncached run, with the same accuracy.
- The saving holds only if requests arrive within the 5-minute cache lifetime. After a longer gap the next request pays the write again.

---

## Section 3. Latency Tuning

**First:** release 3 is out: pull it, verify it, then restart the agent.

```bash
git pull
bash scripts/verify-lab.sh 3
```

```powershell
git pull
pwsh -NoProfile -File scripts/verify-lab.ps1 -Stage 3
```

**Check:** the skill `latency-report` is present; `scripts/run-stream` and `scripts/latency` are there.

Goal: see where the wall-clock time goes, and what streaming, early cancel and parallel calls really save. These are measurements, and some of the results are "it makes no difference". That is a result too.

### Topic 7: Where the time goes

**Why:** before you try to make a run faster, find out what it is waiting for. Waiting for the first token, generating text and waiting for tools need different fixes.

**What happens:** `run-stream` runs the triage headless with `copilot -p`. `latency` then splits the wall clock of the request into wait to first token, generation and tool wait, read from the session's events file (Copilot CLI measures the wait and the call duration itself). It uses quota.

**Run** the commands in `prompts/03-latency-tuning/01-where-time-goes.md`.

**Check:**
- The columns add up to the wall clock, with a leftover near zero. A large or negative leftover means the attribution is wrong.
- Generation is the largest share; tool wait is small.
- Single runs vary by several seconds. Use several runs before comparing.

### Topic 8: Streaming and early cancel

**Why:** if you only need the first few answers, you can stop paying for the rest. But does stopping early really save time?

**What happens:** a scripted Copilot CLI run cannot be cancelled early, so you run the full task and read the wait to the first token of each call. That wait is paid before any answer line can appear, which is what early cancel could not save.

**Run** the commands in `prompts/03-latency-tuning/02-streaming-and-early-cancel.md`.

**Check:**
- The wait to the first token of each call is a large share of the wall clock, and no early cancel can remove it.

### Topic 9: Parallel calls

**Why:** reading five files one at a time makes five round trips; reading them in one message makes one. Where does that show up: in time, in calls or in cost?

**What happens:** `run-stream` takes two prompts that ask for the same five reads, one file per message (`seq`) and all five in one message (`par`). You run each three times and compare the model calls, the wait and the wall clock.

**Run** the commands in `prompts/03-latency-tuning/03-parallel-calls.md`.

**Check:**
- Count model calls from the report, not from the agent's own turn counter, which says the same for both modes.
- The parallel runs use fewer model calls and a little less waiting and cost, but the wall clock is within noise: the reads take milliseconds, and writing the answers dominates. Say what you would have to measure to be sure.

---

## Section 4. Right-Sizing the Model

**First:** release 4 is out: pull it, verify it, then restart the agent.

```bash
git pull
bash scripts/verify-lab.sh 4
```

```powershell
git pull
pwsh -NoProfile -File scripts/verify-lab.ps1 -Stage 4
```

**Check:** the agents `triage-small` and `triage-large` are listed; `scripts/route` is there.

Goal: choose the cheapest model that is good enough, and write the rule down.

### Topic 10: Small against large

**Why:** model choice is the biggest cost lever, and it is usually made by habit. Measure it.

**What happens:** `run-variant` takes the model from `MODEL`. The same triage runs three times each on Haiku 5.5, Sonnet 5.5 and Opus 5.5, with the same cap. You compare accuracy, cost and call time. It uses quota: about $0.10 for the nine runs, most of it the cold Opus run.

**Run** the commands in `prompts/04-right-sizing-the-model/01-small-vs-large.md`.

**Check:**
- Accuracy is about the same; the warm cost differs by an order of magnitude.
- The cold run dominates the large models' bill, because the prefix is written to the cache at a higher price.
- This is a short classification task. A reasoning-heavy task can look different.

### Topic 11: When small wins

**Why:** if the large model does not beat the small one, find out why before you decide.

**What happens:** you list the issues all models get wrong, with the maintainers' labels and titles, and ask `triage-small` and `triage-large` (the same task on two models) to explain.

**Paste** the prompts in `prompts/04-right-sizing-the-model/02-when-small-wins.md`.

**Check:** the wrong answers are mostly issues whose maintainer label looks arbitrary (a bug report labelled `question`), so quality has a ceiling near 9 of 10 whatever the model.

### Topic 12: A routing rule

**Why:** the usual compromise is cheap model first and a larger one when the cheap one is unsure. Does it pay?

**What happens:** `route` runs Haiku first, asks for a confidence, and sends the issues below a threshold to Sonnet. You try thresholds 0, 0.6 and 0.8 and compare cost, accuracy and time with Haiku alone.

**Run** the commands in `prompts/04-right-sizing-the-model/03-routing-rule.md`:

```bash
bash scripts/route.sh 0
bash scripts/route.sh 0.6
bash scripts/route.sh 0.8
```

```powershell
pwsh -NoProfile -File scripts/route.ps1 -Threshold 0
pwsh -NoProfile -File scripts/route.ps1 -Threshold 0.6
pwsh -NoProfile -File scripts/route.ps1 -Threshold 0.8
```

**Check:**
- Routing did not improve accuracy and cost several times more than Haiku alone once the cache is warm.
- Confidence is a poor signal here: the issue Haiku always gets wrong comes with a high confidence.
- Write down your own rule with the numbers: use the cheap model alone, or route, and why.

---

## Files you receive with each release

The course folder is released in five batches. Batch 0 is what you clone; batches 1 to 4 arrive with `git pull` at the start of each section. Files are only ever added, so a pull never overwrites your work. After each pull, restart your agent.
Skills, agents and rules are generated for Copilot CLI into `.github/skills/`, `.github/agents/`, `.github/instructions/` and `.github/hooks/`.

### Release 0: setup (`git clone`)

| File or folder | Role |
|---|---|
| `AGENTS.md` | Standing instructions for the agent: the lab, the safety rules (spend caps, no secrets), the working method. |
| `eval/` | The 30 issues with the maintainers' labels, their checksum, and the fixed 10-issue subset. |
| `scripts/fetch-data`, `verify-data` | Clone Mockito at the pinned commit; check it and the issue file. |
| `scripts/verify-lab`, `reset-lab` | Check the folder and the tools; clean up after your runs. |
| `scripts/course-stages.txt`, `scripts/lib/check.*` | The list of what each release contains; helpers for the checks. |
| `.gitignore`, `.gitattributes` | Keep `data/` and `logs/` out of git; keep line endings stable so the checksum survives. |
| `LAB-GUIDE.md` | This guide. |

### Release 1: start of section 1

| File or folder | Role |
|---|---|
| `prompts/01-token-economics/` | The three topic files. |
| `scripts/prepare-work` | Builds the clean work folder `../triage-work` for a run. |
| `scripts/report` | Prints per-call tokens, cost and latency from the agent's own log. |
| `scripts/hooks/budget-guard` | The budget guard: refuses the next tool call when the request is over budget. |
| `scripts/lib/` | The price file and the `jq` filters that read the logs. |
| `.github/skills/cost-report`, `.github/hooks/budget-guard.json` | The cost report skill and the guard registration. |

### Release 2: start of section 2

| File or folder | Role |
|---|---|
| `prompts/02-cutting-token-cost/` | The three topic files. |
| `scripts/score` | Scores a run against the maintainers' labels. |
| `scripts/run-variant` | Runs the triage several times with one instruction variant and one retrieval mode; logs to `logs/variants.tsv`. |
| `eval/variants/` | The `bloated`, `trimmed` and `minimal` instruction files. |
| `scripts/lib/triage-prompt-*.txt` | The prompts of the retrieval modes. |
| `.github/skills/triage-issues`, `.github/instructions/lean-instructions.instructions.md` | The same, generated for Copilot CLI. |

### Release 3: start of section 3

| File or folder | Role |
|---|---|
| `prompts/03-latency-tuning/` | The three topic files. |
| `scripts/run-stream` | A triage run with every stream line timestamped; optional early cancel. |
| `scripts/latency` | Splits the wall clock of a run into wait, generation and tool wait. |
| `scripts/lib/triage-prompt-seq.txt`, `triage-prompt-par.txt` | The sequential and the parallel prompt. |
| `.github/skills/latency-report` | The latency report skill. |

### Release 4: start of section 4

| File or folder | Role |
|---|---|
| `prompts/04-right-sizing-the-model/` | The three topic files. |
| `scripts/route` | The routing run: cheap model first, a larger one below a confidence threshold. |
| `.github/agents/triage-small.agent.md`, `triage-large.agent.md` | The two triage agents, generated for Copilot CLI. |

---

## Start over

**Why:** to repeat a measurement from a clean state, or to leave the folder as you found it.

**What happens:** `reset-lab` lists what it would delete (a dry run), and deletes only with the flag: the run logs in `logs/`, the work folder `../triage-work` and the opt-in settings. It keeps the data clone unless you ask (`--data`), and never touches the files you were released.

**Run** (bash):

```bash
bash scripts/reset-lab.sh          # dry run
bash scripts/reset-lab.sh --yes    # deletes
bash scripts/verify-lab.sh <stage>
```

**Run** (PowerShell):

```powershell
pwsh -File scripts/reset-lab.ps1
pwsh -File scripts/reset-lab.ps1 -Yes
pwsh -File scripts/verify-lab.ps1 -Stage <stage>
```

## Files you create during the lab

| File | What it is |
|---|---|
| `data/mockito/` | The pinned clone of Mockito. Not in git. |
| `logs/` | Run logs: `variants.tsv`, `route.tsv`, stream captures, predictions. Not in git. |
| `../triage-work/` | The clean work folder for headless runs, next to the course folder. |

## If something goes wrong

| Symptom | Cause and fix |
|---|---|
| `verify-lab` says `missing ...` | You did not pull a release, or the instructor has not pushed it yet. Run `git pull`, or ask. |
| New skills or agents do not appear after `git pull` | Restart the agent; it reads them only at startup. |
| `report` shows the wrong session or the current one | Without a file it reads the newest session. Pass the transcript or events file path. |
| Costs differ a lot between identical runs | Cache state. The first run writes the prefix; a run within 5 minutes reads it. Compare runs in the same state, or compare tokens. |
| Accuracy is 8 of 10 one run and 9 of 10 the next | One issue is within noise. Use three runs and the median. |
| The budget guard never fires | The folder is not trusted, or `copilot` was not started in the course folder. Restart it there and accept the hook. |
| `jq: Bad JSON in --slurpfile` or an error with `<(...)` on Windows | Windows `jq` cannot read bash process substitution. Pass a real file. |
| PowerShell scripts fail in Windows PowerShell 5.1 | Use `pwsh` (PowerShell 7). The scripts were not tested on 5.1. |
| `verify-lab` fails on "report found no tokens" | The agent's log format changed. Tell your instructor. |
| Git warns `LF will be replaced by CRLF` | Harmless on Windows; `.gitattributes` keeps the scripts and `eval/` on LF. |
