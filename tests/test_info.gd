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
	assert_eq(Info.plain(Info.terrain(w, inner)).get_slice("\n", 0), "벽 ♥♥")
	w.tiles[Grid.index(inner)] = World.WALL_CRACKED
	assert_eq(Info.plain(Info.terrain(w, inner)).get_slice("\n", 0), "금 간 벽 ♥")
	w.tiles[Grid.index(inner)] = World.RUBBLE
	assert_true(Info.plain(Info.terrain(w, inner)).begins_with("무너진 벽\n"))
	w.tiles[0] = World.WALL
	assert_eq(Info.plain(Info.terrain(w, Vector2i(0, 0))), "벽\n부술 수 없다")


func test_spells_of_the_same_talismans_but_another_form_read_differently() -> void:
	var fire_orb := Info.plain(Info.spell(Spell.make([Cards.ORB, Cards.FIRE])))
	var homing := Info.plain(Info.spell(Spell.make([Cards.FOX, Cards.ORB, Cards.FIRE])))
	assert_string_contains(fire_orb, "꼬리 2개")
	assert_string_contains(fire_orb, "주위 8칸에 피해 2")
	assert_string_contains(homing, "꼬리 3개")
	assert_string_contains(homing, "가장 가까운 적")
	assert_false(fire_orb.contains("가장 가까운 적"))


func test_a_talisman_tells_what_it_adds() -> void:
	var text := Info.plain(Info.card(Cards.ORB))
	assert_true(text.begins_with("구슬 부적"), text)
	assert_string_contains(text, "피해 1, 4칸 이상 날면 2")


func test_a_creature_tells_its_element() -> void:
	var w := World.create(7)
	var foe := FloorGen.spawn(w, &"haetae", w.player().pos + Vector2i(1, 0))
	var text := Info.plain(Info.creature(w, foe))
	assert_string_contains(text, "오행 수(물)")
	assert_string_contains(text, "면역: 불 (불이 든 주문, 불타는 칸)")


func test_a_creature_tells_the_talisman_it_drops_until_miho_has_it() -> void:
	var w := World.create(7)
	var dog := FloorGen.spawn(w, &"bulgae", w.player().pos + Vector2i(2, 0))
	assert_string_contains(Info.plain(Info.creature(w, dog)), "처치 시 불 부적을 얻을 수 있다")
	w.cards.append(Cards.FIRE)
	assert_false(Info.plain(Info.creature(w, dog)).contains("처치 시"))


func test_a_creature_tells_what_it_is_weak_to() -> void:
	var w := World.create(7)
	var at := w.player().pos + Vector2i(1, 0)
	var text := Info.plain(Info.creature(w, FloorGen.spawn(w, &"jiha", at)))
	assert_string_contains(text, "오행 금(쇠) \n약점: 불 (피해 ×2)")
	var dog := Info.plain(Info.creature(w, FloorGen.spawn(w, &"haetae", at)))
	assert_string_contains(dog, "약점: 흙 (피해 ×2)")
	var boss := Info.plain(Info.creature(w, FloorGen.spawn(w, &"cheonnyeon", at)))
	assert_string_contains(boss, "약점: 불, 물, 흙 (피해 ×2)")
	var plain := Info.plain(Info.creature(w, FloorGen.spawn(w, &"dokkaebi", at)))
	assert_false(plain.contains("약점"), "a creature without an element has no weakness")


func test_a_wood_creature_is_told_to_burn() -> void:
	var w := World.create(7)
	var at := w.player().pos + Vector2i(1, 0)
	var wood := Info.plain(Info.creature(w, FloorGen.spawn(w, &"cheonha", at)))
	assert_string_contains(wood, "약점: 쇠 (피해 ×2)")
	assert_string_contains(wood, "불에 탐")
	var water := Info.plain(Info.creature(w, FloorGen.spawn(w, &"haetae", at)))
	assert_false(water.contains("불에 탐"))


func test_a_creature_tells_what_it_strikes_with() -> void:
	var w := World.create(7)
	var at := w.player().pos + Vector2i(1, 0)
	var told := {
		&"dokkaebi": "근접: 방망이 (피해 1)",
		&"bulgae": "근접: 이빨 (피해 1)",
		&"bulgasari": "근접: 쇠톱 같은 이빨 (피해 1)",
		&"saja": "근접: 오랏줄 (피해 1)",
	}
	for kind: StringName in told:
		assert_string_contains(
			Info.plain(Info.creature(w, FloorGen.spawn(w, kind, at))), told[kind]
		)
	var none := Info.plain(Info.creature(w, FloorGen.spawn(w, &"jangseung", at)))
	assert_false(none.contains("근접"), "a caster that cannot strike has no melee line")


