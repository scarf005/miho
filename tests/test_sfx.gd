extends GutTest
## Which fire Miho hears crackle.

const NONE := Vector2i(-1, -1)
const ME := Vector2i(10, 8)


## Miho at ME in an empty hall that she sees all of.
func _world() -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.FLOOR)
	w.seen.resize(Grid.W * Grid.H)
	w.seen.fill(1)
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.pos = ME
	w.actors.append(me)
	return w


func _burn(w: World, p: Vector2i) -> void:
	w.burning[p] = World.BURN_ROUNDS


func test_no_fire_is_silent() -> void:
	assert_eq(Sfx.nearest_fire(_world()), NONE)


func test_the_nearest_seen_fire_is_heard() -> void:
	var w := _world()
	_burn(w, ME + Vector2i(6, 0))
	_burn(w, ME + Vector2i(-3, 2))
	_burn(w, ME + Vector2i(0, -5))
	assert_eq(Sfx.nearest_fire(w), ME + Vector2i(-3, 2))


func test_fire_out_of_sight_is_not_heard() -> void:
	var w := _world()
	_burn(w, ME + Vector2i(2, 0))
	_burn(w, ME + Vector2i(5, 0))
	w.seen[Grid.index(ME + Vector2i(2, 0))] = 0
	assert_eq(Sfx.nearest_fire(w), ME + Vector2i(5, 0))
	w.seen[Grid.index(ME + Vector2i(5, 0))] = 0
	assert_eq(Sfx.nearest_fire(w), NONE)


func test_fire_is_heard_up_to_ten_tiles() -> void:
	var w := _world()
	_burn(w, ME + Vector2i(Sfx.FIRE_RANGE + 1, 0))
	assert_eq(Sfx.nearest_fire(w), NONE, "eleven tiles away")
	_burn(w, ME + Vector2i(Sfx.FIRE_RANGE, 0))
	assert_eq(Sfx.nearest_fire(w), ME + Vector2i(Sfx.FIRE_RANGE, 0), "ten tiles away")


func test_when_a_track_ends_the_next_plays_and_all_come_round() -> void:
	var sfx := Sfx.new()
	add_child_autofree(sfx)
	var heard := {}
	for i in Sfx.MUSIC.size():
		assert_not_null(sfx._music.stream, "a track plays")
		heard[sfx._music.stream.resource_path] = true
		sfx._music.finished.emit()
	assert_eq(heard.size(), Sfx.MUSIC.size())
