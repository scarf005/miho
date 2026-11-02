# The shard plan of `just test`: reads `<lines> <script>` lines, prints `<shard> <script>`.
# `times` holds the lines of tools/test_times.gd; a script with no time yet counts by its
# lines. A storey is built once on each shard that asks for it, so the longest script
# goes first, to the shard where it costs the least and that still has room, the emptiest
# of those. A shard has room up to ROOM times its share, which measured best: less spreads
# the scripts that share storeys, more leaves one shard longest.
BEGIN {
    ROOM = 1.2
    while ((getline line < times) > 0) {
        n = split(line, f, " ")
        if (f[1] == "STOREY") built[f[3]] = f[2]
        else {
            own[f[3]] = f[2]
            asks[f[3]] = line
        }
    }
    for (k in built) total += built[k]
}
{
    n = split($2, p, "/")
    script[NR] = $2
    start[NR] = (p[n] in own) ? own[p[n]] : $1 * 15
    wants[NR] = asks[p[n]]
    longest[NR] = start[NR]
    total += start[NR]
    m = split(wants[NR], f, " ")
    for (i = 4; i <= m; i++) longest[NR] += built[f[i]]
}
END {
    for (step = 1; step <= NR; step++) {
        next_one = 0
        for (i = 1; i <= NR; i++)
            if (!(i in placed) && (next_one == 0 || longest[i] > longest[next_one])) next_one = i
        placed[next_one] = 1
        m = split(wants[next_one], f, " ")
        best = -1
        for (shard = 0; shard < jobs; shard++) {
            cost = start[next_one]
            for (k = 4; k <= m; k++) if (!((shard, f[k]) in has)) cost += built[f[k]]
            room = load[shard] + cost <= ROOM * total / jobs
            score = room ? cost + load[shard] / 1000000 : 1000000000 + load[shard] + cost
            if (best < 0 || score < best_score) {
                best = shard
                best_score = score
                best_cost = cost
            }
        }
        load[best] += best_cost
        for (k = 4; k <= m; k++) has[best, f[k]] = 1
        print best, script[next_one]
    }
}
