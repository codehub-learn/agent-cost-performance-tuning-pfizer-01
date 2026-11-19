# Rows from copilot-calls.jq (slurped) -> markdown report.
# Args: $prices (--slurpfile of prices.json, so $prices[0]), $budget_usd and $budget_ms (per request), $per_day, $days (projection).
include "cost";
def r2: . * 100 | round / 100;
def r4: . * 10000 | round / 10000;
def money: if . == null then "n/a" else "$" + (. | r4 | tostring) end;
def row: "| " + (map(tostring) | join(" | ")) + " |";
(map(.req) | unique) as $reqs
| map(. + {req: (.req as $r | $reqs | index($r) + 1)})
| to_entries
| map(.value + {n: (.key + 1)} | . + {cost: cost($prices[0].models[.model])})
| . as $calls
| ($calls | map(select(.cost == null) | .model) | unique) as $unpriced
| ($calls | group_by(.req) | map({
    req: .[0].req,
    calls: length,
    in: (map(.in) | add), out: (map(.out) | add), cr: (map(.cr) | add), cw: (map(.cw5m + .cw1h) | add),
    cost: (if any(.[]; .cost == null) then null else (map(.cost) | add) end),
    ms: (if any(.[]; .ms == null) then null else (map(.ms) | add) end),
    worst: (max_by(.cost // 0))
  })) as $reqrows
| ($calls | length) as $nc
| "## Calls (\($nc))",
  "",
  "| # | req | model | in | out | cache read | cache write | cost | ms |",
  "|---|---|---|---|---|---|---|---|---|",
  ($calls[] | [.n, .req, .model, .in, .out, .cr, (.cw5m + .cw1h), (.cost | money), (.ms // "n/a")] | row),
  "",
  "## Requests (budget \($budget_usd | money) and \($budget_ms) ms per request)",
  "",
  "| req | calls | in | out | cache read | cache write | cost | ms | over budget | costliest call # |",
  "|---|---|---|---|---|---|---|---|---|---|",
  ($reqrows[] | [.req, .calls, .in, .out, .cr, .cw, (.cost | money), (.ms // "n/a"),
      ( [ (if .cost != null and .cost > $budget_usd then "cost" else empty end),
          (if .ms != null and .ms > $budget_ms then "time" else empty end) ] | if length == 0 then "no" else join("+") end ),
      .worst.n] | row),
  "",
  "## Per model",
  "",
  "| model | calls | in | out | cache read | cache write | cost |",
  "|---|---|---|---|---|---|---|",
  ($calls | group_by(.model)[] | [.[0].model, length, (map(.in) | add), (map(.out) | add), (map(.cr) | add),
      (map(.cw5m + .cw1h) | add), ((if any(.[]; .cost == null) then null else (map(.cost) | add) end) | money)] | row),
  "",
  (if ($unpriced | length) > 0 then "Unpriced models (not in prices.json, cost shown as n/a): \($unpriced | join(", "))\n" else empty end),
  ( [$reqrows[] | .cost] | if any(. == null) then "## Projection\n\nn/a, some calls are unpriced." else
      (add / length) as $avg
      | "## Projection\n\nAverage cost per request: \($avg | money). At \($per_day) requests a day for \($days) days: \($avg * $per_day * $days | r2 | tostring | "$" + .) a month." end )
