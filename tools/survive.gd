extends SceneTree
## How a plain player fares: a bot (tools/survive_bot.gd) plays seeds 1..N from
## storey 1 to its death, a win, a stall (stuck) or the round limit, and this
## prints Markdown: per storey the runs that reached it, the deaths there and
## their top killers; the deaths in one blow from full health on storeys 1 and 2;
## and a summary. Same seed, same run.
## godot --headless --path . -s tools/survive.gd -- [--seeds=200]
## `just survive` splits the seeds over processes: `-- --shard=I/N --out=DIR`
## plays the seeds with index I mod N into DIR, and `-- --merge=DIR` prints.

const Bot := preload("res://tools/survive_bot.gd")
## Storeys with a table of one-blow deaths.
const BLOW_STOREYS := [1, 2]
const TOP := 3

var _seeds := 200
var _shard := Vector2i(0, 1)
var _out := ""
var _merge := ""


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			_seeds = int(arg.trim_prefix("--seeds="))
		elif arg.begins_with("--shard="):
			var part := arg.trim_prefix("--shard=").split("/")
			_shard = Vector2i(int(part[0]), int(part[1]))
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--merge="):
			_merge = arg.trim_prefix("--merge=")
	if _merge != "":
		_print(_load(_merge))
	else:
		var runs := _play()
		if _out != "":
			var f := FileAccess.open("%s/shard-%d.json" % [_out, _shard.x], FileAccess.WRITE)
			f.store_string(JSON.stringify(runs))
		else:
			_print(runs)
	quit()


## The runs of the seeds of this shard, as plain data.
func _play() -> Array:
	var runs := []
	for s in range(1, _seeds + 1):
		if s % _shard.y == _shard.x:
			runs.append(Bot.play(s))
	return runs


func _load(dir: String) -> Array:
	var runs := []
	for name in DirAccess.get_files_at(dir):
		runs.append_array(JSON.parse_string(FileAccess.get_file_as_string("%s/%s" % [dir, name])))
	runs.sort_custom(func(a, b): return a.seed < b.seed)
	for r in runs:  # JSON reads every number as a float
		r.visited = r.visited.map(func(d): return int(d))
	return runs


func _print(runs: Array) -> void:
	_say("# Survival of a plain player\n")
	_say(
		(
			"%d seeds, round limit %d, stuck after %d rounds without progress.\n"
			% [runs.size(), Bot.ROUND_LIMIT, Bot.STALL]
		)
	)
	_say("| storey | runs | deaths | percent | top killers |")
	_say("|---|---|---|---|---|")
	for depth in range(1, World.FLOORS + 1):
		var reached := runs.filter(func(r): return r.visited.has(depth))
		var dead := reached.filter(func(r): return r.end == "dead" and r.death.depth == depth)
		var killers := {}
		for r in dead:
			killers[r.death.killer] = killers.get(r.death.killer, 0) + 1
		var pct := 100.0 * dead.size() / reached.size() if not reached.is_empty() else 0.0
		_say(
			(
				"| %d | %d | %d | %.1f%% | %s |"
				% [depth, reached.size(), dead.size(), pct, _top(killers)]
			)
		)
	for depth in BLOW_STOREYS:
		_blows(runs, depth)
	var ends := {}
	for r in runs:
		ends[r.end] = ends.get(r.end, 0) + 1
	var deepest := runs.map(func(r): return int(r.deepest))
	deepest.sort()
	_say(
		(
			"\nmedian deepest storey %s, wins %d, dead %d, stuck %d, hit the limit %d"
			% [
				deepest[deepest.size() / 2] if not deepest.is_empty() else "-",
				ends.get("won", 0),
				ends.get("dead", 0),
				ends.get("stuck", 0),
				ends.get("limit", 0),
			]
		)
	)


## The deaths of storey `depth` in one blow from full health, by killer and
## spell, with the mean rounds until that death.
func _blows(runs: Array, depth: int) -> void:
	var blows := runs.filter(
		func(r): return r.end == "dead" and r.death.depth == depth and r.death.blow
	)
	_say("\nStorey %d, deaths in one blow from full health: %d\n" % [depth, blows.size()])
	if blows.is_empty():
		return
	_say("| killer | spell | deaths | mean rounds |")
	_say("|---|---|---|---|")
	var groups := {}
	for r in blows:
		groups.get_or_add("%s|%s" % [r.death.killer, r.death.spell], []).append(r.death.rounds)
	var keys := groups.keys()
	keys.sort_custom(func(a, b): return [-groups[a].size(), a] < [-groups[b].size(), b])
	for k in keys:
		var part: PackedStringArray = k.split("|")
		_say("| %s | %s | %d | %.1f |" % [part[0], part[1], groups[k].size(), _mean(groups[k])])
	_say("| all | | %d | %.1f |" % [blows.size(), _mean(blows.map(func(r): return r.death.rounds))])


func _mean(list: Array) -> float:
	return float(list.reduce(func(a, b): return a + b, 0)) / list.size()


## The `TOP` commonest keys with their counts, most first, ties by name.
func _top(counts: Dictionary) -> String:
	var keys := counts.keys()
	keys.sort_custom(func(a, b): return [-counts[a], a] < [-counts[b], b])
	return ", ".join(keys.slice(0, TOP).map(func(k): return "%s %d" % [k, counts[k]]))


func _say(line: String) -> void:
	print(line)
