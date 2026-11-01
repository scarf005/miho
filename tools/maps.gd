extends SceneTree
## How sound the storeys are and what comes up on them, storey by storey: the storeys
## built, the faults found on them, the share with an event room and with a set room,
## the rooms a storey has, and the milliseconds a build takes. A skeleton named after
## the seeds forces every storey onto it (Skeletons).
## godot --headless --path . -s tools/maps.gd -- 100 keep

const SEEDS := 100
const EVENTS := preload("res://tools/event_rooms.gd")


## Which of the rules every storey keeps `w` breaks, by name.
static func faults(w: World) -> Array[String]:
	var exit := w.elixir if w.depth >= World.FLOORS else w.stairs
	var shut := Masks.floor_of(w, w.traps.keys(), func(_p): return false)
	var out: Array[String] = []
	if not FloorGen.connected(w):
		out.append("whole")
	if not FloorGen.connected(w, w.traps.keys()):
		out.append("plates")
	if Grid.search(w.start, shut).dist[Grid.index(exit)] < 0:
		out.append("exit")
	if w.lit(w.start):
		out.append("start lit")
	if not w.lit(exit):
		out.append("exit dark")
	if w.secrets.size() != FloorGen.hidden_doors(w.depth):
		out.append("hidden doors")
	return out


static func measure(seeds: int, kind: StringName) -> Array[String]:
	var kinds := EVENTS.kinds()
	var rows: Array[String] = [
		"| 층 | 층 수 | 결함 | 사건 방 | 짜인 방 | 방 | ms |",
		"|---|---|---|---|---|---|---|",
	]
	var totals := [0, 0, 0, 0, 0, 0]
	for depth in range(1, World.FLOORS + 1):
		var bad := {}
		var row := [0, 0, 0, 0, 0, 0]
		for seed_value in seeds:
			var w := World.create(seed_value * World.FLOORS + depth)
			w.depth = depth
			var from := Time.get_ticks_usec()
			var made := FloorGen.build(w, kind)
			row[5] += Time.get_ticks_usec() - from
			row[0] += 1
			row[2] += 1 if kinds.values().any(func(k): return not k.seals.call(w).is_empty()) else 0
			row[3] += 0 if made.is_empty() else 1
			row[4] += w.rooms.size() + w.sites.size()
			for fault in faults(w):
				row[1] += 1
				bad[fault] = bad.get(fault, 0) + 1
		rows.append(_row(str(depth), row, bad))
		for k in row.size():
			totals[k] += row[k]
	rows.append(_row("전체", totals, {}))
	return rows


static func _row(name: String, r: Array, bad: Dictionary) -> String:
	return (
		"| %s | %d | %d %s | %.1f%% | %.1f%% | %.1f | %.1f |"
		% [
			name,
			r[0],
			r[1],
			bad if not bad.is_empty() else "",
			100.0 * r[2] / r[0],
			100.0 * r[3] / r[0],
			float(r[4]) / r[0],
			r[5] / 1000.0 / r[0],
		]
	)


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var kind := StringName(args[1]) if args.size() > 1 else &""
	print("\n".join(measure(int(args[0]) if not args.is_empty() else SEEDS, kind)))
	quit()
