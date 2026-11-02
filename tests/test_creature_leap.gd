extends GutTest
## A deep 도깨비 leaps (Leap) in place of growing past 3 health: it charges the
## leap at Miho when she stands in line farther than it lands, one round
## early, and lands short of her.

const WAIT := {t = &"wait"}
const ME := Vector2i(10, 8)
const E := Vector2i(1, 0)
const W := Vector2i(-1, 0)
const DEEP := 5


## An open hall, Miho at ME by a lantern, on storey `depth`.
func _world(depth: int) -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	for y in range(1, Grid.H - 1):
		for x in range(1, Grid.W - 1):
			w.tiles[Grid.index(Vector2i(x, y))] = World.FLOOR
	w.rooms.assign([Rect2i(1, 1, Grid.W - 2, Grid.H - 2)])
	w.tiles[Grid.index(ME + Vector2i(0, -2))] = World.LANTERN
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.hp = 30
	me.max_hp = 30
	me.pos = ME
	w.actors.append(me)
	w.depth = depth
	w.sense()
	return w


## A dokkaebi at `at` hunting Miho, its next spell the leap.
func _leaper(w: World, at: Vector2i, kind := &"dokkaebi") -> Actor:
	var a := FloorGen.spawn(w, kind, at)
	a.brain.alert = Actor.HUNT
	a.brain.target = ME
	a.magic.casts = a.repertoire().find(Bestiary.LEAP)
	w.sense()
	return a


func _is_leap(plan: Dictionary) -> bool:
	return Spell.make(plan.cards).shape == Spell.LEAP


func test_only_a_deep_dokkaebi_knows_the_leap() -> void:
	for depth in range(1, 9):
		var a := FloorGen.spawn(_world(depth), &"dokkaebi", ME + E * 6)
		assert_eq(a.repertoire().has(Bestiary.LEAP), a.rank >= Bestiary.PICKS, "storey %d" % depth)
	var pole := FloorGen.spawn(_world(DEEP), &"jangseung", ME + E * 6)
	assert_false(pole.repertoire().has(Bestiary.LEAP))


func test_the_leap_gives_a_dokkaebi_no_element() -> void:
	assert_eq(Bestiary.elements(&"dokkaebi"), [] as Array[StringName])
	assert_eq(Bestiary.elements(&"bujigaengi"), [Cards.FIRE] as Array[StringName])
	assert_false(Bestiary.burns(&"dokkaebi"))
	assert_false(Bestiary.weak(&"dokkaebi", Spell.make([Cards.WATER])))


func test_it_charges_the_leap_at_miho_in_line_and_lands_short_of_her() -> void:
	var w := _world(DEEP)
	var a := _leaper(w, ME + E * 7)
	var events := w.act(WAIT)
	assert_eq(a.magic.intent.size(), 1, "one spell, never paired")
	assert_true(_is_leap(a.magic.intent[0]))
	assert_eq(a.magic.intent[0].dir, W)
	assert_eq(events.filter(func(e): return e.t == &"charge" and e.id == a.id).size(), 1)
	events = w.act(WAIT)
	var reach := Spell.make(Bestiary.LEAP).leap()
	assert_eq(a.pos, ME + E * (7 - reach))
	var leaps := events.filter(func(e): return e.t == &"leap" and e.id == a.id)
	assert_eq(leaps.size(), 1)
	assert_eq(a.magic.casts, a.repertoire().find(Bestiary.LEAP) + 1)


func test_it_does_not_leap_past_miho_or_off_her_line() -> void:
	var w := _world(DEEP)
	var near := _leaper(w, ME + E * 2)
	assert_eq(
		Aim.at(w, near, w.player()).filter(_is_leap), [] as Array[Dictionary], "she is too near"
	)
	var off := _leaper(w, ME + Vector2i(6, 3))
	assert_eq(Aim.at(w, off, w.player()).filter(_is_leap), [] as Array[Dictionary], "no line")


func test_a_rooted_dokkaebi_does_not_leap() -> void:
	var w := _world(DEEP)
	var a := _leaper(w, ME + E * 7)
	a.ailments.rooted = 3
	assert_eq(Aim.at(w, a, w.player()).filter(_is_leap), [] as Array[Dictionary])


