extends GutTest
## What a jar holds: fixed with the storey, hidden, and let out when the jar breaks.

const E := Vector2i(1, 0)
const WAIT := {t = &"wait"}
const AT := Vector2i(5, 8)
const FAR := Vector2i(8, 8)
const NEAR_FOE := Vector2i(6, 10)
const FAR_FOE := Vector2i(7, 11)
const SEEDS := 12
const ORB := {t = &"cast", spells = [{cards = [Cards.ORB], dir = E}]}


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


func _jar(w: World, at: Vector2i, what: StringName) -> void:
	w.set_tile(at, World.JAR)
	w.jars[at] = what
	w.sense()


## Breaks a jar holding `what` by `how` and returns every event of the rounds.
func _break(w: World, how: StringName, what: StringName) -> Array:
	var seen := []
	if how == &"bump":
		_jar(w, AT, what)
		seen.append_array(w.act({t = &"move", dir = E}))
	else:
		_jar(w, FAR, what)
		seen.append_array(w.act(ORB))
		for i in 4:
			seen.append_array(w.act(WAIT))
	return seen


func _foe(w: World, at: Vector2i) -> Actor:
	var a := FloorGen.spawn(w, &"dokkaebi", at)
	a.cooldown = 99
	w.sense()
	return a


func _jars_of(seed_value: int) -> Dictionary:
	var w := Built.world(seed_value)
	return w.jars


# --- what a storey's jars hold -------------------------------------------------


func test_a_seed_fills_its_jars_the_same_every_time() -> void:
	var held := 0
	for s in SEEDS:
		var jars := _jars_of(s)
		held += jars.size()
		assert_eq(_jars_of(s), jars, "seed %d" % s)
	assert_gt(held, 0, "the storeys have jars")


func test_other_seeds_fill_their_jars_differently() -> void:
	var seen := {}
	for s in SEEDS:
		seen[str(_jars_of(s))] = true
	assert_gt(seen.size(), 1)


func test_every_jar_of_a_storey_holds_one_effect_of_the_table() -> void:
	var ids := Jars.ROWS.map(func(row): return row.id)
	for s in SEEDS:
		var w := World.create(s)
		var jars := []
		for i in w.tiles.size():
			if w.tiles[i] == World.JAR:
				jars.append(Grid.at(i))
		jars.sort()
		var held := w.jars.keys()
		held.sort()
		assert_eq(held, jars, "seed %d: exactly the jars have contents" % s)
		for what: StringName in w.jars.values():
			assert_true(ids.has(what), str(what))


func test_the_hover_does_not_tell_what_a_jar_holds() -> void:
	var told := {}
	for row: Dictionary in Jars.ROWS:
		var w := _world()
		_jar(w, AT, row.id)
		told[Info.plain(Info.terrain(w, AT))] = true
	assert_eq(told.size(), 1)


func test_a_kept_storey_keeps_its_jars() -> void:
	var w := World.create(3)
	var jars := w.jars.duplicate()
	Storeys.leave(w)
	Storeys.enter(w, w.depth)
	assert_eq(w.jars, jars)


# --- breaking a jar --------------------------------------------------------------


func test_water_floods_the_bare_floor_round_the_jar_and_puts_out_fire() -> void:
	for how in [&"bump", &"orb"]:
		var w := _world()
		var at := AT if how == &"bump" else FAR
		_put_round(w, at)
		_break(w, how, &"water")
		assert_eq(w.tile(at), World.SHALLOW, "%s: the jar's own tile" % how)
		assert_eq(w.tile(at + Vector2i(1, 1)), World.SHALLOW)
		assert_eq(w.tile(at + Vector2i(0, -1)), World.LANTERN_OUT, "the lantern is out")
		assert_eq(w.tile(at + Vector2i(0, 1)), World.BOARD, "other kinds stay")
		assert_false(w.burning.has(at + Vector2i(0, 1)), "the fire is out")
		assert_ne(w.tile(at + Vector2i(1, 0)), World.SHALLOW, "a plate's tile stays dry")
		assert_eq(w.tile(at + Vector2i(3, 0)), World.FLOOR, "three tiles away is dry")


