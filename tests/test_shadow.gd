extends GutTest
## 스스로에게 걸기 and 그림자: a spell cast with no direction goes on Miho, and
## 여 with 수 lays a dark wisp on her that darkens the tiles round her (Guise).

const FOX := Cards.FOX
const WATER := Cards.WATER
const E := Vector2i(1, 0)
const ME := Vector2i(4, 8)
const WAIT := {t = &"wait"}


## An open hall walled at the edges, every tile known and seen, Miho at ME
## with every talisman and five tails.
func _world() -> World:
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


func _shadow(w: World) -> Shot:
	for s in w.shots:
		if s.host == w.player().id and not s.gone:
			return s
	return null


func _foe(w: World, at: Vector2i) -> Actor:
	var a := FloorGen.spawn(w, &"dokkaebi", at)
	a.cooldown = 99
	return a


func test_every_recipe_named_in_the_refusal_goes_on_miho() -> void:
	for k in Guise.RECIPE:
		assert_eq(Guise.kind(Spell.make(Guise.RECIPE[k])), k)
		assert_string_contains(Guise.only(), Guise.NAME[k])


func test_only_the_shadow_and_the_guise_go_on_miho() -> void:
	var w := _world()
	assert_true(w.can(_self([FOX, WATER])))
	assert_true(w.can(_self([WATER, FOX, WATER])), "more water, any order")
	for cards in [
		[FOX], [Cards.ORB], [FOX, FOX, WATER], [FOX, WATER, Cards.WOOD, Cards.FIRE], [WATER]
	]:
		assert_false(w.can(_self(cards)), str(cards))
		assert_eq(Guise.why(w.player(), Spell.make(cards)), Guise.only())
	var two := {
		t = &"cast",
		spells = [{cards = [FOX, WATER], dir = Vector2i.ZERO}, {cards = [FOX], dir = Vector2i.ZERO}]
	}
	assert_false(w.can(two), "one spell on herself a round")


func test_the_shadow_rides_miho_for_wisp_life_rounds_and_darkens_her_tile() -> void:
	var w := _world()
	w.set_tile(ME + Vector2i(3, 0), World.LANTERN)
	assert_true(w.lit(ME), "the lantern lights her")
	w.act(_self([FOX, WATER]))
	var s := _shadow(w)
	assert_not_null(s)
	assert_eq(s.spell.title(), "그림자")
	assert_eq(s.life, Spell.WISP_LIFE - 1, "one round has passed")
	assert_false(w.lit(ME), "the shadow puts her in the dark")
	assert_eq(w.tails, 3, "two tails")
	w.act({t = &"move", dir = Vector2i.UP})
	assert_eq(_shadow(w).pos, ME + Vector2i.UP, "it goes where she goes")
	for i in Spell.WISP_LIFE - 3:
		w.act(WAIT)
	assert_not_null(_shadow(w), "still on her in its last round")
	w.act(WAIT)
	assert_null(_shadow(w), "gone after WISP_LIFE rounds")


func test_each_water_past_the_first_darkens_one_tile_farther() -> void:
	assert_eq(Spell.make([FOX, WATER]).light(Actor.FOX).radius, 3)
	assert_eq(Spell.make([FOX, WATER, WATER]).light(Actor.FOX).radius, 4)
	assert_eq(Spell.make([FOX, WATER, WATER, WATER]).light(Actor.FOX).radius, 5)


func test_the_shadow_is_silent() -> void:
	var w := _world()
	var events := w.act(_self([FOX, WATER]))
	assert_eq(events.filter(func(e): return e.t == &"noise").size(), 0)


func test_a_creature_still_sees_her_from_the_next_tile_but_not_from_afar() -> void:
	var w := _world()
	w.set_tile(ME + Vector2i(0, 3), World.LANTERN)
	var far := _foe(w, ME + Vector2i(4, 0))
	var near := _foe(w, ME + Vector2i(-1, 0))
	far.alert = Actor.SEARCH
	near.alert = Actor.SEARCH
	assert_true(w.sees(far, ME), "lit, she is seen from afar")
	Guise.cast(w, w.player(), Spell.make([FOX, WATER]), Vector2i.ZERO)
	assert_false(w.sees(far, ME))
	assert_true(w.sees(near, ME))


