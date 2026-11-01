extends GutTest
## How a noticed change and a body mark read in the log, on hover and in the map text.

const ME := Vector2i(4, 8)
const AT := Vector2i(5, 8)


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
	me.pos = ME
	w.actors.append(me)
	w.sense()
	return w


func test_a_creature_that_heeds_a_change_is_named_in_the_log() -> void:
	var w := _world()
	var foe := FloorGen.spawn(w, &"dokkaebi", AT)
	var lines := Messages.of(w, w, [{t = &"heed", id = foe.id, at = AT, kind = &"body"}])
	assert_eq(Messages.plain(lines[0]), "도깨비가 시체를 보고 살피러 갔다")
	lines = Messages.of(w, w, [{t = &"heed", id = foe.id, at = AT, kind = &"ash"}])
	assert_eq(Messages.plain(lines[0]), "도깨비가 재를 보고 살피러 갔다")


func test_a_body_mark_tells_who_fell_and_that_the_seer_searches() -> void:
	var w := _world()
	var foe := FloorGen.spawn(w, &"dokkaebi", AT)
	w.hurt(foe, 99)
	w.sense()
	var text := Info.plain(Info.terrain(w, AT))
	assert_string_contains(text, "쓰러진 도깨비: 0초 전\n" + Info.TRACE)
	assert_has(Info.glossary()["흔적"], "수색하는 적: 추격 중이 아닌 적")


func test_a_body_not_yet_seen_is_not_told() -> void:
	var w := _world()
	w.changes.append({id = 0, kind = &"body", at = AT, round = 0})
	w.bodies[AT] = {kind = &"dokkaebi", round = 0, met = false}
	assert_false(Info.plain(Info.terrain(w, AT)).contains("쓰러진"))


func test_another_change_tells_its_age() -> void:
	var w := _world()
	Notice.record(w, &"ash", AT)
	w.round_no = 4
	var text := Info.plain(Info.terrain(w, AT))
	assert_string_contains(text, "재: 4초 전")


func test_the_map_text_marks_a_seen_body() -> void:
	var w := _world()
	var foe := FloorGen.spawn(w, &"dokkaebi", AT)
	w.hurt(foe, 99)
	w.sense()
	var rows := Array(Observation.text(w).split("\n"))
	var top := rows.find(rows.filter(func(r): return r.begins_with("map,"))[0])
	var row: String = rows[top + 2 + AT.y]
	assert_eq(row.unicode_at(3 + AT.x), Palette.BODY[0].unicode_at(0), row)
	assert_string_contains(Observation.LEGEND, "fallen-creature")
