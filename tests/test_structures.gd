extends GutTest
## Furniture: screens, jars, censers and courtyards. What each does
## when hit, what the hover and the log tell of it, and where the storeys put it.

const E := Vector2i(1, 0)
const WAIT := {t = &"wait"}
const AT := Vector2i(5, 8)
const SEEDS := 12
const KINDS := [World.SCREEN, World.JAR, World.CENSER, World.COURTYARD]


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
	w.depth = 2
	w.tails = 4
	w.rng.seed = 5
	w.sense()
	return w


func _put(w: World, p: Vector2i, t: int) -> void:
	w.set_tile(p, t)
	w.sense()


func _noises(events: Array) -> Array:
	return events.filter(func(e): return e.t == &"noise")


func _hover(kind: int) -> String:
	var w := _world()
	_put(w, AT, kind)
	return Info.plain(Info.terrain(w, AT))


func _lines(w: World, events: Array) -> Array[String]:
	var out: Array[String] = []
	out.assign(Messages.of(w, w, events).map(Messages.plain))
	return out


# --- screens and jars ----------------------------------------------------------


func test_a_screen_blocks_walking_and_sight_but_not_light_until_knocked_flat() -> void:
	var w := _world()
	_put(w, AT, World.SCREEN)
	assert_false(w.open_floor(AT))
	assert_true(w.opaque(AT))
	assert_false(w.blocks_light(AT))
	var events := w.act({t = &"move", dir = E})
	assert_eq(w.player().pos, Vector2i(4, 8), "the knock spends the move")
	assert_eq(w.tile(AT), World.FLOOR)
	assert_true(w.open_floor(AT))
	assert_false(w.opaque(AT), "sight clears")
	var thud: Dictionary = _noises(events)[0]
	assert_eq([thud.word, thud.loud], ["쿵", World.THUD])


func test_a_jar_clangs_and_breaks_to_walkable_pieces() -> void:
	for jar in [World.JAR]:
		var w := _world()
		_put(w, AT, jar)
		assert_false(w.open_floor(AT))
		assert_false(w.opaque(AT), "a jar blocks the way, not sight")
		var clang: Dictionary = _noises(w.act({t = &"move", dir = E}))[0]
		assert_eq([clang.word, clang.loud], ["쨍그랑", World.KNOCK], str(jar))
		assert_true(w.open_floor(AT))


func test_an_orb_knocks_a_screen_flat_and_breaks_a_jar() -> void:
	for kind in [World.SCREEN, World.JAR]:
		var w := _world()
		_put(w, Vector2i(8, 8), kind)
		w.act({t = &"cast", spells = [{cards = [Cards.ORB], dir = E}]})
		for i in 3:
			w.act(WAIT)
		assert_eq(w.tile(Vector2i(8, 8)), World.FLOOR, str(kind))


func test_a_screen_burns_and_a_jar_does_not() -> void:
	var w := _world()
	_put(w, AT, World.SCREEN)
	_put(w, AT + E, World.JAR)
	w.ignite(AT)
	w.ignite(AT + E)
	assert_true(w.burning.has(AT))
	assert_false(w.burning.has(AT + E))
	for i in World.BURN_ROUNDS:
		w.act(WAIT)
	assert_eq(w.tile(AT), World.ASH)


# --- censers -------------------------------------------------------------------


func _censer(w: World, p: Vector2i) -> void:
	_put(w, p, World.CENSER)
	w.vents[p] = Gas.INCENSE


func test_a_censer_breathes_incense_up_to_the_vent_level_and_it_spreads() -> void:
	var w := _world()
	var far := Vector2i(30, 20)
	_censer(w, far)
	for i in 8:
		w.act(WAIT)
	assert_eq(w.gas[far].x, Gas.INCENSE)
	assert_between(w.gas[far].y, 1, Gas.VENT_LEVEL)
	assert_gt(w.gas.size(), 8, "it spreads round the censer")


func test_incense_does_not_block_sight_however_thick() -> void:
	var w := _world()
	Gas.put(w, AT, Gas.INCENSE, Gas.MAX)
	assert_false(w.opaque(AT))
	Gas.put(w, AT + E, Gas.FOG, Gas.MAX)
	assert_true(w.opaque(AT + E), "fog still does")


func test_incense_erases_the_scent_miho_leaves_in_it() -> void:
	var w := _world()
	Gas.put(w, AT, Gas.INCENSE, Gas.MAX)
	Gas.put(w, AT + E, Gas.FOG, Gas.MAX)
	w.act({t = &"move", dir = E})
	assert_eq(w.scent[Grid.index(AT)], 0, "no trail in incense")
	w.act({t = &"move", dir = E})
	assert_gt(w.scent[Grid.index(AT + E)], 0, "fog leaves it")


func test_a_censer_knocked_over_stops_breathing_and_spills_hot_coals_that_light_the_dry_beside_it(
) -> void:
	var w := _world()
	_censer(w, AT)
	_put(w, AT + Vector2i(0, 1), World.STRAW)
	_put(w, AT + Vector2i(0, -1), World.SHALLOW)
	var events := w.act({t = &"move", dir = E})
	assert_eq(w.tile(AT), World.FLOOR)
	assert_false(w.vents.has(AT))
	for d in [Vector2i.ZERO, E, -E, Vector2i(0, 1)]:
		assert_true(w.hot.has(AT + d), "coals at %s" % d)
	assert_false(w.hot.has(AT + Vector2i(0, -1)), "water stays cool")
	assert_false(w.hot.has(AT + Vector2i(1, 1)), "only the four beside it")
	assert_true(w.burning.has(AT + Vector2i(0, 1)), "straw catches")
	assert_eq(_noises(events)[0].word, "쨍")


