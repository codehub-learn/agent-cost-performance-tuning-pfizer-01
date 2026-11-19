# Copilot CLI events.jsonl (slurped) -> one row per model call.
# Copilot's inputTokens includes cached tokens, so uncached input = inputTokens - cacheRead - cacheWrite.
# Latency and time to first token are measured by Copilot itself.
(reduce .[] as $e ({n: 0, out: []};
   if $e.type == "user.message" then .n += 1
   elif $e.type == "session.usage_record" and $e.data.usage != null
     then .out += [{n: .n, u: $e.data.usage}]
   else . end) | .out)
| map(.u as $u | {
    req: .n,
    model: (($u.responseModel // $u.model) | sub("^(?<a>claude-[a-z]+-[0-9]+)[.](?<b>[0-9]+)$"; "\(.a)-\(.b)")),
    in: ($u.inputTokens - ($u.cacheReadTokens // 0) - ($u.cacheWriteTokens // 0)),
    out: $u.outputTokens,
    cr: ($u.cacheReadTokens // 0),
    cw5m: ($u.cacheWriteTokens // 0),
    cw1h: 0,
    ms: $u.duration,
    ttft_ms: ($u.timeToFirstTokenMs | if . == null then null else round end),
    exact_latency: true
  })
