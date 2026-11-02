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


func _foe(w: World, kind: StringName, at: Vector2i) -> Actor:
	var a := Actor.new()
	a.id = w.new_id()
	a.kind = kind
	a.faction = Actor.HEAVEN
	a.pos = at
	a.hp = 3
	w.actors.append(a)
	return a


func test_a_creature_of_the_dead_is_a_bad_sign_once_when_it_comes_into_sight() -> void:
	var w := _world()
	var saja := _foe(w, &"saja", ME + Vector2i(2, 0))
	_foe(w, &"dokkaebi", ME + Vector2i(0, 2))
	var known := {}
	assert_eq(Sfx.dreaded(w, known), [saja] as Array[Actor])
	assert_eq(Sfx.dreaded(w, known), [] as Array[Actor], "not again")


func test_a_creature_of_the_dead_out_of_sight_is_no_sign_yet() -> void:
	var w := _world()
	var saja := _foe(w, &"saja", ME + Vector2i(2, 0))
	w.seen[Grid.index(saja.pos)] = 0
	var known := {}
	assert_eq(Sfx.dreaded(w, known), [] as Array[Actor])
	w.seen[Grid.index(saja.pos)] = 1
	assert_eq(Sfx.dreaded(w, known), [saja] as Array[Actor])


func test_a_waking_statue_and_a_guise_seen_through_add_the_eerie_sound() -> void:
	assert_eq(Sfx.sounds_of({t = &"wake"}), [&"stone", Sfx.EERIE] as Array[StringName])
	assert_has(Sfx.sounds_of({t = &"unmask", why = &"beside"}), Sfx.EERIE)
	assert_does_not_have(Sfx.sounds_of({t = &"unmask", why = &"dispel"}), Sfx.EERIE)
