extends StoreyShapes
## The pond garden, the keep and the citadel.

## A clump of ponds, bamboo or reeds is CLUMP tiles at least in CLUMPED of the garden
## storeys; the noise leaves the others a tile or three short.
const CLUMP := 8
const CLUMPED := 0.9


func before_all() -> void:
	for kind: StringName in [Skeletons.GARDEN, Skeletons.KEEP, Skeletons.CITADEL]:
		_storeys(kind)


# --- the garden -----------------------------------------------------------------


func test_the_garden_has_hardly_a_wall_and_ponds_bamboo_and_reeds_in_clumps() -> void:
	var gardens := _storeys(Skeletons.GARDEN)
	var clumps := {World.POND: 0, World.BAMBOO: 0, World.REEDS: 0}
	for w: World in gardens:
		var walls := w.tiles.count(World.WALL)
		var ground := 0
		for t in w.tiles:
			ground += 1 if t != World.WALL and t != World.SKY and t != World.WINDOW else 0
		assert_gt(ground, walls * 3, _label(w))
		for t: int in clumps:
			clumps[t] += 1 if w.tiles.count(t) >= CLUMP else 0
	for t: int in clumps:
		assert_gte(clumps[t], gardens.size() * CLUMPED, "storeys with a clump of tile %d" % t)


func test_the_garden_has_walled_houses_for_what_needs_doors() -> void:
	var vaults := 0
	for w: World in _storeys(Skeletons.GARDEN):
		vaults += 1 if not w.seals.is_empty() else 0
		var walled := w.rooms.filter(func(r): return EventRooms.doorways(w, r).size() <= 3)
		assert_gt(walled.size() + w.sites.size() + w.seals.size(), 0, _label(w))
	assert_gt(vaults, 0, "treasure rooms in the garden")


# --- the keep -------------------------------------------------------------------


## The doorways on the walk from `from` to `to` without which there is no walk, in order
## from `from`.
func _gates(w: World, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var open := Masks.floor_of(w, [], func(_p): return false)
	var found: Dictionary = Grid.search(from, open)
	var at := Grid.index(to)
	var out: Array[Vector2i] = []
	while at >= 0:
		var p := Grid.at(at)
		if not FloorGen.room_at(w, p).has_area() and p != to and p != from:
			var shut := open.duplicate()
			shut[at] = 0
			if Grid.search(from, shut).dist[Grid.index(to)] < 0:
				out.push_front(p)
		at = found.parent[at]
	return out


## Draws `kind`, with nothing laid on it yet; returns the plan's goal.
func _drawn(kind: StringName, w: World) -> Rect2i:
	w.depth = 7
	return FloorGen._carve(w, kind).goal


func test_each_wall_of_the_keep_has_one_way_in_on_the_side_opposite_the_next() -> void:
	for seed_value in 30:
		var w := Built.world(seed_value)
		var core := _drawn(Skeletons.KEEP, w)
		var mid := FloorGen._centre(core)
		var gates := _gates(w, FloorGen._centre(w.rooms[0]), mid)
		var label := "seed %d %s" % [seed_value, gates]
		assert_eq(gates.size(), 2, label)
		var a: Vector2i = gates[0] - mid
		var b: Vector2i = gates[1] - mid
		assert_true(a.x * b.x < 0 or a.y * b.y < 0, label)


func test_the_hidden_doors_of_the_keep_skip_a_wall() -> void:
	var skips := 0
	for w: World in _storeys(Skeletons.KEEP):
		var plain: int = Grid.search(w.start, Masks.floor_of(w)).dist[Grid.index(_exit(w))]
		var v := w.clone()
		for p: Vector2i in w.secrets:
			v.set_tile(p, World.DOOR)
		var found: int = Grid.search(v.start, Masks.floor_of(v)).dist[Grid.index(_exit(v))]
		skips += 1 if found < plain else 0
	assert_gt(skips, _storeys(Skeletons.KEEP).size() / 2, "a shorter way once they are found")


func test_the_citadel_holds_its_exit_in_a_keep_on_an_island_of_sky_with_one_bridge() -> void:
	for seed_value in 30:
		var w := Built.world(seed_value)
		var core := _drawn(Skeletons.CITADEL, w)
		var label := "seed %d" % seed_value
		assert_gte(_enclosed_sky(w), 40, label)
		var bridges: Array[int] = []
		for i in w.tiles.size():
			if w.tiles[i] == World.BRIDGE:
				bridges.append(i)
		assert_gt(bridges.size(), 0, label)
		var mid := Grid.index(FloorGen._centre(core))
		var from := FloorGen._centre(w.rooms[0])
		var open := Masks.floor_of(w)
		assert_gte(Grid.search(from, open).dist[mid], 0, label)
		for i in bridges:
			open[i] = 0
		assert_lt(Grid.search(from, open).dist[mid], 0, "%s: the only way over" % label)


## Seeds whose first wings all came up sky, and left the ring no room to start in.
func test_the_citadel_starts_in_a_room_by_its_ring_when_its_first_wings_come_up_empty() -> void:
	for seed_value in [480, 829, 841]:
		var w := Built.world(seed_value)
		var core := _drawn(Skeletons.CITADEL, w)
		var from := FloorGen._centre(w.rooms[0])
		assert_ne(w.rooms[0], core, str(seed_value))
		assert_gt(Grid.search(from, Masks.floor_of(w)).dist[Grid.index(FloorGen._centre(core))], 0)


func test_the_boss_of_the_citadel_stands_with_the_elixir() -> void:
	for w: World in _storeys(Skeletons.CITADEL):
		if w.depth != World.FLOORS:
			continue
		var boss: Array = w.actors.filter(func(a): return a.kind == &"cheonnyeon")
		assert_eq(boss.size(), 1, _label(w))
		var keep := FloorGen.room_at(w, w.elixir)
		assert_true(keep.has_point(boss[0].pos), _label(w))
