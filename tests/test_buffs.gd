extends GutTest
## The buffs Miho casts on herself (Guise): at least 3 talismans in any order, no time
## limit, and she can drop them.

const ME := Vector2i(4, 8)
const WAIT := {t = &"wait"}
const SAVE := "user://test_buffs.cfg"


func before_each() -> void:
	Keys.reset()


func after_each() -> void:
	SaveGame.new(SAVE).erase()


## An open hall walled at the edges, every tile known and seen, Miho at ME with
## every talisman, nine tails and a 도깨비 felled before.
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
	me.prey = &"dokkaebi"
	w.actors.append(me)
	w.known.resize(w.tiles.size())
	w.known.fill(1)
	w.seen = w.known.duplicate()
	w.dim.resize(w.tiles.size())
	w.depth = 5
	w.tails = 9
	w.cards.assign(Cards.ALL)
	return w


func _self(cards: Array) -> Dictionary:
	return {t = &"cast", spells = [{cards = cards, dir = Vector2i.ZERO}]}


func _wear(w: World, kind: StringName) -> void:
	w.tails = 9
	w.act(_self(Guise.RECIPE[kind]))
	w.tails = 9


## Every buff at once; the guise goes last because another cast ends it.
func _wear_all(w: World) -> void:
	for kind: StringName in Guise.RECIPE:
		if kind != Guise.GUISE:
			_wear(w, kind)
	_wear(w, Guise.GUISE)


func _drop(kind: StringName) -> Dictionary:
	return {t = &"dispel", kind = kind}


## Every order of `cards`.
func _orders(cards: Array) -> Array:
	if cards.size() <= 1:
		return [cards]
	var out := []
	for i in cards.size():
		var rest := cards.duplicate()
		var first: Variant = rest.pop_at(i)
		for tail: Array in _orders(rest):
			out.append([first] + tail)
	return out


func test_each_buff_holds_wood_and_goes_on_her_in_every_card_order() -> void:
	for kind: StringName in Guise.RECIPE:
		var cards: Array = Guise.RECIPE[kind]
		assert_true(cards.size() >= 3, kind)
		assert_true(Spell.make(cards).holds(Cards.WOOD), kind)
		for order: Array in _orders(cards):
			assert_eq(Guise.kind(Spell.make(order)), kind, str(order))
			assert_true(_world().can(_self(order)), str(order))


func test_more_water_widens_the_shadow_in_every_order() -> void:
	for order: Array in _orders([Cards.FOX, Cards.WATER, Cards.WOOD, Cards.WATER]):
		var w := _world()
		assert_eq(Guise.kind(Spell.make(order)), Guise.SHADOW, str(order))
		w.act(_self(order))
		assert_eq(Guise.shadows(w, w.player())[0].spell.light(Actor.FOX).radius, 4, str(order))


func test_the_old_shapes_are_refused_the_same_way_as_any_spell() -> void:
	var w := _world()
	for cards: Array in [
		[Cards.FOX, Cards.WATER],
		[Cards.WOOD, Cards.EARTH],
		[Cards.WOOD, Cards.EARTH, Cards.WOOD, Cards.WOOD],
		[Cards.FOX, Cards.WOOD, Cards.EARTH, Cards.WOOD],
		[Cards.FIRE, Cards.EARTH, Cards.METAL, Cards.WATER],
	]:
		assert_false(w.can(_self(cards)), str(cards))
		assert_eq(Guise.why(w.player(), Spell.make(cards)), Guise.only(), str(cards))


func test_no_buff_ends_by_time() -> void:
	for kind: StringName in Guise.RECIPE:
		var w := _world()
		_wear(w, kind)
		for i in 100:
			w.act(WAIT)
		assert_eq(Guise.worn(w, w.player()), [kind])


func test_every_buff_stays_on_her_up_a_storey_and_down_again() -> void:
	var w := World.create(5)
	w.cards.assign(Cards.ALL)
	w.player().prey = &"dokkaebi"
	_wear_all(w)
	var down := w.clone()
	w.act(WAIT)
	for at_storey in [w.depth + 1, w.depth]:
		Storeys.leave(w)
		Storeys.enter(w, at_storey)
		w.sense()
		w.act(WAIT)
		assert_eq(Guise.worn(w, w.player()).size(), Guise.RECIPE.size(), "on storey %d" % at_storey)
		var wisp: Shot = Guise.shadows(w, w.player())[0]
		assert_eq(wisp.pos, w.player().pos, "the wisp rides her on storey %d" % at_storey)
		assert_false(w.lit(w.player().pos), "her tile stays dark on storey %d" % at_storey)
	assert_eq(down.shots.size(), 1, "a clone keeps the wisp")


