extends GutTest
## Which sound each event makes, and that a plate going off is always heard.

const E := Vector2i(1, 0)
const PLATE := Vector2i(7, 8)
const FAR := Vector2i(30, 8)
## One sample of every event that makes a sound, and the sound it makes.
const SOUNDS := [
	[{t = &"move", word = "탁", loud = 0}, &"step"],
	[{t = &"move", word = "사각", loud = 2}, &"rustle"],
	[{t = &"move", word = "바스락", loud = 2}, &"rustle"],
	[{t = &"move", word = "철벅", loud = 2}, &"splash"],
	[{t = &"move", word = "삐걱", loud = 3}, &"creak"],
	[{t = &"leap"}, &"foxfire"],
	[{t = &"swap"}, &"foxfire"],
	[{t = &"crumble"}, &"fall"],
	[{t = &"spot"}, &"find"],
	[{t = &"cast", cards = [Cards.FOX, Cards.FIRE]}, &"foxfire"],
	[{t = &"cast", cards = [Cards.ORB, Cards.FIRE]}, &"orb"],
	[{t = &"cast", cards = [Cards.ORB, Cards.WATER, Cards.WOOD, Cards.FIRE]}, &"orb"],
	[{t = &"hit"}, &"blast"],
	[{t = &"burst"}, &"blast"],
	[{t = &"blast"}, &"blast"],
	[{t = &"splash"}, &"blast"],
	[{t = &"drum", wet = false}, &"blast"],
	[{t = &"clash"}, &"clash"],
	[{t = &"snuff"}, &"clash"],
	[{t = &"claw"}, &"clash"],
	[{t = &"melee"}, &"clash"],
	[{t = &"push"}, &"clash"],
	[{t = &"smash", was = World.JAR}, &"shatter"],
	[{t = &"smash", was = World.WATER_JAR}, &"shatter"],
	[{t = &"smash", was = World.WINDOW}, &"clash"],
	[{t = &"smash", was = World.WALL}, &"blast"],
	[{t = &"smash", was = World.DRUM}, &"tear"],
	[{t = &"smash", was = World.DOOR}, &"fall"],
	[{t = &"smash", was = World.WOOD_WALL}, &"fall"],
	[{t = &"collapse"}, &"blast"],
	[{t = &"absorb"}, &"absorb"],
	[{t = &"grow"}, &"card"],
	[{t = &"card"}, &"card"],
	[{t = &"heal"}, &"card"],
	[{t = &"altar"}, &"card"],
	[{t = &"creak"}, &"card"],
	[{t = &"read"}, &"card"],
	[{t = &"trap", kind = World.TRAP_ALARM}, &"gong"],
	[{t = &"trap", kind = World.TRAP_FIRE}, &"trap"],
	[{t = &"find", kind = World.DOOR}, &"find"],
	[{t = &"find", kind = World.TRAP_FIRE}, &"warn"],
	[{t = &"find", kind = World.TRAP_ALARM}, &"warn"],
	[{t = &"noise", word = "바스락"}, &"rustle"],
	[{t = &"noise", word = "철벅"}, &"splash"],
	[{t = &"open"}, &"door"],
	[{t = &"close"}, &"door"],
	[{t = &"noise", word = "쨍그랑"}, &"shatter"],
	[{t = &"root"}, &"root"],
	[{t = &"freeze"}, &"root"],
	[{t = &"sprout"}, &"root"],
	[{t = &"guise"}, &"root"],
	[{t = &"unmask"}, &"hiss"],
	[{t = &"stun"}, &"stun"],
	[{t = &"gas", kind = Gas.STEAM}, &"hiss"],
	[{t = &"scald"}, &"hiss"],
	[{t = &"cool"}, &"hiss"],
	[{t = &"douse"}, &"hiss"],
	[{t = &"dry"}, &"hiss"],
	[{t = &"quench"}, &"hiss"],
	[{t = &"thaw"}, &"hiss"],
	[{t = &"alight"}, &"burn"],
	[{t = &"ignite"}, &"burn"],
	[{t = &"heat"}, &"burn"],
	[{t = &"relight"}, &"burn"],
	[{t = &"stick"}, &"foxfire"],
	[{t = &"yelp"}, &"foxfire"],
	[{t = &"noise", word = Lure.WORD}, &"foxfire"],
	[{t = &"hurt"}, &"hurt"],
	[{t = &"die"}, &"fall"],
	[{t = &"charge"}, &"charge"],
	[{t = &"notice"}, &"charge"],
	[{t = &"feud"}, &"charge"],
	[{t = &"noise", word = "낄낄"}, &"charge"],
	[{t = &"omen"}, &"charge"],
	[{t = &"arrive"}, &"charge"],
	[{t = &"wake"}, &"charge"],
	[{t = &"ascend"}, &"ascend"],
	[{t = &"fall", depth = 2}, &"fall"],
	[{t = &"won"}, &"win"],
	[{t = &"lost"}, &"lose"],
	[{t = &"noise", word = Traps.GONG}, &"gong"],
	[{t = &"noise", word = "우지끈"}, &"fall"],
]
## Events that only keep the books or are told by another event, so they are silent.
const SILENT := [
	{t = &"hit", spray = true},
	{t = &"drum", wet = true},
	{t = &"fall"},
	{t = &"gas", kind = Gas.SMOKE},
	{t = &"heed"},
	{t = &"calm"},
	{t = &"truce"},
	{t = &"scatter"},
	{t = &"shout"},
	{t = &"spawn"},
	{t = &"spray"},
	{t = &"fly"},
	{t = &"land"},
	{t = &"fade"},
	{t = &"soul"},
	{t = &"prick"},
	{t = &"sear"},
	{t = &"burn"},
	{t = &"burnout"},
	{t = &"become"},
	{t = &"trample"},
	{t = &"soak"},
	{t = &"wet"},
	{t = &"ride"},
	{t = &"cast", cards = [Cards.WATER, Cards.WOOD, Cards.FIRE, Cards.EARTH]},
]


