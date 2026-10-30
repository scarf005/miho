extends GutTest
## The message log tells only what Miho perceived.

const SEEN := Vector2i(6, 8)
const HIDDEN := Vector2i(20, 8)


## An open hall, Miho at (4, 8), seeing only the tiles near her.
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
	w.sense()
	return w


func _lines(w: World, events: Array) -> Array[String]:
	return Messages.of(w, w, events)


func test_seen_events_are_told() -> void:
	var w := _world()
	var foe := FloorGen.spawn(w, &"dokkaebi", SEEN)
	w.sense()
	assert_eq(
		_lines(w, [{t = &"notice", id = foe.id, at = SEEN}]), ["도깨비가 미호를 봤다"] as Array[String]
	)
	assert_eq(_lines(w, [{t = &"die", id = foe.id, at = SEEN}]), ["도깨비 쓰러짐"] as Array[String])
	assert_eq(_lines(w, [{t = &"ascend", depth = 2}]), ["2층"] as Array[String])
	assert_eq(
		_lines(w, [{t = &"card", card = Cards.FIRE, at = SEEN}]), ["불 부적을 얻었다"] as Array[String]
	)
	assert_eq(_lines(w, [{t = &"ignite", at = SEEN}]), ["불이 붙었다"] as Array[String])


func test_hidden_events_give_no_line() -> void:
	var w := _world()
	var foe := FloorGen.spawn(w, &"dokkaebi", HIDDEN)
	w.sense()
	assert_eq(w.seen[Grid.index(HIDDEN)], 0)
	var events := [
		{t = &"notice", id = foe.id, at = HIDDEN},
		{t = &"charge", id = foe.id, cards = [Cards.FOX], dir = Vector2i(-1, 0)},
		{t = &"move", id = foe.id, from = HIDDEN, to = HIDDEN + Vector2i(1, 0)},
		{t = &"die", id = foe.id, at = HIDDEN},
		{t = &"ignite", at = HIDDEN},
		{t = &"smash", at = HIDDEN},
		{t = &"noise", at = HIDDEN, word = "탁", loud = 4, heard = false},
	]
	assert_eq(_lines(w, events), [] as Array[String])


func test_only_noises_heard_out_of_sight_are_told() -> void:
	var w := _world()
	var far := {t = &"noise", at = HIDDEN, word = "쾅", loud = 9, heard = true}
	var near := {t = &"noise", at = SEEN, word = "쾅", loud = 9, heard = true}
	assert_eq(_lines(w, [far]), ["멀리서 쾅"] as Array[String])
	assert_eq(_lines(w, [near]), [] as Array[String])


func test_unknown_events_are_ignored() -> void:
	var w := _world()
	assert_eq(_lines(w, [{t = &"wobble", at = SEEN}, {t = &"cast", id = 1}]), [] as Array[String])


func test_a_claw_tells_its_harm_once() -> void:
	var w := _world()
	var foe := FloorGen.spawn(w, &"dokkaebi", Vector2i(5, 8))
	w.sense()
	var before := w.clone()
	var events := w.act({t = &"move", dir = Vector2i(1, 0)})
	var lines := Messages.of(before, w, events)
	assert_eq(lines.slice(0, 2), ["기습 발톱 3 도깨비", "도깨비 쓰러짐"] as Array[String])
	assert_false(lines.any(func(l): return l.contains("피해")), "%s" % [lines])
	assert_eq(foe.hp, -1)


func test_repeated_lines_are_counted() -> void:
	var log := Messages.new()
	log.add("멀리서 탁", 1)
	log.add("멀리서 탁", 2)
	log.add("2층", 2)
	assert_eq(log.lines.map(Messages.shown), ["멀리서 탁 x2", "2층"])
	for i in Messages.KEEP + 5:
		log.add(str(i), 3)
	assert_eq(log.lines.size(), Messages.KEEP)


func test_lanterns_doors_and_fire_are_told() -> void:
	var w := _world()
	w.tiles[Grid.index(SEEN)] = World.LANTERN
	assert_eq(_lines(w, [{t = &"smash", at = SEEN}]), ["등불이 깨졌다"] as Array[String])
	assert_eq(_lines(w, [{t = &"douse", at = SEEN}]), ["등불이 꺼졌다"] as Array[String])
	w.tiles[Grid.index(SEEN)] = World.DOOR
	assert_eq(_lines(w, [{t = &"smash", at = SEEN}]), ["문이 부서졌다"] as Array[String])
	assert_eq(_lines(w, [{t = &"douse", at = SEEN}]), ["불이 꺼졌다"] as Array[String])
	assert_eq(_lines(w, [{t = &"relight", at = SEEN}]), ["등불이 켜졌다"] as Array[String])
	assert_eq(_lines(w, [{t = &"burnout", at = SEEN}]), ["불이 꺼졌다"] as Array[String])
	var me := w.player()
	var burn := [
		{t = &"burn", at = me.pos, id = me.id},
		{t = &"hurt", id = me.id, n = 1, hp = 2, at = me.pos},
	]
	assert_eq(_lines(w, burn), ["미호 불 피해 1"] as Array[String])
