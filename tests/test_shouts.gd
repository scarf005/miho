extends GutTest
## Shouts (DCSS handle_monster_shouts): a creature of heaven that starts to hunt
## Miho shouts its word, a noise of its own loudness; every creature of heaven
## that hears it, is not hunting and is not deaf searches where it saw her.

const WAIT := {t = &"wait"}
const ME := Vector2i(4, 8)


## An unlit open hall, Miho at ME.
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
	me.pos = ME
	w.actors.append(me)
	return w


## A creature searching the tile it stands on, so it is awake and not hunting.
func _creature(w: World, kind: StringName, at: Vector2i) -> Actor:
	var a := FloorGen.spawn(w, kind, at)
	a.cooldown = 99
	a.alert = Actor.SEARCH
	a.target = at
	a.lost = -99
	return a


func _shouts(events: Array) -> Array:
	return events.filter(func(e): return e.t == &"shout")


func test_a_creature_that_notices_miho_shouts_its_word() -> void:
	var w := _world()
	var a := _creature(w, &"dokkaebi", ME + Vector2i(1, 0))
	var events := w.act(WAIT)
	assert_eq(a.alert, Actor.HUNT)
	var cry: Dictionary = Bestiary.info(&"dokkaebi").shout
	assert_eq(_shouts(events).map(func(e): return [e.id, e.word]), [[a.id, cry.word]])
	var noise := events.filter(func(e): return e.t == &"noise" and e.word == cry.word)
	assert_eq(noise.map(func(e): return [e.at, e.loud]), [[a.pos, cry.loud]])


func test_it_shouts_once_per_hunt() -> void:
	var w := _world()
	_creature(w, &"dokkaebi", ME + Vector2i(1, 0))
	w.act(WAIT)
	assert_eq(_shouts(w.act(WAIT)), [])


func test_those_in_earshot_search_where_the_shouter_saw_miho() -> void:
	var w := _world()
	var shouter := _creature(w, &"bulgae", ME + Vector2i(1, 0))
	var loud: int = Bestiary.info(&"bulgae").shout.loud
	var near := _creature(w, &"imugi", shouter.pos + Vector2i(loud, 0))
	var far := _creature(w, &"imugi", shouter.pos + Vector2i(loud + 1, 0))
	var deaf := _creature(w, &"jangseung", shouter.pos + Vector2i(0, 2))
	var spot := far.target
	w.act(WAIT)
	assert_eq(near.alert, Actor.SEARCH)
	assert_eq(near.target, ME, "where the shouter saw Miho")
	assert_eq(far.target, spot, "out of earshot")
	assert_eq(deaf.target, deaf.pos, "deaf")


func test_a_hunter_keeps_its_own_quarry() -> void:
	var w := _world()
	_creature(w, &"bulgae", ME + Vector2i(1, 0))
	var hunter := _creature(w, &"imugi", ME + Vector2i(4, 0))
	hunter.alert = Actor.HUNT
	hunter.target = Vector2i(20, 3)
	w.act(WAIT)
	assert_eq(hunter.alert, Actor.HUNT)
	assert_ne(hunter.target, ME)


func test_a_silent_kind_makes_no_sound_when_it_notices() -> void:
	for kind in Bestiary.KINDS:
		if kind != &"miho" and not Bestiary.info(kind).has("shout"):
			var w := _world()
			Mind.hunt_from(w, _creature(w, kind, ME + Vector2i(1, 0)), ME)
			assert_eq(_shouts(w.events), [], kind)
			assert_eq(w.events.filter(func(e): return e.t == &"noise"), [], kind)


func test_the_hover_and_the_doc_tell_the_shout() -> void:
	var cry: Dictionary = Bestiary.info(&"dokkaebi").shout
	var text := Info.plain(Info.creature_facts(Codex.foe(&"dokkaebi"), []))
	assert_true(text.split("\n").has("말할 수 있다."), text)
	assert_false(text.contains(cry.word), "no word in the hover")
	var mute := Info.plain(Info.creature_facts(Codex.foe(&"jangseung"), []))
	assert_false(mute.contains("말할 수 있다"), mute)


func test_the_log_tells_a_shout_in_sight_and_one_heard_out_of_it() -> void:
	var w := _world()
	_creature(w, &"dokkaebi", ME + Vector2i(1, 0))
	w.sense()
	var before := w.clone()
	var lines := Messages.of(before, w, w.act(WAIT)).map(Messages.plain)
	assert_has(lines, "도깨비가 낄낄 소리쳤다")
	var far := _world()
	var hunter := _creature(far, &"bulgae", Vector2i(12, 8))
	far.sense()
	before = far.clone()
	Mind.hunt_from(far, hunter, ME)
	var heard := Messages.of(before, far, far.events).map(Messages.plain)
	assert_has(heard, "멀리서 %s 소리를 들었다" % Bestiary.info(&"bulgae").shout.word)


func test_a_shout_in_sight_pops_its_bare_word_over_the_shouter() -> void:
	var popup := Perceived.popup_of({t = &"shout", word = "낄낄", where = ME})
	assert_eq(popup.text, "낄낄")
	assert_eq(popup.at, ME)
	assert_eq(popup.color, Palette.SOUND)
