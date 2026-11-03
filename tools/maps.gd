extends SceneTree
## How sound and how varied the storeys of whole runs are. Every run climbs from the first
## storey by Storeys.enter, as a game does. Prints, per storey, the storeys built, the faults
## found on them, the share with an event room and with a set room, the rooms a storey has
## and the milliseconds a build takes; then, over the runs, the shapes, their overlap and
## their make-up. A skeleton named after the seeds forces every storey onto it, one storey
## to a seed, without the part about runs.
## godot --headless --path . -s tools/maps.gd -- 200 [skeleton]

const SEEDS := 200
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


## One row of the table per storey, over `seeds` storeys each on skeleton `kind`.
static func forced(seeds: int, kind: StringName) -> Array[String]:
	var kinds := EVENTS.kinds()
	var rows: Array[String] = _head()
	var totals := [0, 0, 0, 0, 0, 0]
	for depth in range(1, World.FLOORS + 1):
		var bad := {}
		var row := [0, 0, 0, 0, 0, 0]
		for seed_value in seeds:
			var w := World.create(seed_value * World.FLOORS + depth)
			w.depth = depth
			var from := Time.get_ticks_usec()
			var made := FloorGen.build(w, kind)
			_count(w, made, Time.get_ticks_usec() - from, kinds, row, bad)
		rows.append(_row(str(depth), row, bad))
		for k in row.size():
			totals[k] += row[k]
	rows.append(_row("전체", totals, {}))
	return rows


## The same table over `seeds` whole runs, then what the runs share.
static func runs(seeds: int) -> Array[String]:
	var kinds := EVENTS.kinds()
	var table := []
	var bad := []
	for depth in World.FLOORS:
		table.append([0, 0, 0, 0, 0, 0])
		bad.append({})
	var shapes := {}
	var twice := 0
	var again := 0
	var plans := {}
	var layouts := []
	var worst := {shape = &"", ms = 0.0}
	for seed_value in seeds:
		var w := World.create(seed_value)
		var plan := RunPlan.shapes(seed_value)
		var seen := {}
		plans[str(plan)] = true
		var layout := []
		for depth in range(1, World.FLOORS + 1):
			if depth > 1:
				Storeys.leave(w)
			var from := Time.get_ticks_usec()
			if depth > 1:
				Storeys.enter(w, depth)
			var spent := Time.get_ticks_usec() - from
			var built := w
			if depth == 1:
				# World.create has sensed already, which may find a hidden door.
				built = World.create(seed_value)
				from = Time.get_ticks_usec()
				FloorGen.build(built)
				spent = Time.get_ticks_usec() - from
			_count(built, {}, spent, kinds, table[depth - 1], bad[depth - 1])
			var shape := plan[depth - 1]
			var row: Array = shapes.get(shape, [0, 0.0, 0.0])
			row[0] += 1
			row[1] += spent / 1000.0
			row[2] = maxf(row[2], spent / 1000.0)
			shapes[shape] = row
			if spent / 1000.0 > worst.ms:
				worst = {shape = shape, ms = spent / 1000.0}
			if seen.has(shape):
				twice += 1
			seen[shape] = true
			layout.append(_layout(w))
		layouts.append(layout)
		again += 1 if RunPlan.shapes(seed_value) != plan else 0
	var rows: Array[String] = _head()
	for depth in World.FLOORS:
		rows.append(_row(str(depth + 1), table[depth], bad[depth]))
	rows.append("")
	rows.append("runs %d, different orders %d" % [seeds, plans.size()])
	rows.append("shape twice in one run: %d, plan differs on a second read: %d" % [twice, again])
	rows.append("| 모양 | 층 수 | 평균 ms | 최대 ms |")
	rows.append("|---|---|---|---|")
	for shape: StringName in shapes:
		var r: Array = shapes[shape]
		rows.append("| %s | %d | %.1f | %.1f |" % [shape, r[0], r[1] / r[0], r[2]])
	rows.append("slowest storey: %s %.1f ms" % [worst.shape, worst.ms])
	rows.append("same storey across runs, walkable overlap (below .441): %.3f" % _overlap(layouts))
	rows.append("floor make-up, cosine between storeys (below .882): %.3f" % _make_up(layouts))
	rows.append_array(_mazes(seeds))
	return rows


