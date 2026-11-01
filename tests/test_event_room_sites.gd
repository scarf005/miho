extends GutTest
## Which room an event room is built in (EventRooms).

const ROOM := Rect2i(10, 5, 11, 5)
const SECRET := Vector2i(9, 7)
const KINDS := [&"vault", &"altar", &"veil", &"yard", &"creak"]


## ROOM cut into a wall, Miho in a passage west of it, a way in at SECRET.
func _hall(secret: bool) -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	for y in range(ROOM.position.y, ROOM.end.y):
		for x in range(ROOM.position.x, ROOM.end.x):
			w.tiles[Grid.index(Vector2i(x, y))] = World.FLOOR
	for x in range(4, 10):
		if not secret or x < SECRET.x:
			w.tiles[Grid.index(Vector2i(x, 7))] = World.FLOOR
	if secret:
		w.secrets[SECRET] = true
	w.rooms.assign([ROOM, Rect2i(4, 6, 3, 3)])
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.hp = 3
	me.max_hp = 3
	me.pos = Vector2i(5, 7)
	w.actors.append(me)
	w.depth = 5
	w.tails = 1
	return w


func test_a_room_behind_a_hidden_door_is_never_built_into_an_event_room() -> void:
	for kind in KINDS:
		var w := _hall(true)
		var before := w.tiles.duplicate()
		var rng := RandomNumberGenerator.new()
		assert_false(EventRooms._try(w, w.rooms[1], rng, kind), str(kind))
		assert_eq(w.tiles, before, "%s changed nothing" % kind)
		assert_eq(w.rooms.size(), 2)
		assert_true(w.sites.is_empty() and w.seals.is_empty() and w.actors.size() == 1)


func test_a_built_room_leaves_the_room_list_and_the_start_room_is_never_taken() -> void:
	var w := _hall(false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	assert_true(EventRooms._try(w, w.rooms[1], rng, &"creak"))
	assert_eq(w.rooms, [Rect2i(4, 6, 3, 3)] as Array[Rect2i])
	assert_false(EventRooms._try(w, w.rooms[0], rng, &"creak"), "the start room stays")