func test_it_does_not_leap_into_fire() -> void:
	var w := _world(DEEP)
	var a := _leaper(w, ME + E * 7)
	var to := Leap.landing(w, a.pos, W, Spell.make(Bestiary.LEAP).leap())
	w.burning[to] = World.BURN_ROUNDS
	assert_eq(Aim.at(w, a, w.player()).filter(_is_leap), [] as Array[Dictionary])


func test_a_leap_is_cast_alone_even_where_it_would_double() -> void:
	var w := _world(7)
	var a := _leaper(w, ME + E * 7)
	assert_gte(a.rank, Bestiary.DOUBLES)
	var plans := Aim.at(w, a, w.player())
	assert_eq(plans.size(), 1)
	assert_true(_is_leap(plans[0]))


func test_a_fight_with_a_rival_leaps_the_same_way() -> void:
	var w := _world(DEEP)
	var a := _leaper(w, ME + E * 7)
	var rival := FloorGen.spawn(w, &"jangseung", a.pos + W * 5)
	var plans := Aim.at(w, a, rival)
	assert_true(plans.any(_is_leap))
	assert_eq(plans.filter(_is_leap)[0].dir, W)


func test_the_forecast_equals_the_round() -> void:
	var w := _world(DEEP)
	var a := _leaper(w, ME + E * 5)
	for round_no in 2:
		var f := Forecast.of(w, WAIT)
		var before := f.after.actor(a.id)
		assert_not_null(before, "Miho sees it")
		assert_eq(f.leaps, [], "the preview of Miho's cast shows no leap of hers")
		w.act(WAIT)
		assert_eq(before.pos, a.pos, "round %d" % round_no)
		assert_eq(f.after.rng.state, w.rng.state)
	assert_ne(a.pos, ME + E * 5)


func test_every_event_of_the_leap_makes_a_sound() -> void:
	var w := _world(DEEP)
	_leaper(w, ME + E * 7)
	var events := w.act(WAIT) + w.act(WAIT)
	var kinds := {}
	for e in events:
		if e.t in [&"charge", &"leap", &"move"]:
			kinds[e.t] = true
			assert_ne(Sfx.sound_of(e), &"", e.t)
	assert_eq(kinds.keys().size(), 3, "charge, leap and the step on landing")


func test_hover_and_codex_list_the_leap_with_its_numbers() -> void:
	var text := Info.plain(Info.creature_facts(Codex.foe(&"dokkaebi", DEEP), []))
	var leap := Bestiary.spell(&"dokkaebi", Bestiary.LEAP)
	assert_string_contains(text, "주술: " + leap.title())
	var line := text.substr(text.find("주술: " + leap.title()))
	assert_false(line.split("\n")[0].contains("피해"), "a leap hurts no one")
	var shallow := Info.plain(Info.creature_facts(Codex.foe(&"dokkaebi", 2), []))
	assert_false(shallow.contains(leap.title()))


func test_a_charging_dokkaebi_shows_the_leap_it_gathers() -> void:
	var w := _world(DEEP)
	var a := _leaper(w, ME + E * 7)
	w.act(WAIT)
	var text := Info.plain(Info.creature(w, a))
	assert_string_contains(text, "모으는 중")


## A dokkaebi that charged the leap at Miho in the round before.
func _charged(w: World, at: Vector2i) -> Actor:
	var a := _leaper(w, at)
	w.act(WAIT)
	assert_true(_is_leap(a.magic.intent[0]))
	return a


func test_a_charged_leap_is_dropped_when_she_roots_it_first() -> void:
	var w := _world(DEEP)
	var a := _charged(w, ME + E * 7)
	var from := a.pos
	a.ailments.rooted = 3
	var events := w.act(WAIT)
	assert_eq(a.pos, from)
	assert_false(events.any(func(e): return e.t == &"leap"))


func test_a_charged_leap_walled_in_does_not_tread_its_own_tile() -> void:
	var w := _world(DEEP)
	var a := _charged(w, ME + E * 7)
	var hp := a.hp
	var from := a.pos
	w.set_tile(from + W, World.WALL)
	w.set_tile(from, World.THORNS)
	var events := w.act(WAIT)
	assert_eq(a.pos, from)
	assert_false(events.any(func(e): return e.t in [&"leap", &"move", &"prick"] and e.id == a.id))
	assert_eq(a.hp, hp)
