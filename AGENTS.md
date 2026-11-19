# AGENTS.md

Lab: "AI Agent Cost and Performance Tuning". The learner measures and tunes the coding agent itself (GitHub Copilot CLI) on a real workload: triaging real issues of a pinned open-source repo (`mockito/mockito`). They read tokens, cost and latency from the agent's own logs, cut cost without losing quality, speed runs up, and pick the right model per task.

## Stack

- Agent: GitHub Copilot CLI. Tested with Copilot CLI 1.0.109; newer versions are expected to work, and `scripts/verify-lab` warns on a difference and checks that the scripts can still read the agent logs.
- Workload: `mockito/mockito` at a pinned commit (cloned into `data/`) and a fixed issue sample with the maintainers' labels (`eval/`). No database, no service. Source code only if a measurement cannot be done otherwise: Java 25, Maven 3.9+, never Python.
- Tools: the agent's built-in tools only, no MCP servers. Lab components live in `.github/` (skills, agents, instructions, hooks).
- Boundary: permission deny rules, hooks and spend caps (`--max-ai-credits`). A prompt is never the boundary.

## Safety rules for the agent

- Show the exact command or SQL before anything that changes state.
- Ask before any destructive or hard-to-reverse action, and say what it would affect.
- Use the narrowest tool or server that can do the job; say which one you use.
- If a tool blocks an action, report it. Do not look for a way around it.
- Never print secrets or connection strings.
- Never start a run without a spend cap, and say which model a run uses before it starts.
- Read measurements from the agent's own logs; never estimate a number you can read.
- Do not edit the user's global agent configuration (`~/.copilot`).

## Working method

- Verify results before presenting them: counts, sanity checks, a second way to compute the same number.
- If a request is ambiguous, ask one short clarifying question before acting.
- State assumptions and what you could not verify.

## Repo layout

- `docs/`: the instructor runbook and reference material (not in the course folder).
- `prompts/`: one folder per syllabus section, `01-token-economics` to `04-right-sizing-the-model`. Each holds one `.md` file per topic with the prompts and anything else the learner needs to reach that topic's goal, plus expected answers.
- `scripts/`: setup, reset and verify scripts (`.sh` and `.ps1`).
- `.github/`: the agent components (skills, agents, instructions, hooks).
- `data/`: the cloned workload repo (not in git).
- `eval/`: the fixed issue sample and ground-truth labels (in git).
- `logs/`: run logs and reports (not in git).

## Style

- Plain prose, no em dashes, write like a human.