## An open hall walled at the edges with no light, Miho at (4, 8).
func _world() -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	for y in range(1, Grid.H - 1):
		for x in range(1, Grid.W - 1):
			w.tiles[Grid.index(Vector2i(x, y))] = World.FLOOR
	w.rooms.assign([Rect2i(1, 1, Grid.W - 2, Grid.H - 2)])
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.hp = 3
	me.max_hp = 3
	me.pos = Vector2i(4, 8)
	w.actors.append(me)
	w.depth = 4
	w.tails = 1
	w.sense()
	return w


## The sounds Miho is told of in the round from `before` to `after`.
func _heard(before: World, after: World) -> Array:
	var out := []
	for f in Perceived.of(before, after, after.events).facts:
		out.append(Sfx.sound_of(f))
	return out


func test_every_event_in_the_list_makes_its_sound() -> void:
	for pair in SOUNDS:
		assert_eq(Sfx.sound_of(pair[0]), pair[1], str(pair[0]))


func test_the_bookkeeping_events_are_silent() -> void:
	for e in SILENT:
		assert_eq(Sfx.sound_of(e), &"", str(e))


func test_every_event_the_core_emits_is_sounded_or_silent_on_purpose() -> void:
	var known := {&"open": true, &"close": true}
	for pair in SOUNDS:
		known[pair[0].t] = true
	for e in SILENT:
		known[e.t] = true
	var found := RegEx.create_from_string('\\bt = &"(\\w+)"')
	for file in DirAccess.get_files_at("res://src/core"):
		for m in found.search_all(FileAccess.get_file_as_string("res://src/core/" + file)):
			assert_true(
				known.has(StringName(m.get_string(1))), "%s in %s" % [m.get_string(1), file]
			)


func test_every_sound_is_a_listed_file() -> void:
	var names := {}
	for pair in SOUNDS:
		names[pair[1]] = true
	for w: StringName in Sfx.WORDS.values():
		names[w] = true
	for n: StringName in names:
		assert_has(Sfx.NAMES, n)
	for n: StringName in Sfx.NAMES:
		assert_true(ResourceLoader.exists(Sfx.DIR % n), "%s has a file" % n)


func test_the_gong_word_is_the_gong_not_a_blast() -> void:
	assert_eq(Sfx.WORDS[Traps.GONG], &"gong")


func test_miho_stepping_on_the_alarm_plate_in_sight_hears_the_gong() -> void:
	var w := _world()
	w.player().pos = PLATE - E
	w.traps[PLATE] = World.TRAP_ALARM
	var before := w.clone()
	w.act({t = &"move", dir = E})
	var types := Perceived.of(before, w, w.events).facts.map(func(f): return f.t)
	assert_does_not_have(types, &"noise", "her own gong is no noise she is told of")
	assert_has(_heard(before, w), &"gong")
	assert_does_not_have(_heard(before, w), &"trap", "the gong replaces the click")


func test_a_creature_stepping_on_the_alarm_plate_in_sight_is_heard_once() -> void:
	var w := _world()
	w.tiles[Grid.index(PLATE + Vector2i(0, 2))] = World.LANTERN
	w._changed()
	w.traps[PLATE] = World.TRAP_ALARM
	var foe := FloorGen.spawn(w, &"dokkaebi", PLATE - E)
	foe.cooldown = 99
	w.sense()
	var before := w.clone()
	w.push(foe, E, 1)
	w.sense()
	assert_eq(_heard(before, w).count(&"gong"), 1)


func test_a_creature_stepping_on_the_alarm_plate_out_of_sight_is_heard_as_a_noise() -> void:
	var w := _world()
	w.traps[FAR] = World.TRAP_ALARM
	var foe := FloorGen.spawn(w, &"dokkaebi", FAR - E)
	foe.cooldown = 99
	w.sense()
	var before := w.clone()
	w.push(foe, E, 1)
	w.sense()
	assert_eq(_heard(before, w).count(&"gong"), 1)