func test_the_shadow_stays_on_her_through_a_fall() -> void:
	var w := World.create(5)
	w.cards.assign(Cards.ALL)
	w.tails = 9
	w.player().hp = 9
	Storeys.leave(w)
	Storeys.enter(w, 2)
	w.cast(w.player(), Spell.make(Guise.RECIPE[Guise.SHADOW]), Vector2i.ZERO)
	Fall._drop(w, w.player(), w.player().pos)
	assert_eq(w.depth, 1)
	assert_eq(Guise.shadows(w, w.player())[0].pos, w.player().pos)


func test_going_up_leaves_a_wisp_of_another_behind() -> void:
	var w := World.create(5)
	var wisp := Shot.new()
	wisp.id = w.new_id()
	wisp.spell = Spell.make([Cards.FOX])
	wisp.caster = 12345
	w.shots.append(wisp)
	Elements.stick(w, wisp, w.player())
	Storeys.leave(w)
	Storeys.enter(w, 2)
	assert_eq(w.shots.size(), 0)


func test_dropping_ends_only_the_chosen_buff_takes_a_round_and_costs_no_tail() -> void:
	for kind: StringName in Guise.RECIPE:
		var w := _world()
		_wear_all(w)
		var round_no := w.round_no
		var events := w.act(_drop(kind))
		var left := Guise.RECIPE.keys().filter(func(k): return k != kind)
		assert_eq(Guise.worn(w, w.player()), left, kind)
		assert_eq(w.round_no, round_no + 1, kind)
		assert_eq(w.tails, 9, kind)
		assert_eq(events.filter(func(e): return e.t == &"noise").size(), 0, kind)


func test_dropping_is_legal_only_for_a_buff_she_wears_and_not_while_stunned() -> void:
	var w := _world()
	assert_false(w.can(_drop(Guise.CLOAK)), "not worn")
	_wear(w, Guise.CLOAK)
	assert_false(w.can(_drop(Guise.TALON)), "another one")
	assert_true(w.can(_drop(Guise.CLOAK)))
	w.player().stunned = 2
	assert_false(w.can(_drop(Guise.CLOAK)), "stunned")


func test_a_forecast_of_a_drop_equals_the_round() -> void:
	for kind: StringName in Guise.RECIPE:
		var w := _world()
		_wear(w, kind)
		var f := Forecast.of(w, _drop(kind))
		var events := w.act(_drop(kind))
		assert_eq(f.events, events, kind)
		assert_eq(Guise.worn(f.after, f.after.player()), Guise.worn(w, w.player()), kind)


func test_a_drop_replays_from_a_save() -> void:
	var run := SaveGame.new(SAVE, 11)
	var w := World.create(11)
	var actions := [
		{t = &"cheat", cmd = &"cards"},
		{t = &"cheat", cmd = &"tails"},
		_self(Guise.RECIPE[Guise.TALON]),
		_self(Guise.RECIPE[Guise.CLOAK]),
		_drop(Guise.TALON),
		WAIT,
	]
	for i in actions.size():
		assert_true(w.can(actions[i]), str(actions[i]))
		w.act(actions[i])
		run.record(actions[i], 0, false)
	var back := SaveGame.load_from(SAVE)
	assert_not_null(back)
	assert_true(back.replay())
	assert_eq(Guise.worn(back.world, back.world.player()), [Guise.CLOAK])
	assert_eq(back.world.round_no, w.round_no)
	assert_eq(back.world.rng.state, w.rng.state)


func test_each_drop_is_told_in_the_log_with_a_sound() -> void:
	var told := {
		Guise.SHADOW: "그림자가 사라졌다",
		Guise.GUISE: "둔갑이 풀렸다",
		Guise.TALON: "쇠발톱이 사라졌다",
		Guise.CLOAK: "은신이 풀렸다",
	}
	for kind: StringName in told:
		var w := _world()
		_wear(w, kind)
		var before := w.clone()
		var events := w.act(_drop(kind))
		assert_has(Messages.of(before, w, events).map(Messages.plain), told[kind])
		assert_true(events.any(func(e): return Sfx.sound_of(e) != &""), kind)


