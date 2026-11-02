extends GutTest
## The dokkaebi of the folk tales: 외다리 도깨비 throws Miho in 씨름, 부지깽이
## 도깨비 lights every dark lantern beside it and takes no harm from fire, and
## 빗자루 도깨비 sweeps along her scent.

const WAIT := {t = &"wait"}
const ME := Vector2i(4, 8)
const KINDS := [&"oedari", &"bujigaengi", &"bitjaru"]


## An unlit open hall, Miho at ME.
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
	me.pos = ME
	w.actors.append(me)
	w.depth = 2
	return w


func _hunter(w: World, kind: StringName, at: Vector2i) -> Actor:
	var a := FloorGen.spawn(w, kind, at)
	a.alert = Actor.HUNT
	a.target = w.player().pos
	return a


func test_the_new_kinds_are_dokkaebi() -> void:
	for kind in KINDS:
		assert_true(Bestiary.allied(kind, &"dokkaebi"), kind)


func test_the_ssireum_throws_miho_back() -> void:
	var w := _world()
	_hunter(w, &"oedari", ME + Vector2i(1, 0))
	var events := w.act(WAIT)
	var throw: int = Bestiary.info(&"oedari").melee.throw
	assert_eq(w.player().pos, ME - Vector2i(throw, 0))
	assert_eq(w.player().hp, 3 - Bestiary.info(&"oedari").melee.damage)
	assert_true(events.any(func(e): return e.t == &"push" and e.id == w.player().id))


func test_a_wall_stops_the_throw() -> void:
	var w := _world()
	w.player().pos = Vector2i(2, 8)
	_hunter(w, &"oedari", Vector2i(3, 8))
	w.act(WAIT)
	assert_eq(w.player().pos, Vector2i(1, 8))


func test_a_throw_into_the_sky_drops_miho_a_storey() -> void:
	var w := _world()
	w.rng.seed = 1  # the storey below is built from it; unseeded, it may be sky there too
	w.tiles[Grid.index(ME - Vector2i(1, 0))] = World.SKY
	_hunter(w, &"oedari", ME + Vector2i(1, 0))
	w.act(WAIT)
	assert_eq(w.depth, 1)


func test_a_lone_fire_out_of_reach_is_never_charged() -> void:
	var w := _world()
	w.tiles[Grid.index(ME + Vector2i(0, -2))] = World.LANTERN
	var a := _hunter(w, &"oedari", ME + Vector2i(3, 0))
	a.cooldown = 0
	var events := w.act(WAIT)
	assert_false(events.any(func(e): return e.t == &"charge"))
	assert_eq(a.pos, ME + Vector2i(2, 0))


func test_the_poker_lights_a_dark_lantern_beside_it_at_rest() -> void:
	var w := _world()
	var lamp := Vector2i(11, 8)
	w.tiles[Grid.index(lamp)] = World.LANTERN_OUT
	var a := FloorGen.spawn(w, &"bujigaengi", Vector2i(10, 8))
	var events := w.act(WAIT)
	assert_eq(w.tile(lamp), World.LANTERN)
	assert_true(events.any(func(e): return e.t == &"relight" and e.id == a.id))
	assert_eq(a.pos, Vector2i(10, 8), "the lighting is its turn")
	var other := _world()
	other.tiles[Grid.index(lamp)] = World.LANTERN_OUT
	FloorGen.spawn(other, &"dokkaebi", Vector2i(10, 8))
	other.act(WAIT)
	assert_eq(other.tile(lamp), World.LANTERN_OUT, "a resting dokkaebi leaves it")


func test_the_poker_takes_no_harm_from_fire() -> void:
	var w := _world()
	var a := FloorGen.spawn(w, &"bujigaengi", Vector2i(10, 8))
	w.burning[a.pos] = World.BURN_ROUNDS
	w.act(WAIT)
	assert_eq(a.hp, Bestiary.hp(&"bujigaengi", 1))
	assert_true(Bestiary.absorbs(&"bujigaengi", Spell.make([Cards.ORB, Cards.FIRE])))


func test_the_broom_sweeps_along_miho_s_scent() -> void:
	var w := _world()
	var broom := FloorGen.spawn(w, &"bitjaru", Vector2i(10, 8))
	Scent.lay(w, Vector2i(11, 8))
	w.act(WAIT)
	assert_eq(broom.pos, Vector2i(11, 8))
	assert_eq(broom.alert, Actor.SEARCH)


func test_a_dokkaebi_that_does_not_track_ignores_the_scent() -> void:
	var w := _world()
	var a := FloorGen.spawn(w, &"dokkaebi", Vector2i(10, 8))
	Scent.lay(w, Vector2i(11, 8))
	w.act(WAIT)
	assert_eq(a.alert, Actor.REST)


func test_water_leaves_the_broom_no_trail() -> void:
	var w := _world()
	var broom := FloorGen.spawn(w, &"bitjaru", Vector2i(10, 8))
	w.tiles[Grid.index(Vector2i(11, 8))] = World.SHALLOW
	Scent.lay(w, Vector2i(11, 8))
	w.act(WAIT)
	assert_eq(broom.alert, Actor.REST)


