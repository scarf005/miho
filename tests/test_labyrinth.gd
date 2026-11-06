extends GutTest
## 미궁: half a storey of unbreakable maze with a prize deep inside, patrolled, of many kinds.

const SEEDS_MOST := 400
const DEPTH := 5


## A storey on a maze of `concept`: the first seed whose plan draws it.
func _storey(concept: StringName, skip := 0, depth := DEPTH) -> World:
	for seed_value in SEEDS_MOST:
		if RunPlan.labyrinth(seed_value).concept == concept:
			if skip == 0:
				return Built.storey(seed_value, depth, Skeletons.LABYRINTH)
			skip -= 1
	return null


func _prize(w: World) -> Vector2i:
	for s: Dictionary in w.sites:
		if s.kind == Labyrinth.PRIZE:
			return s.at
	return Vector2i(-1, -1)


func _guards(w: World) -> Array:
	var area: Rect2i = Labyrinth.site(w).area
	return w.actors.filter(func(a): return not a.is_miho() and area.has_point(a.pos))


## Opens the maze's door, so a walk may start: as finding it does.
func _found_door(w: World) -> void:
	var door: Vector2i = Labyrinth.site(w).at
	if w.secrets.has(door):
		w.secrets.erase(door)
		w.set_tile(door, World.DOOR)


## Walks Miho to `to` by real steps. Plates and boards are walked round when `open` says so.
## Keeps the creatures still, because this checks the way, not the fight.
func _walk(w: World, to: Vector2i, open: PackedByteArray) -> bool:
	var me := w.player()
	for i in 400:
		if me.pos == to:
			return true
		var dist: PackedInt32Array = Grid.search(to, open).dist
		var best := me.pos
		for d in Grid.DIRS:
			var p: Vector2i = me.pos + d
			var di := dist[Grid.index(p)]
			if di >= 0 and di < dist[Grid.index(best)]:
				best = p
		if best == me.pos:
			return false
		for a: Actor in w.actors.duplicate():
			if not a.is_miho():
				w.actors.erase(a)
		w.act({t = &"move", dir = best - me.pos})
		w.player().hp = w.player().max_hp
		if w.depth != DEPTH:
			return true
	return me.pos == to


func _ways(w: World) -> PackedByteArray:
	return Masks.floor_of(w, w.traps.keys() + _cracks(w), func(_p): return false)


func _cracks(w: World) -> Array:
	var out := []
	for i in w.tiles.size():
		if Tiles.of(w.tiles[i], "crumbles") >= 0:
			out.append(Grid.at(i))
	return out


## Walks in over the door, to the prize, and out again: the walk the player makes.
func _in_and_out(w: World) -> void:
	_found_door(w)
	var cards := w.cards.size()
	var door: Vector2i = Labyrinth.site(w).at
	var prize := _prize(w)
	var start := w.player().pos
	var open := _ways(w)
	var missing := w.cards.has(Cards.WOOD)
	assert_false(missing, "Miho holds nothing but fox and orb yet")
	assert_true(_walk(w, door, open), "to the door")
	assert_true(_walk(w, prize, open), "to the prize")
	assert_eq(w.cards.size(), cards + 1, "the prize gives a talisman")
	assert_eq(w.tile(prize), World.FLOOR)
	assert_true(_walk(w, start, _ways(w)), "back to where she came in")


func test_orthodox_is_a_perfect_maze_she_walks_in_and_out_of() -> void:
	var w := _storey(Labyrinth.ORTHODOX)
	_in_and_out(w)


func test_a_circuit_has_no_dead_end_and_is_walked_in_and_out_of() -> void:
	var w := _storey(Labyrinth.CIRCUIT)
	var area: Rect2i = Labyrinth.site(w).area
	var mask := Masks.opened(w)
	for y in range(area.position.y + 1, area.end.y - 1, 2):
		for x in range(area.position.x + 1, area.end.x - 1, 2):
			var p := Vector2i(x, y)
			var exits := Placement.SIDES.filter(func(d): return mask[Grid.index(p + d)] == 1)
			if not w.peaches.has(p):
				assert_gt(exits.size(), 1, "cell %s" % p)
	_in_and_out(w)


