extends GutTest
## The floor plan: the rooms of a pavilion share walls one tile thick, joined
## by doorways.

const SEEDS := 6

var _storeys: Array[World] = []


## Every storey of several seeds, built once.
func before_all() -> void:
	for seed_value in SEEDS:
		for depth in range(1, World.FLOORS + 1):
			var w := World.create(seed_value)
			w.depth = depth
			FloorGen.build(w)
			_storeys.append(w)


func _label(w: World) -> String:
	return "seed %d storey %d" % [w.rng.seed, w.depth]


# --- the floor plan ----------------------------------------------------------


func test_every_wall_has_a_tile_that_is_neither_wall_nor_sky_within_one_step() -> void:
	for w in _storeys:
		for i in w.tiles.size():
			var p := Grid.at(i)
			if not Terrain.wall(w.tiles[i]):
				continue
			var open := Grid.DIRS.any(
				func(d):
					var q: Vector2i = p + d
					return Grid.inside(q) and not Terrain.wall(w.tile(q)) and w.tile(q) != World.SKY
			)
			assert_true(open, "%s wall %s is thick" % [_label(w), p])


func test_rooms_are_at_least_three_wide_and_a_wall_apart() -> void:
	for w in _storeys:
		assert_gte(w.rooms.size(), FloorGen.MIN_ROOMS, _label(w))
		for a in w.rooms:
			assert_gte(mini(a.size.x, a.size.y), FloorGen.ROOM_LEAST, "%s %s" % [_label(w), a])
			for b in w.rooms:
				if a != b:
					assert_false(a.grow(1).intersects(b), "%s %s and %s" % [_label(w), a, b])


func test_miho_starts_in_the_westmost_room_and_the_exit_is_in_the_farthest() -> void:
	for w in _storeys:
		var home := w.rooms[0]
		assert_eq(w.start, home.position + home.size / 2, _label(w))
		for r in w.rooms:
			assert_lte(home.get_center().x, r.get_center().x, _label(w))
		var dist: PackedInt32Array = Grid.search(w.start, Masks.floor_of(w)).dist
		var exit := w.elixir if w.depth >= World.FLOORS else w.stairs
		for r in w.rooms:
			var centre := r.position + r.size / 2
			assert_lte(dist[Grid.index(centre)], dist[Grid.index(exit)], _label(w))


func test_the_storey_is_whole_with_plates_counted_as_walls() -> void:
	for w in _storeys:
		assert_true(FloorGen.connected(w, w.traps.keys()), _label(w))
