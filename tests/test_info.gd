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
	assert_eq(Info.plain(Info.terrain(w, Vector2i(0, 0))), "벽\n부술 수 없다.")


func test_spells_of_the_same_talismans_but_another_form_read_differently() -> void:
	var fire_orb := Info.plain(SpellInfo.spell(Spell.make([Cards.ORB, Cards.FIRE])))
	var homing := Info.plain(SpellInfo.spell(Spell.make([Cards.FOX, Cards.ORB, Cards.FIRE])))
	assert_string_contains(fire_orb, "꼬리: 2")
	assert_string_contains(fire_orb, "폭발: 주위 8칸, 피해 2")
	assert_string_contains(homing, "꼬리: 3")
	assert_string_contains(homing, "모양: 유도 구슬\n대상: 가장 가까운 적")
	assert_string_contains(homing, "회전: 칸당 45°")
	assert_false(fire_orb.contains("가장 가까운 적"))


func test_a_spell_tells_every_number() -> void:
	var text := Info.plain(
		SpellInfo.spell(Spell.make([Cards.FOX, Cards.FOX, Cards.WOOD, Cards.WOOD]))
	)
	for part in [
		"꼬리: 5",
		"모양: 여우불 2발",
		"발당 피해: 1",
		"회전: 칸당 60°",
		"사거리: 7칸",
		"지속 시간: 8초",
		"속도: 초당 3칸",
		"묶임: 3초",
		"빛: 3칸",
		"소음: 2",
	]:
		assert_string_contains(text, part)
	text = Info.plain(SpellInfo.spell(Spell.make([Cards.ORB, Cards.ORB, Cards.WATER])))
	assert_string_contains(text, "피해: 2\n4칸 이상 날아간 뒤 피해: 3")
	assert_string_contains(text, "빛: 없음")
	assert_string_contains(text, "소음: 없음")


func test_a_talisman_tells_what_it_does_and_what_the_queue_becomes() -> void:
	var text := Info.plain(SpellInfo.card(Cards.ORB, Spell.make([Cards.FOX, Cards.ORB])))
	assert_true(text.begins_with("구슬 부적 · 꼬리: 1"), text)
	assert_string_contains(text, "피해: 1\n4칸 이상 날아간 뒤 피해: 2")
	assert_string_contains(text, "넣으면: 유도 구슬 · 꼬리: 2")


func test_a_queue_slot_tells_its_talisman_and_the_whole_spell() -> void:
	var s := Spell.make([Cards.FOX, Cards.FIRE, Cards.WATER])
	var text := Info.plain(SpellInfo.slot(s, 1))
	assert_true(text.begins_with("증기 · 꼬리: 2 · 물+불"), text)
	assert_string_contains(text, "꼬리: 3")


func test_a_lone_talisman_s_slot_heads_its_hover_once() -> void:
	var lines := SpellInfo.slot(Spell.make([Cards.FOX]), 0).map(Messages.plain)
	assert_eq(lines.filter(func(l): return l.contains("꼬리")).size(), 1, "\n".join(lines))


func test_a_homing_shot_in_flight_tells_whom_it_chases_and_how_it_turns() -> void:
	var w := World.create(7)
	var foe := FloorGen.spawn(w, &"haetae", w.player().pos + Vector2i(3, 0))
	var s := Shot.new()
	s.spell = Spell.make([Cards.FOX, Cards.FOX, Cards.ORB])
	s.pos = w.player().pos + Vector2i(1, 0)
	s.origin = w.player().pos
	s.dir = Vector2i(1, 0)
	s.target = foe.id
	s.turn = s.spell.turn()
	s.life = 4
	var text := Info.plain(SpellInfo.shot(w, s))
	for part in ["미호의 유도 구슬", "피해: 1", "대상: 해태", "회전: 90°", "초당 2칸", "남은 시간: 4초"]:
		assert_string_contains(text, part)


func test_a_creature_tells_its_element() -> void:
	var w := World.create(7)
	var foe := FloorGen.spawn(w, &"haetae", w.player().pos + Vector2i(1, 0))
	var text := Info.plain(Info.creature(w, foe))
	assert_string_contains(text, "오행: 수(물)")
	assert_string_contains(text, "면역: 불 주문, 불타는 칸")


func test_a_creature_tells_the_talisman_it_drops_until_miho_has_it() -> void:
	var w := World.create(7)
	var dog := FloorGen.spawn(w, &"bulgae", w.player().pos + Vector2i(2, 0))
	assert_string_contains(Info.plain(Info.creature(w, dog)), "소지품: 불 부적")
	w.cards.append(Cards.FIRE)
	assert_false(Info.plain(Info.creature(w, dog)).contains("소지품:"))


