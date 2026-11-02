extends GutTest
## How gas is told: the log, the hover and the walks.

const ME := Vector2i(4, 8)


## An open hall walled all round, Miho at ME.
func _hall() -> World:
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
	me.hp = 5
	me.max_hp = 5
	me.pos = ME
	w.actors.append(me)
	w.rng.seed = 5
	w.sense()
	return w


## Lays `amount` of `kind` on a block of tiles, `half` tiles out from `at`.
func _block(w: World, at: Vector2i, half: int, kind: int, amount: int) -> void:
	for y in range(at.y - half, at.y + half + 1):
		for x in range(at.x - half, at.x + half + 1):
			Gas.put(w, Vector2i(x, y), kind, amount)


func _lines(before: World, after: World, events: Array) -> Array[String]:
	var out: Array[String] = []
	out.assign(Messages.of(before, after, events).map(Messages.plain))
	return out


# --- the log -------------------------------------------------------------------


func test_steam_that_scalds_miho_says_so_in_the_log() -> void:
	var w := _hall()
	_block(w, ME, 2, Gas.STEAM, Gas.MAX)
	var before := w.clone()
	var lines := _lines(before, w, w.act({t = &"wait"}))
	assert_true(lines.has("증기에 데어 피해를 1 입었다"), str(lines))


func test_a_creature_in_steam_in_sight_is_named_in_the_log() -> void:
	var w := _hall()
	var at := ME + Vector2i(2, 0)
	var foe := FloorGen.spawn(w, &"jangseung", at)
	foe.magic.cooldown = 99
	_block(w, at + Vector2i(1, 0), 1, Gas.STEAM, Gas.MAX)
	w.sense()
	var before := w.clone()
	var lines := _lines(before, w, w.act({t = &"wait"}))
	assert_true(lines.has("장승이 증기에 데어 피해를 1 입었다"), str(lines))


func test_steam_out_of_sight_gives_no_line() -> void:
	var w := _hall()
	var far := Vector2i(30, 8)
	var foe := FloorGen.spawn(w, &"jangseung", far)
	foe.magic.cooldown = 99
	_block(w, far, 1, Gas.STEAM, Gas.MAX)
	w.sense()
	var before := w.clone()
	var events := w.act({t = &"wait"})
	assert_lt(foe.hp, foe.max_hp, "it was scalded")
	assert_eq(_lines(before, w, events), [] as Array[String])


func test_a_new_cloud_in_sight_is_told_and_one_out_of_sight_is_not() -> void:
	var w := _hall()
	var seen := ME + Vector2i(1, 0)
	var far := Vector2i(30, 8)
	var told := _lines(w, w, [{t = &"gas", at = seen, kind = Gas.SMOKE}])
	assert_eq(told, ["연기가 피어올랐다"] as Array[String])
	assert_eq(
		_lines(w, w, [{t = &"gas", at = seen, kind = Gas.FOG}]), ["안개가 피어올랐다"] as Array[String]
	)
	assert_eq(
		_lines(w, w, [{t = &"gas", at = seen, kind = Gas.STEAM}]), ["증기가 피어올랐다"] as Array[String]
	)
	assert_eq(_lines(w, w, [{t = &"gas", at = far, kind = Gas.SMOKE}]), [] as Array[String])


func test_a_fire_in_sight_tells_of_its_smoke() -> void:
	var w := _hall()
	var fire := ME + Vector2i(3, 0)
	w.set_tile(fire, World.BOARD)
	w.burning[fire] = World.BURN_ROUNDS
	var before := w.clone()
	var lines := _lines(before, w, w.act({t = &"wait"}))
	assert_true(lines.has("연기가 피어올랐다"), str(lines))


# --- travel --------------------------------------------------------------------


func test_a_walk_goes_round_steam_in_sight_but_not_round_fog() -> void:
	var w := _hall()
	var steam := ME + Vector2i(1, 0)
	var fog := ME + Vector2i(0, 1)
	w.known.fill(1)
	Gas.put(w, steam, Gas.STEAM, 2)
	Gas.put(w, fog, Gas.FOG, 2)
	w.sense()
	assert_false(Travel.walkable(w, steam))
	assert_true(Travel.walkable(w, fog))


# --- the hover -----------------------------------------------------------------


