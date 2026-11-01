extends GutTest
## How creatures read projectiles by their wits, and how long a hurt one stays
## wary.

const E := Vector2i(1, 0)
const WAIT := {t = &"wait"}
const ME := Vector2i(4, 8)
const DULL := &"jangseung"
const SHARP := &"imugi"
const CUNNING := &"cheonnyeon"


## An open hall walled at the edges, with no light, Miho at ME.
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
	w.depth = 4
	w.tails = 4
	return w


func _foe(w: World, kind: StringName, at: Vector2i) -> Actor:
	var a := FloorGen.spawn(w, kind, at)
	a.cooldown = 99
	# One step from its home, it is awake: a creature at its home sleeps.
	a.home += E
	return a


func _cast(cards: Array) -> Dictionary:
	return {t = &"cast", spells = [{cards = cards, dir = E}]}


func test_a_dull_creature_that_sees_a_wisp_searches_the_wisp() -> void:
	var w := _world()
	var foe := _foe(w, DULL, Vector2i(12, 4))
	w.act(_cast([Cards.FOX]))
	assert_eq(foe.alert, Actor.SEARCH)
	assert_eq(foe.target, Vector2i(8, 8))


func test_a_sharp_creature_that_sees_a_wisp_searches_where_it_came_from() -> void:
	var w := _world()
	var foe := _foe(w, SHARP, Vector2i(12, 4))
	w.act(_cast([Cards.FOX]))
	assert_eq(foe.alert, Actor.SEARCH)
	assert_eq(foe.target, ME)


func test_a_cunning_creature_that_sees_a_wisp_hunts_from_where_it_came() -> void:
	var w := _world()
	var foe := _foe(w, CUNNING, Vector2i(12, 4))
	var events := w.act(_cast([Cards.FOX]))
	assert_eq(foe.alert, Actor.HUNT)
	assert_eq(foe.target, ME)
	assert_false(foe.sees_me, "it cannot see her in the dark")
	assert_true(events.any(func(e): return e.t == &"notice" and e.id == foe.id))


func test_a_creature_that_saw_the_orb_coming_keeps_that_reaction_when_it_is_struck() -> void:
	var w := _world()
	var foe := _foe(w, SHARP, Vector2i(9, 8))
	foe.hp = 5
	w.act(_cast([Cards.ORB]))
	assert_eq(foe.hp, 5, "the orb is still flying")
	assert_eq(foe.target, ME, "it saw the lit orb and looked to where it came from")
	w.act(WAIT)
	assert_lt(foe.hp, 5, "the orb struck it")
	assert_eq(foe.target, ME, "and not the strike's own tile or the view edge")


func _struck(kind: StringName, lit := false) -> Actor:
	var w := _world()
	if lit:
		w.tiles[Grid.index(ME + Vector2i(0, 1))] = World.LANTERN
	var foe := _foe(w, kind, Vector2i(7, 8))
	foe.hp = 5
	w.act(_cast([Cards.ORB]))
	assert_eq(foe.hp, 4, "the orb strikes in the round it is cast")
	return foe


func test_a_dull_creature_hit_by_an_unseen_orb_looks_around_its_own_tile() -> void:
	var foe := _struck(DULL)
	assert_eq(foe.alert, Actor.SEARCH)
	assert_eq(foe.target, Vector2i(7, 8))


func test_a_sharp_creature_hit_by_an_unseen_orb_searches_back_along_the_flight_to_its_view_edge(
) -> void:
	var foe := _struck(SHARP)
	assert_eq(foe.alert, Actor.SEARCH)
	assert_eq(foe.target, Vector2i(5, 8), "wary, it sees two tiles in the dark")


func test_a_cunning_creature_hit_by_an_unseen_orb_searches_where_it_came_from() -> void:
	var foe := _struck(CUNNING)
	assert_eq(foe.alert, Actor.SEARCH)
	assert_eq(foe.target, ME)


func test_a_cunning_creature_hit_by_an_unseen_orb_hunts_if_it_then_sees_miho() -> void:
	var foe := _struck(CUNNING, true)
	assert_eq(foe.alert, Actor.HUNT)
	assert_true(foe.sees_me)


func test_a_hit_hunter_keeps_hunting() -> void:
	var w := _world()
	var foe := _foe(w, &"dokkaebi", Vector2i(7, 8))
	foe.hp = 5
	foe.alert = Actor.HUNT
	foe.target = Vector2i(20, 3)
	w.act(_cast([Cards.ORB]))
	assert_eq(foe.alert, Actor.HUNT)
	assert_eq(foe.target, Vector2i(20, 3))


func test_any_hurt_with_no_projectile_makes_a_resting_creature_look_around_whatever_its_wits(
) -> void:
	for kind in [DULL, SHARP, CUNNING]:
		var w := _world()
		var foe := _foe(w, kind, Vector2i(9, 3))
		w.hurt(foe, 1)
		assert_eq(foe.alert, Actor.SEARCH, kind)
		assert_eq(foe.target, foe.pos, kind)
		assert_eq(foe.wary, World.WARY_ROUNDS, kind)