func test_a_creature_tells_what_it_is_weak_to() -> void:
	var w := World.create(7)
	var at := w.player().pos + Vector2i(1, 0)
	var text := Info.plain(Info.creature(w, FloorGen.spawn(w, &"jiha", at)))
	assert_string_contains(text, "오행: 금(쇠) \n약점: 불\n")
	var dog := Info.plain(Info.creature(w, FloorGen.spawn(w, &"haetae", at)))
	assert_string_contains(dog, "약점: 흙\n")
	var boss := Info.plain(Info.creature(w, FloorGen.spawn(w, &"cheonnyeon", at)))
	assert_string_contains(boss, "약점: 불, 물, 흙\n")
	assert_has(Info.glossary()["약점"], "피해: ×2", "the doubling is told once")
	var plain := Info.plain(Info.creature(w, FloorGen.spawn(w, &"jangseung", at)))
	assert_false(plain.contains("약점"), "a creature without an element has no weakness")


func test_a_wood_creature_is_told_to_burn() -> void:
	var w := World.create(7)
	var at := w.player().pos + Vector2i(1, 0)
	var wood := Info.plain(Info.creature(w, FloorGen.spawn(w, &"cheonha", at)))
	assert_string_contains(wood, "약점: 쇠\n")
	assert_string_contains(wood, "불에 탐")
	var water := Info.plain(Info.creature(w, FloorGen.spawn(w, &"haetae", at)))
	assert_false(water.contains("불에 탐"))


func test_a_creature_tells_what_it_strikes_with() -> void:
	var w := World.create(7)
	var at := w.player().pos + Vector2i(1, 0)
	var told := {
		&"dokkaebi": "근접: 방망이\n  피해: 1",
		&"bulgae": "근접: 이빨\n  피해: 1",
		&"bulgasari": "근접: 이빨\n  피해: 1",
		&"saja": "근접: 오랏줄\n  피해: 1",
	}
	for kind: StringName in told:
		assert_string_contains(
			Info.plain(Info.creature(w, FloorGen.spawn(w, kind, at))), told[kind]
		)
	var none := Info.plain(Info.creature(w, FloorGen.spawn(w, &"jiha", at)))
	assert_false(none.contains("근접"), "a caster that cannot strike has no melee line")


func test_the_starfish_tells_it_grows_on_metal() -> void:
	var w := World.create(7)
	var foe := FloorGen.spawn(w, &"bulgasari", w.player().pos + Vector2i(1, 0))
	var text := Info.plain(Info.creature(w, foe))
	var growth := [Bestiary.GROWTH, Bestiary.GROWTH]
	assert_string_contains(text, "먹이: 쇠 주문\n  최대 체력: +%d\n  체력: +%d" % growth)
	var other := Info.plain(Info.creature(w, FloorGen.spawn(w, &"haetae", foe.pos)))
	assert_false(other.contains("먹이"))


func test_every_immunity_is_its_own_line() -> void:
	var w := World.create(7)
	var at := w.player().pos + Vector2i(1, 0)
	var told := {
		&"bulgae": ["면역: 불 주문, 불타는 칸"],
		&"bulgasari": ["면역: 불 없는 주문"],
		&"jangseung": ["면역: 소음"],
		&"dokkaebi": [],
	}
	for kind: StringName in told:
		var lines := Info.plain(Info.creature(w, FloorGen.spawn(w, kind, at))).split("\n")
		var got := Array(lines).filter(func(l): return l.begins_with("면역"))
		assert_eq(got, told[kind], str(kind))
		assert_eq("\n".join(lines).contains("고정"), kind == &"jangseung", str(kind))


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
	assert_string_contains(Info.plain(Info.creature(w, foe)), "약점: 나무 (불과 함께)")


func _hall() -> World:
	var w := World.create(7)
	w.sense()
	return w


func _seen_tile(w: World, t: int) -> Vector2i:
	var p := w.player().pos + Vector2i(1, 0)
	w.set_tile(p, t)
	w.sense()
	return p


func test_a_burning_tile_tells_time_left_harm_light_and_noise() -> void:
	var w := _hall()
	var p := _seen_tile(w, World.BOARD)
	w.burning[p] = 2
	w.sense()
	var text := Info.plain(Info.terrain(w, p))
	assert_string_contains(text, "불타는 중: 2초 남음")
	assert_string_contains(text, "초당 피해: %d" % World.FIRE_DAMAGE)
	assert_string_contains(text, "빛: %d칸\n소음: %d" % [Light.FIRE_RADIUS, World.CRACKLE])


