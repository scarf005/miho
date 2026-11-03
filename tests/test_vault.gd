extends GutTest
## The three-lantern treasure room (세 등불 보물방): a room shut off but for a
## plain wall in front of it. The wall breaks like any other, and it collapses
## when the three dark lanterns standing in a row in front of it are lit.

const WAIT := {t = &"wait"}
const SEEDS := 12
const GATE := Vector2i(10, 8)
const LANTERNS: Array[Vector2i] = [Vector2i(7, 6), Vector2i(7, 8), Vector2i(7, 10)]

var _storeys: Array[World] = []


func before_all() -> void:
	for seed_value in SEEDS:
		for depth in range(1, World.FLOORS + 1):
			var w := Built.storey(seed_value, depth)
			if Labyrinth.site(w).is_empty():
				_storeys.append(w)


func _label(w: World) -> String:
	return "seed %d storey %d" % [w.rng.seed, w.depth]


## Every walkable tile reachable from the start: with the wall standing, or with
## the vault open (Masks.opened).
func _reach(w: World, open: bool) -> PackedInt32Array:
	var mask := Masks.opened(w) if open else Masks.floor_of(w)
	return Grid.search(w.start, mask).dist


## The open tiles Miho cannot reach with the wall standing.
func _inside(w: World) -> Array[Vector2i]:
	var shut := _reach(w, false)
	var out: Array[Vector2i] = []
	for i in w.tiles.size():
		if w.open_floor(Grid.at(i)) and shut[i] < 0:
			out.append(Grid.at(i))
	return out


# --- where it lies -----------------------------------------------------------


func test_some_storeys_of_every_tier_have_one_vault() -> void:
	var tiers := {}
	for w in _storeys:
		assert_lte(w.seals.size(), 1, _label(w))
		if not w.seals.is_empty():
			tiers[w.depth] = true
	assert_eq(tiers.size(), 9, "every tier")


func test_a_vault_is_shut_off_but_for_a_plain_wall_and_holds_two_peaches() -> void:
	for w in _storeys:
		for at: Vector2i in w.seals:
			var label := "%s %s" % [_label(w), at]
			assert_eq(w.tile(at), World.WALL, label)
			var open := _reach(w, true)
			var inside := _inside(w)
			var cut_off := []
			for i in w.tiles.size():
				if open[i] < 0 and w.open_floor(Grid.at(i)):
					cut_off.append(Grid.at(i))
			assert_eq(cut_off, [], label + " whole once open")
			assert_gt(inside.size(), 0, label)
			var prize := w.peaches.filter(func(p): return inside.has(p))
			assert_eq(prize.size(), Vault.PRIZE, label)
			assert_false(inside.has(w.start) or inside.has(w.stairs) or inside.has(w.elixir), label)
			assert_true(w.actors.all(func(a): return not inside.has(a.pos)), label)


func test_its_three_lanterns_stand_in_a_row_near_the_wall_and_are_reachable() -> void:
	for w in _storeys:
		for at: Vector2i in w.seals:
			var lanterns: Array = w.seals[at].duplicate()
			assert_eq(lanterns.size(), 3, _label(w))
			lanterns.sort_custom(
				func(a: Vector2i, b: Vector2i): return a.x < b.x or (a.x == b.x and a.y < b.y)
			)
			var step: Vector2i = lanterns[1] - lanterns[0]
			assert_eq(lanterns[2] - lanterns[1], step, _label(w) + " evenly spaced")
			assert_true(
				step in [Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(0, 2)],
				"%s a straight row, adjacent or one tile apart: %s" % [_label(w), step]
			)
			var shut := _reach(w, false)
			for p: Vector2i in lanterns:
				assert_eq(w.tile(p), World.LANTERN_OUT, _label(w))
				assert_between(
					Grid.cheb(p, at), 2, Vault.NEAR, "%s %s near the wall" % [_label(w), p]
				)
				assert_true(
					Grid.DIRS.any(func(d): return shut[Grid.index(p + d)] >= 0),
					"%s %s can be reached" % [_label(w), p]
				)


func test_every_storey_stays_whole_with_the_vault_shut_and_with_it_open() -> void:
	for w in _storeys:
		assert_true(FloorGen.connected(w), _label(w))
		var inside := _inside(w)
		var shut := _reach(w, false)
		var exit := w.elixir if w.depth >= World.FLOORS else w.stairs
		assert_gt(shut[Grid.index(exit)], -1, _label(w) + " exit")
		var cut_off := []
		for i in w.tiles.size():
			if shut[i] < 0 and w.open_floor(Grid.at(i)) and not inside.has(Grid.at(i)):
				cut_off.append(Grid.at(i))
		assert_eq(cut_off, [], "%s tiles outside the vault" % _label(w))


func test_every_wall_round_a_vault_breaks_like_any_other_wall() -> void:
	for w in _storeys:
		for at: Vector2i in w.seals:
			var inside := _inside(w)
			var ring := {}
			for p in inside:
				for d in Grid.DIRS:
					if Terrain.wall(w.tile(p + d)):
						ring[p + d] = true
			assert_true(ring.has(at), _label(w))
			for p: Vector2i in ring:
				var inner := p.x > 0 and p.y > 0 and p.x < Grid.W - 1 and p.y < Grid.H - 1
				assert_eq(Terrain.breakable(w, p), inner, "%s wall %s" % [_label(w), p])


