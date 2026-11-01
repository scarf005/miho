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
	var out: Array[String] = []
	out.assign(Messages.of(w, w, events).map(Messages.plain))
	return out


func test_seen_events_are_told() -> void:
	var w := _world()
	var foe := FloorGen.spawn(w, &"dokkaebi", SEEN)
	w.sense()
	assert_eq(_lines(w, [{t = &"notice", id = foe.id, at = SEEN}]), ["도깨비에게 들켰다"] as Array[String])
	assert_eq(_lines(w, [{t = &"die", id = foe.id, at = SEEN}]), ["도깨비가 쓰러졌다"] as Array[String])
	assert_eq(_lines(w, [{t = &"ascend", depth = 2}]), ["2층으로 올라갔다"] as Array[String])
	assert_eq(
		_lines(w, [{t = &"card", card = Cards.FIRE, at = SEEN}]), ["불 부적을 얻었다"] as Array[String]
	)
	assert_eq(_lines(w, [{t = &"ignite", at = SEEN}]), ["바닥에 불이 붙었다"] as Array[String])
	assert_eq(
		_lines(w, [{t = &"alight", id = foe.id, at = SEEN}]), ["도깨비에게 불이 붙었다"] as Array[String]
	)
	assert_eq(
		_lines(w, [{t = &"burnout", at = SEEN}]),
		[] as Array[String],
		"bare floor leaves no ash line"
	)
	w.tiles[Grid.index(SEEN + Vector2i.DOWN)] = World.BAMBOO
	assert_eq(
		_lines(w, [{t = &"ignite", at = SEEN + Vector2i.DOWN}]), ["대숲에 불이 붙었다"] as Array[String]
	)


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
	assert_eq(_lines(w, [far]), ["멀리서 쾅 소리를 들었다"] as Array[String])
	assert_eq(_lines(w, [near]), [] as Array[String])


func test_unknown_events_are_ignored() -> void:
	var w := _world()
	assert_eq(_lines(w, [{t = &"wobble", at = SEEN}, {t = &"cast", id = 1}]), [] as Array[String])


func test_a_claw_tells_its_harm_once() -> void:
	var w := _world()
	var foe := FloorGen.spawn(w, &"dokkaebi", Vector2i(5, 8))
	foe.blind = 2
	w.sense()
	var before := w.clone()
	var events := w.act({t = &"move", dir = Vector2i(1, 0)})
	var lines := Messages.of(before, w, events).map(Messages.plain)
	assert_eq(lines.slice(0, 2), ["도깨비에게 피해를 3 주었다", "도깨비가 쓰러졌다"])
	assert_eq(lines.filter(func(l): return l.contains("피해")).size(), 1, "%s" % [lines])
	assert_eq(foe.hp, -1)


func test_repeated_lines_are_counted() -> void:
	var log := Messages.new()
	log.add([["멀리서 ", Palette.TEXT], ["탁", Palette.SOUND]], 1)
	log.add([["멀리서 ", Palette.TEXT], ["탁", Palette.SOUND]], 2)
	log.add([["2층", Palette.TEXT]], 2)
	assert_eq(log.lines.map(func(l): return Messages.plain(Messages.shown(l))), ["멀리서 탁 x2", "2층"])
	for i in Messages.KEEP + 5:
		log.add([[str(i), Palette.TEXT]], 3)
	assert_eq(log.lines.size(), Messages.KEEP)


func test_lanterns_doors_and_fire_are_told() -> void:
	var w := _world()
	w.tiles[Grid.index(SEEN)] = World.LANTERN
	var out := {t = &"smash", at = SEEN, was = World.LANTERN, left = World.LANTERN_OUT}
	assert_eq(_lines(w, [out]), ["등불이 꺼졌다"] as Array[String])
	out.left = World.LANTERN_BROKEN
	assert_eq(_lines(w, [out]), ["등불이 부서졌다"] as Array[String], "an orb breaks it outright")
	assert_eq(_lines(w, [{t = &"douse", at = SEEN}]), ["등불이 꺼졌다"] as Array[String])
	var broken := {t = &"smash", at = SEEN, was = World.LANTERN_OUT}
	assert_eq(_lines(w, [broken]), ["꺼진 등불이 부서졌다"] as Array[String])
	var crack := {t = &"smash", at = SEEN, was = World.WALL}
	assert_eq(_lines(w, [crack]), ["벽에 금이 갔다"] as Array[String])
	var fall := {t = &"smash", at = SEEN, was = World.WALL_CRACKED}
	assert_eq(_lines(w, [fall]), ["금 간 벽이 무너졌다"] as Array[String])
	w.tiles[Grid.index(SEEN)] = World.DOOR
	var door := {t = &"smash", at = SEEN, was = World.DOOR}
	assert_eq(_lines(w, [door]), ["문이 부서졌다"] as Array[String])
	assert_eq(_lines(w, [{t = &"douse", at = SEEN}]), ["문의 불이 꺼졌다"] as Array[String])
	assert_eq(_lines(w, [{t = &"relight", at = SEEN}]), ["등불이 다시 켜졌다"] as Array[String])
	assert_eq(_lines(w, [{t = &"burnout", at = SEEN}]), ["문이 재가 되었다"] as Array[String])
	var me := w.player()
	var burn := [
		{t = &"burn", at = me.pos, id = me.id},
		{t = &"hurt", id = me.id, n = 1, hp = 2, at = me.pos},
	]
	assert_eq(_lines(w, burn), ["불에 타 피해를 1 입었다"] as Array[String])


