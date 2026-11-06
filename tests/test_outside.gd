extends GutTest
## Storey 1 stands on outside ground: no sky left, a trail from the start to the map's edge,
## fog in patches over the ground, and the same outside for the same seed.

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


func test_start_is_outside_and_the_trail_runs_to_the_edge() -> void:
	for s in SEEDS:
		var w := Built.world(s)
		var trail := _joined(w, w.start, World.COURTYARD)
		assert_eq(w.tile(w.start), World.COURTYARD, "seed %d starts on the trail" % s)
		assert_true(w.trail_end in trail, "seed %d" % s)
		var end := w.trail_end
		assert_true(end.x in [0, Grid.W - 1] or end.y in [0, Grid.H - 1], "seed %d: an edge" % s)
		assert_ne(w.start, end, "seed %d starts off the exit" % s)
		assert_eq(w.player().pos, w.start)
		var open := Masks.floor_of(w)
		assert_gte(Grid.distance(w.start, open, w.stairs), 0, "seed %d walks to the stairs" % s)


func test_the_trail_breathes_no_fog() -> void:
	for s in SEEDS:
		var w := Built.world(s)
		for p in _joined(w, w.start, World.COURTYARD):
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
	for s in _seeds_of(&"waterside", 3):
		var w := Built.world(s)
		assert_gt(_count(w, World.SHALLOW), w.vents.size() / 5, "waterside %d: pools" % s)


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
		assert_eq(a.rng.state, b.rng.state)


func test_the_outside_is_kept_as_she_left_it() -> void:
	var w := Built.world(2)
	var kept := {
		tiles = w.tiles.duplicate(), vents = w.vent_levels.duplicate(), trail = w.trail_end
	}
	Storeys.leave(w)
	Storeys.enter(w, 2)
	Storeys.leave(w)
	Storeys.enter(w, 1)
	assert_eq(w.tiles, kept.tiles)
	assert_eq(w.vent_levels, kept.vents)
	assert_eq(w.trail_end, kept.trail)
