extends GutTest
## The talisman queue: two different elements merge into one compound slot,
## number keys fill it on the game scene, a saved spell replaces it, Esc clears
## it, and the lower status row shows its slots.

const FOX := Cards.FOX
const ORB := Cards.ORB


## An open hall walled at the edges, every tile known and seen, Miho at (4, 8).
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
	w.depth = 13
	w.tails = 5
	w.cards.assign([FOX, ORB, Cards.FIRE, Cards.WATER])
	return w


func _main() -> Node:
	var m: Node = load("res://src/view/main.tscn").instantiate()
	m.save_path = ""
	add_child_autofree(m)
	Keys.reset()
	m._new_run(3)
	m.state = &"play"
	m.world = _hall()
	m.settings.spells = {}
	m.term.show_world(m.world)
	m._forecast()
	return m


func _press(m: Node, key: String) -> void:
	var e := Keys.event(key)
	e.pressed = true
	m._key(e)


func test_number_keys_queue_talismans_with_repeats_until_the_tails_run_out() -> void:
	var m := _main()
	for k in ["1", "1", "3", "4"]:
		_press(m, k)
	assert_eq(m.picked, [FOX, FOX, Cards.FIRE, Cards.WATER] as Array[StringName])
	assert_eq(Spell.make(m.picked).slots, [FOX, FOX, &"steam"] as Array[StringName])
	_press(m, "2")
	_press(m, "2")
	assert_eq(m.picked.size(), 5, "five tails, five cards")
	_press(m, "Escape")
	assert_true(m.picked.is_empty(), "Esc clears the queue")


func test_the_queue_holds_five_slots_even_with_tails_to_spare() -> void:
	var m := _main()
	m.world.tails = 9
	m.world.depth = 25
	for i in 6:
		_press(m, "1")
	assert_eq(m.picked.size(), 5)


func test_a_saved_spell_fills_the_queue() -> void:
	var m := _main()
	m.settings.spells = {&"slot_1": "fox+fox+fire"}
	_press(m, "2")
	_press(m, "Q")
	assert_eq(m.picked, [FOX, FOX, Cards.FIRE] as Array[StringName], "it replaces the queue")
	m.world.tails = 2
	m.settings.spells = {&"slot_2": "fox+fox+fox"}
	m.picked.clear()
	_press(m, "W")
	assert_true(m.picked.is_empty(), "not with too few tails")


func test_the_status_row_shows_and_points_at_each_queue_slot() -> void:
	var m := _main()
	for k in ["1", "3", "4"]:
		_press(m, k)
	var t: Term = m.term
	var row := (t.rows - 1 + 0.5) * Term.CELL.y
	var first := (StatusBar.queue_x(t) + 0.5) * Term.CELL.x
	assert_eq(StatusBar.queue_at(t, Vector2(first, row)), 0)
	assert_eq(StatusBar.queue_at(t, Vector2(first + Term.CELL.x, row)), 1, "the steam slot")
	assert_eq(StatusBar.queue_at(t, Vector2(first + 2 * Term.CELL.x, row)), -1, "an empty slot")
	assert_eq(StatusBar.hand_at(t, Vector2(first, row)), "fox+fire+water")


func test_two_different_elements_merge_into_the_first_ones_compound() -> void:
	var pairs := {
		&"wildfire": [Cards.WOOD, Cards.FIRE],
		&"lava": [Cards.FIRE, Cards.EARTH],
		&"shrapnel": [Cards.EARTH, Cards.METAL],
		&"frost": [Cards.METAL, Cards.WATER],
		&"rain": [Cards.WATER, Cards.WOOD],
		&"steam": [Cards.WATER, Cards.FIRE],
		&"molten": [Cards.FIRE, Cards.METAL],
		&"thorn": [Cards.METAL, Cards.WOOD],
		&"split": [Cards.WOOD, Cards.EARTH],
		&"mud": [Cards.EARTH, Cards.WATER],
	}
	for c in pairs:
		for order in [pairs[c], [pairs[c][1], pairs[c][0]]]:
			assert_eq(Spell.make([FOX] + order).slots, [FOX, c] as Array[StringName], str(order))
	var queue := Spell.make([ORB, Cards.FIRE, Cards.FIRE, Cards.WATER])
	assert_eq(queue.slots, [ORB, &"steam", Cards.FIRE] as Array[StringName])
	assert_eq(queue.count(Cards.FIRE), 2)
	queue = Spell.make([ORB, Cards.FIRE, Cards.WATER, Cards.WOOD, Cards.FIRE])
	assert_eq(queue.slots, [ORB, &"steam", &"wildfire"] as Array[StringName], "never a compound")
	assert_true(queue.has(Cards.WATER))
