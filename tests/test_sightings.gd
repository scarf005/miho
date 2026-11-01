extends GutTest
## Where Miho last saw the creatures of heaven, which walks keep stepping around.


## An open hall walled at the edges, every tile known and seen, Miho at (4, 8).
func _world() -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
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
	return w


func test_a_creature_out_of_sight_still_blocks_where_it_was_seen() -> void:
	var w := _world()
	var foe := FloorGen.spawn(w, &"jangseung", Vector2i(6, 8))
	var memory := Sightings.new()
	memory.update(w)
	var seen := Travel.route(Travel.search(w, memory.at), Vector2i(8, 8))
	w.seen[Grid.index(foe.pos)] = 0
	memory.update(w)
	assert_eq(memory.at.keys(), [foe.pos])
	assert_eq(Travel.route(Travel.search(w, memory.at), Vector2i(8, 8)), seen, "the same walk")
	assert_false(seen.has(foe.pos))


func test_a_tile_seen_empty_is_forgotten() -> void:
	var w := _world()
	var foe := FloorGen.spawn(w, &"dokkaebi", Vector2i(6, 8))
	var memory := Sightings.new()
	memory.update(w)
	foe.pos = Vector2i(6, 12)
	memory.update(w)
	assert_eq(memory.at.keys(), [Vector2i(6, 12)])


func test_a_creature_under_the_hat_is_not_remembered() -> void:
	var w := _world()
	FloorGen.spawn(w, &"gamtu", Vector2i(9, 8))
	var memory := Sightings.new()
	memory.update(w)
	assert_eq(memory.at, {})


func test_another_storey_or_world_starts_with_nothing_remembered() -> void:
	var w := _world()
	FloorGen.spawn(w, &"jangseung", Vector2i(6, 8))
	var memory := Sightings.new()
	memory.update(w)
	w.actors.pop_back()
	w.depth += 1
	w.seen.fill(0)
	memory.update(w)
	assert_eq(memory.at, {}, "a new storey")
	var other := _world()
	other.seen.fill(0)
	memory.update(w)
	FloorGen.spawn(w, &"jangseung", Vector2i(6, 8))
	w.seen.fill(1)
	memory.update(w)
	memory.update(other)
	assert_eq(memory.at, {}, "a new run")
