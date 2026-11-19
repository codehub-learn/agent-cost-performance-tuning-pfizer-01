# Rows (slurped) -> "cost_usd ms" of the CURRENT request (the last user prompt), for the budget guard.
include "cost";
(map(.req) | max) as $cur
| map(select(.req == $cur) | . + {cost: cost($prices[0].models[.model])})
| "\((map(.cost // 0) | add)) \((map(.ms // 0) | add))"