func test_harm_from_miho_spells_is_told_as_dealt_and_harm_to_her_as_taken() -> void:
	var w := _world()
	var foe := FloorGen.spawn(w, &"dokkaebi", SEEN)
	var me := w.player()
	w.sense()
	var mine := [
		{t = &"spawn", shot = 90, at = me.pos, faction = Actor.FOX, cards = [Cards.ORB]},
		{t = &"hit", shot = 90, id = foe.id, at = SEEN},
		{t = &"hurt", id = foe.id, n = 2, hp = 0, at = SEEN},
	]
	assert_eq(_lines(w, mine), ["도깨비에게 피해를 2 주었다"] as Array[String])
	var theirs := [
		{t = &"spawn", shot = 91, at = SEEN, faction = Actor.HEAVEN, cards = [Cards.ORB]},
		{t = &"hit", shot = 91, id = me.id, at = me.pos},
		{t = &"hurt", id = me.id, n = 1, hp = 2, at = me.pos},
	]
	assert_eq(_lines(w, theirs), ["피해를 1 입었다"] as Array[String])


func test_names_harm_and_sounds_stand_out_in_their_colours() -> void:
	var w := _world()
	var foe := FloorGen.spawn(w, &"dokkaebi", SEEN)
	w.sense()
	var line: Array = Messages.of(w, w, [{t = &"die", id = foe.id, at = SEEN}])[0]
	assert_eq(line[0], ["도깨비", Palette.KIND[&"dokkaebi"]])
	var heard: Array = (
		Messages.of(w, w, [{t = &"noise", at = HIDDEN, word = "끽", loud = 9, heard = true}])[0]
	)
	assert_true(heard.has(["끽", Palette.SOUND]), "%s" % [heard])


func test_healing_tells_its_source() -> void:
	var w := _world()
	var me := w.player()
	var heal := {t = &"heal", id = me.id, hp = 3}
	assert_eq(_lines(w, [heal]), ["복숭아를 먹었다. 체력을 1 회복했다"] as Array[String])
	var grew := {t = &"heal", id = me.id, hp = 4, grew = true}
	assert_eq(_lines(w, [grew]), ["복숭아를 먹었다. 최대 체력이 1 늘었다"] as Array[String])
	assert_eq(
		_lines(w, [{t = &"ascend", depth = 2}, heal]), ["2층으로 올라갔다", "체력을 1 회복했다"] as Array[String]
	)


func test_a_weakness_hit_starts_with_a_warning() -> void:
	var w := _world()
	var foe := FloorGen.spawn(w, &"cheonha", SEEN)
	var me := w.player()
	w.sense()
	var hit := [
		{t = &"spawn", shot = 90, at = me.pos, faction = Actor.FOX, cards = [Cards.ORB]},
		{t = &"hit", shot = 90, id = foe.id, at = SEEN},
	]
	var weak := hit + [{t = &"hurt", id = foe.id, n = 2, hp = 2, at = SEEN, weak = true}]
	assert_eq(_lines(w, weak), ["천하대장군에게 피해를 2 주었다"] as Array[String])
	var plain := hit + [{t = &"hurt", id = foe.id, n = 1, hp = 3, at = SEEN, weak = false}]
	assert_eq(_lines(w, plain), ["천하대장군에게 피해를 1 주었다"] as Array[String])


func test_a_melee_blow_names_the_weapon_of_the_creature() -> void:
	var w := _world()
	var told := {
		&"dokkaebi": "도깨비의 방망이에 맞아 피해를 1 입었다",
		&"bulgae": "불개의 이빨에 물려 피해를 1 입었다",
		&"bulgasari": "불가사리의 쇠톱 같은 이빨에 물려 피해를 1 입었다",
		&"saja": "저승사자의 오랏줄에 맞아 피해를 1 입었다",
	}
	for kind: StringName in told:
		var foe := FloorGen.spawn(w, kind, SEEN)
		w.sense()
		var blow := {t = &"melee", id = foe.id, target = w.player().id, at = w.player().pos, n = 1}
		assert_eq(_lines(w, [blow]), [told[kind]] as Array[String], str(kind))
		w.actors.erase(foe)


func test_a_starfish_that_grows_says_what_it_ate() -> void:
	var w := _world()
	var foe := FloorGen.spawn(w, &"bulgasari", SEEN)
	w.sense()
	var grow := {t = &"grow", id = foe.id, hp = 4, max_hp = 4}
	assert_eq(_lines(w, [grow]), ["불가사리가 쇠를 먹고 커졌다"] as Array[String])


func test_a_new_tail_is_told_and_losing_one_is_not() -> void:
	var w := _world()
	var before := w.clone()
	w.tail_bonus += 1
	var grown := "꼬리가 %d개로 늘었다" % w.max_tails()
	assert_eq(Messages.of(before, w, []).map(Messages.plain), [grown])
	assert_eq(Messages.of(w, before, []), [])
