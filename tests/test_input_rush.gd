extends GutTest
## An animation only shows a round the world has already played, so it never
## holds up a key.


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
	w.depth = 5
	w.tails = 5
	w.cards.assign([Cards.FOX, Cards.ORB])
	return w


func _main() -> Node:
	var m: Node = load("res://src/view/main.tscn").instantiate()
	m.save_path = ""
	add_child_autofree(m)
	Keys.reset()
	m.new_run(3)
	m.state = &"play"
	m.world = _hall()
	m.term.show_world(m.world)
	m.forecast()
	return m


func _key(key: String, echo := false) -> InputEventKey:
	var e := Keys.event(key)
	e.pressed = true
	e.echo = echo
	return e


## A cast whose orb flies on: the round after it animates too.
func _throw(m: Node) -> void:
	m.act({t = &"cast", spells = [{cards = [Cards.ORB], dir = Vector2i.RIGHT}]})


func test_a_key_during_an_animation_plays_its_round_at_once() -> void:
	var m := _main()
	_throw(m)
	assert_true(m.busy, "the cast is still animating")
	var rounds: int = m.world.round_no
	m._unhandled_input(_key("Period"))
	assert_eq(m.world.round_no, rounds + 1, "in the same call, not after the animation")


func test_a_held_key_repeats_through_animations() -> void:
	var m := _main()
	_throw(m)
	var rounds: int = m.world.round_no
	for i in 3:
		m._unhandled_input(_key("Left", true))
	assert_eq(m.world.round_no, rounds + 3)


func test_a_key_during_a_walk_stops_it_at_once() -> void:
	var m := _main()
	m.journey.go(func(): return {t = &"move", dir = Vector2i.RIGHT})
	assert_true(m.journey.walking, "still walking")
	m._unhandled_input(_key("Period"))
	assert_false(m.journey.walking)
	assert_false(m.busy)


func test_the_rushed_round_ends_on_the_world_as_it_is() -> void:
	var m := _main()
	_throw(m)
	var settled := []
	m.term.settled.connect(func(w): settled.append(w))
	m.term.rush()
	assert_false(m.busy)
	assert_eq(settled, [m.world])