func test_a_claw_makes_the_creature_wary_for_thirty_rounds() -> void:
	var w := _world()
	var foe := _foe(w, DULL, ME + E)
	foe.hp = 9
	foe.alert = Actor.HUNT
	w.act({t = &"move", dir = E})
	assert_eq(World.WARY_ROUNDS, 30)
	assert_eq(foe.wary, World.WARY_ROUNDS - 1, "the round of the claw is the first")
	for i in World.WARY_ROUNDS - 1:
		w.act(WAIT)
	assert_eq(foe.wary, 0)


func test_a_wary_searcher_does_not_rest_until_the_wariness_ends() -> void:
	var w := _world()
	var foe := _foe(w, DULL, Vector2i(20, 8))
	w.hurt(foe, 1)
	assert_gt(foe.wary, World.SEARCH_ROUNDS)
	for i in World.WARY_ROUNDS:
		w.act(WAIT)
		assert_eq(foe.alert, Actor.SEARCH, "round %d" % (i + 1))
	w.act(WAIT)
	assert_eq(foe.alert, Actor.REST)


func test_a_wary_mover_keeps_searching_around_its_target() -> void:
	var w := _world()
	var foe := _foe(w, SHARP, Vector2i(20, 8))
	foe.alert = Actor.SEARCH
	foe.target = foe.pos
	foe.wary = World.WARY_ROUNDS
	for i in World.SEARCH_ROUNDS * 2:
		w.act(WAIT)
		assert_eq(foe.alert, Actor.SEARCH, "round %d" % (i + 1))
		assert_lte(Grid.cheb(foe.pos, Vector2i(20, 8)), 3)


func test_a_wary_creature_notices_miho_one_tile_farther_in_the_dark() -> void:
	var w := _world()
	var calm := _foe(w, DULL, ME + Vector2i(2, 0))
	var wary := _foe(w, DULL, ME + Vector2i(0, 2))
	var far := _foe(w, DULL, ME + Vector2i(3, 0))
	wary.wary = 5
	far.wary = 5
	assert_false(w.sees(calm, ME))
	assert_true(w.sees(wary, ME))
	assert_false(w.sees(far, ME))


func test_wariness_counts_down_in_a_forecast_exactly() -> void:
	var w := _world()
	var foe := _foe(w, SHARP, Vector2i(20, 8))
	w.hurt(foe, 1)
	var after := w.preview(WAIT)
	assert_eq(w.actor(foe.id).wary, World.WARY_ROUNDS, "the world itself does not change")
	w.act(WAIT)
	assert_eq(after.actor(foe.id).wary, foe.wary)
	assert_eq(after.actor(foe.id).target, foe.target)
	assert_eq(after.rng.state, w.rng.state)


func test_the_info_panel_names_the_wits_and_the_wariness() -> void:
	var w := _world()
	var foes := {DULL: "둔함", SHARP: "영리함", CUNNING: "교활함"}
	for kind in foes:
		var foe := _foe(w, kind, ME + Vector2i(6, 0))
		var text := Info.plain(Info.creature(w, foe))
		assert_string_contains(text, foes[kind])
		assert_false(text.contains("경계:"), text)
		foe.wary = 12
		text = Info.plain(Info.creature(w, foe))
		assert_string_contains(text, "경계: 12초")


func test_the_observation_tells_the_wits_and_the_wariness() -> void:
	var w := _world()
	var foes := {DULL: "dull", SHARP: "sharp", CUNNING: "cunning"}
	for kind in foes:
		var foe := _foe(w, kind, ME + Vector2i(6, 0))
		var text := Observation._creature(w, foe)
		assert_string_contains(text, ", wits " + foes[kind])
		assert_false(text.contains("wary"), text)
		foe.wary = 12
		assert_string_contains(Observation._creature(w, foe), ", wary 12")


func test_a_bulgae_hit_by_a_fire_orb_from_the_dark_hunts_miho_and_closes_in() -> void:
	var w := _world()
	w.cards.assign([Cards.FIRE, Cards.ORB])
	var foe := _foe(w, &"bulgae", ME + Vector2i(6, 0))
	var struck := false
	for i in 12:
		foe.post = foe.pos
		var events := w.act(WAIT if i > 0 else _cast([Cards.FIRE, Cards.ORB]))
		struck = events.any(func(e): return e.t == &"absorb" and e.id == foe.id)
		if struck:
			break
	assert_true(struck, "the orb reached it")
	assert_false(foe.sees_me, "it cannot see her in the dark")
	assert_eq(foe.alert, Actor.HUNT)
	assert_eq(foe.target, ME)
	foe.cooldown = 99
	var gap := Grid.cheb(foe.pos, ME)
	w.act(WAIT)
	assert_lt(Grid.cheb(foe.pos, ME), gap, "it comes for her")
