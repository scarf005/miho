extends GutTest
## 둔갑: 목+토 cast on Miho gives her the form of the last creature of heaven
## that fell, and a creature that is not hunting her does not know her (Guise).

const WOOD := Cards.WOOD
const EARTH := Cards.EARTH
const E := Vector2i(1, 0)
const ME := Vector2i(4, 8)
const WAIT := {t = &"wait"}


## An open hall walled at the edges, every tile known and seen, Miho at ME
## with every talisman, five tails and a 도깨비 felled before.
func _world(prey := &"dokkaebi") -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	w.rooms = [Rect2i(1, 1, Grid.W - 2, Grid.H - 2)]
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
	me.prey = prey
	w.actors.append(me)
	w.known.resize(w.tiles.size())
	w.known.fill(1)
	w.seen = w.known.duplicate()
	w.dim.resize(w.tiles.size())
	w.depth = 5
	w.tails = 5
	w.cards.assign(Cards.ALL)
	return w


func _self(cards: Array) -> Dictionary:
	return {t = &"cast", spells = [{cards = cards, dir = Vector2i.ZERO}]}


func _foe(w: World, at: Vector2i, alert := Actor.SEARCH) -> Actor:
	var a := FloorGen.spawn(w, &"dokkaebi", at)
	a.cooldown = 99
	a.alert = alert
	a.target = at
	return a


## A lit hall: a lantern lights Miho, so a creature in line sees her from afar.
func _lit(w: World) -> void:
	w.set_tile(ME + Vector2i(0, 3), World.LANTERN)


func test_the_guise_needs_a_creature_felled_first() -> void:
	var w := _world(&"")
	assert_false(w.can(_self([WOOD, EARTH])))
	assert_eq(Guise.why(w.player(), Spell.make([WOOD, EARTH])), Guise.NO_PREY)
	w.player().prey = &"bulgae"
	assert_true(w.can(_self([WOOD, EARTH])))
	assert_true(w.can(_self([EARTH, WOOD, WOOD])), "more wood, any order")
	assert_false(w.can(_self([WOOD, EARTH, EARTH])), "more earth is no guise")


func test_a_creature_felled_is_the_form_the_next_guise_takes() -> void:
	var w := _world(&"")
	var foe := FloorGen.spawn(w, &"dokkaebi", ME + E)
	foe.hp = 1
	w.act({t = &"move", dir = E})
	assert_false(foe.alive(), "a claw fells it")
	assert_eq(w.player().prey, &"dokkaebi")


func test_the_guise_lasts_rounds_and_two_more_for_every_wood() -> void:
	var w := _world()
	w.act(_self([WOOD, EARTH]))
	var me := w.player()
	assert_eq([me.guise, me.form], [Guise.ROUNDS - 1, &"dokkaebi"])
	assert_eq(w.tails, 3)
	assert_eq(Guise.looks(me), &"dokkaebi", "the map draws her as it")
	for i in Guise.ROUNDS - 2:
		w.act(WAIT)
	assert_eq(me.guise, 1, "still in guise in its last round")
	var events := w.act(WAIT)
	assert_eq(me.guise, 0)
	assert_eq(Guise.looks(me), &"miho")
	assert_eq(events.filter(func(e): return e.t == &"unmask" and e.why == &"time").size(), 1)
	var more := _world()
	more.act(_self([WOOD, EARTH, WOOD]))
	assert_eq(more.player().guise, Guise.ROUNDS + Guise.PER_WOOD - 1)


func test_the_guise_is_silent() -> void:
	var w := _world()
	var events := w.act(_self([WOOD, EARTH]))
	assert_eq(events.filter(func(e): return e.t == &"noise").size(), 0)


func test_a_creature_that_is_not_hunting_does_not_know_her() -> void:
	var w := _world()
	_lit(w)
	var searcher := _foe(w, ME + Vector2i(4, 0))
	w.act(_self([WOOD, EARTH]))
	assert_true(w.sees(searcher, ME), "it sees her tile")
	assert_false(Guise.knows(w, searcher))
	assert_ne(searcher.alert, Actor.HUNT)
	w.act(WAIT)
	assert_ne(searcher.alert, Actor.HUNT, "it goes on searching")
	assert_true(w.caught_unawares(searcher), "her claws catch it unawares")


func test_without_the_guise_the_same_creature_hunts_her() -> void:
	var w := _world()
	_lit(w)
	var searcher := _foe(w, ME + Vector2i(4, 0))
	w.act(WAIT)
	assert_eq(searcher.alert, Actor.HUNT)


func test_a_hunter_is_not_fooled() -> void:
	var w := _world()
	_lit(w)
	var hunter := _foe(w, ME + Vector2i(4, 0), Actor.HUNT)
	w.act(_self([WOOD, EARTH]))
	assert_true(Guise.knows(w, hunter))
	assert_true(hunter.sees_me)
	assert_false(w.caught_unawares(hunter))