func test_each_kind_comes_from_its_tier_on() -> void:
	var first := {}
	for tier in range(1, 10):
		for kind in FloorGen.PLAN[tier]:
			if not first.has(kind):
				first[kind] = tier
	assert_eq([first.get(&"oedari"), first.get(&"bujigaengi"), first.get(&"bitjaru")], [2, 3, 4])


func test_the_hover_and_the_doc_tell_each_trick() -> void:
	var text := {}
	for kind in KINDS:
		text[kind] = Info.plain(Info.creature_facts(Codex.foe(kind), []))
	var melee: Dictionary = Bestiary.info(&"oedari").melee
	assert_string_contains(
		text[&"oedari"], "근접: 씨름 · 피해: %d · 던짐: %d칸" % [melee.damage, melee.throw]
	)
	assert_string_contains(text[&"bujigaengi"], "등불 켜기")
	assert_string_contains(text[&"bujigaengi"], "면역: 불")
	assert_string_contains(text[&"bitjaru"], "냄새 추적")
	assert_false(text[&"bitjaru"].contains("말할 수 있다"))


## A 부지깽이 도깨비 that sleeps whatever it does, to see what sleep takes from it.
class Sleeper:
	extends Actor

	func asleep() -> bool:
		return true


func _lamp_world() -> World:
	var w := _world()
	w.tiles[Grid.index(Vector2i(11, 8))] = World.LANTERN_OUT
	return w


func test_a_sleeping_poker_leaves_the_dark_lantern_beside_it() -> void:
	var w := _lamp_world()
	var a := Sleeper.new()
	a.id = w.new_id()
	a.kind = &"bujigaengi"
	a.pos = Vector2i(10, 8)
	a.home = a.pos
	a.hp = 2
	w.actors.append(a)
	w.act(WAIT)
	assert_eq(w.tile(Vector2i(11, 8)), World.LANTERN_OUT)


func test_an_awake_poker_lights_it_on_patrol_searching_hunting_and_walking_home() -> void:
	for alert in [Actor.REST, Actor.SEARCH, Actor.HUNT]:
		var w := _lamp_world()
		var a := FloorGen.spawn(w, &"bujigaengi", Vector2i(10, 8))
		a.alert = alert
		a.target = Vector2i(10, 8)
		w.act(WAIT)
		assert_false(a.asleep(), "a patrol never sleeps")
		assert_eq(w.tile(Vector2i(11, 8)), World.LANTERN, "alert %d" % alert)
	var home := _lamp_world()
	var walker := FloorGen.spawn(home, &"bujigaengi", Vector2i(10, 8))
	walker.home = Vector2i(20, 8)
	home.act(WAIT)
	assert_eq(home.tile(Vector2i(11, 8)), World.LANTERN)


func test_the_hover_and_the_doc_say_the_poker_lights_lanterns_when_awake() -> void:
	var text := Info.plain(Info.creature_facts(Codex.foe(&"bujigaengi"), []))
	assert_string_contains(text, "등불 켜기")


func test_the_lone_fire_gives_a_plain_dokkaebi_no_element() -> void:
	assert_eq(Bestiary.elements(&"oedari"), [] as Array[StringName])
	assert_eq(Bestiary.weak_to(&"dokkaebi"), [] as Array[StringName])


func test_a_plain_dokkaebi_keeps_throwing_wisps_below_the_third_rank() -> void:
	var w := _world()
	w.tiles[Grid.index(ME + Vector2i(0, -2))] = World.LANTERN
	var a := _hunter(w, &"dokkaebi", ME + Vector2i(4, 0))
	w.sense()
	for next in 2:
		a.casts = next
		var plans := Aim.at(w, a, w.player())
		assert_eq(plans.size(), 1)
		assert_eq(plans[0].cards, [Cards.FOX])


func test_it_sets_the_grass_under_miho_alight_in_place_of_a_blow() -> void:
	var w := _world()
	w.tiles[Grid.index(ME + Vector2i(0, -2))] = World.LANTERN
	w.tiles[Grid.index(ME)] = World.GRASS
	var a := _hunter(w, &"oedari", ME + Vector2i(1, 0))
	a.cooldown = 0
	var events := w.act(WAIT)
	assert_true(events.any(func(e): return e.t == &"charge" and e.cards == [Cards.FIRE]))
	assert_eq(w.player().hp, 3, "the charge is its turn")
	w.act(WAIT)
	assert_true(w.burning.has(ME))


func test_on_bare_floor_it_strikes_as_before() -> void:
	var w := _world()
	w.tiles[Grid.index(ME + Vector2i(0, -2))] = World.LANTERN
	var a := _hunter(w, &"oedari", ME + Vector2i(1, 0))
	a.cooldown = 0
	assert_true(w.act(WAIT).any(func(e): return e.t == &"melee" and e.id == a.id))
