extends GutTest
## The proximity fuse (Flight.fuse): what holds 유탄, and the orbs a furnace or 봉화 lets out,
## burst as soon as a foe stands beside them in flight.

const ORB := Cards.ORB
const FOX := Cards.FOX
const FIRE := Cards.FIRE
const EARTH := Cards.EARTH
const METAL := Cards.METAL
const MORTAR := [ORB, EARTH, METAL]
const WISP := [FOX, EARTH, METAL]
const LAVA := [ORB, FIRE, EARTH]
const E := Vector2i(1, 0)
const S := Vector2i(0, 1)
const ME := Vector2i(20, 12)
const WAIT := {t = &"wait"}


func _world() -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	for y in range(1, Grid.H - 1):
		for x in range(1, Grid.W - 1):
			w.tiles[Grid.index(Vector2i(x, y))] = World.FLOOR
	for x in range(2, Grid.W - 2, 3):
		w.tiles[Grid.index(Vector2i(x, ME.y - 6))] = World.LANTERN
		w.tiles[Grid.index(Vector2i(x, ME.y + 6))] = World.LANTERN
	w.rooms.assign([Rect2i(1, 1, Grid.W - 2, Grid.H - 2)])
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.hp = 9
	me.max_hp = 9
	me.pos = ME
	w.actors.append(me)
	w.depth = 5
	w.tails = 9
	w.cards.assign(Cards.ALL)
	w.sense()
	return w


func _cast(cards: Array, dir := E) -> Dictionary:
	return {t = &"cast", spells = [{cards = cards, dir = dir}]}


## A creature that stands and does nothing but take what comes.
func _post(w: World, at: Vector2i) -> Actor:
	var a := FloorGen.spawn(w, &"jangseung", at)
	a.magic.cooldown = 99
	a.max_hp = 9
	a.hp = 9
	w.sense()
	return a


func _bursts(events: Array[Dictionary]) -> Array:
	return events.filter(func(e): return e.t == &"burst").map(func(e): return e.at)


func _settle(w: World) -> Array:
	var out: Array = []
	while w.shots.any(func(s): return s.dir != Vector2i.ZERO):
		out += _bursts(w.act(WAIT))
	return out


func test_a_foe_that_steps_off_the_line_still_takes_the_burst() -> void:
	var w := _world()
	var foe := _post(w, ME + E * 8)
	w.act(_cast(MORTAR))
	assert_eq(w.shots[0].pos, ME + E * 3)
	Walk.move(w, foe, foe.pos + S)
	var bursts := _settle(w)
	assert_eq(bursts, [ME + E * 7], "it bursts on the first tile beside the foe")
	assert_eq(foe.hp, 9 - Compounds.MORTAR)


func test_a_foe_two_tiles_off_the_line_is_left_alone() -> void:
	var w := _world()
	var foe := _post(w, ME + E * 4 + S * 2)
	w.act(_cast(MORTAR))
	w.act(WAIT)
	assert_gt(w.shots[0].pos.x, foe.pos.x, "it has flown past")
	assert_eq(foe.hp, 9)


func test_a_fast_orb_goes_off_on_the_tile_it_passes_within_a_round() -> void:
	var w := _world()
	var foe := _post(w, ME + E * 3 + S)
	var cards := [ORB, ORB, ORB, EARTH, METAL]
	assert_gt(Spell.make(cards).speed(), 2)
	assert_eq(_bursts(w.act(_cast(cards))), [ME + E * 2])
	assert_lt(foe.hp, 9)


func test_an_ally_beside_the_path_sets_off_nothing() -> void:
	var w := _world()
	var ally := FloorGen.spawn(w, Forge.FURNACE, ME + E * 3 + S)
	w.sense()
	var hp := ally.hp
	w.act(_cast(MORTAR))
	w.act(WAIT)
	assert_gt(w.shots[0].pos.x, ally.pos.x, "it has flown past")
	assert_eq(ally.hp, hp)


func test_a_dead_creature_beside_the_path_sets_off_nothing() -> void:
	var w := _world()
	var foe := _post(w, ME + E * 2 + S)
	foe.hp = 0
	w.act(_cast(MORTAR))
	assert_eq(w.shots.size(), 1)


func test_what_has_no_fuse_flies_on_past_a_foe_beside_its_path() -> void:
	for cards: Array in [[ORB], [ORB, METAL], LAVA]:
		var w := _world()
		var foe := _post(w, ME + E * 2 + S)
		var flown := w.act(_cast(cards))
		assert_eq(_bursts(flown), [], str(cards))
		assert_eq(w.shots.size(), 1, str(cards))
		assert_gt(w.shots[0].pos.x, foe.pos.x, str(cards))
		assert_eq(foe.hp, 9, str(cards))


