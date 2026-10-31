extends GutTest
## The tile table gives the same answers the separate tile-kind tables did, so a
## seed and its actions still make the same world.

const WALKABLE := [
	World.FLOOR,
	World.DOOR,
	World.DOOR_OPEN,
	World.BAMBOO,
	World.BOARD,
	World.ASH,
	World.LANTERN_BROKEN,
	World.RUBBLE,
	World.BRIDGE,
	World.DRUM_TORN
]
const FLAMMABLE := [World.DOOR, World.DOOR_OPEN, World.BAMBOO, World.BOARD, World.DRUM]
const TREAD := {World.BAMBOO: [2, "사각"], World.BOARD: [3, "삐걱"], World.BRIDGE: [3, "삐걱"]}
const BREAKS := {
	World.WALL: World.WALL_CRACKED,
	World.WALL_CRACKED: World.RUBBLE,
	World.LANTERN: World.LANTERN_OUT,
	World.LANTERN_OUT: World.LANTERN_BROKEN,
	World.DOOR: World.FLOOR,
	World.WINDOW: World.FLOOR,
	World.DRUM: World.DRUM_TORN,
}
const SEEDS := [1, 2, 3, 7, 11, 42]


func test_every_tile_kind_is_a_row() -> void:
	assert_eq(Tiles.ROWS.keys(), range(World.DRUM_TORN + 1))
	for t: int in Tiles.ROWS:
		assert_ne(Tiles.of(t, "name"), "", str(t))


func test_each_kind_has_the_walk_burn_tread_and_break_it_always_had() -> void:
	for t in 256:
		assert_eq(Tiles.walk[t] == 1, WALKABLE.has(t), "walk %d" % t)
		assert_eq(Tiles.burns[t] == 1, FLAMMABLE.has(t), "burns %d" % t)
		assert_eq(Tiles.of(t, "tread"), TREAD.get(t, [0, "탁"]), "tread %d" % t)
		assert_eq(Tiles.of(t, "breaks_to"), BREAKS.get(t, -1), "breaks_to %d" % t)
		assert_eq(Tiles.of(t, "burns_to"), World.ASH, "burns_to %d" % t)


func test_the_masks_for_rust_keep_their_old_tests() -> void:
	var blocks_light := [World.WALL, World.WALL_CRACKED, World.BAMBOO]
	var blocks_sight: Array = blocks_light + [World.DOOR]
	for t in 256:
		assert_eq(Tiles.sight[t] == 1, blocks_sight.has(t), "sight %d" % t)
		assert_eq(Tiles.light[t] == 0, blocks_light.has(t), "light %d" % t)
		assert_eq(Terrain.wall(t), t == World.WALL or t == World.WALL_CRACKED, "wall %d" % t)
		var knocked := t in [World.LANTERN, World.LANTERN_OUT, World.WINDOW, World.DRUM]
		assert_eq(Terrain.knockable(t), knocked, "knock %d" % t)


func test_worlds_of_several_seeds_follow_the_old_tables_at_every_tile() -> void:
	for s: int in SEEDS:
		var w := World.create(s)
		var floor_mask := Masks.floor_of(w)
		for i in w.tiles.size():
			var p := Grid.at(i)
			var t := w.tile(p)
			var inner := p.x > 0 and p.y > 0 and p.x < Grid.W - 1 and p.y < Grid.H - 1
			var wall := t == World.WALL or t == World.WALL_CRACKED
			assert_eq(w.open_floor(p), WALKABLE.has(t), "seed %d %s" % [s, p])
			assert_eq(floor_mask[i] == 1, WALKABLE.has(t), "seed %d %s" % [s, p])
			assert_eq(Terrain.breakable(w, p), BREAKS.has(t) and (inner or not wall), str(p))
