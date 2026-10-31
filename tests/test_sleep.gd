extends GutTest
## A resting creature at its home is asleep: it sees nothing, even next to it.
## Noise or a wound wakes it. A patrol never sleeps.

const E := Vector2i(1, 0)
const WAIT := {t = &"wait"}
const SLEEPER := &"imugi"
const PATROL := &"dokkaebi"


## An open hall walled at the edges, every tile known and seen, Miho at (4, 8).
func _hall() -> World:
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
	me.pos = Vector2i(4, 8)
	w.actors.append(me)
	w.known.resize(w.tiles.size())
	w.known.fill(1)
	w.seen = w.known.duplicate()
	w.dim.resize(w.tiles.size())
	w.depth = 4
	w.tails = 4
	return w


func _foe(w: World, kind: StringName, at: Vector2i, alert := Actor.REST) -> Actor:
	var a := FloorGen.spawn(w, kind, at)
	a.alert = alert
	a.cooldown = 99
	return a


func _claw(w: World) -> Dictionary:
	return w.act({t = &"move", dir = E}).filter(func(e): return e.t == &"claw")[0]


func test_a_sleeper_next_to_miho_does_not_see_her_and_takes_a_sneak_claw() -> void:
	var w := _hall()
	var foe := _foe(w, SLEEPER, Vector2i(5, 8))
	foe.hp = 9
	assert_true(foe.asleep())
	assert_false(w.sees(foe, w.player().pos))
	assert_true(w.caught_unawares(foe))
	assert_eq(w.view_of(foe).count(1), 0, "its eyes are shut")
	var claw := _claw(w)
	assert_true(claw.sneak)
	assert_eq(claw.n, 3)
	assert_eq(foe.hp, 6)
	assert_eq(foe.alert, Actor.HUNT, "a wound wakes it")


func test_a_sleeper_in_the_light_stays_asleep_while_miho_walks_by() -> void:
	var w := _hall()
	w.tiles[Grid.index(Vector2i(5, 7))] = World.LANTERN
	var foe := _foe(w, SLEEPER, Vector2i(6, 8))
	for i in 3:
		var events := w.act({t = &"move", dir = E} if i == 0 else WAIT)
		assert_false(events.any(func(e): return e.t == &"notice"))
	assert_eq(foe.alert, Actor.REST)
	assert_true(foe.asleep())


func test_noise_wakes_a_sleeper_and_it_goes_to_search_the_spot() -> void:
	var w := _hall()
	var foe := _foe(w, SLEEPER, Vector2i(12, 8))
	w.noise(Vector2i(10, 8), 6, "쾅", true, 0)
	assert_eq(foe.alert, Actor.SEARCH)
	assert_eq(foe.target, Vector2i(10, 8))
	assert_false(foe.asleep())
	w.act(WAIT)
	assert_ne(foe.pos, Vector2i(12, 8), "it walks to the noise")


func test_a_searching_creature_next_to_miho_sees_her_and_takes_a_plain_claw() -> void:
	var w := _hall()
	var foe := _foe(w, SLEEPER, Vector2i(5, 8), Actor.SEARCH)
	foe.hp = 9
	foe.target = foe.pos
	assert_false(foe.asleep())
	assert_true(w.sees(foe, w.player().pos))
	assert_false(w.caught_unawares(foe))
	var claw := _claw(w)
	assert_false(claw.sneak)
	assert_eq(claw.n, 1)


func test_a_resting_patrol_is_never_asleep_and_sees_miho() -> void:
	var w := _hall()
	var foe := _foe(w, PATROL, Vector2i(5, 8))
	foe.hp = 9
	assert_false(foe.asleep())
	assert_true(w.sees(foe, w.player().pos))
	assert_false(w.caught_unawares(foe))
	assert_false(_claw(w).sneak)


func test_a_creature_walking_back_to_its_post_is_awake() -> void:
	var w := _hall()
	var foe := _foe(w, SLEEPER, Vector2i(5, 8))
	foe.home = Vector2i(9, 8)
	assert_false(foe.asleep())
	assert_true(w.sees(foe, w.player().pos))
	assert_false(w.caught_unawares(foe))


func test_miho_and_a_hunter_are_never_asleep() -> void:
	var w := _hall()
	assert_false(w.player().asleep(), "Miho rests by default")
	assert_false(_foe(w, SLEEPER, Vector2i(5, 8), Actor.HUNT).asleep())
	assert_false(_foe(w, &"saja", Vector2i(9, 8)).asleep(), "it always knows where she is")


func test_the_hover_and_the_sidebar_call_a_sleeper_asleep_and_agree_with_its_sight() -> void:
	var w := _hall()
	var foe := _foe(w, SLEEPER, Vector2i(5, 8))
	w.sense()
	var text := Info.plain(Info.at(w.known_clone(), foe.pos))
	assert_string_contains(text, "자는 중")
	assert_string_contains(text, "당신을 볼 수 없다")
	assert_string_contains(text, "기습 시 피해 3")
	assert_eq(Info.state(foe), "자는 중")
	foe.alert = Actor.SEARCH
	text = Info.plain(Info.at(w.known_clone(), foe.pos))
	assert_string_contains(text, "수색 중")
	assert_string_contains(text, "당신을 보고 있다")
	assert_string_contains(text, "공격 시 피해 1")
	var patrol := _foe(w, PATROL, Vector2i(5, 9))
	assert_eq(Info.state(patrol), "쉬는 중")


func test_the_forecast_notices_an_awake_creature_but_not_a_sleeper() -> void:
	var w := _hall()
	var sleeper := _foe(w, SLEEPER, Vector2i(5, 8))
	var patrol := _foe(w, PATROL, Vector2i(4, 9))
	w.sense()
	var f := Forecast.of(w, WAIT)
	assert_true(f.noticed.has(patrol.id))
	assert_false(f.noticed.has(sleeper.id))


func test_the_map_shows_no_vision_of_a_sleeper_and_tints_it_as_catchable() -> void:
	var m: Node = load("res://src/view/main.tscn").instantiate()
	m.save_path = ""
	add_child_autofree(m)
	Keys.reset()
	m._new_run(3)
	m.state = &"play"
	m.world = _hall()
	m.term.show_world(m.world)
	var sleeper := _foe(m.world, SLEEPER, Vector2i(5, 8))
	var patrol := _foe(m.world, PATROL, Vector2i(4, 10))
	m.world.sense()
	m._forecast()
	assert_true(m._sneakable(sleeper))
	assert_false(m._sneakable(patrol))
	m.hover = sleeper.pos
	m._refresh()
	assert_eq(m.known.view_of(sleeper).count(1), 0)
	assert_eq(m.term.tints.keys().size(), 1, "only the sneak tint")
	m.hover = patrol.pos
	m._refresh()
	assert_gt(m.term.tints.keys().size(), 1, "an awake one shows what it sees")