func test_a_piercing_wisp_that_holds_shrapnel_goes_on_through_a_foe() -> void:
	var w := _world()
	var foe := _post(w, ME + E * 3)
	var cards := [FOX, METAL, METAL, METAL, EARTH]
	assert_true(Spell.make(cards).pierces())
	assert_true(Spell.make(cards).has(&"shrapnel"))
	w.act(_cast(cards))
	assert_eq(w.shots.size(), 1)
	assert_gt(w.shots[0].pos.x, foe.pos.x, "it has gone through")
	assert_ne(w.shots[0].dir, Vector2i.ZERO)


func test_a_wisp_of_shrapnel_bursts_beside_a_foe_and_hovers_where_it_burst() -> void:
	var w := _world()
	var foe := _post(w, ME + E * 3 + S * 2)
	w.act(_cast(WISP))
	assert_eq(foe.hp, 9 - Compounds.SHRAPNEL)
	assert_eq(w.shots.size(), 1)
	assert_eq(w.shots[0].dir, Vector2i.ZERO, "it hovers")
	assert_eq(Grid.cheb(w.shots[0].pos, foe.pos), 1)


func test_a_wisp_that_has_landed_has_no_fuse_for_a_foe_that_walks_up() -> void:
	var w := _world()
	w.act(_cast(WISP))
	_settle(w)
	var hover: Shot = w.shots[0]
	assert_eq(hover.pos, ME + E * Spell.RANGE)
	var foe := _post(w, hover.pos + S * 3)
	Walk.move(w, foe, hover.pos + S)
	w.act(WAIT)
	w.act(WAIT)
	assert_eq(foe.hp, 9)
	assert_true(w.shots.has(hover))


func test_a_wisp_off_the_aimed_line_goes_off_on_the_tile_it_leaves_onto() -> void:
	var w := _world()
	var foe := _post(w, ME + E * 2 + S * 2)
	w.events = []
	Cast.cast(w, w.player(), Spell.make([FOX, FOX, EARTH, METAL]), E)
	assert_eq(w.shots.size(), 2)
	assert_true(w.shots.all(func(s): return s.dir == Vector2i.ZERO), "both have burst")
	assert_eq(foe.hp, 9 - 2 * Compounds.SHRAPNEL)


func test_a_burst_reaches_a_foe_diagonal_past_a_corner_so_its_fuse_goes_off() -> void:
	var w := _world()
	var ne := Vector2i(1, -1)
	var at := ME + ne * 2
	w.tiles[Grid.index(at + E)] = World.WALL
	w.tiles[Grid.index(at + S)] = World.WALL
	var foe := _post(w, at + E + S)
	assert_eq(_bursts(w.act(_cast(MORTAR, ne))), [at])
	assert_eq(foe.hp, 9 - Compounds.MORTAR)


func test_her_own_burst_beside_her_spares_her_and_hurts_the_foe() -> void:
	var w := _world()
	var foe := _post(w, ME + S)
	w.events = []
	Cast.cast(w, w.player(), Spell.make(MORTAR), E)
	assert_eq(_bursts(w.events), [ME + E])
	assert_eq(foe.hp, 9 - Compounds.MORTAR)
	assert_eq(w.player().hp, 9)


func test_a_creature_s_fused_spell_goes_off_beside_her_and_not_beside_its_own() -> void:
	var w := _world()
	var foe := _post(w, ME + E * 6 + S)
	var friend := _post(w, ME + E * 4 + S * 2)
	Cast.cast(w, foe, Spell.make(MORTAR), -E)
	assert_eq(w.shots.size(), 1, "its own side lets it by")
	assert_eq(w.shots[0].pos, ME + E * 5 + S)
	w.act(WAIT)
	assert_eq(w.shots.size(), 1, "still its own side")
	w.act(WAIT)
	assert_true(w.shots.is_empty())
	assert_eq(w.player().hp, 9 - Compounds.MORTAR)
	assert_eq(friend.hp, 9)


