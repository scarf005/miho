extends GutTest
## The stairs down (World.down): on the start of every storey from the second, they take
## Miho to the up stairs of the storey below as she left it, and put 저승의 저주 on it.

const WAIT := {t = &"wait"}


## Miho takes the stairs up.
func _climb(w: World) -> void:
	w.player().pos = w.stairs
	Walk.arrive(w, w.player())


## Miho takes the stairs down.
func _descend(w: World) -> void:
	w.player().pos = w.down
	Walk.arrive(w, w.player())


## The way from `p` to a free tile beside it with no plate.
func _off(w: World, p: Vector2i) -> Vector2i:
	for d in Grid.DIRS:
		if w.vacant(p + d) and not w.traps.has(p + d):
			return d
	return Vector2i.ZERO


## Miho steps off her tile and back onto it.
func _step_back(w: World) -> void:
	var d := _off(w, w.player().pos)
	assert_ne(d, Vector2i.ZERO, "a free tile beside her")
	w.act({t = &"move", dir = d})
	w.act({t = &"move", dir = -d})


func test_every_storey_from_the_second_has_stairs_down_on_its_start() -> void:
	for depth in range(1, World.FLOORS + 1):
		var w := Built.storey(1, depth)
		var down := w.start if depth >= 2 else Vector2i(-1, -1)
		assert_eq(w.down, down, "storey %d" % depth)


func test_the_stairs_down_lead_to_the_up_stairs_of_the_storey_left_as_it_was() -> void:
	var w := World.create(3)
	var tiles := w.tiles.duplicate()
	var stairs := w.stairs
	var arrives := Curse.arrival(w)
	_climb(w)
	assert_eq(w.player().pos, w.down, "she comes up on the stairs down")
	w.act(WAIT)
	assert_eq(w.depth, 2, "standing on them does not take her down")
	_step_back(w)
	assert_eq(w.depth, 1)
	assert_eq(w.tiles, tiles)
	assert_eq(w.player().pos, stairs)
	assert_eq(Curse.arrival(w), arrives - Curse.SOONER, "저승사자 comes sooner")
	assert_eq(Curse.worn(w), [Curse.REAPER])


func test_back_up_the_storey_above_is_as_she_left_it() -> void:
	var w := World.create(3)
	_climb(w)
	w.act(WAIT)
	var tiles := w.tiles.duplicate()
	var ids := w.actors.map(func(a): return a.id)
	_descend(w)
	w.act(WAIT)
	assert_eq(w.depth, 1, "standing on the stairs up does not take her up")
	_step_back(w)
	assert_eq(w.depth, 2)
	assert_eq(w.tiles, tiles)
	assert_eq(w.actors.map(func(a): return a.id), ids)
	assert_eq(w.player().pos, w.down)


func test_each_way_down_brings_the_reaper_of_the_storey_below_sooner_again() -> void:
	var w := World.create(3)
	var arrives := Curse.arrival(w)
	_climb(w)
	_descend(w)
	_climb(w)
	_descend(w)
	assert_eq(Curse.arrival(w), arrives - 2 * Curse.SOONER)


func test_past_its_omen_the_reaper_comes_at_the_end_of_her_first_round_below() -> void:
	var w := World.create(3)
	w.round_no = Curse.arrival(w) - Curse.LEAD + 1
	_climb(w)
	_descend(w)
	var told := w.act(WAIT)
	assert_true(told.any(func(e): return e.t == &"arrive"), str(told.map(func(e): return e.t)))


func test_a_reaper_that_has_come_is_not_brought_again() -> void:
	var w := World.create(3)
	w.round_no = Curse.arrival(w) + 5
	_climb(w)
	var told := []
	_descend(w)
	told.append_array(w.events)
	told.append_array(w.act(WAIT))
	assert_false(told.any(func(e): return e.t in [&"arrive", &"curse"]))


func test_going_down_keeps_only_the_tails_of_the_storey_below_and_heals_nothing() -> void:
	var w := World.create(3)
	for i in 4:
		_climb(w)
	assert_eq(w.depth, 5)
	w.tails = 5
	w.player().hp = 1
	_descend(w)
	assert_eq(w.depth, 4)
	assert_eq(w.tails, 4)
	assert_eq(w.player().hp, 1)
	var told := w.events.filter(func(e): return e.t == &"descend")
	assert_eq(told.map(func(e): return e.depth), [4])


func test_an_ally_beside_her_comes_down_with_her() -> void:
	var w := World.create(3)
	_climb(w)
	var ally := FloorGen.spawn(w, Cards.BUNSIN, w.down + _off(w, w.down))
	_descend(w)
	assert_eq(w.depth, 1)
	assert_not_null(w.actor(ally.id))
	assert_lt(Grid.cheb(w.actor(ally.id).pos, w.player().pos), 2)


func test_no_spell_turns_or_grows_over_the_stairs_down() -> void:
	var w := World.create(3)
	_climb(w)
	w.player().pos = w.down + _off(w, w.down)
	assert_false(Compounds.open(w, w.down))
	assert_eq(Elements.growable(w, [w.down] as Array[Vector2i]), [] as Array[Vector2i])


func test_a_walk_goes_round_the_stairs_down_and_ends_on_them_only_when_told() -> void:
	var w := World.create(3)
	_climb(w)
	w.known.fill(1)
	var d := Vector2i.ZERO
	for one in Grid.DIRS:
		if w.vacant(w.down + one) and w.vacant(w.down - one) and d == Vector2i.ZERO:
			d = one
	w.player().pos = w.down + d
	w.sense()
	var found := Travel.search(w)
	assert_does_not_have(Travel.route(found, w.down - d), w.down)
	assert_eq(Travel.route(found, w.down), [w.down] as Array[Vector2i])
	assert_ne(w.player().pos + Travel.explore_step(w, found), w.down)


func test_the_hover_names_the_stairs_down_and_their_curse() -> void:
	var w := World.create(3)
	_climb(w)
	var text := Info.plain(Info.terrain_facts(w, w.down))
	assert_true(text.begins_with("내려가는 계단\n저승의 저주"), text)


func test_the_agent_map_draws_the_stairs_down() -> void:
	var w := World.create(3)
	_climb(w)
	w.player().pos = w.down + _off(w, w.down)
	w.sense()
	var rows := Observation.text(w).split("\n")
	var head := "map, x across 0-%d, y down 0-%d:" % [Grid.W - 1, Grid.H - 1]
	var row: String = rows[rows.find(head) + 2 + w.down.y]
	assert_eq(row[3 + w.down.x], ">")


func test_the_log_tells_the_storey_she_went_down_to() -> void:
	var w := World.create(3)
	w.known.fill(1)
	_climb(w)
	var before := w.clone()
	w.events = []
	_descend(w)
	var lines := Messages.of(before, w, w.events).map(Messages.plain)
	assert_eq(lines, ["1층으로 내려갔다", "오한이 든다..."], "the stairs she took up are no find")
