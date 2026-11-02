extends GutTest
## The board primitives in Rust and the masks they read: each mask agrees with
## the World test it stands for on every tile, and search, sight and light
## keep their bounds.


## A storey with a creature in a doorway, a projectile in another, burning
## bamboo, a burning door and a dead creature left in a doorway.
func _busy(seed_value: int) -> World:
	var w := Built.world(seed_value)
	var doors: Array[Vector2i] = []
	var bamboo: Array[Vector2i] = []
	for i in w.tiles.size():
		if w.tiles[i] == World.DOOR:
			doors.append(Grid.at(i))
		elif w.tiles[i] == World.BAMBOO:
			bamboo.append(Grid.at(i))
	for d in doors.slice(0, 1):
		FloorGen.spawn(w, &"cheonha", d)
	for d in doors.slice(1, 2):
		var s := Shot.new()
		s.id = w.new_id()
		s.spell = Spell.make([Cards.FOX])
		s.pos = d
		w.shots.append(s)
	for d in doors.slice(2, 3):
		w.burning[d] = 2
	for d in doors.slice(3, 4):
		FloorGen.spawn(w, &"cheonha", d).hp = 0
	for p in bamboo.slice(0, 2):
		w.burning[p] = 2
	w._changed()
	return w


func test_the_opaque_mask_agrees_with_opaque_on_every_tile() -> void:
	for s in 6:
		var w := _busy(s)
		var mask := w.opaque_mask()
		for i in mask.size():
			assert_eq(mask[i] == 1, w.opaque(Grid.at(i)), "seed %d %s" % [s, Grid.at(i)])


func test_a_walk_mask_agrees_with_the_test_on_every_tile_and_holds_the_walker() -> void:
	for s in 6:
		var w := _busy(s)
		for a in w.actors.filter(func(b): return not Bestiary.flies(b.kind)):
			var test := func(p): return p == a.pos or (w.vacant(p) and not w.burning.has(p))
			var mask := Masks.walk(w, a, test)
			var wrong: Array[Vector2i] = []
			for i in mask.size():
				if (mask[i] == 1) != test.call(Grid.at(i)):
					wrong.append(Grid.at(i))
			assert_eq(wrong, [] as Array[Vector2i], "seed %d tiles the mask gets wrong" % s)


func test_the_travel_mask_agrees_with_travel_walkable_and_the_exclusions() -> void:
	for s in 6:
		var w := _busy(s)
		var avoid := {w.player().pos + Vector2i(1, 0): true}
		var mask := Travel.open(w, avoid)
		var wrong: Array[Vector2i] = []
		for i in mask.size():
			var p := Grid.at(i)
			if (mask[i] == 1) != (Travel.walkable(w, p) and not avoid.has(p)):
				wrong.append(p)
		assert_eq(wrong, [] as Array[Vector2i], "seed %d tiles the mask gets wrong" % s)


func test_mask_lets_the_test_decide_only_at_odd_tiles_on_the_board() -> void:
	var tiles := PackedByteArray()
	tiles.resize(Grid.W * Grid.H)
	var floor_only := Grid.table(func(t): return t == World.FLOOR)
	var odd := [Vector2i(3, 3), Vector2i(-1, 0), Vector2i(Grid.W, 0)]
	var mask := Grid.mask(tiles, floor_only, odd, func(_p): return false)
	assert_eq(mask[Grid.index(Vector2i(3, 3))], 0, "the test closes an odd tile")
	assert_eq(mask[Grid.index(Vector2i(4, 3))], 1, "the table opens the rest")
	assert_eq(mask.count(0), 1, "tiles off the board are left out")


func test_search_counts_steps_and_leaves_closed_tiles_unreached() -> void:
	var open := PackedByteArray()
	open.resize(Grid.W * Grid.H)
	open.fill(1)
	var wall := Vector2i(6, 5)
	open[Grid.index(wall)] = 0
	var from := Vector2i(5, 5)
	open[Grid.index(from)] = 0
	var found := Grid.search(from, open)
	assert_eq(found.dist[Grid.index(from)], 0, "the start, closed or not")
	assert_eq(found.dist[Grid.index(wall)], -1)
	assert_eq(found.dist[Grid.index(Vector2i(7, 5))], 2, "around the closed tile")
	assert_eq(found.dist[Grid.index(Vector2i(0, 0))], 5, "diagonal steps count one")
	assert_eq(found.parent[Grid.index(Vector2i(5, 4))], Grid.index(from))
	assert_eq(Grid.first_step(found, from, Vector2i(9, 5)).x, 6)


func test_search_stops_expanding_at_the_limit() -> void:
	var open := PackedByteArray()
	open.resize(Grid.W * Grid.H)
	open.fill(1)
	var found := Grid.search(Vector2i(10, 10), open, 3)
	assert_eq(found.dist[Grid.index(Vector2i(13, 10))], 3)
	assert_eq(found.dist[Grid.index(Vector2i(14, 10))], -1)
	assert_eq(found.dist.count(-1), Grid.W * Grid.H - 49)


func test_search_from_off_the_board_reaches_nothing() -> void:
	var open := PackedByteArray()
	open.resize(Grid.W * Grid.H)
	open.fill(1)
	var found := Grid.search(Vector2i(-1, 3), open)
	assert_eq(found.dist.count(-1), Grid.W * Grid.H)


func test_sight_from_off_the_board_sees_nothing() -> void:
	var opaque := PackedByteArray()
	opaque.resize(Grid.W * Grid.H)
	assert_eq(Sight.field(Vector2i(Grid.W, 0), 10, opaque).count(1), 0)


func test_light_fades_with_distance_to_a_quarter_at_its_radius() -> void:
	var opaque := PackedByteArray()
	opaque.resize(Grid.W * Grid.H)
	var at := Vector2i(10, 10)
	opaque[Grid.index(Vector2i(10, 12))] = 1
	var s := Light.spread(at, 4, opaque)
	assert_eq(s[Grid.index(at)], 1.0)
	assert_eq(s[Grid.index(Vector2i(14, 10))], 0.25)
	assert_almost_eq(s[Grid.index(Vector2i(13, 13))], 1.0 - 0.75 * sqrt(18.0) / 4.0, 1e-6)
	assert_eq(s[Grid.index(Vector2i(15, 10))], 0.0, "past the radius")
	assert_eq(s[Grid.index(Vector2i(10, 13))], 0.0, "behind a wall")


func test_light_adds_up_every_source() -> void:
	var opaque := PackedByteArray()
	opaque.resize(Grid.W * Grid.H)
	var one: Array[Dictionary] = [{at = Vector2i(10, 10), radius = 4, color = Vector3(1, 0, 0)}]
	var two: Array[Dictionary] = one.duplicate()
	two.append({at = Vector2i(12, 10), radius = 4, color = Light.DARK})
	var i := Grid.index(Vector2i(11, 10))
	var lone := Light.field(one, opaque)[i]
	assert_almost_eq(lone.x, 0.8125, 1e-6)
	var both := Light.field(two, opaque)[i]
	assert_almost_eq(both, lone + Light.DARK * 0.8125, Vector3.ONE * 1e-6)
	assert_eq(Light.field(one, opaque)[Grid.index(Vector2i(20, 10))], Vector3.ZERO)
