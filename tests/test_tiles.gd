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
	World.DRUM_TORN,
	World.GRASS,
	World.STRAW,
	World.REEDS,
	World.REEDS_FLAT,
	World.LEAVES,
	World.SHALLOW,
	World.ICE,
	World.THORNS,
	World.MUD,
	World.TRAP_ALARM,
	World.TRAP_COLLAPSE,
	World.TRAP_FIRE,
	World.TRAP_VINE,
	World.TALISMAN,
	World.SHELF,
	World.SHELF_READ,
	World.COURTYARD,
	World.BOARD_ROTTEN,
]
const FLAMMABLE := [
	World.DOOR,
	World.DOOR_OPEN,
	World.BAMBOO,
	World.BOARD,
	World.DRUM,
	World.GRASS,
	World.STRAW,
	World.LEAVES,
	World.WOOD_WALL,
	World.THORNS,
	World.SHELF,
	World.SHELF_READ,
	World.SCREEN,
	World.BOARD_ROTTEN,
]
const TREAD := {
	World.BAMBOO: [2, "사각"],
	World.BOARD: [3, "삐걱"],
	World.BRIDGE: [3, "삐걱"],
	World.REEDS: [2, "바스락"],
	World.LEAVES: [2, "바스락"],
	World.SHALLOW: [2, "철벅"],
	World.BOARD_ROTTEN: [3, "삐걱"],
}
const BREAKS := {
	World.WALL: World.WALL_CRACKED,
	World.WALL_CRACKED: World.RUBBLE,
	World.LANTERN: World.LANTERN_OUT,
	World.LANTERN_OUT: World.LANTERN_BROKEN,
	World.DOOR: World.FLOOR,
	World.WINDOW: World.FLOOR,
	World.DRUM: World.DRUM_TORN,
	World.WOOD_WALL: World.FLOOR,
	World.SCREEN: World.FLOOR,
	World.JAR: World.FLOOR,
	World.WATER_JAR: World.SHALLOW,
	World.CENSER: World.FLOOR,
}
const SEEDS := [1, 2, 3, 7, 11, 42]


func test_every_tile_kind_is_a_row() -> void:
	assert_eq(Tiles.ROWS.keys(), range(World.BOARD_ROTTEN + 1))
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
	var blocks_light := [
		World.WALL, World.WALL_CRACKED, World.BAMBOO, World.PILLAR, World.WOOD_WALL
	]
	var blocks_sight: Array = blocks_light + [World.DOOR, World.REEDS, World.SCREEN]
	for t in 256:
		assert_eq(Tiles.sight[t] == 1, blocks_sight.has(t), "sight %d" % t)
		assert_eq(Tiles.light[t] == 0, blocks_light.has(t), "light %d" % t)
		assert_eq(Terrain.wall(t), t == World.WALL or t == World.WALL_CRACKED, "wall %d" % t)
		var knocked := (
			t
			in [
				World.LANTERN,
				World.LANTERN_OUT,
				World.WINDOW,
				World.DRUM,
				World.SCREEN,
				World.JAR,
				World.WATER_JAR,
				World.CENSER
			]
		)
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


func test_grass_takes_fire_at_15_percent_and_every_other_kind_at_half() -> void:
	for t in 256:
		assert_eq(Tiles.of(t, "spread"), 0.15 if t == World.GRASS else 0.5, "spread %d" % t)


func test_only_bamboo_and_shallow_water_hold_no_scent() -> void:
	var scentless := [World.BAMBOO, World.SHALLOW]
	for t in 256:
		assert_eq(Tiles.of(t, "scentless"), scentless.has(t), "scentless %d" % t)


func test_only_shallow_water_ice_and_mud_are_never_taken_by_fire() -> void:
	for t in 256:
		assert_eq(
			Tiles.of(t, "douses"), t in [World.SHALLOW, World.ICE, World.MUD], "douses %d" % t
		)


func test_only_reeds_lie_flat_when_stepped_on() -> void:
	for t in 256:
		assert_eq(Tiles.of(t, "trample"), World.REEDS_FLAT if t == World.REEDS else -1, str(t))


func test_only_the_four_plates_are_traps() -> void:
	var plates := [World.TRAP_ALARM, World.TRAP_COLLAPSE, World.TRAP_FIRE, World.TRAP_VINE]
	for t in 256:
		assert_eq(Tiles.of(t, "trap"), plates.has(t), "trap %d" % t)