func test_the_starfish_tells_it_grows_on_metal() -> void:
	var w := World.create(7)
	var foe := FloorGen.spawn(w, &"bulgasari", w.player().pos + Vector2i(1, 0))
	var text := Info.plain(Info.creature(w, foe))
	assert_string_contains(text, "쇠 주문을 먹으면 최대 체력 +%d, 체력 +%d" % [Bestiary.GROWTH, Bestiary.GROWTH])
	var other := Info.plain(Info.creature(w, FloorGen.spawn(w, &"haetae", foe.pos)))
	assert_false(other.contains("먹으면"))


func test_every_immunity_is_its_own_line() -> void:
	var w := World.create(7)
	var at := w.player().pos + Vector2i(1, 0)
	var told := {
		&"bulgae": ["면역: 불 (불이 든 주문, 불타는 칸)"],
		&"bulgasari": ["면역: 불이 없는 모든 주문"],
		&"jangseung": ["면역: 소리 (경보를 듣지 못한다)", "면역: 묶기 (움직이지 못한다)"],
		&"dokkaebi": [],
	}
	for kind: StringName in told:
		var lines := Info.plain(Info.creature(w, FloorGen.spawn(w, kind, at))).split("\n")
		var got := Array(lines).filter(func(l): return l.begins_with("면역"))
		assert_eq(got, told[kind], str(kind))


func test_the_old_trait_words_for_immunity_are_gone() -> void:
	var w := World.create(7)
	var at := w.player().pos + Vector2i(1, 0)
	for kind in [&"haetae", &"bulgasari", &"jiha"]:
		var text := Info.plain(Info.creature(w, FloorGen.spawn(w, kind, at)))
		for word in ["불 면역", "불로만 피해", "청각 없음", "이동 불가"]:
			assert_false(text.contains(word), "%s says %s" % [kind, word])


func test_a_starfish_weakness_holds_only_with_fire() -> void:
	var w := World.create(7)
	var foe := FloorGen.spawn(w, &"bulgasari", w.player().pos + Vector2i(1, 0))
	assert_string_contains(Info.plain(Info.creature(w, foe)), "약점: 나무 (피해 ×2, 불과 함께)")


func _hall() -> World:
	var w := World.create(7)
	w.sense()
	return w


func _seen_tile(w: World, t: int) -> Vector2i:
	var p := w.player().pos + Vector2i(1, 0)
	w.set_tile(p, t)
	w.sense()
	return p


func test_a_burning_tile_tells_time_left_harm_spread_light_and_noise() -> void:
	var w := _hall()
	var p := _seen_tile(w, World.BOARD)
	w.burning[p] = 2
	w.sense()
	var text := Info.plain(Info.terrain(w, p))
	assert_string_contains(text, "불타는 중. 2초 뒤 재가 된다")
	assert_string_contains(text, "서 있으면 매 초 피해 %d" % World.FIRE_DAMAGE)
	assert_string_contains(text, "초당 %d%% 번진다" % roundi(World.SPREAD * 100))
	assert_string_contains(text, "주위 %d칸을 밝힌다. 타닥 소리 %d칸" % [Light.FIRE_RADIUS, World.CRACKLE])


func test_a_remembered_tile_does_not_tell_whether_it_burns_now() -> void:
	var w := _hall()
	var p := _seen_tile(w, World.BOARD)
	w.burning[p] = 2
	w.seen[Grid.index(p)] = 0
	var text := Info.plain(Info.terrain(w, p))
	assert_false(text.contains("불타는 중"), text)
	assert_string_contains(text, "지금은 보이지 않는다")


func test_terrain_tells_its_light_noise_and_burn_time_from_the_rules() -> void:
	var w := _hall()
	var told := {
		World.LANTERN: ["주위 %d칸을 밝힌다" % Light.LANTERN_RADIUS, "쨍 소리 %d칸" % World.KNOCK],
		World.BAMBOO: ["사각 소리 %d칸" % World.TREAD[World.BAMBOO][0], "%d초 타고" % World.BURN_ROUNDS],
		World.BOARD: ["삐걱 소리 %d칸" % World.TREAD[World.BOARD][0], "%d초 타고" % World.BURN_ROUNDS],
		World.DOOR: ["%d초 타고" % World.BURN_ROUNDS],
		World.BRIDGE: ["삐걱 소리 %d칸" % World.TREAD[World.BRIDGE][0], "불에 타지 않는다"],
		World.WINDOW: ["쨍 소리 %d칸" % World.KNOCK],
		World.WALL: ["쿵 소리 %d칸" % World.THUD],
		World.ASH: ["다시 타지 않는다"],
	}
	for t: int in told:
		var p := _seen_tile(w, t)
		w.tiles[Grid.index(p)] = t
		var text := Info.plain(Info.terrain(w, p))
		for part: String in told[t]:
			assert_string_contains(text, part)