## Over the runs of `seeds` with a maze: how many have one, by concept and by storey, how many
## creatures live in it, and whether its prize is reached by walking through nothing that breaks.
static func _mazes(seeds: int) -> Array[String]:
	var rows: Array[String] = []
	var per := {}
	var depths := {}
	var guards := {}
	var found := 0
	var unreached := 0
	var breakable := 0
	var faulty := 0
	var first_seed := {}
	for concept: StringName in Labyrinth.CONCEPTS:
		per[concept] = 0
	for seed_value in seeds:
		var plan := RunPlan.labyrinth(seed_value)
		if plan.depth == 0:
			continue
		found += 1
		per[plan.concept] += 1
		depths[plan.depth] = depths.get(plan.depth, 0) + 1
		first_seed[plan.concept] = first_seed.get(plan.concept, [seed_value, plan.depth])
		var w := World.create(seed_value)
		w.depth = plan.depth
		FloorGen.build(w, Skeletons.LABYRINTH)
		var site := Labyrinth.site(w)
		faulty += 1 if not faults(w).is_empty() else 0
		var n := w.actors.filter(func(a): return not a.is_miho() and site.area.has_point(a.pos))
		guards[n.size()] = guards.get(n.size(), 0) + 1
		var prize: Vector2i = w.sites.filter(func(s): return s.kind == Labyrinth.PRIZE)[0].at
		var open := Masks.opened(w)
		unreached += 1 if Grid.search(w.start, open).dist[Grid.index(prize)] < 0 else 0
		if plan.concept == Labyrinth.ORTHODOX:
			for i in w.tiles.size():
				if site.area.has_point(Grid.at(i)) and Grid.at(i) != site.at:
					breakable += 1 if Terrain.wall(w.tiles[i]) else 0
	rows.append("runs with a maze (40%%): %d of %d, %.1f%%" % [found, seeds, 100.0 * found / seeds])
	rows.append("by concept: %s" % per)
	rows.append("by storey: %s" % depths)
	rows.append("creatures inside: %s" % guards)
	rows.append("mazes with a fault: %d, prize unreached: %d" % [faulty, unreached])
	rows.append("orthodox: breakable tiles in the maze but the door: %d" % breakable)
	rows.append("first seed and storey of each concept: %s" % first_seed)
	return rows


## What is walked on and how much of each tile kind: {open, kinds}.
static func _layout(w: World) -> Dictionary:
	var kinds := {}
	for t in w.tiles:
		if Tiles.walk[t] == 1 or t == World.POND:
			kinds[t] = kinds.get(t, 0) + 1
	return {open = Masks.floor_of(w), kinds = kinds}


## The mean Jaccard index of the walkable tiles of one storey in neighbouring runs.
static func _overlap(layouts: Array) -> float:
	var sum := 0.0
	var pairs := 0
	for i in range(1, layouts.size()):
		for depth in World.FLOORS:
			var a: PackedByteArray = layouts[i - 1][depth].open
			var b: PackedByteArray = layouts[i][depth].open
			var both := 0
			var any := 0
			for k in a.size():
				both += a[k] & b[k]
				any += a[k] | b[k]
			sum += float(both) / maxi(any, 1)
			pairs += 1
	return sum / maxi(pairs, 1)


## The mean cosine similarity of the tile kinds of two storeys of one run.
static func _make_up(layouts: Array) -> float:
	var sum := 0.0
	var pairs := 0
	for layout: Array in layouts:
		for i in layout.size():
			for j in range(i + 1, layout.size()):
				sum += _cosine(layout[i].kinds, layout[j].kinds)
				pairs += 1
	return sum / maxi(pairs, 1)


static func _cosine(a: Dictionary, b: Dictionary) -> float:
	var dot := 0.0
	var la := 0.0
	var lb := 0.0
	for k in a:
		dot += a[k] * b.get(k, 0)
		la += a[k] * a[k]
	for k in b:
		lb += b[k] * b[k]
	return dot / maxf(sqrt(la * lb), 1.0)


static func _head() -> Array[String]:
	return [
		"| 층 | 층 수 | 결함 | 사건 방 | 짜인 방 | 방 | ms |",
		"|---|---|---|---|---|---|---|",
	]


## Adds a storey to `row`: [storeys, faults, event rooms, set rooms, rooms, microseconds].
static func _count(
	w: World, made: Dictionary, spent: int, kinds: Dictionary, row: Array, bad: Dictionary
) -> void:
	row[5] += spent
	row[0] += 1
	row[2] += 1 if kinds.values().any(func(k): return not k.seals.call(w).is_empty()) else 0
	row[3] += 0 if made.is_empty() else 1
	row[4] += w.rooms.size() + w.sites.size()
	for fault in faults(w):
		row[1] += 1
		bad[fault] = bad.get(fault, 0) + 1


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
	var seeds := int(args[0]) if not args.is_empty() else SEEDS
	var kind := StringName(args[1]) if args.size() > 1 else &""
	print("\n".join(forced(seeds, kind) if kind != &"" else runs(seeds)))
	quit()