func test_corridors_of_bamboo_grow_all_the_way_but_the_prize_and_are_walked() -> void:
	var w := _storey(Labyrinth.BAMBOO)
	assert_gt(w.tiles.count(World.BAMBOO), 150)
	_in_and_out(w)


func test_galleries_of_plates_always_leave_a_way_round_them() -> void:
	var w := _storey(Labyrinth.PLATES)
	assert_gt(w.traps.size(), 20)
	assert_true(FloorGen.connected(w, w.traps.keys()))
	assert_gt(w.traps.values().count(World.TRAP_COLLAPSE), w.traps.size() / 2)
	_in_and_out(w)


func test_a_hunter_that_goes_over_a_pit_in_the_galleries_falls() -> void:
	var w := _storey(Labyrinth.PLATES)
	var pit := Vector2i(-1, -1)
	for p: Vector2i in w.traps:
		if w.traps[p] == World.TRAP_COLLAPSE:
			pit = p
			break
	var hunter := FloorGen.spawn(w, &"bitjaru", pit)
	Traps.enter(w, hunter, Vector2i.RIGHT)
	assert_false(hunter.alive() and hunter.pos == pit, "gone through the floor")


func test_chambers_have_a_door_on_every_link_and_are_walked() -> void:
	var w := _storey(Labyrinth.CELLS)
	var area: Rect2i = Labyrinth.site(w).area
	var doors := 0
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var t := w.tile(Vector2i(x, y))
			doors += 1 if t == World.DOOR or t == World.DOOR_OPEN else 0
	var cells: Vector2i = (area.size - Vector2i.ONE) / 4
	assert_gte(doors, cells.x * cells.y - 1)
	_in_and_out(w)


func test_the_island_cannot_be_walked_back_from_and_its_pit_is_the_way_out() -> void:
	var w := _storey(Labyrinth.ISLAND)
	var site := Labyrinth.site(w)
	var land: Rect2i = site.island
	_found_door(w)
	var boards := _cracks(w)
	assert_gte(boards.size(), 2, "boards over the sky")
	var prize := _prize(w)
	assert_true(land.has_point(prize), "the prize lies on the island")
	var cards := w.cards.size()
	var open := Masks.floor_of(w, w.traps.keys(), func(_p): return false)
	assert_true(_walk(w, site.at, open), "to the door")
	assert_true(_walk(w, prize, open), "over the boards to the prize")
	assert_eq(w.cards.size(), cards + 1)
	for p: Vector2i in boards:
		assert_eq(w.tile(p), World.SKY, "the boards fell behind her: %s" % p)
	var back := Masks.floor_of(w, w.traps.keys(), func(_p): return false)
	assert_lt(Grid.distance(w.player().pos, back, site.at), 0, "no walk back")
	var pits := w.traps.keys().filter(func(p): return land.has_point(p))
	assert_eq(pits.size(), 2)
	for p: Vector2i in pits:
		assert_eq(w.traps[p], World.TRAP_COLLAPSE)
	assert_true(_walk(w, pits[0], Masks.floor_of(w)), "to a pit")
	assert_lt(w.depth, DEPTH, "down a storey")


func test_nothing_on_the_way_to_the_orthodox_prize_can_be_broken() -> void:
	for skip in 12:
		var w := _storey(Labyrinth.ORTHODOX, skip)
		var site := Labyrinth.site(w)
		var area: Rect2i = site.area
		for y in range(area.position.y, area.end.y):
			for x in range(area.position.x, area.end.x):
				var p := Vector2i(x, y)
				if p != site.at:
					assert_false(Terrain.wall(w.tile(p)), "%s" % p)


func test_two_or_three_live_in_the_maze_of_the_storey_s_kind_and_stay_on_patrol() -> void:
	var kinds := {3: &"bitjaru", 4: &"bitjaru", 5: &"dueoksini", 6: &"dueoksini", 7: &"eodeopsini"}
	for depth: int in kinds:
		var w := _storey(Labyrinth.ORTHODOX, depth, depth)
		var guards := _guards(w)
		assert_between(guards.size(), 2, 3, "storey %d" % depth)
		for a: Actor in guards:
			assert_eq(a.kind, kinds[depth], "storey %d" % depth)