func test_a_furnace_hurling_at_a_foe_that_steps_aside_hurts_it() -> void:
	var w := _world()
	var f := FloorGen.spawn(w, Forge.FURNACE, ME + S * 3)
	var foe := _post(w, f.pos + E * 5)
	var rounds := 0
	while w.shots.is_empty() and rounds < 4:
		w.act(WAIT)
		rounds += 1
	assert_eq(w.shots.size(), 1)
	assert_true(w.shots[0].fused, "by the furnace, whatever its talismans")
	Walk.move(w, foe, foe.pos + S)
	var bursts := []
	while bursts.is_empty():
		bursts = _bursts(w.act(WAIT))
	assert_eq(Grid.cheb(bursts[0], foe.pos), 1)
	assert_eq(
		foe.hp, 9 - 2 * Compounds.HOT[Compounds.MOLTEN].harm, "as it bursts, as the round ends"
	)


func test_a_furnace_orb_hurts_a_foe_that_walks_on_off_the_hot_iron() -> void:
	var w := _world()
	var f := FloorGen.spawn(w, Forge.FURNACE, ME + S * 3)
	var foe := FloorGen.spawn(w, &"dokkaebi", f.pos + E * 6 + S * 2)
	foe.max_hp = 40
	foe.hp = 40
	w.sense()
	var burst: Array = []
	var rounds := 0
	while burst.is_empty() and rounds < 12:
		foe.magic.cooldown = 99
		burst = _bursts(w.act(WAIT))
		rounds += 1
	assert_eq(burst.size(), 1)
	assert_eq(Grid.cheb(burst[0], foe.pos), 2, "it walked on from beside the burst")
	assert_lt(foe.hp, 40, "off the hot iron by the end of the round")


func test_her_homing_lava_flies_on_up_to_a_foe_and_a_beacon_s_goes_off_beside_it() -> void:
	var w := _world()
	_post(w, ME + E * 4)
	assert_eq(_bursts(w.act(_cast([FOX, ORB, FIRE, EARTH]))), [], "she has no 쇠 in it")
	w = _world()
	var foe := _post(w, ME + E * 4)
	w.events = []
	Cast.cast(w, w.player(), Spell.make(Cards.recipe(&"beacon")), E)
	assert_true(w.shots.all(func(s): return s.fused))
	var bursts := []
	for i in 3:
		bursts += _bursts(w.act(WAIT))
	assert_true(bursts.any(func(p): return Grid.cheb(p, foe.pos) == 1), str(bursts))


func test_the_forecast_shows_the_burst_short_of_the_foe_as_the_round_plays_it() -> void:
	var w := _world()
	var foe := _post(w, ME + E * 3 + S)
	var action := _cast(MORTAR)
	var f := Forecast.of(w, action)
	var path: Array = f.paths.values()[0].tiles
	assert_eq(path.back(), ME + E * 2)
	assert_false(f.paths.values()[0].live)
	assert_eq(f.harm[foe.id], Compounds.MORTAR)
	w.act(action)
	assert_eq(foe.hp, 9 - f.harm[foe.id])


func test_an_ally_holds_back_a_burst_that_would_go_off_early_beside_its_own() -> void:
	var w := _world()
	var a := FloorGen.spawn(w, Forge.FURNACE, ME + S * 3)
	var far := _post(w, a.pos + E * 8)
	_post(w, a.pos + E * 2 + S)
	var plan := {cards = MORTAR, dir = E}
	assert_false(Aim.catches(w, a, plan, far), "nothing of its side by the early burst")
	var friend := FloorGen.spawn(w, Forge.FURNACE, a.pos + E * 2 - S * 2)
	assert_true(Aim.catches(w, a, plan, far), "it goes off beside the near foe")
	friend.hp = 0
	FloorGen.spawn(w, Forge.FURNACE, far.pos + E)
	assert_false(Aim.catches(w, a, plan, far), "it does not get as far as the far foe")


func test_a_furnace_holds_its_fire_when_the_early_burst_would_catch_her() -> void:
	var w := _world()
	var f := FloorGen.spawn(w, Forge.FURNACE, ME + Vector2i(-2, 1))
	_post(w, f.pos + E * 3 + S)
	for i in 4:
		w.act(WAIT)
	assert_true(w.shots.is_empty(), "she stands by where it would go off")
	assert_true(w.hot.is_empty())


func test_the_hover_of_a_shot_in_flight_tells_the_fuse_the_furnace_gave_it() -> void:
	var w := _world()
	var f := FloorGen.spawn(w, Forge.FURNACE, ME + S * 3)
	_post(w, f.pos + E * 7)
	while w.shots.is_empty():
		w.act(WAIT)
	var tag := Lang.t(Info.FUSE) + "."
	assert_string_contains(Info.plain(SpellInfo.shot(w, w.shots[0])), tag)
	var own := Shot.of(w, w.player(), Spell.make(LAVA))
	assert_false(Info.plain(SpellInfo.shot(w, own)).contains(tag))
