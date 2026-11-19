# Cost in USD of one call row (fields in, out, cr, cw5m, cw1h) at the prices of one model ($p is null when unpriced).
def cost($p): if $p == null then null else
  ((.in * $p.in) + (.out * $p.out) + (.cr * $p.cr) + (.cw5m * $p.cw5m) + (.cw1h * $p.cw1h)) / 1000000 end;
