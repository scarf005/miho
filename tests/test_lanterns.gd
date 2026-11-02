extends GutTest
## Lanterns: knocked, struck, doused, relit.

const FOX := Cards.FOX
const ORB := Cards.ORB
const E := Vector2i(1, 0)
const WAIT := {t = &"wait"}


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
	return w


func _put(w: World, p: Vector2i, t: int) -> void:
	w.tiles[Grid.index(p)] = t


func _cast(cards: Array, dir: Vector2i) -> Dictionary:
	return {t = &"cast", spells = [{cards = cards, dir = dir}]}


func _foe(w: World, kind: StringName, at: Vector2i) -> Actor:
	var a := FloorGen.spawn(w, kind, at)
	a.magic.cooldown = 99
	return a


func _types(events: Array) -> Array:
	return events.map(func(e): return e.t)


func _noises(events: Array) -> Array:
	return events.filter(func(e): return e.t == &"noise")


func test_walking_into_a_lantern_knocks_it_out_with_a_clang() -> void:
	var w := _world()
	_put(w, Vector2i(5, 8), World.LANTERN)
	for y in range(1, Grid.H - 1):
		_put(w, Vector2i(7, y), World.WALL)
	_put(w, Vector2i(7, 8), World.DOOR)
	var listener := _foe(w, &"imugi", Vector2i(9, 8))
	assert_true(w.lit(Vector2i(6, 8)))
	var events := w.act({t = &"move", dir = E})
	assert_eq(w.tile(Vector2i(5, 8)), World.LANTERN_OUT)
	assert_eq(w.player().pos, Vector2i(4, 8), "the knock takes her move")
	assert_false(w.lit(Vector2i(6, 8)))
	assert_has(_types(events), &"smash")
	var clang: Dictionary = _noises(events)[0]
	assert_eq([clang.word, clang.loud], ["쨍", World.KNOCK])
	assert_eq(listener.alert, Actor.SEARCH, "heard through the door")
	assert_eq(listener.target, Vector2i(5, 8))


func test_a_noise_reaches_exactly_as_far_as_it_is_loud() -> void:
	var w := _world()
	_put(w, Vector2i(5, 8), World.LANTERN)
	var near := _foe(w, &"imugi", Vector2i(9, 8))
	var far := _foe(w, &"imugi", Vector2i(10, 4))
	w.act({t = &"move", dir = E})
	assert_eq(near.alert, Actor.SEARCH, "four steps away")
	assert_eq(far.alert, Actor.REST, "five steps away")


func test_water_douses_a_lantern_silently_and_a_searcher_or_fire_relights_it() -> void:
	var w := _world()
	w.cards.append(Cards.WATER)
	_put(w, Vector2i(10, 8), World.LANTERN)
	var events := w.act(_cast([FOX, Cards.WATER], E))
	events.append_array(w.act(WAIT))
	assert_eq(w.tile(Vector2i(10, 8)), World.LANTERN_OUT)
	assert_has(_types(events), &"douse")
	assert_eq(_noises(events), [], "silent")
	var searcher := _foe(w, &"dokkaebi", Vector2i(11, 9))
	searcher.alert = Actor.SEARCH
	searcher.target = Vector2i(14, 9)
	events = w.act(WAIT)
	assert_eq(w.tile(Vector2i(10, 8)), World.LANTERN)
	var relight: Dictionary = events.filter(func(e): return e.t == &"relight")[0]
	assert_eq(relight.id, searcher.id)
	assert_eq(searcher.pos, Vector2i(11, 9), "relighting takes its turn")
	var fire := _world()
	fire.cards.append(Cards.FIRE)
	_put(fire, Vector2i(10, 8), World.LANTERN_OUT)
	assert_false(fire.lit(Vector2i(12, 8)))
	fire.act(_cast([FOX, Cards.FIRE], E))
	assert_has(_types(fire.act(WAIT)), &"relight")
	assert_eq(fire.tile(Vector2i(10, 8)), World.LANTERN)
	assert_true(fire.lit(Vector2i(12, 8)))


func test_an_orb_smashes_the_lantern_or_closed_door_it_strikes() -> void:
	for t in [World.LANTERN, World.DOOR]:
		var w := _world()
		if t == World.DOOR:
			for y in range(1, Grid.H - 1):
				_put(w, Vector2i(10, y), World.WALL)
		_put(w, Vector2i(10, 8), t)
		var events := w.act(_cast([ORB], E))
		events.append_array(w.act(WAIT))
		events.append_array(w.act(WAIT))
		assert_eq(
			w.tile(Vector2i(10, 8)), World.LANTERN_BROKEN if t == World.LANTERN else World.FLOOR
		)
		assert_has(_types(events), &"smash")
		assert_has(_noises(events).map(func(e): return e.word), "쾅", "it bursts loudly")
		assert_eq(w.shots, [] as Array[Shot])


