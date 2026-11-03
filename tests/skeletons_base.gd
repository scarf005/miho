class_name SkeletonsBase
extends GutTest
## What every skeleton a storey is built on (Skeletons) shares: each stays whole, gives two
## routes to the exit, cuts links only across long walks, and differs from seed to seed. The
## scripts that extend this one name the `kinds` they try, so that the skeletons that cost
## the most to build run apart.

const SEEDS := 6
## The most rooms of a storey with one way in and nothing hidden behind it, the start
## and the exit left out.
const DEAD_ENDS := {
	pavilions = 10,
	ring = 5,
	avenue = 5,
	towers = 5,
	broken = 8,
	scattered = 5,
	garden = 5,
	keep = 8,
	ruin = 5,
	citadel = 8,
}
## How many tiles two seeds' outlines differ by at least, on one storey.
const OUTLINES_APART := 50

## The skeletons this script tries.
var kinds: Array[StringName] = []
## Every storey of each of them: [{w, made}], built once.
var _built := {}


func before_all() -> void:
	for kind in kinds:
		_built[kind] = []
		for seed_value in SEEDS:
			for depth in range(1, World.FLOORS + 1):
				_built[kind].append(Built.made(seed_value * World.FLOORS + depth, depth, kind))


func _label(w: World, kind: StringName) -> String:
	return "%s seed %d storey %d" % [kind, w.rng.seed, w.depth]


func _exit(w: World) -> Vector2i:
	return w.elixir if w.depth >= World.FLOORS else w.stairs


## The tiles open to walk on, plates shut as Heaven's walks treat them.
func _walk(w: World) -> PackedByteArray:
	return Masks.floor_of(w, w.traps.keys(), func(_p): return false)


## The first tile whose 3 by 3 block cuts `from` off from `to`, tiles within 3 of the
## rooms `ends` left out; (-1, -1) when none does.
func _choke(open: PackedByteArray, from: Vector2i, to: Vector2i, ends: Array) -> Vector2i:
	for i in open.size():
		var mid := Grid.at(i)
		if open[i] == 0 or ends.any(func(r: Rect2i): return r.grow(3).has_point(mid)):
			continue
		var shut := open.duplicate()
		for d in Grid.DIRS + [Vector2i.ZERO]:
			if Grid.inside(mid + d):
				shut[Grid.index(mid + d)] = 0
		if Grid.distance(from, shut, to) < 0:
			return mid
	return Vector2i(-1, -1)


# --- every skeleton ----------------------------------------------------------


func test_every_storey_is_whole_and_its_exit_can_be_walked_to() -> void:
	for kind: StringName in _built:
		for row: Dictionary in _built[kind]:
			var w: World = row.w
			assert_true(FloorGen.connected(w, w.traps.keys()), _label(w, kind))
			var dist: PackedInt32Array = Grid.search(w.start, _walk(w)).dist
			assert_gt(dist[Grid.index(_exit(w))], 0, _label(w, kind))


## A yard beside the start room once lit the start and left the exit dark.
func test_the_start_stays_dark_and_the_exit_lit() -> void:
	for kind: StringName in _built:
		for row: Dictionary in _built[kind]:
			var w: World = row.w
			assert_false(w.lit(w.start), _label(w, kind))
			assert_true(w.lit(_exit(w)), _label(w, kind))


func test_every_storey_has_rooms_a_wall_apart_and_the_start_in_the_first() -> void:
	for kind: StringName in _built:
		for row: Dictionary in _built[kind]:
			var w: World = row.w
			assert_true(w.rooms[0].has_point(w.start), _label(w, kind))
			assert_gte(w.rooms.size() + w.sites.size(), FloorGen.MIN_ROOMS - 1, _label(w, kind))
			for a in w.rooms:
				assert_gte(mini(a.size.x, a.size.y), FloorGen.ROOM_LEAST, _label(w, kind))
				for b in w.rooms:
					if a != b:
						assert_false(a.grow(1).intersects(b), "%s %s %s" % [_label(w, kind), a, b])


