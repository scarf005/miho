extends GutTest
## Storey 1 stands on outside ground: no sky left, Miho starts inside the pavilion, a trail
## from its gate to the map's edge, fog in patches over the ground, and the same outside
## for the same seed.

const SEEDS := 12
const GROUND := [World.GRASS, World.BAMBOO, World.LEAVES, World.SHALLOW]


## The tiles joined to `from` by `tile` tiles, four ways a step.
func _joined(w: World, from: Vector2i, tile: int) -> Array[Vector2i]:
	var open := Grid.mask(w.tiles, Grid.table(func(t): return t == tile))
	var out: Array[Vector2i] = [from]
	for p in out:
		for d in Placement.SIDES:
			if Grid.inside(p + d) and open[Grid.index(p + d)] == 1 and p + d not in out:
				out.append(p + d)
	return out


## How many outside tiles (those that breathe fog or did) of `w` are `tile`.
func _count(w: World, tile: int) -> int:
	return w.vents.keys().filter(func(p): return w.tile(p) == tile).size()


## The first `n` seeds whose outside is `design`.
func _seeds_of(design: StringName, n: int) -> Array:
	var out := []
	var s := 0
	while out.size() < n:
		if RunPlan.outside(s) == design:
			out.append(s)
		s += 1
	return out


func test_storey_one_keeps_no_sky() -> void:
	for s in SEEDS:
		assert_false(World.SKY in Built.world(s).tiles, "seed %d" % s)


func test_a_storey_below_the_first_keeps_its_sky() -> void:
	var w := Built.storey(3, 2)
	assert_true(World.SKY in w.tiles)
	assert_true(w.vent_levels.is_empty())
	assert_eq(w.trail_end, Vector2i(-1, -1))
	assert_eq(w.gate, Vector2i(-1, -1))


## Every tile known and seen, and no creature but Miho, so a walk sees only the map.
func _open(w: World) -> World:
	w.known.fill(1)
	w.seen = w.known.duplicate()
	w.actors.assign([w.player()])
	return w


func test_storey_one_starts_inside_the_pavilion_before_the_gate() -> void:
	for s in SEEDS:
		var w := Built.world(s)
		assert_false(w.tile(w.start) in GROUND, "seed %d starts inside" % s)
		assert_false(w.start in _joined(w, w.trail_end, World.COURTYARD), "seed %d" % s)
		assert_true(w.gate - w.start in Placement.SIDES, "seed %d starts before the gate" % s)
		assert_eq(w.player().pos, w.start)


func test_the_gate_leads_from_the_pavilion_onto_the_trail_to_the_edge() -> void:
	for s in SEEDS:
		var w := Built.world(s)
		assert_false(w.tile(w.gate) in GROUND, "seed %d" % s)
		assert_true(Placement.SIDES.any(func(d): return w.tile(w.gate + d) == World.COURTYARD))
		var end := w.trail_end
		assert_true(end.x in [0, Grid.W - 1] or end.y in [0, Grid.H - 1], "seed %d: an edge" % s)


func test_miho_walks_from_the_start_out_through_the_gate() -> void:
	for s in SEEDS:
		var w := _open(Built.world(s))
		var route := Travel.route(Travel.search(w), w.trail_end)
		assert_false(route.is_empty(), "seed %d walks to the trail's end" % s)
		assert_true(w.gate in route, "seed %d leaves through the gate" % s)


func test_exploring_with_the_gate_excluded_never_reaches_the_outside() -> void:
	for s in SEEDS:
		var w := _open(Built.world(s))
		var found := Travel.search(w, {w.gate: true})
		for p in w.vents.keys() + _joined(w, w.trail_end, World.COURTYARD):
			assert_eq(found.dist[Grid.index(p)], -1, "seed %d: %s" % [s, p])
		assert_gte(
			Travel.search(w).dist[Grid.index(w.trail_end)], 0, "seed %d: open without it" % s
		)


func test_the_trail_breathes_no_fog() -> void:
	for s in SEEDS:
		var w := Built.world(s)
		for p in _joined(w, w.trail_end, World.COURTYARD):
			assert_false(w.vents.has(p) or w.gas.has(p), "seed %d at %s" % [s, p])


func test_every_outside_tile_off_the_trail_breathes_fog_of_two_to_four() -> void:
	var w := Built.world(1)
	assert_gt(w.vents.size(), 100)
	for p: Vector2i in w.vents:
		assert_true(w.tile(p) in GROUND, "%s" % p)
		assert_between(w.vent_levels[p], 2, 4)
	assert_eq(w.vent_levels.keys().size(), w.vents.size())
	assert_true(w.vent_levels.values().has(2) and w.vent_levels.values().has(4))


func test_each_design_shows_its_ground() -> void:
	for s in _seeds_of(&"meadow", 3):
		var w := Built.world(s)
		assert_gt(_count(w, World.GRASS), w.vents.size() / 2, "meadow %d: mostly grass" % s)
		assert_gt(_count(w, World.LEAVES), 0, "meadow %d" % s)
	for s in _seeds_of(&"grove", 3):
		var w := Built.world(s)
		assert_gt(_count(w, World.BAMBOO), _count(w, World.GRASS), "grove %d: mostly bamboo" % s)
	var pools := 0
	var ground := 0
	for s in _seeds_of(&"waterside", 3):
		var w := Built.world(s)
		pools += _count(w, World.SHALLOW)
		ground += w.vents.size()
	assert_gt(pools, ground / 5, "waterside: pools")