func test_breaking_the_wall_of_a_vault_opens_it_to_the_whole_storey() -> void:
	for w in _storeys:
		for at: Vector2i in w.seals:
			var broken := w.clone()
			Terrain.hit(broken, at)
			Terrain.hit(broken, at)
			var reach := _reach(broken, false)
			var cut_off := []
			for i in broken.tiles.size():
				if reach[i] < 0 and broken.open_floor(Grid.at(i)):
					cut_off.append(Grid.at(i))
			assert_eq(cut_off, [], "%s tiles" % _label(w))
			for p in broken.peaches:
				assert_gt(reach[Grid.index(p)], -1, "%s peach" % _label(w))


# --- opening it --------------------------------------------------------------


## A hall cut by a wall at x = 10 with a vault record at GATE; three dark
## lanterns in a row west of it; Miho at (8, 4), in sight of the wall.
func _world() -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	for y in range(1, Grid.H - 1):
		for x in range(1, Grid.W - 1):
			w.tiles[Grid.index(Vector2i(x, y))] = World.FLOOR if x != GATE.x else World.WALL
	for p in LANTERNS:
		w.tiles[Grid.index(p)] = World.LANTERN_OUT
	w.seals[GATE] = LANTERNS.duplicate()
	w.rooms.assign([Rect2i(1, 1, 9, Grid.H - 2)])
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.hp = 3
	me.max_hp = 3
	me.pos = Vector2i(8, 4)
	w.actors.append(me)
	w.depth = 2
	w.sense()
	return w


func _light(w: World, n: int) -> void:
	for p in LANTERNS.slice(0, n):
		w.tiles[Grid.index(p)] = World.LANTERN
	w._changed()


func _names(events: Array) -> Array:
	return events.map(func(e): return e.t)


func test_the_wall_collapses_in_the_round_the_third_lantern_is_lit_and_says_so() -> void:
	var w := _world()
	_light(w, 2)
	w.act(WAIT)
	assert_eq(w.tile(GATE), World.WALL, "two of three")
	_light(w, 3)
	var before := w.clone()
	var events := w.act(WAIT)
	assert_eq(w.tile(GATE), World.RUBBLE)
	assert_eq(w.seals, {})
	assert_has(_names(events), &"collapse")
	assert_has(Messages.of(before, w, events).map(Messages.plain), "벽이 무너졌다")


func test_the_collapse_thuds_as_loud_as_a_wall_that_an_orb_brings_down() -> void:
	var w := _world()
	_light(w, 3)
	var noise := w.act(WAIT).filter(func(e): return e.t == &"noise" and e.at == GATE)
	assert_eq(noise.size(), 1)
	assert_eq(noise[0].loud, World.THUD)
	assert_eq(noise[0].word, "쿵")


func test_a_cracked_wall_still_collapses_when_the_third_lantern_is_lit() -> void:
	var w := _world()
	Terrain.hit(w, GATE)
	assert_eq(w.tile(GATE), World.WALL_CRACKED)
	_light(w, 3)
	assert_has(_names(w.act(WAIT)), &"collapse")
	assert_eq(w.tile(GATE), World.RUBBLE)


func test_a_wall_broken_by_an_orb_opens_the_vault_without_the_lanterns() -> void:
	var w := _world()
	Terrain.hit(w, GATE)
	Terrain.hit(w, GATE)
	_light(w, 3)
	var events := w.act(WAIT)
	assert_true(w.open_floor(GATE))
	assert_eq(w.seals, {})
	assert_does_not_have(_names(events), &"collapse")


func test_an_earth_orb_brings_the_wall_down_in_one_blow() -> void:
	var w := _world()
	var s := Shot.new()
	s.spell = Spell.make([Cards.ORB, Cards.EARTH])
	s.caster = w.player().id
	Terrain.smash(w, s, GATE, World.WALL)
	assert_eq(w.tile(GATE), World.RUBBLE)
	w.act(WAIT)
	assert_eq(w.seals, {})


func test_a_broken_lantern_shuts_nothing_for_good() -> void:
	var w := _world()
	_light(w, 2)
	w.tiles[Grid.index(LANTERNS[2])] = World.LANTERN_BROKEN
	for i in 3:
		w.act(WAIT)
	assert_eq(w.tile(GATE), World.WALL)
	assert_true(Terrain.breakable(w, GATE))
	Terrain.hit(w, GATE)
	Terrain.hit(w, GATE)
	assert_true(w.open_floor(GATE))


func test_a_clone_keeps_the_vault_and_its_lanterns() -> void:
	var w := _world()
	assert_eq(w.clone().seals, {GATE: LANTERNS})
	assert_eq(w.known_clone().seals, {GATE: LANTERNS})


func test_the_sealing_wall_and_its_lanterns_hover_like_any_other_wall_and_dark_lantern() -> void:
	var w := _world()
	_light(w, 1)
	var plain := w.clone()
	plain.seals = {}
	var wall := Info.plain(Info.terrain(w, GATE))
	assert_string_contains(wall, "벽")
	assert_eq(wall, Info.plain(Info.terrain(plain, GATE)))
	assert_eq(wall, Info.plain(Info.terrain(w, GATE + Vector2i(0, 4))))
	for p in LANTERNS:
		var text := Info.plain(Info.terrain(w, p))
		assert_eq(text, Info.plain(Info.terrain(plain, p)))
		assert_false(text.contains("봉인") or text.contains("/3"), text)
	assert_eq(w.tile(GATE), World.WALL)