func test_two_rounds_next_to_a_creature_end_the_guise() -> void:
	var w := _world()
	var foe := _foe(w, ME + Vector2i(2, 0))
	foe.stunned = 99
	w.act(_self([WOOD, EARTH]))
	w.act({t = &"move", dir = E})
	assert_gt(w.player().guise, 0, "one round beside it")
	w.act({t = &"move", dir = -E})
	w.act({t = &"move", dir = E})
	assert_gt(w.player().guise, 0, "stepping away starts the count again")
	var events := w.act(WAIT)
	assert_eq(w.player().guise, 0)
	assert_eq(events.filter(func(e): return e.t == &"unmask" and e.why == &"beside").size(), 1)


func test_casting_a_spell_ends_the_guise() -> void:
	var w := _world()
	w.act(_self([WOOD, EARTH]))
	var events := w.act({t = &"cast", spells = [{cards = [Cards.FOX], dir = E}]})
	assert_eq(w.player().guise, 0)
	assert_eq(events.filter(func(e): return e.t == &"unmask" and e.why == &"cast").size(), 1)


func test_harm_ends_the_guise() -> void:
	var w := _world()
	w.act(_self([WOOD, EARTH]))
	w.hurt(w.player(), 1)
	assert_eq(w.player().guise, 0)
	assert_eq(w.events.back().t, &"unmask")
	assert_eq(w.events.back().why, &"hurt")


func test_the_forecast_casts_the_guise_the_round_does() -> void:
	var w := _world()
	_lit(w)
	_foe(w, ME + Vector2i(4, 0))
	var f := Forecast.of(w, _self([WOOD, EARTH, WOOD]))
	w.act(_self([WOOD, EARTH, WOOD]))
	var told := f.after.player()
	var me := w.player()
	assert_eq([told.guise, told.form, told.beside], [me.guise, me.form, me.beside])
	assert_eq(f.noticed, {}, "no one notices her")


func test_the_log_tells_the_guise_and_its_end() -> void:
	var w := _world()
	var before := w.clone()
	var lines := Messages.of(before, w, w.act(_self([WOOD, EARTH]))).map(Messages.plain)
	assert_has(lines, "도깨비의 모습으로 둔갑했다")
	before = w.clone()
	var cast := {t = &"cast", spells = [{cards = [Cards.FOX], dir = E}]}
	lines = Messages.of(before, w, w.act(cast)).map(Messages.plain)
	assert_has(lines, "둔갑이 풀렸다")


func test_the_hover_tells_the_guise_on_miho_and_on_a_fooled_creature() -> void:
	var w := _world()
	_lit(w)
	var searcher := _foe(w, ME + Vector2i(4, 0))
	searcher.rooted = 99
	assert_string_contains(Info.plain(Info.creature(w, w.player())), "둔갑할 모습: 도깨비")
	var no_wood := _world()
	no_wood.cards.erase(WOOD)
	assert_false(Info.plain(Info.creature(no_wood, no_wood.player())).contains("둔갑할"))
	w.act(_self([WOOD, EARTH]))
	var mine := Info.plain(Info.creature(w, w.player()))
	assert_string_contains(mine, "둔갑: 도깨비\n  남은 시간: %d초" % (Guise.ROUNDS - 1))
	assert_string_contains(mine, "적 옆: 0/%d초" % Guise.BESIDE)
	var its := Info.plain(Info.creature(w, searcher))
	assert_string_contains(its, "둔갑한 당신을 알아볼 수 없다")
	assert_false(its.contains("당신을 볼 수 있다"))
	var seen := Observation.text(w)
	assert_string_contains(seen, "in guise as 도깨비 for %d rounds" % (Guise.ROUNDS - 1))
	assert_string_contains(seen, "sees Miho but not through her guise")


func test_the_spell_info_tells_what_the_guise_does() -> void:
	var text := Info.plain(SpellInfo.spell(Spell.make([WOOD, EARTH, WOOD])))
	for part in ["둔갑", "%d초" % (Guise.ROUNDS + Guise.PER_WOOD), "해제: 적 옆에서 %d초" % Guise.BESIDE]:
		assert_string_contains(text, part)
	assert_has(Codex.entries(1).map(func(e): return e.name), Guise.NAME[Guise.GUISE])


func _main() -> Node:
	var m: Node = load("res://src/view/main.tscn").instantiate()
	m.save_path = ""
	add_child_autofree(m)
	Keys.reset()
	m._new_run(3)
	m.state = &"play"
	m.world = _world(&"")
	m.settings.spells = {}
	m.term.show_world(m.world)
	m._forecast()
	return m


func _press(m: Node, key: String) -> void:
	var e := Keys.event(key)
	e.pressed = true
	m._key(e)


func test_comma_with_no_creature_felled_says_so_and_keeps_the_turn() -> void:
	var m := _main()
	_press(m, "5")
	_press(m, "7")
	var round_no: int = m.world.round_no
	_press(m, "Comma")
	assert_eq(m.world.round_no, round_no)
	assert_eq(m.messages.lines.back().text, Guise.NO_PREY)


func test_a_lone_spell_mixed_with_another_slot_says_why_along_any_direction() -> void:
	var m := _main()
	m.picked = [Cards.FIRE, Cards.METAL, Cards.WOOD, Cards.FOX] as Array[StringName]
	var round_no: int = m.world.round_no
	m._direction(Vector2i.RIGHT, false)
	assert_eq(m.world.round_no, round_no)
	assert_eq(m.messages.lines.back().text, Guise.MIXED)