func test_a_storey_has_all_its_hidden_doors_on_every_skeleton() -> void:
	for kind: StringName in _built:
		for row: Dictionary in _built[kind]:
			var w: World = row.w
			assert_eq(w.secrets.size(), FloorGen.hidden_doors(w.depth), _label(w, kind))


func test_dead_ends_stay_under_the_limit() -> void:
	for kind: StringName in _built:
		for row: Dictionary in _built[kind]:
			var w: World = row.w
			var goal := FloorGen.room_at(w, _exit(w))
			var dead := w.rooms.filter(
				func(r: Rect2i):
					var ways := EventRooms.doorways(w, r)
					return (
						r != w.rooms[0]
						and r != goal
						and ways.size() == 1
						and not w.secrets.has(ways[0])
					)
			)
			assert_lte(dead.size(), DEAD_ENDS[kind], _label(w, kind))


func test_a_seed_builds_the_same_storey_on_every_skeleton() -> void:
	for kind in kinds:
		var a := World.create(5)
		FloorGen.build(a, kind)
		var b := World.create(5)
		FloorGen.build(b, kind)
		assert_eq(a.tiles, b.tiles, kind)
		assert_eq(a.rooms, b.rooms, kind)


func test_two_seeds_give_a_skeleton_different_outlines() -> void:
	for kind: StringName in _built:
		var rows: Array = _built[kind]
		for i in rows.size():
			for j in range(i + 1, rows.size()):
				var a: World = rows[i].w
				var b: World = rows[j].w
				if a.depth != b.depth:
					continue
				var differ := 0
				for k in a.tiles.size():
					differ += 1 if (a.tiles[k] == World.SKY) != (b.tiles[k] == World.SKY) else 0
				assert_gte(differ, OUTLINES_APART, "%s and seed %d" % [_label(a, kind), b.rng.seed])


func test_set_rooms_and_treasure_rooms_come_up_on_every_skeleton() -> void:
	for kind: StringName in _built:
		var rows: Array = _built[kind]
		var sets := rows.filter(func(row): return not row.made.is_empty()).size()
		var vaults := rows.filter(func(row): return not row.w.seals.is_empty()).size()
		assert_gte(float(sets) / rows.size(), 0.9, "%s set rooms" % kind)
		assert_between(float(vaults) / rows.size(), 0.1, 0.65, "%s vaults" % kind)


# --- two routes --------------------------------------------------------------


func test_all_but_the_one_way_skeletons_have_two_routes_from_start_to_exit() -> void:
	for kind: StringName in _built:
		if Skeletons.ONE_WAY.has(kind):
			continue
		for row: Dictionary in _built[kind]:
			var w: World = row.w
			var ends := [w.rooms[0], FloorGen.room_at(w, _exit(w))]
			var cut := _choke(_walk(w), w.start, _exit(w), ends)
			assert_eq(cut, Vector2i(-1, -1), _label(w, kind))


# --- far links ---------------------------------------------------------------


func test_every_link_a_storey_cut_joined_two_places_far_apart() -> void:
	for kind in kinds:
		var cut := 0
		for seed_value in SEEDS:
			for depth in range(1, World.FLOORS + 1):
				var w := Built.world(seed_value * World.FLOORS + depth)
				w.depth = depth
				var links: Array = FloorGen._carve(w, kind).links
				cut += links.size()
				var doors := links.filter(func(l): return l.a + (l.b - l.a) / 2 == l.at)
				if kind not in [Skeletons.BROKEN, Skeletons.SCATTERED, Skeletons.RUIN]:
					assert_lte(doors.size(), FloorGen.LOOPS, _label(w, kind))
				var open := Masks.floor_of(w)
				for k in range(links.size() - 1, -1, -1):
					open[Grid.index(links[k].at)] = 0
					var dist: int = Grid.search(links[k].a, open).dist[Grid.index(links[k].b)]
					if dist >= 0:
						assert_gte(dist, FloorGen.APART, "%s %s" % [_label(w, kind), links[k]])
		if kind not in [Skeletons.GARDEN, Skeletons.KEEP]:
			assert_gt(cut, SEEDS * World.FLOORS, "%s cuts more than one a storey" % kind)