func test_a_tile_in_sight_tells_its_gas_from_the_rules() -> void:
	var w := _hall()
	var at := ME + Vector2i(1, 0)
	Gas.put(w, at, Gas.FOG, 2)
	w.sense()
	var text := Info.plain(Info.terrain(w, at))
	assert_string_contains(text, "안개: 2/%d" % Gas.MAX)
	assert_false(text.contains("시야 막음"), "thin gas leaves sight open")
	assert_string_contains(text, "감소: 초당 %d%%" % Gas.of(Gas.FOG, "decay"))
	assert_false(text.contains("피해"), text)
	Gas.put(w, at, Gas.FOG, 1)
	w.sense()
	assert_string_contains(Info.plain(Info.terrain(w, at)), "안개: 3/%d\n시야를 막음." % Gas.MAX)


func test_steam_tells_its_harm_decay_and_wetting() -> void:
	var w := _hall()
	var at := ME + Vector2i(1, 0)
	Gas.put(w, at, Gas.STEAM, 4)
	w.sense()
	var text := Info.plain(Info.terrain(w, at))
	assert_string_contains(text, "증기: 4/%d" % Gas.MAX)
	assert_string_contains(text, "감소: 초당 %d%%" % Gas.of(Gas.STEAM, "decay"))
	assert_string_contains(text, "초당 피해: %d" % Gas.of(Gas.STEAM, "harm"))
	assert_string_contains(text, "북: %d초 동안 소음 없음" % Drums.WET_ROUNDS)


func test_smoke_tells_its_decay() -> void:
	var w := _hall()
	var at := ME + Vector2i(1, 0)
	Gas.put(w, at, Gas.SMOKE, 5)
	w.sense()
	var text := Info.plain(Info.terrain(w, at))
	assert_string_contains(text, "연기: 5/%d" % Gas.MAX)
	assert_string_contains(text, "감소: 초당 %d%%" % Gas.of(Gas.SMOKE, "decay"))


func test_a_remembered_tile_does_not_tell_gas() -> void:
	var w := _hall()
	var at := ME + Vector2i(1, 0)
	Gas.put(w, at, Gas.STEAM, 4)
	w.sense()
	w.seen[Grid.index(at)] = 0
	var text := Info.plain(Info.terrain(w, at))
	assert_false(text.contains("증기"), text)


func test_a_creature_standing_in_gas_tells_it() -> void:
	var w := _hall()
	var at := ME + Vector2i(2, 0)
	var foe := FloorGen.spawn(w, &"dokkaebi", at)
	Gas.put(w, at, Gas.STEAM, 6)
	w.sense()
	var text := Info.plain(Info.creature(w, foe))
	assert_string_contains(text, "증기: 6/%d" % Gas.MAX)
	assert_string_contains(text, "초당 피해: 1")
	Gas.put(w, ME, Gas.FOG, 4)
	w.sense()
	assert_string_contains(Info.plain(Info.at(w, ME)), "안개: 4/%d" % Gas.MAX)


func test_every_gas_has_a_colour_and_a_glyph_for_the_map_and_the_text_view() -> void:
	for kind: int in Gas.ROWS:
		assert_true(Palette.GAS.has(kind), str(kind))
		assert_eq(Palette.GAS[kind][0].length(), 1)
		assert_true(Fonts.pixel().has_char(Palette.GAS[kind][0].unicode_at(0)), str(kind))
	assert_lt(
		Palette.gas_alpha(Gas.OPAQUE - 1), Palette.gas_alpha(Gas.OPAQUE), "thick reads thicker"
	)
	for n in range(1, Gas.MAX):
		assert_lt(Palette.gas_alpha(n), Palette.gas_alpha(n + 1), "amount %d" % n)


func test_a_vent_pond_tells_what_it_breathes_and_up_to_what_amount() -> void:
	var w := _hall()
	var at := ME + Vector2i(1, 0)
	w.set_tile(at, World.POND)
	w.sense()
	assert_false(Info.plain(Info.terrain(w, at)).contains("뿜는 기체"))
	w.vents[at] = Gas.FOG
	var text := Info.plain(Info.terrain(w, at))
	assert_string_contains(text, "뿜는 기체: 안개\n  최대 양: %d" % Gas.VENT_LEVEL)