## What Miho's step east onto a tile of `tile` sounds like: the sound and its level.
func _step_onto(tile: int, wet := 0) -> Dictionary:
	var w := _world()
	w.tiles[Grid.index(w.player().pos + E)] = tile
	w._changed()
	w.player().wet = wet
	var step: Dictionary = w.act({t = &"move", dir = E}).filter(func(e): return e.t == &"move")[0]
	return {sound = Sfx.sound_of(step), db = Sfx.level_of(step)}


func test_a_step_sounds_by_the_tile_stepped_onto() -> void:
	assert_eq(_step_onto(World.FLOOR).sound, &"step")
	assert_eq(_step_onto(World.BAMBOO).sound, &"rustle")
	assert_eq(_step_onto(World.LEAVES).sound, &"rustle")
	assert_eq(_step_onto(World.REEDS).sound, &"rustle")
	assert_eq(_step_onto(World.BOARD).sound, &"creak")
	assert_eq(_step_onto(World.SHALLOW).sound, &"splash")


func test_a_wet_creature_splashes_on_dry_floor() -> void:
	assert_eq(_step_onto(World.FLOOR, Status.WET).sound, &"splash")


func test_a_step_is_louder_the_farther_its_tread_is_heard() -> void:
	var bare: float = _step_onto(World.FLOOR).db
	assert_lt(bare, _step_onto(World.BAMBOO).db)
	assert_lt(_step_onto(World.BAMBOO).db, _step_onto(World.BOARD).db)
	assert_eq(bare, Sfx.LEVEL[&"move"], "bare ground keeps the old level")


func test_mud_swallows_the_step_to_the_plain_one() -> void:
	assert_eq(_step_onto(World.MUD).sound, &"step")


## The find events of a round in which Miho notices what stands next to her.
func _finds(setup: Callable) -> Array:
	var w := _world()
	setup.call(w)
	w.sense()
	return w.events.filter(func(e): return e.t == &"find")


func test_finding_a_plate_warns() -> void:
	var finds := _finds(func(w): w.traps[w.player().pos + E] = World.TRAP_FIRE)
	assert_eq(finds.size(), 1)
	assert_eq(Sfx.sound_of(finds[0]), &"warn")


func test_finding_a_hidden_door_chimes() -> void:
	var finds := _finds(
		func(w):
			w.tiles[Grid.index(w.player().pos + E)] = World.WALL
			w.secrets[w.player().pos + E] = true
	)
	assert_eq(finds.size(), 1)
	assert_eq(Sfx.sound_of(finds[0]), &"find")


## The useful things first seen in Miho's move from tile `from` to tile `to` of the hall.
func _spotted_on(w: World, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	w.player().pos = from
	w.sense()
	var before := w.clone()
	w.player().pos = to
	w.sense()
	return Perceived.spotted(before, w)


func test_the_stairs_a_peach_and_the_elixir_are_spotted_once() -> void:
	var w := _world()
	w.stairs = Vector2i(24, 8)
	w.peaches.assign([Vector2i(24, 10)])
	w.elixir = Vector2i(24, 6)
	var far := Vector2i(4, 8)
	var near := Vector2i(18, 8)
	assert_eq(_spotted_on(w, far, far), [], "out of sight")
	assert_eq(_spotted_on(w, far, near).size(), 3, "all three come into sight")
	assert_eq(_spotted_on(w, near, near), [], "not again while in sight")
	_spotted_on(w, near, far)
	assert_eq(_spotted_on(w, far, near), [], "not again on coming back")


func test_a_new_storey_spots_what_is_in_sight_at_once() -> void:
	var w := _world()
	w.stairs = Vector2i(6, 8)
	var before := w.clone()
	before.depth -= 1
	assert_eq(Perceived.spotted(before, w), [w.stairs])


func test_a_talisman_stand_and_a_library_are_spotted_but_not_an_altar() -> void:
	var w := _world()
	w.sites.append({kind = &"yard", at = Vector2i(24, 8), card = Cards.FIRE})
	w.sites.append({kind = &"library", at = Vector2i(24, 10)})
	w.sites.append({kind = &"altar", at = Vector2i(24, 6), fallen = 0})
	assert_eq(_spotted_on(w, Vector2i(4, 8), Vector2i(18, 8)).size(), 2)


func test_the_view_chimes_for_a_spotted_thing_in_the_round_it_comes_into_sight() -> void:
	var w := _world()
	w.stairs = Vector2i(24, 8)
	var t: Term = autofree(Term.new())
	watch_signals(t)
	var before := w.clone()
	w.player().pos = Vector2i(18, 8)
	w.sense()
	await t.play([], before, w)
	assert_signal_emit_count(t, "shown", 1)
	assert_eq(get_signal_parameters(t, "shown")[0].t, &"spot")
	await t.play([], w.clone(), w)
	assert_signal_emit_count(t, "shown", 1, "the next round is quiet")