func test_a_fire_lit_in_the_dark_ends_the_shadow() -> void:
	var w := _world()
	w.set_tile(ME + Vector2i(1, 0), World.GRASS)
	w.act(_self([FOX, WATER]))
	var id := _shadow(w).id
	var before := w.clone()
	var events := w.act({t = &"cast", spells = [{cards = [Cards.FIRE], dir = E}]})
	assert_null(_shadow(w))
	var faded := events.filter(func(e): return e.t == &"fade" and e.shot == id)
	assert_eq(faded.size(), 1)
	assert_true(faded[0].get("lit", false))
	assert_has(Messages.of(before, w, events).map(Messages.plain), "그림자가 불빛에 사라졌다")


func test_a_lantern_lit_in_the_dark_ends_it_and_one_lit_beyond_does_not() -> void:
	for x in [ME.x + 1, ME.x + 6]:
		var w := _world()
		w.set_tile(Vector2i(x + 1, ME.y - 2), World.LANTERN_OUT)
		var stoker := _foe(w, Vector2i(x, ME.y - 2))
		stoker.alert = Actor.SEARCH
		stoker.target = stoker.pos
		w.act(_self([FOX, WATER]))
		var lit := w.events.filter(func(e): return e.t == &"relight").size() > 0
		assert_true(lit, "the lantern was lit")
		assert_eq(_shadow(w) == null, x == ME.x + 1, "lantern at x %d" % (x + 1))


func test_the_forecast_lays_the_shadow_the_round_does() -> void:
	var w := _world()
	w.set_tile(ME + Vector2i(3, 0), World.LANTERN)
	_foe(w, ME + Vector2i(6, 0)).alert = Actor.SEARCH
	var f := Forecast.of(w, _self([FOX, WATER, WATER]))
	w.act(_self([FOX, WATER, WATER]))
	var told := _shadow(f.after)
	assert_not_null(told)
	assert_eq([told.pos, told.life, told.host], [_shadow(w).pos, _shadow(w).life, _shadow(w).host])
	assert_eq(f.after.lit(ME), w.lit(ME))
	assert_eq(f.noticed, {})


func test_the_log_and_the_hover_tell_the_shadow() -> void:
	var w := _world()
	var before := w.clone()
	var lines := Messages.of(before, w, w.act(_self([FOX, WATER]))).map(Messages.plain)
	assert_has(lines, "그림자가 붙었다")
	var text := Info.plain(Info.creature(w, w.player()))
	assert_string_contains(text, "그림자 붙음: %d초" % (Spell.WISP_LIFE - 1))


func test_the_spell_info_tells_what_the_shadow_does_on_herself() -> void:
	var text := Info.plain(SpellInfo.spell(Spell.make([FOX, WATER, WATER])))
	for part in ["자신에게", "그림자", "%d초" % Spell.WISP_LIFE, "둘레 4칸", "불", "등불"]:
		assert_string_contains(text, part)


func test_the_codex_lists_the_shadow() -> void:
	var names := Codex.entries(2).map(func(e): return e.name)
	assert_has(names, Guise.NAME[Guise.SHADOW])


func _main() -> Node:
	var m: Node = load("res://src/view/main.tscn").instantiate()
	m.save_path = ""
	add_child_autofree(m)
	Keys.reset()
	m._new_run(3)
	m.state = &"play"
	m.world = _world()
	m.settings.spells = {}
	m.term.show_world(m.world)
	m._forecast()
	return m


func _press(m: Node, key: String) -> void:
	var e := Keys.event(key)
	e.pressed = true
	m._key(e)


func test_comma_casts_the_queue_on_miho() -> void:
	var m := _main()
	_press(m, "1")
	_press(m, "4")
	_press(m, "Comma")
	while m.busy:
		await get_tree().process_frame
	assert_not_null(_shadow(m.world))
	assert_eq(m.picked, [] as Array[StringName])


func test_a_click_on_miho_with_a_queue_casts_it_on_her() -> void:
	var m := _main()
	_press(m, "1")
	_press(m, "4")
	m.hover = ME
	m._use_tile(ME, false)
	while m.busy:
		await get_tree().process_frame
	assert_not_null(_shadow(m.world))


func test_comma_with_a_spell_that_does_not_go_on_miho_says_so_and_keeps_the_turn() -> void:
	var m := _main()
	_press(m, "1")
	var round_no: int = m.world.round_no
	_press(m, "Comma")
	assert_eq(m.world.round_no, round_no)
	assert_eq(m.messages.lines.back().text, Guise.only())
	assert_eq(m.picked, [FOX] as Array[StringName], "the queue stays")
