extends GutTest
## Which sound each event makes, and that a plate going off is always heard.

const E := Vector2i(1, 0)
const PLATE := Vector2i(7, 8)
const FAR := Vector2i(30, 8)
## One sample of every event that makes a sound, and the sound it makes.
const SOUNDS := [
	[{t = &"move"}, &"step"],
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
	[{t = &"smash"}, &"clash"],
	[{t = &"absorb"}, &"absorb"],
	[{t = &"grow"}, &"card"],
	[{t = &"card"}, &"card"],
	[{t = &"heal"}, &"card"],
	[{t = &"altar"}, &"card"],
	[{t = &"creak"}, &"card"],
	[{t = &"read"}, &"card"],
	[{t = &"trap", kind = World.TRAP_ALARM}, &"gong"],
	[{t = &"trap", kind = World.TRAP_FIRE}, &"trap"],
	[{t = &"find"}, &"find"],
	[{t = &"open"}, &"door"],
	[{t = &"close"}, &"door"],
	[{t = &"unseal"}, &"door"],
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
	{t = &"crumble"},
	{t = &"soak"},
	{t = &"wet"},
	{t = &"ride"},
	{t = &"leap"},
	{t = &"swap"},
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
