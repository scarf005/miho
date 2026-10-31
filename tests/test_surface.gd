extends GutTest
## Ground kinds from the tile table: grass, straw, leaves, reeds, shallow water, pillars.

const E := Vector2i(1, 0)
const WEST := Vector2i(-1, 0)
const WAIT := {t = &"wait"}
const SOURCE := Vector2i(10, 8)
const NEXT := Vector2i(11, 8)
const TRIALS := 2000


## An open hall walled at the edges, with no light, Miho at (4, 8).
func _world() -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	for y in range(1, Grid.H - 1):
		for x in range(1, Grid.W - 1):
			w.tiles[Grid.index(Vector2i(x, y))] = World.FLOOR
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.hp = 3
	me.max_hp = 3
	me.pos = Vector2i(4, 8)
	w.actors.append(me)
	w.depth = 4
	w.tails = 4
	w.sense()
	return w


func _put(w: World, p: Vector2i, t: int) -> void:
	w.tiles[Grid.index(p)] = t
	w._changed()


func _noises(events: Array) -> Array:
	return events.filter(func(e): return e.t == &"noise")


func _types(events: Array) -> Array:
	return events.map(func(e): return e.t)


## How often fire at SOURCE takes a tile of `kind` at NEXT in one second.
func _catch_rate(kind: int) -> float:
	var w := _world()
	w.rng.seed = 5
	var caught := 0
	for i in TRIALS:
		_put(w, NEXT, kind)
		w.burning.clear()
		w.burning[SOURCE] = World.BURN_ROUNDS
		w._burn()
		caught += 1 if w.burning.has(NEXT) else 0
	return float(caught) / TRIALS


func test_fire_takes_each_kind_at_its_own_chance() -> void:
	for kind in [World.GRASS, World.STRAW, World.LEAVES, World.BOARD]:
		assert_almost_eq(_catch_rate(kind), Tiles.of(kind, "spread"), 0.04, str(kind))
	assert_lt(_catch_rate(World.GRASS), _catch_rate(World.STRAW) / 2, "grass burns slower")


func test_fire_never_takes_shallow_water_reeds_or_a_pillar() -> void:
	for kind in [World.SHALLOW, World.REEDS, World.REEDS_FLAT, World.PILLAR]:
		assert_eq(_catch_rate(kind), 0.0, str(kind))


func test_a_fire_spell_flies_over_shallow_water_and_leaves_it_unlit() -> void:
	var cast := {t = &"cast", spells = [{cards = [Cards.FOX, Cards.FIRE], dir = E}]}
	for kind in [World.SHALLOW, World.BOARD]:
		var w := _world()
		w.cards.append(Cards.FIRE)
		for x in range(5, 11):
			_put(w, Vector2i(x, 8), kind)
		w.act(cast)
		assert_eq(w.burning.is_empty(), kind != World.BOARD, str(kind))


func test_a_burning_creature_does_not_set_the_water_it_stands_in_alight() -> void:
	var w := _world()
	_put(w, Vector2i(5, 8), World.SHALLOW)
	_put(w, Vector2i(6, 8), World.BOARD)
	w._ignite(Vector2i(5, 8), true)
	w._ignite(Vector2i(6, 8), true)
	assert_false(w.burning.has(Vector2i(5, 8)))
	assert_true(w.burning.has(Vector2i(6, 8)))


func test_grass_straw_and_leaves_burn_to_ash() -> void:
	for kind in [World.GRASS, World.STRAW, World.LEAVES]:
		var w := _world()
		_put(w, NEXT, kind)
		w._ignite(NEXT)
		for i in World.BURN_ROUNDS:
			w.act(WAIT)
		assert_eq(w.tile(NEXT), World.ASH, str(kind))


func test_leaves_rustle_and_shallow_water_splashes_where_grass_and_straw_are_quiet() -> void:
	var told := {
		World.LEAVES: ["바스락", 2],
		World.SHALLOW: ["철벅", 2],
		World.REEDS: ["바스락", 2],
		World.GRASS: null,
		World.STRAW: null,
		World.REEDS_FLAT: null,
	}
	for kind: int in told:
		var w := _world()
		_put(w, Vector2i(5, 8), kind)
		var noises := _noises(w.act({t = &"move", dir = E}))
		var tread: Array = Tiles.of(kind, "tread")
		if told[kind] == null:
			assert_eq(noises, [], "kind %d is silent" % kind)
			assert_eq(tread[0], 0)
			continue
		assert_eq([noises[0].word, noises[0].loud], told[kind], "kind %d" % kind)
		assert_eq([tread[1], tread[0]], told[kind])