func test_the_coals_burn_whoever_stands_on_them_and_cool_after_their_time() -> void:
	var w := _world()
	_censer(w, AT)
	w.act({t = &"move", dir = E})
	var spec: Dictionary = Compounds.HOT[Compounds.LAVA]
	var hp := w.player().hp
	w.act(WAIT)
	assert_eq(w.player().hp, hp - spec.harm, "Miho at (4, 8) stands beside the censer")
	for i in Compounds.HOT_ROUNDS:
		w.act({t = &"move", dir = Vector2i(-1, 0)})
	assert_false(w.hot.has(AT))


# --- courtyards ----------------------------------------------------------------


func test_a_courtyard_is_lit_by_the_moon_in_a_dark_hall_and_walkable() -> void:
	var w := _world()
	var far := Vector2i(30, 12)
	assert_false(w.lit(far))
	_put(w, far, World.COURTYARD)
	assert_true(w.lit(far))
	assert_true(w.open_floor(far))
	assert_false(w.lit(far + Vector2i(0, 4)), "only its own tile")


# --- hover and log ---------------------------------------------------------------


func test_hover_tells_every_rule_of_each_piece_of_furniture() -> void:
	var told := {
		World.SCREEN:
		["막음: 길, 시야", "타격: 쓰러짐", "부딪칠 때 소음: %d" % Tiles.of(World.SCREEN, "hit")[0], "가연성"],
		World.JAR: ["막음: 길", "타격: 깨짐", "부딪칠 때 소음: %d" % Tiles.of(World.JAR, "hit")[0]],
		World.CENSER:
		[
			"향 연기 최대 양: %d" % Gas.VENT_LEVEL,
			"이 칸과 옆 4칸",
			": %d초\n" % Compounds.HOT_ROUNDS,
			"초당 피해: %d" % Compounds.HOT[Compounds.LAVA].harm,
			"옆 가연성·인화성 칸에 불",
		],
	}
	for kind: int in told:
		var text := _hover(kind)
		assert_string_contains(text, Tiles.of(kind, "name"))
		for part: String in told[kind]:
			assert_string_contains(text, part)
		assert_false(text.contains("쿵") or text.contains("쨍그랑"), "no sound word in the hover")
	assert_false(_hover(World.JAR).contains("가연성"), "a jar does not burn")


func test_the_hover_of_incense_says_it_does_not_block_sight_and_erases_the_scent() -> void:
	var w := _world()
	Gas.put(w, AT, Gas.INCENSE, Gas.MAX)
	w.sense()
	var text := Info.plain(Info.terrain(w, AT))
	assert_string_contains(text, "향 연기")
	assert_string_contains(text, "시야를 막지 않음.")
	assert_string_contains(text, "냄새: 지워짐")
	assert_string_contains(text, "초당 %d%%" % Gas.of(Gas.INCENSE, "decay"))


func test_the_log_tells_each_piece_breaking_where_miho_sees_it() -> void:
	var w := _world()
	var told := {
		World.SCREEN: "병풍이 쓰러졌다",
		World.JAR: "장독이 깨졌다",
		World.CENSER: "향로가 쓰러졌다",
	}
	for kind: int in told:
		assert_eq(_lines(w, [{t = &"smash", at = AT, was = kind}]), [told[kind]], str(kind))
	var none: Array[String] = []
	assert_eq(_lines(w, [{t = &"smash", at = Vector2i(30, 20), was = World.JAR}]), none)


# --- the storeys -----------------------------------------------------------------


func test_storeys_lay_each_kind_and_stay_whole() -> void:
	var seen := {}
	for seed_value in SEEDS:
		for depth in range(1, World.FLOORS + 1):
			var w := World.create(seed_value)
			w.depth = depth
			FloorGen.build(w)
			var label := "seed %d storey %d" % [seed_value, depth]
			assert_true(FloorGen.connected(w), label)
			for kind: int in KINDS:
				if w.tiles.has(kind):
					seen[kind] = seen.get(kind, 0) + 1
			for p: Vector2i in w.vents:
				if w.vents[p] == Gas.INCENSE:
					assert_eq(w.tile(p), World.CENSER, "incense comes from a censer: " + label)
			for i in w.tiles.size():
				if w.tiles[i] == World.CENSER:
					assert_eq(w.vents.get(Grid.at(i)), Gas.INCENSE, "a censer breathes: " + label)
	for kind: int in KINDS:
		assert_gt(seen.get(kind, 0), 10, "kind %d appears" % kind)


func test_no_censer_before_the_second_storey_and_the_same_seed_lays_the_same_tiles() -> void:
	for seed_value in 4:
		var a := World.create(seed_value)
		var b := World.create(seed_value)
		assert_eq(a.tiles, b.tiles)
		assert_eq(a.vents, b.vents)
		for depth in range(1, 2):
			a.depth = depth
			FloorGen.build(a)
			assert_false(a.tiles.has(World.CENSER), "storey %d" % depth)