func test_an_orb_cast_at_a_lantern_breaks_it_however_near() -> void:
	for dist: int in [1, 3, 6]:
		var w := _world()
		var lantern := w.player().pos + E * dist
		_put(w, lantern, World.LANTERN)
		w.act(_cast([ORB], E))
		w.act(WAIT)
		w.act(WAIT)
		assert_eq(w.tile(lantern), World.LANTERN_BROKEN, "lantern %d tiles away" % dist)


func test_bumping_a_lantern_twice_puts_it_out_then_breaks_it_into_rubble_she_can_cross() -> void:
	var w := _world()
	var at := Vector2i(5, 8)
	_put(w, at, World.LANTERN)
	var first := w.act({t = &"move", dir = E})
	assert_eq(w.tile(at), World.LANTERN_OUT)
	assert_true(w.can({t = &"move", dir = E}), "a dark lantern can be knocked too")
	var second := w.act({t = &"move", dir = E})
	assert_eq(w.tile(at), World.LANTERN_BROKEN)
	assert_eq([first[0].was, second[0].was], [World.LANTERN, World.LANTERN_OUT])
	assert_eq(_noises(second)[0].word, "쨍", "every hit clangs")
	assert_eq(w.player().pos, Vector2i(4, 8), "a knock takes her move")
	w.act({t = &"move", dir = E})
	assert_eq(w.player().pos, at, "rubble is walked over")


func test_an_orb_breaks_a_lit_lantern_outright_so_no_one_relights_it() -> void:
	var w := _world()
	var at := Vector2i(10, 8)
	_put(w, at, World.LANTERN)
	var events := w.act(_cast([ORB], E))
	events.append_array(w.act(WAIT))
	events.append_array(w.act(WAIT))
	assert_eq(w.tile(at), World.LANTERN_BROKEN)
	var smashed := events.filter(func(e): return e.t == &"smash")
	assert_eq(smashed.map(func(e): return e.was), [World.LANTERN])
	_put(w, at, World.LANTERN_OUT)
	w.act(_cast([ORB], E))
	w.act(WAIT)
	w.act(WAIT)
	assert_eq(w.tile(at), World.LANTERN_BROKEN, "and a dark one")
	w.act(_cast([ORB], E))
	w.act(WAIT)
	w.act(WAIT)
	assert_eq(w.shots[0].pos, Vector2i(11, 8), "rubble no longer stops an orb")


func test_water_douses_a_lantern_but_never_breaks_it() -> void:
	var w := _world()
	w.cards.append(Cards.WATER)
	var at := Vector2i(10, 8)
	_put(w, at, World.LANTERN)
	for i in 3:
		w.act(_cast([ORB, Cards.WATER], E))
		w.act(WAIT)
		w.act(WAIT)
		assert_eq(w.tile(at), World.LANTERN_OUT, "water orb %d" % i)
		w.tails = 4


func test_fire_relights_a_dark_lantern_but_not_rubble() -> void:
	var w := _world()
	w.cards.append(Cards.FIRE)
	_put(w, Vector2i(10, 8), World.LANTERN_BROKEN)
	var events := w.act(_cast([FOX, Cards.FIRE], E))
	events.append_array(w.act(WAIT))
	assert_eq(w.tile(Vector2i(10, 8)), World.LANTERN_BROKEN)
	assert_does_not_have(_types(events), &"relight")
	var orb := _world()
	orb.cards.append(Cards.FIRE)
	_put(orb, Vector2i(10, 8), World.LANTERN_OUT)
	orb.act(_cast([ORB, Cards.FIRE], E))
	orb.act(WAIT)
	orb.act(WAIT)
	assert_eq(orb.tile(Vector2i(10, 8)), World.LANTERN, "fire lights what it strikes")


func test_a_searcher_relights_a_dark_lantern_but_not_rubble() -> void:
	for t in [World.LANTERN_OUT, World.LANTERN_BROKEN]:
		var w := _world()
		_put(w, Vector2i(10, 8), t)
		var searcher := _foe(w, &"dokkaebi", Vector2i(11, 9))
		searcher.alert = Actor.SEARCH
		searcher.target = Vector2i(14, 9)
		w.act(WAIT)
		assert_eq(w.tile(Vector2i(10, 8)), World.LANTERN if t == World.LANTERN_OUT else t)


func test_a_searcher_without_a_fire_spell_leaves_a_dark_lantern_dark() -> void:
	var w := _world()
	_put(w, Vector2i(10, 8), World.LANTERN_OUT)
	var searcher := _foe(w, &"jangseung", Vector2i(11, 9))
	searcher.alert = Actor.SEARCH
	searcher.target = Vector2i(14, 9)
	w.act(WAIT)
	assert_eq(w.tile(Vector2i(10, 8)), World.LANTERN_OUT)
