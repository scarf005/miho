extends GutTest
## Scent: a hunter that lost sight of Miho follows the trail she walked.

const WAIT := {t = &"wait"}
const E := Vector2i(1, 0)
const W := Vector2i(-1, 0)
const N := Vector2i(0, -1)
const SEED := 1


## A dark L-shaped corridor: y = 8 from x = 2 to 16, then x = 16 from y = 2 to 8.
## Miho stands at (12, 8).
func _world() -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	for x in range(2, 17):
		w.tiles[Grid.index(Vector2i(x, 8))] = World.FLOOR
	for y in range(2, 9):
		w.tiles[Grid.index(Vector2i(16, y))] = World.FLOOR
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.hp = 3
	me.max_hp = 3
	me.pos = Vector2i(12, 8)
	w.actors.append(me)
	w.depth = 2
	w.tails = 4
	return w


## A dokkaebi that lost Miho and heads for the spot it last saw her.
func _hunter(w: World, at: Vector2i) -> Actor:
	var a := FloorGen.spawn(w, &"dokkaebi", at)
	a.cooldown = 99
	a.alert = Actor.HUNT
	a.target = w.player().pos
	return a


func _walk(w: World, dirs: Array) -> void:
	for d in dirs:
		w.act({t = &"move", dir = d})


func _stamp(w: World, p: Vector2i, stamp: int) -> void:
	w.scent.resize(w.tiles.size())
	w.scent[Grid.index(p)] = stamp


func test_a_hunter_follows_miho_round_a_corner() -> void:
	var w := _world()
	var a := _hunter(w, Vector2i(9, 8))
	_walk(w, [E, E, E, E, N, N, N, N])
	assert_eq(w.player().pos, Vector2i(16, 4))
	assert_false(a.sees_me, "it never saw her again")
	assert_eq(a.alert, Actor.HUNT)
	assert_eq(a.pos.x, 16, "it came round the corner")
	assert_lt(a.pos.y, 8)


func test_a_hunter_follows_a_trail_of_trail_age_and_drops_an_older_one() -> void:
	for age in [Scent.TRAIL_AGE, Scent.TRAIL_AGE + 1]:
		var w := _world()
		w.round_no = 100
		var a := _hunter(w, Vector2i(5, 8))
		a.target = a.pos
		_stamp(w, Vector2i(6, 8), w.round_no + 1 - age)
		w.act(WAIT)
		if age == Scent.TRAIL_AGE:
			assert_eq(a.alert, Actor.HUNT, "age %d is followed" % age)
			assert_eq(a.pos, Vector2i(6, 8))
		else:
			assert_eq(a.alert, Actor.SEARCH, "age %d is cold" % age)


func test_a_hunter_does_not_step_onto_an_older_tile() -> void:
	var w := _world()
	var a := _hunter(w, Vector2i(5, 8))
	a.target = a.pos
	_stamp(w, a.pos, 5)
	_stamp(w, Vector2i(6, 8), 3)
	w.act(WAIT)
	assert_eq(a.alert, Actor.SEARCH)


func test_a_static_creature_never_follows() -> void:
	var w := _world()
	var a := FloorGen.spawn(w, &"jangseung", Vector2i(9, 8))
	_stamp(w, Vector2i(10, 8), 1)
	assert_eq(Scent.next(w, a), a.pos)


## Miho walks east from (7, 8) over `tile` at x = 8..10; a hunter trails her.
func _trail_over(tile: int) -> Actor:
	var w := _world()
	w.player().pos = Vector2i(7, 8)
	var a := _hunter(w, Vector2i(4, 8))
	for x in range(8, 11):
		w.tiles[Grid.index(Vector2i(x, 8))] = tile
	_walk(w, [E, E, E, E, E, E])
	return a


func test_bamboo_breaks_the_trail() -> void:
	assert_eq(_trail_over(World.BAMBOO).alert, Actor.SEARCH, "the trail ends at the bamboo")
	assert_eq(_trail_over(World.FLOOR).alert, Actor.HUNT, "the same walk over floor is followed")


func test_a_tile_set_alight_loses_its_scent() -> void:
	var w := _world()
	w.act({t = &"move", dir = E})
	var p := w.player().pos
	assert_gt(w.scent[Grid.index(p)], 0)
	w.tiles[Grid.index(p)] = World.BOARD
	Terrain.ignite(w, p)
	assert_eq(w.scent[Grid.index(p)], 0)


func test_miho_leaves_no_scent_on_a_burning_tile() -> void:
	var w := _world()
	w.burning[Vector2i(13, 8)] = 2
	w.act({t = &"move", dir = E})
	assert_eq(w.scent[Grid.index(Vector2i(13, 8))], 0)