func test_stairs_and_peaches_tell_the_health_they_give() -> void:
	var w := _hall()
	var p := _seen_tile(w, World.FLOOR)
	w.stairs = p
	assert_string_contains(Info.plain(Info.terrain(w, p)), "체력 %d 회복" % World.HEAL)
	w.stairs = Vector2i(-1, -1)
	w.peaches.append(p)
	assert_string_contains(Info.plain(Info.terrain(w, p)), "최대 체력 +%d" % World.HEAL)


func test_a_dark_tile_tells_how_far_heaven_sees_in_the_dark() -> void:
	var w := _hall()
	for i in w.tiles.size():
		if w.tiles[i] == World.LANTERN:
			w.tiles[i] = World.LANTERN_OUT
	w.sense()
	var p := w.player().pos + Vector2i(2, 0)
	w.seen[Grid.index(p)] = 1
	var reach: int = World.NIGHT[Actor.HEAVEN]
	assert_string_contains(Info.plain(Info.terrain(w, p)), "어둡다. %d칸 안에서만" % reach)


func test_a_creature_tells_its_conditions_with_seconds_left() -> void:
	var w := _hall()
	var foe := FloorGen.spawn(w, &"dokkaebi", w.player().pos + Vector2i(1, 0))
	foe.blind = 2
	foe.rooted = 3
	foe.stunned = 1
	foe.wary = 7
	var text := Info.plain(Info.creature(w, foe))
	for part in ["눈이 멀었다 (2초)", "묶여 있다 (3초)", "기절했다 (1초)", "경계 중 (7초)"]:
		assert_string_contains(text, part)
	assert_string_contains(text, "어둠 속 시야 %d칸" % (World.NIGHT[Actor.HEAVEN] + 1))
	foe.wary = 0
	assert_string_contains(
		Info.plain(Info.creature(w, foe)), "어둠 속 시야 %d칸" % World.NIGHT[Actor.HEAVEN]
	)


func test_a_creature_in_fire_tells_the_harm_unless_it_eats_fire() -> void:
	var w := _hall()
	var at := w.player().pos + Vector2i(1, 0)
	w.burning[at] = 3
	var foe := FloorGen.spawn(w, &"dokkaebi", at)
	assert_string_contains(
		Info.plain(Info.creature(w, foe)), "불타는 칸 위 (3초). 매 초 피해 %d" % World.FIRE_DAMAGE
	)
	var dog := FloorGen.spawn(w, &"bulgae", at)
	assert_false(Info.plain(Info.creature(w, dog)).contains("불타는 칸 위"))


func test_a_creature_tells_the_harm_and_noise_of_what_it_casts() -> void:
	var w := _hall()
	var at := w.player().pos + Vector2i(1, 0)
	var orb := Info.plain(Info.creature(w, FloorGen.spawn(w, &"jangseung", at)))
	assert_string_contains(orb, "피해 1 (%d칸 이상 날면 2)" % Spell.MOMENTUM)
	var orb_spell := Spell.make([Cards.ORB])
	assert_string_contains(
		orb, "소리 %d칸, 터질 때 %d칸" % [orb_spell.cast_noise(), orb_spell.burst_noise()]
	)
	var boss := Info.plain(Info.creature(w, FloorGen.spawn(w, &"cheonnyeon", at)))
	assert_string_contains(boss, "터지면 주위 피해 %d" % World.FIRE_DAMAGE)
	var water := Info.plain(Info.creature(w, FloorGen.spawn(w, &"haetae", at)))
	assert_string_contains(water, "소리 없음")


func test_miho_tells_her_claws_sight_footsteps_and_conditions() -> void:
	var w := _hall()
	var me := w.player()
	me.blind = 2
	me.rooted = 1
	var text := Info.plain(Info.creature(w, me))
	assert_string_contains(text, "발톱: 피해 %d, 기습 시 %d" % [World.CLAW, World.CLAW * World.SNEAK])
	assert_string_contains(text, "어둠 속 시야 %d칸" % World.NIGHT[Actor.FOX])
	var steps := "발소리: 대숲 %d칸, 마루 %d칸, 하늘다리 %d칸"
	var loud := [World.BAMBOO, World.BOARD, World.BRIDGE].map(func(t): return World.TREAD[t][0])
	assert_string_contains(text, steps % loud)
	assert_string_contains(text, "눈이 멀었다 (2초)")
	assert_string_contains(text, "묶여 있다 (1초)")
