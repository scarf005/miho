extends GutTest
## 이무기 stays off to cast, and bites hard what comes next to it.

const E := Vector2i(1, 0)
const ME := Vector2i(30, 12)


func _hall() -> World:
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
	me.hp = 9
	me.max_hp = 9
	me.pos = ME
	w.actors.append(me)
	Status.ignite(w, me)
	w.sense()
	return w


func _hunter(w: World, kind: StringName, at: Vector2i) -> Actor:
	var a := FloorGen.spawn(w, kind, at)
	a.brain.alert = Actor.HUNT
	a.brain.target = ME
	return a


func _bite(kind: StringName) -> int:
	var w := _hall()
	var a := _hunter(w, kind, ME + E)
	a.magic.cooldown = 0
	var blows := w.act({t = &"wait"}).filter(func(e): return e.t == &"melee" and e.id == a.id)
	assert_eq(blows.size(), 1, "%s strikes what stands next to it" % kind)
	return blows[0].n if not blows.is_empty() else 0


func test_an_imugi_next_to_her_bites_harder_than_a_fist() -> void:
	assert_gt(_bite(&"imugi"), _bite(&"dalgyal"))


func test_an_imugi_away_from_her_still_casts() -> void:
	var w := _hall()
	var a := _hunter(w, &"imugi", ME + E * 4)
	a.magic.cooldown = 0
	var events := w.act({t = &"wait"})
	assert_true(events.any(func(e): return e.t == &"charge" and e.id == a.id))
	assert_false(events.any(func(e): return e.t == &"melee"))


func test_its_bite_is_heard() -> void:
	var w := _hall()
	var a := _hunter(w, &"imugi", ME + E)
	var blows := w.act({t = &"wait"}).filter(func(e): return e.t == &"melee" and e.id == a.id)
	assert_eq(blows.size(), 1)
	assert_ne(Sfx.sound_of(blows[0]), &"")


func test_its_hover_tells_the_harm_of_its_bite() -> void:
	var w := _hall()
	var a := _hunter(w, &"imugi", ME + E)
	var hover := Info.plain(Info.creature(w, a))
	assert_string_contains(hover, "근접: ")
	assert_string_contains(hover, "피해: %d" % a.info().melee.damage)


func test_its_codex_example_has_a_part_for_its_strike_in_which_it_strikes() -> void:
	var part: Dictionary = CodexScene.foe(&"imugi", 1).each[0]
	assert_string_contains(part.label, "근접")
	var w := CodexScene.build(part)
	var told := []
	for action in CodexScene.actions(part):
		told.append_array(w.act(action).map(func(e): return e.t))
	assert_has(told, &"melee")