func test_the_hover_tells_the_talon_harm_by_creature() -> void:
	var w := _world()
	var plain := FloorGen.spawn(w, &"imugi", ME + Vector2i(2, 0))
	var eater := FloorGen.spawn(w, &"bulgasari", ME + Vector2i(3, 0))
	_wear(w, Guise.TALON)
	assert_eq(w.claw_harm(w.player(), false, plain), World.CLAW + Guise.TALON_HARM)
	assert_eq(w.claw_harm(w.player(), false, eater), World.CLAW + Guise.TALON_ABSORBED)
	var sneak := World.CLAW * World.SNEAK + Guise.TALON_ABSORBED
	assert_string_contains(Info.plain(Info.creature(w, eater)), "기습 피해: %d" % sneak)


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
	m._unhandled_input(e)


func _settle(m: Node) -> void:
	for i in 200:
		if not m.busy:
			return
		await get_tree().process_frame


func test_g_with_one_buff_drops_it_and_takes_a_round() -> void:
	var m := _main()
	_wear(m.world, Guise.CLOAK)
	var round_no: int = m.world.round_no
	_press(m, "G")
	await _settle(m)
	assert_false(m.world.player().cloak)
	assert_eq(m.world.round_no, round_no + 1)
	assert_eq(m.overlay, &"")


func test_g_with_none_says_so_and_keeps_the_round() -> void:
	var m := _main()
	var round_no: int = m.world.round_no
	_press(m, "G")
	assert_eq(m.world.round_no, round_no)
	assert_eq(m.messages.lines.back().text, "풀 수 있는 주문이 없다")


func test_g_with_several_lists_them_and_the_row_chosen_ends_that_one() -> void:
	var m := _main()
	_wear(m.world, Guise.CLOAK)
	_wear(m.world, Guise.TALON)
	var round_no: int = m.world.round_no
	_press(m, "G")
	assert_eq(m.overlay, &"dispel")
	assert_eq(m.world.round_no, round_no, "listing takes no round")
	_press(m, "Up")
	assert_eq(m.menu.selected, 1, "up wraps to the last row")
	_press(m, "Down")
	assert_eq(m.menu.selected, 0, "down wraps to the first row")
	_press(m, "Enter")
	await _settle(m)
	assert_eq(m.overlay, &"")
	assert_eq(Guise.worn(m.world, m.world.player()), [Guise.CLOAK])
	assert_eq(m.world.round_no, round_no + 1)


func test_esc_leaves_the_list_with_every_buff_on_and_the_round_kept() -> void:
	var m := _main()
	_wear(m.world, Guise.CLOAK)
	_wear(m.world, Guise.TALON)
	var round_no: int = m.world.round_no
	_press(m, "G")
	_press(m, "Escape")
	assert_eq(m.overlay, &"")
	assert_eq(Guise.worn(m.world, m.world.player()).size(), 2)
	assert_eq(m.world.round_no, round_no)


func test_a_click_on_a_row_of_the_list_ends_that_one() -> void:
	var m := _main()
	_wear(m.world, Guise.CLOAK)
	_wear(m.world, Guise.TALON)
	_press(m, "G")
	assert_eq(m.menu.click(1, -1), &"dispel")
	assert_eq(m.menu.buffs[m.menu.selected], Guise.CLOAK)


func test_a_click_on_her_with_no_queue_lists_the_buffs_and_takes_no_round() -> void:
	var m := _main()
	var round_no: int = m.world.round_no
	m._use_tile(ME, false)
	assert_eq(m.overlay, &"", "with none, a stray click does nothing")
	_wear(m.world, Guise.CLOAK)
	round_no = m.world.round_no
	m._use_tile(ME, false)
	assert_eq(m.overlay, &"dispel")
	assert_eq(m.world.round_no, round_no)


func test_the_options_list_the_dispel_page_and_esc_goes_back() -> void:
	var m := _main()
	_wear(m.world, Guise.TALON)
	m._open(&"options")
	m.menu.selected = Menu.OPTIONS.find(&"dispel")
	_press(m, "Enter")
	assert_eq(m.menu.page, &"dispel")
	_press(m, "Escape")
	assert_eq(m.menu.page, &"options")
	assert_eq(m.menu.selected, Menu.OPTIONS.find(&"dispel"))
