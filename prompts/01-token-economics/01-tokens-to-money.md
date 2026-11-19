# Turning token counts into money

Goal: compute what one agent call, one request and one month cost from token counts and a per-model price list, and see how model choice changes the bill.

Prices are in `scripts/lib/prices.json` (source and date inside, USD per million tokens). Run everything from the project root.

## Prompt

```
A call to claude-haiku-5-5 used 2 input tokens, 87 output tokens, 0 cache read tokens and 31,053 cache write tokens (5 minute cache). A second call to the same model used 2 input, 340 output, 31,053 cache read and 5,798 cache write tokens.
Using only the prices in scripts/lib/prices.json, give me: the cost of each call, the cost of the request (both calls), and the monthly cost at 200 requests a day for 22 days.
Show the formula and the price you used for each token type. Then price the first call's tokens on claude-sonnet-5-5 and claude-opus-5-5.
```

Paste it into an interactive session started in the project root (not verified by the build), or run it headless with the same text (save it as `prompt.txt` first):

```bash
copilot -p "$(cat prompt.txt)" --model claude-haiku-5.5 --max-ai-credits 30
```

```powershell
copilot -p (Get-Content -Raw prompt.txt) --model claude-haiku-5.5 --max-ai-credits 30
```

## Expected answer

Computed with `jq` from `prices.json`, not by an agent. Price per token type for Haiku 5.5: input 0.10, output 0.50, cache read 0.01, cache write (5 minute) 0.125, all per million tokens.

| Item | Result |
|---|---|
| Call 1 | $0.003925 (2 x 0.10 + 87 x 0.50 + 31,053 x 0.125, divided by 1,000,000) |
| Call 2 | $0.001205 |
| Request (both calls) | $0.005131 |
| Month (200 x 22 = 4,400 requests) | $22.58 |
| Call 1 tokens on Sonnet 5.5 | $0.0785 (about 20 times Haiku) |
| Call 1 tokens on Opus 5.5 | $0.1570 (about 40 times Haiku) |

These are the real tokens of an early cold-cache baseline run of this lab, and the cost report printed $0.0039, $0.0012, $0.0051 and $22.58 for the same tokens.

## Check yourself

- The cache write is the biggest term of call 1: 31,053 x 0.125 / 1,000,000 = $0.003882 of the $0.003925. Cache read is 12.5 times cheaper than a cache write for Haiku.
- If the agent used a different cache write price (1 hour: 0.20) or forgot cache tokens, the numbers differ. Ask which price it used for each token type.
- A figure the agent states without a price from the file is an estimate; reject it.
