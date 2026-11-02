extends GutTest
## 은신 and 둔갑 seen through: a creature that goes by smell, and a clever one that
## throws a wisp at where it suspects Miho.

const ME := Vector2i(4, 8)
const E := Vector2i(1, 0)
const WAIT := {t = &"wait"}


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
	me.buffs.prey = &"dokkaebi"
	w.actors.append(me)
	w.known.resize(w.tiles.size())
	w.known.fill(1)
	w.seen = w.known.duplicate()
	w.dim.resize(w.tiles.size())
	w.depth = 5
	w.tails = 9
	w.cards.assign(Cards.ALL)
	return w


## A lit hall: a lantern lights Miho, so a creature in line sees her from afar.
func _lit(w: World) -> void:
	w.set_tile(ME + Vector2i(0, 3), World.LANTERN)
	w.sense()


func _self(cards: Array) -> Dictionary:
	return {t = &"cast", spells = [{cards = cards, dir = Vector2i.ZERO}]}


func _wear(w: World, kind: StringName) -> void:
	w.tails = 9
	w.act(_self(Guise.RECIPE[kind]))
	w.tails = 9


func _foe(w: World, kind: StringName, at: Vector2i, alert := Actor.SEARCH) -> Actor:
	var a := FloorGen.spawn(w, kind, at)
	a.alert = alert
	a.target = at
	return a


func _types(events: Array) -> Array:
	return events.map(func(e): return e.t)


func test_a_tracker_follows_her_trail_under_the_cloak_and_reaches_her() -> void:
	var w := _world()
	w.player().hp = 99
	w.player().pos = Vector2i(3, 8)
	_wear(w, Guise.CLOAK)
	for i in 4:
		w.act({t = &"move", dir = E})
	var a := _foe(w, &"bitjaru", Vector2i(3, 8), Actor.HUNT)
	a.target = Vector2i(3, 2)
	w.act({t = &"move", dir = E})
	assert_eq(a.pos, Vector2i(4, 8), "it goes to the scent, not the spot it last saw her")
	assert_eq(a.alert, Actor.HUNT)
	for i in 6:
		w.act(WAIT)
	assert_eq(Grid.cheb(a.pos, w.player().pos), 1, "the trail takes it to her")
	assert_true(a.sees_me)


func test_a_hunter_that_does_not_track_goes_to_the_spot_it_last_saw_her() -> void:
	var w := _world()
	w.player().pos = Vector2i(3, 8)
	_wear(w, Guise.CLOAK)
	for i in 4:
		w.act({t = &"move", dir = E})
	var a := _foe(w, &"gamtu", Vector2i(3, 8), Actor.HUNT)
	a.target = Vector2i(3, 2)
	w.act({t = &"move", dir = E})
	assert_eq(a.pos, Vector2i(3, 7))


## She walks east over `tile` at x = 6..8 under the cloak, a tracker on her trail.
func _crossing(tile: int) -> Actor:
	var w := _world()
	w.player().pos = Vector2i(3, 8)
	_wear(w, Guise.CLOAK)
	w.act({t = &"move", dir = E})
	w.act({t = &"move", dir = E})
	for x in range(6, 9):
		w.set_tile(Vector2i(x, 8), tile)
	var a := _foe(w, &"bitjaru", Vector2i(3, 8), Actor.HUNT)
	for i in 9:
		w.act({t = &"move", dir = E})
	return a


func test_a_tracker_loses_her_across_water() -> void:
	assert_eq(_crossing(World.SHALLOW).alert, Actor.SEARCH, "the trail ends at the water")
	assert_eq(_crossing(World.FLOOR).alert, Actor.HUNT, "the same walk over floor is followed")


func test_a_clever_creature_casts_its_wisp_at_the_lit_tile_it_suspects_and_shows_her() -> void:
	for alert in [Actor.SEARCH, Actor.HUNT]:
		var w := _world()
		_lit(w)
		var a := _foe(w, &"dokkaebi", ME + Vector2i(5, 0), alert)
		a.target = ME
		_wear(w, Guise.CLOAK)
		assert_true(Hat.hidden(w, w.player(), a.pos))
		assert_false(a.magic.intent.is_empty(), "it charges when it cannot see her")
		assert_eq(a.magic.intent[0].dir, Vector2i(-1, 0))
		var clung := false
		for i in 4:
			w.act(WAIT)
			clung = clung or w.shots.any(func(s): return s.host == w.player().id)
		assert_true(clung, "the wisp clings to her")
		assert_eq(a.alert, Actor.HUNT, "and it hunts her")
		assert_true(a.sees_me)


func test_a_clever_creature_throws_one_wisp_at_a_time() -> void:
	var w := _world()
	_lit(w)
	var a := _foe(w, &"dokkaebi", ME + Vector2i(0, -6))
	a.target = Vector2i(1, 2)
	a.ailments.rooted = 99
	_wear(w, Guise.CLOAK)
	var charges := 0
	for i in 2:
		charges += w.act(WAIT).filter(func(e): return e.t == &"charge").size()
	assert_lte(charges, 1)


func test_a_creature_with_no_wisp_spell_does_not_throw() -> void:
	var w := _world()
	_lit(w)
	var a := _foe(w, &"gamtu", ME + Vector2i(5, 0))
	a.target = ME
	_wear(w, Guise.CLOAK)
	assert_true(a.magic.intent.is_empty())
	assert_does_not_have(_types(w.act(WAIT)), &"charge")


func test_a_dull_creature_with_a_wisp_spell_does_not_throw() -> void:
	var w := _world()
	_lit(w)
	var a := _foe(w, &"jiha", ME + Vector2i(5, 0))
	a.target = ME
	_wear(w, Guise.CLOAK)
	assert_true(a.magic.intent.is_empty())
	assert_does_not_have(_types(w.act(WAIT)), &"charge")


func test_without_the_cloak_a_searcher_throws_no_wisp_at_a_lit_tile() -> void:
	var w := _world()
	_lit(w)
	w.player().pos = Vector2i(2, 2)
	var a := _foe(w, &"dokkaebi", ME + Vector2i(5, 0))
	a.target = ME
	assert_does_not_have(_types(w.act(WAIT)), &"charge")


func test_a_tracker_sees_through_the_guise() -> void:
	var w := _world()
	_lit(w)
	var a := _foe(w, &"bitjaru", ME + Vector2i(4, 0))
	a.magic.cooldown = 99
	w.act(_self(Guise.RECIPE[Guise.GUISE]))
	assert_true(Guise.knows(w, a))
	assert_eq(a.alert, Actor.HUNT)


func test_another_kind_that_does_not_track_is_still_fooled() -> void:
	var w := _world()
	_lit(w)
	var a := _foe(w, &"jangseung", ME + Vector2i(4, 0))
	w.act(_self(Guise.RECIPE[Guise.GUISE]))
	assert_false(Guise.knows(w, a))
	assert_ne(a.alert, Actor.HUNT)
	assert_true(Harm.caught_unawares(w, a))