func test_a_water_spell_washes_the_scent_where_it_lands() -> void:
	var w := _world()
	w.cards.assign([Cards.FOX, Cards.ORB, Cards.WATER])
	w.scent.resize(w.tiles.size())
	for x in range(2, 17):
		w.scent[Grid.index(Vector2i(x, 8))] = 5
	w.act({t = &"cast", spells = [{cards = [Cards.ORB, Cards.WATER], dir = E}]})
	w.act(WAIT)
	var washed := range(2, 17).filter(func(x): return w.scent[Grid.index(Vector2i(x, 8))] == 0)
	assert_false(washed.is_empty(), "the spell washed some scent")
	assert_lte(washed.back() - washed.front(), 2, "only the 3x3 where it landed")
	assert_gt(washed.front(), 12, "ahead of Miho, where it flew")
	assert_eq(w.scent[Grid.index(Vector2i(2, 8))], 5, "far tiles keep theirs")


func test_a_clone_and_a_preview_carry_the_scent() -> void:
	var w := _world()
	_walk(w, [E, E])
	assert_eq(w.clone().scent, w.scent)
	assert_eq(w.known_clone().scent, w.scent)
	var a := _hunter(w, Vector2i(10, 8))
	a.target = Vector2i(13, 8)
	var step := {t = &"move", dir = E}
	var shown := w.preview(step)
	w.act(step)
	assert_eq(shown.scent, w.scent)
	assert_eq(shown.actors[1].pos, a.pos)
	assert_eq(shown.actors[1].alert, a.alert)


func test_the_same_seed_and_actions_leave_the_same_scent_and_creatures() -> void:
	var a := World.create(SEED)
	var b := World.create(SEED)
	for i in 60:
		var action := {t = &"move", dir = Grid.DIRS[i % 8]}
		if not a.can(action):
			action = WAIT
		a.act(action)
		b.act(action)
	assert_lt(a.scent.count(0), a.scent.size(), "Miho left a trail")
	assert_eq(a.scent, b.scent)
	var state := func(x): return [x.pos, x.alert]
	assert_eq(a.actors.map(state), b.actors.map(state))


func test_a_new_storey_starts_without_scent() -> void:
	var w := World.create(SEED)
	w.player().pos = w.stairs - E
	w.scent.resize(w.tiles.size())
	w.scent.fill(9)
	w.act({t = &"move", dir = E})
	assert_eq(w.depth, 2)
	assert_eq(w.scent.count(9), 0)


func test_searching_lasts_search_rounds() -> void:
	var w := _world()
	var a := FloorGen.spawn(w, &"jangseung", Vector2i(5, 8))
	a.cooldown = 99
	a.alert = Actor.SEARCH
	a.target = a.pos
	assert_eq(World.SEARCH_ROUNDS, 15)
	for i in World.SEARCH_ROUNDS:
		w.act(WAIT)
		assert_eq(a.alert, Actor.SEARCH, "round %d" % (i + 1))
	w.act(WAIT)
	assert_eq(a.alert, Actor.REST)


func test_the_observation_says_a_hunter_is_tracking_scent() -> void:
	var w := _world()
	var a := _hunter(w, Vector2i(5, 8))
	assert_string_contains(Observation._creature(w, a), ", tracking scent")
	a.alert = Actor.SEARCH
	assert_false(Observation._creature(w, a).contains("tracking"))
	var near := _hunter(w, Vector2i(11, 8))
	assert_false(Observation._creature(w, near).contains("tracking"), "it sees her")


## A water wisp at `at`, as when it lands there.
func _water_lands(w: World, at: Vector2i) -> void:
	var s := Shot.new()
	s.spell = Spell.make([Cards.FOX, Cards.WATER])
	Terrain.touch(w, s, at, Vector2i(-1, -1))


func test_water_landing_on_the_bottom_row_washes_only_the_tiles_on_the_map() -> void:
	var w := _world()
	var at := Vector2i(10, Grid.H - 1)
	w.set_tile(at + W, World.LANTERN)
	_water_lands(w, at)
	assert_eq(w.tile(at + W), World.LANTERN_OUT)


func test_water_landing_on_a_side_of_the_map_leaves_the_scent_on_the_far_side() -> void:
	var w := _world()
	var row := 10
	var east := Vector2i(Grid.W - 1, row)
	var wrapped := Vector2i(0, row + 1)
	Scent.lay(w, wrapped)
	_water_lands(w, east)
	assert_gt(w.scent[Grid.index(wrapped)], 0, "past the east edge is not the next row's west end")
	var west := Vector2i(0, row)
	var wrapped_west := Vector2i(Grid.W - 1, row - 1)
	Scent.lay(w, wrapped_west)
	_water_lands(w, west)
	assert_gt(w.scent[Grid.index(wrapped_west)], 0, "past the west edge either")