func test_reeds_block_sight_until_stepped_on() -> void:
	var w := _world()
	var far := Vector2i(8, 8)
	_put(w, Vector2i(5, 8), World.REEDS)
	assert_true(w.opaque(Vector2i(5, 8)))
	assert_false(w.blocks_light(Vector2i(5, 8)), "reeds let light through")
	assert_eq(w.fov(w.player().pos)[Grid.index(far)], 0, "hidden behind the reeds")
	assert_true(w.open_floor(Vector2i(5, 8)), "they can be walked")
	var events := w.act({t = &"move", dir = E})
	assert_eq(w.tile(Vector2i(5, 8)), World.REEDS_FLAT)
	assert_eq(events.filter(func(e): return e.t == &"trample")[0].was, World.REEDS)
	assert_eq(w.fov(w.player().pos)[Grid.index(far)], 1, "sight clears")
	assert_eq(_noises(w.act({t = &"move", dir = WEST})), [], "flat reeds rustle no more")


func test_a_creature_that_steps_on_reeds_flattens_them_too() -> void:
	var w := _world()
	_put(w, Vector2i(8, 8), World.REEDS)
	var foe := FloorGen.spawn(w, &"dokkaebi", Vector2i(9, 8))
	w.move(foe, Vector2i(8, 8))
	assert_eq(w.tile(Vector2i(8, 8)), World.REEDS_FLAT)


func test_shallow_water_breaks_the_trail() -> void:
	var w := _world()
	_put(w, Vector2i(5, 8), World.SHALLOW)
	w.act({t = &"move", dir = E})
	assert_eq(w.scent[Grid.index(Vector2i(5, 8))], 0, "no scent in the water")
	w.act({t = &"move", dir = E})
	assert_gt(w.scent[Grid.index(Vector2i(6, 8))], 0, "scent on the floor after it")


func test_a_pillar_blocks_walking_sight_and_light_and_never_breaks() -> void:
	var w := _world()
	var pillar := Vector2i(5, 8)
	_put(w, pillar, World.PILLAR)
	assert_false(w.can({t = &"move", dir = E}), "cannot walk into it")
	assert_false(w.open_floor(pillar))
	assert_true(w.opaque(pillar))
	assert_true(w.blocks_light(pillar))
	assert_false(Terrain.breakable(w, pillar))
	for i in 4:
		w.tails = 4
		w.act({t = &"cast", spells = [{cards = [Cards.ORB, Cards.FOX], dir = E}]})
	assert_eq(w.tile(pillar), World.PILLAR, "orbs burst on it and leave it standing")
	var wall := Vector2i(5, 10)
	_put(w, wall, World.WALL)
	w.player().pos = Vector2i(4, 10)
	w.tails = 4
	w.act({t = &"cast", spells = [{cards = [Cards.ORB, Cards.FOX], dir = E}]})
	assert_eq(w.tile(wall), World.WALL_CRACKED, "a wall, unlike a pillar, takes the hit")


func test_pillars_are_cover_from_sight_and_a_pillar_casts_a_shadow() -> void:
	var w := _world()
	_put(w, Vector2i(9, 8), World.LANTERN)
	w.sense()
	assert_true(w.lit(Vector2i(7, 8)), "the lantern lights it")
	assert_eq(w.fov(Vector2i(4, 8))[Grid.index(Vector2i(7, 8))], 1, "and Miho sees it")
	_put(w, Vector2i(8, 8), World.PILLAR)
	w._changed()
	assert_false(w.lit(Vector2i(7, 8)), "the pillar casts a shadow")
	for y in range(7, 10):
		_put(w, Vector2i(6, y), World.PILLAR)
	w._changed()
	assert_eq(w.fov(Vector2i(4, 8))[Grid.index(Vector2i(7, 8))], 0, "hidden behind a row of them")


