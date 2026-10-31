extends GutTest
## The three-lantern treasure room (세 등불 보물방): a room sealed off but for a
## seal that opens once the three dark lanterns in front of it are lit.

const WAIT := {t = &"wait"}
const SEEDS := 6
const SEAL := Vector2i(10, 8)
const LANTERNS: Array[Vector2i] = [Vector2i(6, 4), Vector2i(6, 12), Vector2i(3, 8)]

var _storeys: Array[World] = []


func before_all() -> void:
	for seed_value in SEEDS:
		for depth in range(1, World.FLOORS + 1):
			var w := World.create(seed_value)
			w.depth = depth
			FloorGen.build(w)
			_storeys.append(w)


func _label(w: World) -> String:
	return "seed %d storey %d" % [w.rng.seed, w.depth]


## Every walkable tile reachable from the start: with the seals shut, or open.
func _reach(w: World, open: bool) -> PackedInt32Array:
	var mask := Masks.floor_of(w, w.seals.keys(), func(_p): return open)
	return Grid.search(w.start, mask).dist


# --- where it lies -----------------------------------------------------------


func test_some_storeys_of_every_tier_have_one_vault() -> void:
	var tiers := {}
	for w in _storeys:
		assert_lte(w.seals.size(), 1, _label(w))
		if not w.seals.is_empty():
			tiers[w.tier()] = true
	assert_eq(tiers.size(), 9, "every tier")


func test_a_vault_is_shut_off_but_for_its_seal_and_holds_two_peaches() -> void:
	for w in _storeys:
		for at: Vector2i in w.seals:
			var label := "%s %s" % [_label(w), at]
			assert_eq(w.tile(at), World.SEAL, label)
			var shut := _reach(w, false)
			var open := _reach(w, true)
			var inside := []
			for i in w.tiles.size():
				if w.open_floor(Grid.at(i)):
					assert_gt(open[i], -1, label + " whole once open")
					if shut[i] < 0:
						inside.append(Grid.at(i))
			assert_gt(inside.size(), 0, label)
			var prize := w.peaches.filter(func(p): return inside.has(p))
			assert_eq(prize.size(), FloorGen.PRIZE, label)
			assert_false(inside.has(w.start) or inside.has(w.stairs) or inside.has(w.elixir), label)
			assert_true(w.actors.all(func(a): return not inside.has(a.pos)), label)


func test_its_three_lanterns_are_dark_and_reachable_with_the_seal_shut() -> void:
	for w in _storeys:
		for at: Vector2i in w.seals:
			var lanterns: Array = w.seals[at]
			assert_eq(lanterns.size(), 3, _label(w))
			var shut := _reach(w, false)
			for p: Vector2i in lanterns:
				assert_eq(w.tile(p), World.LANTERN_OUT, _label(w))
				assert_true(
					Grid.DIRS.any(func(d): return shut[Grid.index(p + d)] >= 0),
					"%s %s can be reached" % [_label(w), p]
				)


# --- opening it --------------------------------------------------------------


## A hall cut by a wall at x = 10 with the seal at SEAL; three dark lanterns
## west of it; Miho at (8, 8), in sight of the seal.
func _world() -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	for y in range(1, Grid.H - 1):
		for x in range(1, Grid.W - 1):
			w.tiles[Grid.index(Vector2i(x, y))] = World.FLOOR if x != SEAL.x else World.WALL
	w.tiles[Grid.index(SEAL)] = World.SEAL
	for p in LANTERNS:
		w.tiles[Grid.index(p)] = World.LANTERN_OUT
	w.seals[SEAL] = LANTERNS.duplicate()
	w.rooms.assign([Rect2i(1, 1, 9, Grid.H - 2)])
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.hp = 3
	me.max_hp = 3
	me.pos = Vector2i(8, 8)
	w.actors.append(me)
	w.depth = 4
	w.sense()
	return w


func _light(w: World, n: int) -> void:
	for p in LANTERNS.slice(0, n):
		w.tiles[Grid.index(p)] = World.LANTERN
	w._changed()


func test_a_seal_blocks_walking_sight_and_light_and_never_breaks() -> void:
	var w := _world()
	assert_false(w.open_floor(SEAL))
	assert_true(w.opaque(SEAL))
	assert_true(w.blocks_light(SEAL))
	assert_false(Terrain.breakable(w, SEAL))


func test_the_seal_opens_in_the_round_the_third_lantern_is_lit_and_says_so() -> void:
	var w := _world()
	_light(w, 2)
	w.act(WAIT)
	assert_eq(w.tile(SEAL), World.SEAL, "two of three")
	_light(w, 3)
	var before := w.clone()
	var events := w.act(WAIT)
	assert_eq(w.tile(SEAL), World.DOOR_OPEN)
	assert_eq(w.seals, {})
	assert_has(events.map(func(e): return e.t), &"unseal")
	assert_has(Messages.of(before, w, events).map(Messages.plain), "봉인문이 열렸다")


func test_a_broken_lantern_keeps_the_seal_shut_for_good() -> void:
	var w := _world()
	_light(w, 2)
	w.tiles[Grid.index(LANTERNS[2])] = World.LANTERN_BROKEN
	for i in 3:
		w.act(WAIT)
	assert_eq(w.tile(SEAL), World.SEAL)


func test_a_clone_keeps_the_seal_and_its_lanterns() -> void:
	var w := _world()
	assert_eq(w.clone().seals, {SEAL: LANTERNS})
	assert_eq(w.known_clone().seals, {SEAL: LANTERNS})


func test_hovering_the_seal_or_one_of_its_lanterns_tells_how_many_are_lit() -> void:
	var w := _world()
	_light(w, 2)
	var seal := Info.plain(Info.terrain(w, SEAL))
	assert_string_contains(seal, "꺼진 등불 셋이 모두 켜지면 열린다")
	assert_string_contains(seal, "켜진 등불 (2/3)")
	assert_string_contains(Info.plain(Info.terrain(w, LANTERNS[2])), "봉인문의 등불 (2/3)")
	assert_false(Info.plain(Info.terrain(w, Vector2i(20, 8))).contains("봉인문"))