func test_a_patrol_of_the_maze_heads_for_its_tiles_and_stays_there() -> void:
	var w := _storey(Labyrinth.CIRCUIT)
	var area: Rect2i = Labyrinth.site(w).area
	var guards := _guards(w)
	var me := w.player()
	me.pos = w.start
	w.actors.assign(guards + [me])
	var inside := 0
	for round_no in 200:
		w.act({t = &"wait"})
		me.hp = me.max_hp
		inside += 1 if guards.all(func(a): return area.has_point(a.pos)) else 0
	assert_gt(inside, 190)
	var moved := guards.filter(func(a): return a.pos != a.brain.home)
	assert_gt(moved.size(), 0)


func test_the_prize_lies_far_along_the_walk_and_never_at_a_middle_to_guess() -> void:
	var near_middle := 0
	var count := 0
	for concept: StringName in [Labyrinth.ORTHODOX, Labyrinth.CELLS, Labyrinth.BAMBOO]:
		for skip in 10:
			var w := _storey(concept, skip)
			_found_door(w)
			var site := Labyrinth.site(w)
			var prize := _prize(w)
			var open := Masks.opened(w)
			var dist: PackedInt32Array = Grid.search(site.at, open).dist
			var area: Rect2i = site.area
			var longest := 0
			for y in range(area.position.y, area.end.y):
				for x in range(area.position.x, area.end.x):
					longest = maxi(longest, dist[Grid.index(Vector2i(x, y))])
			assert_gt(dist[Grid.index(prize)], longest / 3, "%s %d" % [concept, skip])
			var middle: Vector2i = area.position + area.size / 2
			near_middle += 1 if Grid.cheb(prize, middle) <= 3 else 0
			count += 1
	assert_lt(near_middle, count / 3)


func test_two_or_three_peaches_lie_in_the_maze_with_the_talisman() -> void:
	for concept: StringName in Labyrinth.CONCEPTS:
		var w := _storey(concept)
		var area: Rect2i = Labyrinth.site(w).area
		var inside := w.peaches.filter(func(p): return area.has_point(p))
		assert_between(inside.size(), 2, 3, concept)
		assert_true(_prize(w).x >= 0, concept)


func test_explore_does_not_loop_in_a_maze_and_leaves_rotten_boards_alone() -> void:
	for concept: StringName in Labyrinth.CONCEPTS:
		var w := _storey(concept)
		_found_door(w)
		w.actors.assign([w.player()])
		w.sense()
		var seen := {}
		var rounds := 0
		while rounds < 1200:
			var step := Travel.explore_step(w, Travel.search(w))
			if step == Vector2i.ZERO:
				break
			var key := [w.player().pos, w.known.count(1)]
			seen[key] = seen.get(key, 0) + 1
			assert_lt(seen[key], 3, "%s back and forth at %s" % [concept, key])
			if seen[key] >= 3:
				break
			w.act({t = &"move", dir = step})
			rounds += 1
		assert_lt(rounds, 1200, concept)
		if concept == Labyrinth.ISLAND:
			assert_eq(w.depth, DEPTH, "explore does not cross the rotten boards")
			assert_false(Labyrinth.site(w).island.has_point(w.player().pos))


func test_a_run_on_a_maze_saves_the_same_door_as_it_found_it() -> void:
	var w := _storey(Labyrinth.PLATES)
	var copy := w.clone()
	assert_eq(Labyrinth.site(copy).at, Labyrinth.site(w).at)
	assert_eq(copy.tiles, w.tiles)


## The bridge to the maze ends in a room or a gallery, never on a wall's crossing in front of a
## doorway that two rooms share. The seeds and storeys the skeleton tests carve.
func test_the_bridge_to_the_maze_leads_into_a_room_not_a_doorway() -> void:
	for seed_value in 6:
		for depth in range(1, World.FLOORS + 1):
			var w := Built.world(seed_value * World.FLOORS + depth)
			w.depth = depth
			var links: Array = FloorGen._carve(w, Skeletons.LABYRINTH).links
			var door: Vector2i = Labyrinth.site(w).at
			if door.x < 0:
				continue
			var d := (
				Vector2i.RIGHT if w.tile(door + Vector2i.RIGHT) == World.BRIDGE else Vector2i.LEFT
			)
			var mouth := door + d
			while w.tile(mouth) == World.BRIDGE:
				mouth += d
			assert_false(
				links.any(func(l): return l.at == mouth + d),
				"seed %d storey %d mouth %s" % [seed_value, depth, mouth]
			)