func test_the_masks_agree_with_the_tests_over_every_new_kind() -> void:
	var w := _world()
	var kinds := [
		World.GRASS,
		World.STRAW,
		World.REEDS,
		World.REEDS_FLAT,
		World.LEAVES,
		World.SHALLOW,
		World.PILLAR
	]
	for i in kinds.size():
		_put(w, Vector2i(10 + i, 8), kinds[i])
	w.burning[Vector2i(10, 8)] = 2
	w._ignite(Vector2i(12, 8), true)
	w._changed()
	var opaque := w.opaque_mask()
	var shade := w.light_mask()
	for i in opaque.size():
		assert_eq(opaque[i] == 1, w.opaque(Grid.at(i)), str(Grid.at(i)))
		assert_eq(shade[i] == 1, w.blocks_light(Grid.at(i)), str(Grid.at(i)))
	assert_false(w.opaque(Vector2i(12, 8)), "burning reeds block nothing")
	assert_true(w.opaque(Vector2i(16, 8)), "a pillar does")


func _hover(kind: int) -> String:
	var w := _world()
	var p := w.player().pos + E
	_put(w, p, kind)
	w.sense()
	return Info.plain(Info.terrain(w, p))


func _percent(kind: int) -> String:
	return "초당 %d%% 로 옮겨" % roundi(Tiles.of(kind, "spread") * 100)


func test_hover_tells_every_rule_of_each_kind_from_the_table() -> void:
	var burn := "%d초 타고" % World.BURN_ROUNDS
	var rustle := "바스락 소리 %d칸" % Tiles.of(World.LEAVES, "tread")[0]
	var splash := "철벅 소리 %d칸" % Tiles.of(World.SHALLOW, "tread")[0]
	var told := {
		World.GRASS: [burn, _percent(World.GRASS)],
		World.STRAW: [burn, _percent(World.STRAW)],
		World.LEAVES: [burn, _percent(World.LEAVES), rustle],
		World.REEDS: ["시야를 막는다", "쓰러져 시야가 트인다", rustle],
		World.SHALLOW: [splash, "냄새가 남지 않는다", "불이 붙지 않는다"],
		World.PILLAR: ["길과 시야와 빛을 막는다", "부술 수 없다"],
	}
	for kind: int in told:
		var text := _hover(kind)
		assert_string_contains(text, Tiles.of(kind, "name"))
		for part: String in told[kind]:
			assert_string_contains(text, part)
	assert_false(_hover(World.SHALLOW).contains(burn), "water has no burn time")
	assert_false(_hover(World.PILLAR).contains("밝다"), "a pillar has no light line")


func _lines(w: World, events: Array) -> Array[String]:
	var out: Array[String] = []
	out.assign(Messages.of(w, w, events).map(Messages.plain))
	return out


func test_the_log_tells_reeds_lying_down_only_where_miho_sees_it() -> void:
	var w := _world()
	var seen := w.player().pos + E
	var out_of_sight := Vector2i(30, 20)
	var told: Array[String] = ["갈대가 쓰러졌다"]
	assert_eq(_lines(w, [{t = &"trample", at = seen, was = World.REEDS}]), told)
	var none: Array[String] = []
	assert_eq(_lines(w, [{t = &"trample", at = out_of_sight, was = World.REEDS}]), none)


func test_miho_walking_into_reeds_is_told_in_the_log() -> void:
	var w := _world()
	_put(w, w.player().pos + E, World.REEDS)
	w.sense()
	var after := w.preview({t = &"move", dir = E})
	assert_has(_types(after.events), &"trample")
	var lines := Messages.of(w, after, after.events).map(Messages.plain)
	assert_has(lines, "갈대가 쓰러졌다")


func test_every_new_kind_has_its_own_glyph_and_the_mcp_legend_lists_it() -> void:
	var glyphs := {}
	for kind in range(World.GRASS, World.PILLAR + 1):
		var glyph: String = Palette.TILES[kind][0]
		assert_true(Observation.LEGEND.contains(glyph), "legend lists %s" % glyph)
		assert_false(glyphs.has(glyph), "%s is used twice" % glyph)
		glyphs[glyph] = true
	for kind in range(World.GRASS):
		assert_false(
			glyphs.has(Palette.TILES[kind][0]), "an older kind uses %s" % Palette.TILES[kind][0]
		)