func test_a_remembered_tile_does_not_tell_whether_it_burns_now() -> void:
	var w := _hall()
	var p := _seen_tile(w, World.BOARD)
	w.burning[p] = 2
	w.seen[Grid.index(p)] = 0
	var text := Info.plain(Info.terrain(w, p))
	assert_false(text.contains("불타는 중"), text)
	assert_string_contains(text, "보이지 않음.")


func test_terrain_tells_its_light_noise_and_burn_time_from_the_rules() -> void:
	var w := _hall()
	var told := {
		World.LANTERN: ["빛: %d칸" % Light.LANTERN_RADIUS, "부딪칠 때 소음: %d" % World.KNOCK],
		World.BAMBOO: ["발소리: %d칸" % Tiles.of(World.BAMBOO, "tread")[0], "\n가연성.", "냄새가 남지 않음."],
		World.BOARD: ["발소리: %d칸" % Tiles.of(World.BOARD, "tread")[0], "\n가연성."],
		World.GRASS: ["가연성.\n번질 확률: %d%%" % roundi(Tiles.of(World.GRASS, "spread") * 100)],
		World.DOOR: ["\n가연성."],
		World.BRIDGE: ["발소리: %d칸" % Tiles.of(World.BRIDGE, "tread")[0], "불에 타지 않음."],
		World.WINDOW: ["부딪칠 때 소음: %d" % World.KNOCK],
		World.WALL: ["부서짐: 구슬\n부서질 때 소음: %d" % World.THUD],
	}
	for t: int in told:
		var p := _seen_tile(w, t)
		w.tiles[Grid.index(p)] = t
		var text := Info.plain(Info.terrain(w, p))
		for part: String in told[t]:
			assert_string_contains(text, part)
	var ash := _seen_tile(w, World.ASH)
	assert_false(Info.plain(Info.terrain(w, ash)).contains("가연성"), "ash does not burn again")
	var wall := Info.plain(Info.terrain(w, _seen_tile(w, World.WALL)))
	assert_false(wall.contains("한 번에"), "the spell tells what breaks a wall at once")
	var glossary := "\n".join(Info.glossary()["가연성"])
	assert_string_contains(glossary, "불타는 시간: %d초\n불탄 뒤: 재" % World.BURN_ROUNDS)
	assert_string_contains(
		glossary, "번지는 속도: 초당 1칸\n번질 확률: %d%%" % roundi(Tiles.DEFAULT.spread * 100)
	)
	var fierce := "\n".join(Info.glossary()["인화성"])
	assert_string_contains(fierce, "번지는 속도: 초당 2칸\n초당 피해: %d" % World.FIERCE_DAMAGE)


func test_stairs_and_peaches_tell_the_health_they_give() -> void:
	var w := _hall()
	var p := _seen_tile(w, World.FLOOR)
	w.stairs = p
	assert_string_contains(Info.plain(Info.terrain(w, p)), "체력: +%d" % World.HEAL)
	w.stairs = Vector2i(-1, -1)
	w.peaches.append(p)
	assert_string_contains(Info.plain(Info.terrain(w, p)), "최대 체력: +%d" % World.HEAL)


func test_a_dark_tile_tells_how_far_heaven_sees_in_the_dark() -> void:
	var w := _hall()
	for i in w.tiles.size():
		if w.tiles[i] == World.LANTERN:
			w.tiles[i] = World.LANTERN_OUT
	var p := w.player().pos + Vector2i(2, 0)
	w.tiles[Grid.index(p)] = World.FLOOR
	w.sense()
	w.seen[Grid.index(p)] = 1
	var reach: int = World.NIGHT[Actor.HEAVEN]
	assert_string_contains(Info.plain(Info.terrain(w, p)), "어두움: %d칸 안에서만" % reach)


func test_a_creature_tells_its_conditions_with_seconds_left() -> void:
	var w := _hall()
	var foe := FloorGen.spawn(w, &"dokkaebi", w.player().pos + Vector2i(1, 0))
	foe.blind = 2
	foe.rooted = 3
	foe.stunned = 1
	foe.wary = 7
	var text := Info.plain(Info.creature(w, foe))
	for part in ["눈멂: 2초", "묶임: 3초", "기절: 1초", "경계: 7초"]:
		assert_string_contains(text, part)
	assert_false(text.contains("시야"), "the hover does not tell a creature's sight")