## Vents on a block of 5 x 5 tiles at `at` that keep `level` (the usual one when 0).
func _bank(w: World, at: Vector2i, level: int) -> void:
	for y in range(at.y - 2, at.y + 3):
		for x in range(at.x - 2, at.x + 3):
			w.vents[Vector2i(x, y)] = Gas.FOG
			if level > 0:
				w.vent_levels[Vector2i(x, y)] = level


func test_a_vent_tops_up_to_its_own_level() -> void:
	var w := Arena.hall(Vector2i(2, 2))
	w.rng.seed = 5
	var banks := {2: Vector2i(8, 14), 4: Vector2i(26, 14), 0: Vector2i(44, 14)}
	for level: int in banks:
		_bank(w, banks[level], level)
	var thick := {2: false, 4: false, 0: false}
	for r in 60:
		Gas.tick(w)
		for level: int in banks:
			thick[level] = thick[level] or Gas.blocks(w, banks[level])
	assert_false(thick[2], "a vent of 2 never blocks sight")
	assert_true(thick[4], "a vent of 4 does")
	assert_true(thick[0], "and so does one with no level, which keeps %d" % Gas.VENT_LEVEL)


func test_fire_turns_the_fog_to_steam() -> void:
	var w := Arena.hall(Vector2i(2, 2))
	var at := Vector2i(30, 14)
	Gas.put(w, at, Gas.FOG, 3)
	Gas.light(w, at)
	assert_eq(Gas.at(w, at), Vector2i(Gas.STEAM, 3))


func test_one_seed_one_outside() -> void:
	for s in 3:
		var a := World.create(s)
		var b := World.create(s)
		assert_eq(a.tiles, b.tiles)
		assert_eq(a.vent_levels, b.vent_levels)
		assert_eq(a.gas, b.gas)
		assert_eq(a.trail_end, b.trail_end)
		assert_eq(a.start, b.start)
		assert_eq(a.gate, b.gate)
		assert_eq(a.rng.state, b.rng.state)


func test_the_outside_is_kept_as_she_left_it() -> void:
	var w := Built.world(2)
	var kept := {
		tiles = w.tiles.duplicate(),
		vents = w.vent_levels.duplicate(),
		trail = w.trail_end,
		gate = w.gate
	}
	Storeys.leave(w)
	Storeys.enter(w, 2)
	Storeys.leave(w)
	Storeys.enter(w, 1)
	assert_eq(w.tiles, kept.tiles)
	assert_eq(w.vent_levels, kept.vents)
	assert_eq(w.trail_end, kept.trail)
	assert_eq(w.gate, kept.gate)


func test_the_moon_lights_all_the_outside_ground_the_map_s_edge_too() -> void:
	for s in 3:
		var w := Built.world(s)
		var edge := 0
		for i in w.tiles.size():
			var p := Grid.at(i)
			var rim := Outside._edge(p) and w.tiles[i] in GROUND
			edge += 1 if rim else 0
			if rim or w.vents.has(p):
				assert_true(w.lit(p), "seed %d at %s" % [s, p])
		assert_gt(edge, 0)


func test_the_moon_lights_no_vent_but_those_outside() -> void:
	var w := Arena.hall(Vector2i(2, 2))
	var p := Vector2i(30, 14)
	assert_false(w.lit(p))
	w.vents[p] = Gas.FOG
	w._changed()
	assert_false(w.lit(p))


## Whether `p` stands between walls on two opposite sides, as a doorway does.
func _gap(w: World, p: Vector2i) -> bool:
	var wall := func(q): return Terrain.wall(w.tile(q))
	return (
		wall.call(p + Vector2i.LEFT) and wall.call(p + Vector2i.RIGHT)
		or (wall.call(p + Vector2i.UP) and wall.call(p + Vector2i.DOWN))
	)


## The room round `from`: the tiles joined to it, four ways a step, through no doorway,
## wall or sky.
func _room_of(w: World, from: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = [from]
	for p in out:
		for d in Placement.SIDES:
			var q := p + d
			var t := w.tile(q)
			if not Terrain.wall(t) and t != World.SKY and not _gap(w, q) and q not in out:
				out.append(q)
	return out


func test_the_room_miho_starts_in_holds_no_event_room_set_room_or_hidden_door() -> void:
	for s in 120:
		var w := World.new()
		w.rng.seed = s
		var me := Actor.new()
		me.id = w.new_id()
		me.kind = &"miho"
		w.actors.append(me)
		var made := FloorGen.build(w, &"", true)
		Outside.lay(w)
		var mine := w.rooms.filter(func(r): return r.grow(1).has_point(w.start))
		assert_ne(mine, [], "seed %d starts in a room or its doorway" % s)
		assert_false(made.get("room", Rect2i()) in mine, "seed %d: set room" % s)
		for r: Rect2i in mine:
			for p in w.secrets:
				assert_false(r.grow(1).has_point(p), "seed %d: hidden door at %s" % [s, p])
		var near: Array = Placement.SIDES.map(func(d): return w.start + d) + [w.start]
		var events: Array = w.sites.map(func(z): return z.at)
		for i in w.tiles.size():
			if w.tiles[i] == World.VEIL:
				events.append(Grid.at(i))
		for at: Vector2i in events:
			var room := _room_of(w, at)
			assert_false(near.any(room.has), "seed %d: event room at %s" % [s, at])