func _put_round(w: World, at: Vector2i) -> void:
	w.set_tile(at + Vector2i(0, 1), World.BOARD)
	w.set_tile(at + Vector2i(0, -1), World.LANTERN)
	w.traps[at + Vector2i(1, 0)] = World.TRAP_ALARM
	w.ignite(at + Vector2i(0, 1))


func test_kimchi_lies_where_the_jar_stood() -> void:
	for how in [&"bump", &"orb"]:
		var w := _world()
		_break(w, how, Jars.KIMCHI)
		assert_eq(Jars.spots(w), [AT if how == &"bump" else FAR], str(how))


func test_a_jar_gives_its_effect_once_and_an_empty_one_nothing() -> void:
	for how in [&"bump", &"orb"]:
		var w := _world()
		_break(w, how, &"empty")
		assert_true(Jars.spots(w).is_empty(), str(how))
		assert_true(w.jars.is_empty())
		var told := w.events.filter(func(e): return e.t == &"jar")
		assert_true(told.is_empty(), "an empty jar tells nothing more")
	var w := _world()
	_jar(w, AT, Jars.KIMCHI)
	w.act({t = &"move", dir = E})
	assert_false(w.jars.has(AT), "the effect is spent")


func test_a_torn_effigy_hurts_the_nearest_creature_miho_sees() -> void:
	for how in [&"bump", &"orb"]:
		var w := _world()
		var near := _foe(w, NEAR_FOE)
		var far := _foe(w, FAR_FOE)
		var hp := [near.hp, far.hp]
		_break(w, how, &"effigy")
		assert_eq(near.hp, hp[0] - Jars.EFFIGY_HARM, "%s: the nearest" % how)
		assert_eq(far.hp, hp[1], "%s: only one" % how)


func test_a_torn_effigy_with_no_creature_in_sight_hurts_none() -> void:
	var w := _world()
	var hidden := FloorGen.spawn(w, &"jangseung", Vector2i(30, 12))
	var hp := hidden.hp
	_break(w, &"bump", &"effigy")
	assert_eq(hidden.hp, hp)
	assert_eq(w.player().hp, 3)


func test_a_fallen_scarecrow_sends_the_creatures_that_see_it_to_search_there() -> void:
	for how in [&"bump", &"orb"]:
		var w := _world()
		var foe := _foe(w, NEAR_FOE)
		_break(w, how, &"scarecrow")
		var at := AT if how == &"bump" else FAR
		assert_eq(Notice.at(w, at).get("kind"), &"scarecrow", str(how))
		if how == &"bump":
			assert_eq(foe.alert, Actor.SEARCH)
			assert_eq(foe.target, at)


# --- kimchi ---------------------------------------------------------------------


func _kimchi(hp: int) -> World:
	var w := _world()
	w.player().hp = hp
	w.sites.append({kind = Jars.KIMCHI, at = AT})
	return w


func test_kimchi_heals_one_and_is_eaten() -> void:
	var w := _kimchi(2)
	w.act({t = &"move", dir = E})
	assert_eq([w.player().hp, w.player().max_hp], [2 + World.HEAL, 3])
	assert_true(Jars.spots(w).is_empty())


func test_kimchi_stays_while_she_is_at_full_health_and_she_keeps_her_scent() -> void:
	var w := _kimchi(3)
	w.act({t = &"move", dir = E})
	assert_eq([w.player().hp, w.player().max_hp], [3, 3])
	assert_eq(Jars.spots(w), [AT] as Array[Vector2i], "it stays for later")
	assert_eq(w.pungent, 0)
	assert_false(w.events.any(func(e): return e.t == &"heal"))


func test_she_eats_the_kimchi_under_her_once_she_is_hurt() -> void:
	var w := _kimchi(3)
	w.act({t = &"move", dir = E})
	w.hurt(w.player(), 1)
	w.act({t = &"wait"})
	assert_eq(w.player().hp, 3)
	assert_true(Jars.spots(w).is_empty())