func test_a_creature_in_fire_tells_the_harm_unless_it_eats_fire() -> void:
	var w := _hall()
	var at := w.player().pos + Vector2i(1, 0)
	w.set_tile(at, World.BOARD)
	w.burning[at] = 3
	var foe := FloorGen.spawn(w, &"dokkaebi", at)
	assert_string_contains(
		Info.plain(Info.creature(w, foe)), "불타는 칸 위: 3초\n  초당 피해: %d" % World.FIRE_DAMAGE
	)
	var dog := FloorGen.spawn(w, &"bulgae", at)
	assert_false(Info.plain(Info.creature(w, dog)).contains("불타는 칸 위"))


func test_a_creature_tells_the_harm_and_noise_of_what_it_casts() -> void:
	var w := _hall()
	var at := w.player().pos + Vector2i(1, 0)
	var orb := Info.plain(Info.creature(w, FloorGen.spawn(w, &"jangseung", at)))
	var cast := Spell.make(Bestiary.casts(&"jangseung", 1)[0])
	assert_string_contains(
		orb,
		(
			"피해: %d\n  %d칸 이상 날아간 뒤 피해: %d"
			% [cast.damage(0), Spell.MOMENTUM, cast.damage(Spell.MOMENTUM)]
		)
	)
	var orb_spell := Spell.make([Cards.ORB])
	var noise := [orb_spell.cast_noise(), orb_spell.burst_noise()]
	assert_string_contains(orb, "소음: %d\n  충돌 소음: %d" % noise)
	var boss := Info.plain(Info.creature(w, FloorGen.spawn(w, &"cheonnyeon", at)))
	var molten: Dictionary = Compounds.HOT[Compounds.MOLTEN]
	assert_string_contains(boss, "  %s: %d초" % [molten.name, Compounds.HOT_ROUNDS])
	var water := Info.plain(Info.creature(w, FloorGen.spawn(w, &"haetae", at)))
	assert_string_contains(water, "소음: 없음")


func test_miho_tells_her_claws_and_conditions() -> void:
	var w := _hall()
	var me := w.player()
	me.blind = 2
	me.rooted = 1
	var text := Info.plain(Info.creature(w, me))
	assert_string_contains(text, "발톱 피해: %d\n기습 피해: %d" % [World.CLAW, World.CLAW * World.SNEAK])
	assert_false(text.contains("시야"))
	assert_false(text.contains("발소리"), "footsteps are told on each tile")
	assert_string_contains(text, "눈멂: 2초")
	assert_string_contains(text, "묶임: 1초")


func test_a_searching_creature_tells_how_many_more_looks_before_it_rests() -> void:
	var w := _hall()
	var foe := FloorGen.spawn(w, &"jangseung", w.player().pos + Vector2i(3, 0))
	foe.alert = Actor.SEARCH
	foe.target = foe.pos
	foe.lost = 4
	foe.cooldown = 99
	var left := World.SEARCH_ROUNDS + 1 - foe.lost
	assert_string_contains(Info.plain(Info.creature(w, foe)), "수색: %d번 더" % left)
	for i in left - 1:
		Mind.search(w, foe)
	assert_eq(foe.alert, Actor.SEARCH, "still searching after one look fewer")
	Mind.search(w, foe)
	assert_eq(foe.alert, Actor.REST, "rests after the told number of looks")


func test_a_wary_searching_creature_tells_it_rests_when_no_longer_wary() -> void:
	var w := _hall()
	var foe := FloorGen.spawn(w, &"jangseung", w.player().pos + Vector2i(3, 0))
	foe.alert = Actor.SEARCH
	foe.target = foe.pos
	foe.lost = World.SEARCH_ROUNDS + 3
	foe.wary = 2
	foe.cooldown = 99
	assert_string_contains(Info.plain(Info.creature(w, foe)), "수색: 경계가 끝날 때까지")
	Mind.search(w, foe)
	assert_eq(foe.alert, Actor.SEARCH, "wary: keeps looking")
	foe.wary = 0
	Mind.search(w, foe)
	assert_eq(foe.alert, Actor.REST, "rests at the first look once no longer wary")


func test_sky_and_ponds_tell_that_spells_and_leaps_cross_them() -> void:
	var w := World.create(7)
	var p := Vector2i(5, 5)
	for t in [World.SKY, World.POND]:
		w.tiles[Grid.index(p)] = t
		var text := Info.plain(Info.terrain_facts(w, p))
		assert_string_contains(text, "주문과 멀리뛰기로만 건널 수 있다.")
	w.tiles[Grid.index(p)] = World.SKY
	var sky := Info.plain(Info.terrain_facts(w, p))
	assert_string_contains(sky, "추락한 적: 사라짐\n층당 추락 피해: 1")
