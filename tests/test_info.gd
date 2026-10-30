extends GutTest
## What hovering tells about terrain, talismans and spells.


func test_breakable_terrain_shows_its_health_as_hearts() -> void:
	assert_eq(Info.hearts(2, 3), "♥♥♡")
	var w := World.create(7)
	var lantern := Vector2i(-1, -1)
	for i in w.tiles.size():
		if w.tiles[i] == World.LANTERN:
			lantern = Grid.at(i)
			w.known[i] = 1
			break
	var text := Info.plain(Info.terrain(w, lantern))
	assert_true(text.begins_with("등불 ♥"), text)
	w.tiles[Grid.index(lantern)] = World.LANTERN_OUT
	text = Info.plain(Info.terrain(w, lantern))
	assert_true(text.begins_with("꺼진 등불 ♥"), text)
	w.tiles[Grid.index(lantern)] = World.LANTERN_BROKEN
	text = Info.plain(Info.terrain(w, lantern))
	assert_true(text.begins_with("부서진 등불"), text)
	assert_false(text.contains("♥"), text)


func test_walls_show_their_health_but_the_outer_edge_shows_none() -> void:
	var w := World.create(7)
	var inner := Vector2i(5, 5)
	w.tiles[Grid.index(inner)] = World.WALL
	assert_eq(Info.plain(Info.terrain(w, inner)), "벽 ♥♥")
	w.tiles[Grid.index(inner)] = World.WALL_CRACKED
	assert_eq(Info.plain(Info.terrain(w, inner)), "금 간 벽 ♥")
	w.tiles[Grid.index(inner)] = World.RUBBLE
	assert_true(Info.plain(Info.terrain(w, inner)).begins_with("무너진 벽\n"))
	assert_eq(Info.plain(Info.terrain(w, Vector2i(0, 0))), "벽")


func test_spells_of_the_same_talismans_but_another_form_read_differently() -> void:
	var fire_orb := Info.plain(Info.spell(Spell.make([Cards.ORB, Cards.FIRE])))
	var homing := Info.plain(Info.spell(Spell.make([Cards.FOX, Cards.ORB, Cards.FIRE])))
	assert_string_contains(fire_orb, "꼬리 2개")
	assert_string_contains(fire_orb, "주위 8칸")
	assert_string_contains(homing, "꼬리 3개")
	assert_string_contains(homing, "가장 가까운 적")
	assert_false(fire_orb.contains("가장 가까운 적"))


func test_a_talisman_tells_what_it_adds() -> void:
	var text := Info.plain(Info.card(Cards.ORB))
	assert_true(text.begins_with("구슬 부적"), text)
	assert_string_contains(text, "피해 1, 4칸 넘게 날면 2")


func test_a_creature_tells_its_element() -> void:
	var w := World.create(7)
	var foe := FloorGen.spawn(w, &"haetae", w.player().pos + Vector2i(1, 0))
	var text := Info.plain(Info.creature(w, foe))
	assert_string_contains(text, "오행 수(물)")
	assert_string_contains(text, "불 면역")