func test_a_hurt_miho_never_goes_above_the_maximum() -> void:
	var w := _kimchi(2)
	w.player().max_hp = 2 + World.HEAL
	w.act({t = &"move", dir = E})
	assert_eq(w.player().hp, w.player().max_hp)


func test_kimchi_makes_her_scent_strong_for_a_number_of_rounds() -> void:
	var w := _kimchi(2)
	w.act({t = &"move", dir = E})
	assert_true(w.strong.has(AT), "the tile she ate on")
	w.act({t = &"move", dir = E})
	assert_true(w.strong.has(AT + E), "the next tile she walks")
	for i in Jars.PUNGENT_ROUNDS:
		w.act(WAIT)
	w.act({t = &"move", dir = E})
	assert_false(w.strong.has(AT + E * 2), "later tiles are plain")


func test_a_hunter_follows_a_strong_trail_longer_than_a_plain_one() -> void:
	for strong in [true, false]:
		var w := _world()
		w.round_no = 100
		var foe := FloorGen.spawn(w, &"dokkaebi", Vector2i(10, 8))
		foe.cooldown = 99
		var trail := Vector2i(11, 8)
		w.scent.resize(w.tiles.size())
		w.scent[Grid.index(trail)] = w.round_no + 1 - Scent.TRAIL_AGE - 1
		if strong:
			w.strong[trail] = true
		assert_eq(Scent.next(w, foe) == trail, strong, "strong %s" % strong)
		w.round_no += Scent.STRONG_EXTRA
		assert_eq(Scent.next(w, foe), foe.pos, "even a strong trail goes cold")


func test_water_washes_a_strong_trail_away() -> void:
	var w := _world()
	w.pungent = Jars.PUNGENT_ROUNDS
	Scent.lay(w, AT)
	assert_true(w.strong.has(AT))
	Scent.clear(w, AT)
	assert_false(w.strong.has(AT))


# --- 소금, 팥 and 숯 ----------------------------------------------------------------


func _lay_trail(w: World) -> void:
	w.scent.resize(w.tiles.size())
	for x in range(8, 12):
		w.scent[Grid.index(Vector2i(x, 8))] = w.round_no + x
	w.strong[Vector2i(10, 8)] = true


func test_salt_clears_the_scent_trail_so_a_hunter_follows_nothing() -> void:
	for how in [&"bump", &"orb"]:
		var w := _world()
		_lay_trail(w)
		var foe := _foe(w, Vector2i(9, 9))
		assert_ne(Scent.next(w, foe), foe.pos, "%s: a trail to follow before" % how)
		_break(w, how, &"salt")
		assert_eq(Scent.next(w, foe), foe.pos, "%s: nothing to follow" % how)
		assert_true(w.strong.is_empty(), str(how))


func test_beans_stun_each_creature_of_heaven_round_the_jar_and_not_miho() -> void:
	for how in [&"bump", &"orb"]:
		var w := _world()
		var at := AT if how == &"bump" else FAR
		var near := _foe(w, at + Vector2i(0, 1))
		var far := _foe(w, at + Vector2i(0, 3))
		var stunned := {}
		for e in _break(w, how, &"beans").filter(func(e): return e.t == &"stun"):
			stunned[e.id] = e.rounds
		assert_eq(stunned.get(near.id), Jars.BEANS_STUN, "%s: round the jar" % how)
		assert_false(stunned.has(far.id), "%s: three tiles away" % how)
		assert_false(stunned.has(w.player().id), "%s: Miho is not stunned" % how)


func test_miho_beside_a_jar_of_beans_is_not_stunned() -> void:
	var w := _world()
	_jar(w, AT, &"beans")
	Structures.broke(w, World.JAR, AT)
	assert_eq(Grid.cheb(w.player().pos, AT), 1)
	assert_eq(w.player().stunned, 0)


func test_beans_make_the_stun_sound_once_for_a_creature() -> void:
	var w := _world()
	_foe(w, AT + Vector2i(0, 1))
	_break(w, &"bump", &"beans")
	var sounds := []
	for e in w.events:
		sounds.append_array(Sfx.sounds_of(e))
	assert_eq(sounds.count(&"stun"), 1)


func test_coals_spill_hot_ground_on_the_jar_and_its_four_sides() -> void:
	for how in [&"bump", &"orb"]:
		var w := _world()
		var at := AT if how == &"bump" else FAR
		var heated := []
		for e in _break(w, how, &"coals").filter(func(e): return e.t == &"heat"):
			heated.append_array(e.tiles)
		var ring: Array[Vector2i] = [at]
		for d in Placement.SIDES:
			ring.append(at + d)
		ring.sort()
		heated.sort()
		assert_eq(heated, ring, str(how))


func test_coals_hurt_a_creature_standing_on_them() -> void:
	var w := _world()
	var foe := _foe(w, AT + Vector2i(0, 1))
	var hp := foe.hp
	_break(w, &"bump", &"coals")
	assert_lt(foe.hp, hp)


func test_each_new_jar_event_has_a_log_line_and_a_sound() -> void:
	for id in [&"salt", &"beans", &"coals"]:
		var e := {t = &"jar", what = id, at = AT}
		assert_ne(Sfx.sound_of(e), &"", str(id))
		assert_true(Messages.JAR_DOES.has(id), str(id))


# --- forecast and the 도감 ---------------------------------------------------------


func test_a_preview_lets_the_same_things_out_as_the_round() -> void:
	for row: Dictionary in Jars.ROWS:
		var w := _world()
		_foe(w, NEAR_FOE)
		_jar(w, AT, row.id)
		var action := {t = &"move", dir = E}
		var ahead := w.preview(action)
		w.act(action)
		assert_eq(ahead.sites, w.sites, str(row.id))
		assert_eq(ahead.tiles, w.tiles, str(row.id))
		assert_eq(ahead.actors.map(func(a): return a.hp), w.actors.map(func(a): return a.hp))


func test_the_chances_add_up_to_a_hundred_and_follow_the_weights() -> void:
	var tables := [
		Jars.ROWS, [{weight = 1}, {weight = 1}, {weight = 1}], [{weight = 7}, {weight = 2}]
	]
	for rows: Array in tables:
		var total := 0
		for row: Dictionary in rows:
			total += row.weight
		var chances := Jars.chances(rows)
		assert_eq(chances.reduce(func(s, n): return s + n, 0), 100)
		for k in rows.size():
			assert_almost_eq(float(chances[k]), 100.0 * rows[k].weight / total, 1.0)


func test_the_codex_tells_each_effect_of_a_jar_with_its_chance() -> void:
	var entry := _entry(4, Tiles.of(World.JAR, "name"))
	var text := Info.plain(Codex.detail(entry))
	var chances := Jars.chances()
	for k in Jars.ROWS.size():
		assert_string_contains(text, "%s: %d%%" % [Jars.ROWS[k].name, chances[k]])


func test_the_codex_lists_kimchi_among_the_items() -> void:
	var text := Info.plain(Codex.detail(_entry(3, Jars.name_of(Jars.KIMCHI))))
	assert_string_contains(text, "체력: +%d" % World.HEAL)


func _entry(tab: int, name: String) -> Dictionary:
	for e in Codex.entries(tab):
		if e.name == name:
			return e
	return {}


func test_explore_leaves_kimchi_while_she_is_at_full_health() -> void:
	var w := _world()
	var at := w.player().pos + Vector2i(2, 0)
	w.sites.append({kind = Jars.KIMCHI, at = at})
	w.known.fill(1)
	var found := Travel.search(w)
	w.player().hp = w.player().max_hp
	assert_ne(Travel.explore_step(w, found), Vector2i(1, 0), "nothing to heal")
	w.player().hp = w.player().max_hp - 1
	assert_eq(Travel.explore_step(w, found), Vector2i(1, 0), "she goes for it hurt")


func test_a_forecast_does_not_tell_what_a_jar_holds() -> void:
	for row: Dictionary in Jars.ROWS:
		var w := _world()
		w.jars[AT] = row.id
		var seen := Forecast.of(w, ORB)
		assert_eq(seen.after.jars, {}, "%s stays unknown" % row.id)
