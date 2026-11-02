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
	assert_eq(Info.plain(Info.terrain(w, Vector2i(0, 0))), "벽")


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
	for part in ["당신의 유도 구슬", "피해: 1", "대상: 해태", "회전: 90°", "초당 2칸", "남은 시간: 4초"]:
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
	assert_has(Glossary.rows()["약점"], "피해: ×2", "the doubling is told once")
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
		&"dokkaebi": "근접: 방망이 · 피해: 1",
		&"bulgae": "근접: 이빨 · 피해: 1",
		&"bulgasari": "근접: 이빨 · 피해: 1",
		&"saja": "근접: 오랏줄 · 피해: 1",
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
		World.BRIDGE: ["발소리: %d칸" % Tiles.of(World.BRIDGE, "tread")[0]],
		World.WINDOW: ["부딪칠 때 소음: %d" % World.KNOCK],
		World.WALL: ["부서짐: 구슬, 밀침, 도약\n부서질 때 소음: %d" % World.THUD],
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
	var glossary := "\n".join(Glossary.rows()["가연성"])
	assert_string_contains(glossary, "불타는 시간: %d초\n불탄 뒤: 재" % World.BURN_ROUNDS)
	assert_string_contains(
		glossary, "번지는 속도: 초당 1칸\n번질 확률: %d%%" % roundi(Tiles.DEFAULT.spread * 100)
	)
	var fierce := "\n".join(Glossary.rows()["인화성"])
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
	foe.ailments.blind = 2
	foe.ailments.rooted = 3
	foe.ailments.stunned = 1
	foe.brain.wary = 7
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


func test_a_creature_tells_each_spell_on_one_row_with_its_harm_and_reach() -> void:
	var cast := Spell.make(Bestiary.casts(&"jangseung", 1)[0])
	var pole := Info.plain(Info.creature_facts(Codex.foe(&"jangseung"), []))
	var row := "주술: %s · 간격: " % Bestiary.spell(&"jangseung", cast.cards).shown()
	assert_string_contains(pole, row)
	assert_string_contains(pole, " · 피해: %d" % cast.damage(0))
	var jet := Info.plain(Info.creature_facts(Codex.foe(&"haetae", 4), [])).split("\n")
	var rows := Array(jet).filter(func(l: String): return l.begins_with("주술: 물줄기"))
	var jet_row: String = rows[0]
	assert_true(jet_row.contains(" · 범위: "), jet_row)
	assert_false(jet_row.contains("피해"), "a spell that harms nothing has no harm part")


func test_miho_tells_her_claws_and_conditions() -> void:
	var w := _hall()
	var me := w.player()
	me.ailments.blind = 2
	me.ailments.rooted = 1
	var text := Info.plain(Info.creature(w, me))
	assert_string_contains(text, "발톱 피해: %d\n기습 피해: %d" % [World.CLAW, World.CLAW * World.SNEAK])
	assert_false(text.contains("시야"))
	assert_false(text.contains("발소리"), "footsteps are told on each tile")
	assert_string_contains(text, "눈멂: 2초")
	assert_string_contains(text, "묶임: 1초")


func test_a_searching_creature_tells_how_many_more_looks_before_it_rests() -> void:
	var w := _hall()
	var foe := FloorGen.spawn(w, &"jangseung", w.player().pos + Vector2i(3, 0))
	foe.brain.alert = Actor.SEARCH
	foe.brain.target = foe.pos
	foe.brain.lost = 4
	foe.magic.cooldown = 99
	var left := World.SEARCH_ROUNDS + 1 - foe.brain.lost
	assert_string_contains(Info.plain(Info.creature(w, foe)), "수색: %d번 더" % left)
	for i in left - 1:
		Mind.search(w, foe)
	assert_eq(foe.brain.alert, Actor.SEARCH, "still searching after one look fewer")
	Mind.search(w, foe)
	assert_eq(foe.brain.alert, Actor.REST, "rests after the told number of looks")


func test_a_wary_searching_creature_tells_it_rests_when_no_longer_wary() -> void:
	var w := _hall()
	var foe := FloorGen.spawn(w, &"jangseung", w.player().pos + Vector2i(3, 0))
	foe.brain.alert = Actor.SEARCH
	foe.brain.target = foe.pos
	foe.brain.lost = World.SEARCH_ROUNDS + 3
	foe.brain.wary = 2
	foe.magic.cooldown = 99
	assert_string_contains(Info.plain(Info.creature(w, foe)), "수색: 경계가 끝날 때까지")
	Mind.search(w, foe)
	assert_eq(foe.brain.alert, Actor.SEARCH, "wary: keeps looking")
	foe.brain.wary = 0
	Mind.search(w, foe)
	assert_eq(foe.brain.alert, Actor.REST, "rests at the first look once no longer wary")


func test_sky_and_deep_water_are_tagged_impassable_and_the_tag_tells_what_crosses_them() -> void:
	var w := World.create(7)
	var p := Vector2i(5, 5)
	for t in [World.SKY, World.POND]:
		w.tiles[Grid.index(p)] = t
		var text := Info.plain(Info.terrain_facts(w, p))
		assert_true(text.split("\n").has("이동 불가."), text)
	assert_has(Glossary.rows()["이동 불가"], "넘을 수 있음: 주문, 멀리뛰기")
	w.tiles[Grid.index(p)] = World.SKY
	var sky := Info.plain(Info.terrain_facts(w, p))
	assert_string_contains(sky, "사라짐: 추락한 적\n층당 추락 피해: 1")


func test_a_compound_hover_tells_its_elements_and_one_with_none_tells_nothing() -> void:
	var swamp := Info.plain(SpellInfo.combo(&"swamp"))
	assert_string_contains(swamp, "오행: 물+흙\n")
	for c in [&"hypnosis", &"thunder", Forge.FURNACE, &"beacon", Cards.VAULT]:
		assert_false(Info.plain(SpellInfo.combo(c)).contains("오행:"), c)


func test_the_hover_of_electricity_is_a_tag_and_the_glossary_tells_its_rows() -> void:
	var text := Info.plain(SpellInfo.combo(&"thunder"))
	assert_string_contains(text, "\n전기.\n")
	assert_false(text.contains("젖음"), "the glossary holds it")
	var rows: Array = Glossary.rows()[Info.ELECTRIC]
	assert_eq(rows.size(), Elements.CONDUCTS.size() + 1 + Elements.GROUNDS.size())
	assert_true(rows.any(func(r: String): return r.begins_with("젖음: ")))


func test_a_hunter_tells_that_it_hunts_apart_from_whether_it_sees_you() -> void:
	var w := World.create(7)
	var foe := FloorGen.spawn(w, &"dokkaebi", w.player().pos + Vector2i(1, 0))
	foe.brain.alert = Actor.HUNT
	var text := Info.plain(Info.creature(w, foe))
	assert_string_contains(text, "당신을 추격 중이다")
	assert_string_contains(text, "당신을 볼 수 있다")
	foe.faction = Actor.FOX
	assert_false(Info.plain(Info.creature(w, foe)).contains("당신을 추격"), "an ally hunts others")


func test_a_searcher_bound_for_your_tile_tells_so_and_not_how_many_looks_are_left() -> void:
	var w := World.create(7)
	var foe := FloorGen.spawn(w, &"dokkaebi", w.player().pos + Vector2i(1, 0))
	foe.brain.alert = Actor.SEARCH
	foe.brain.target = w.player().pos
	var text := Info.plain(Info.creature(w, foe))
	assert_string_contains(text, "당신에게 오는 중")
	assert_false(text.contains("소음"), "it may be after a spell it saw: %s" % text)
	assert_false(text.contains("수색"), text)


func test_a_hunter_fighting_a_rival_does_not_also_say_it_hunts_you() -> void:
	var w := World.create(7)
	var foe := FloorGen.spawn(w, &"dokkaebi", w.player().pos + Vector2i(1, 0))
	var rival := FloorGen.spawn(w, &"dokkaebi", w.player().pos + Vector2i(2, 0))
	foe.brain.alert = Actor.HUNT
	foe.ties.rival = rival.id
	foe.ties.grudge = 3
	var text := Info.plain(Info.creature(w, foe))
	assert_string_contains(text, "싸우는 중")
	assert_false(text.contains("추격"), text)


func test_a_searcher_elsewhere_is_only_searching() -> void:
	var w := World.create(7)
	var foe := FloorGen.spawn(w, &"dokkaebi", w.player().pos + Vector2i(1, 0))
	foe.brain.alert = Actor.SEARCH
	foe.brain.target = foe.pos
	var text := Info.plain(Info.creature(w, foe))
	assert_string_contains(text, "수색 중")
	assert_string_contains(text, "수색: ")


func test_a_tracker_on_your_trail_tells_so() -> void:
	var w := World.create(7)
	var kind := &""
	for k in Codex.foes():
		if (
			Bestiary.info(k).get("tracks", false)
			and Bestiary.info(k).get("move", &"static") != &"static"
		):
			kind = k
	assert_ne(kind, &"")
	var foe := FloorGen.spawn(w, kind, w.player().pos + Vector2i(1, 0))
	foe.brain.alert = Actor.SEARCH
	foe.brain.target = foe.pos
	w.scent.resize(w.tiles.size())
	w.round_no = 5
	var ahead := foe.pos + Vector2i(1, 0)
	w.tiles[Grid.index(ahead)] = World.FLOOR
	w.scent[Grid.index(ahead)] = 5
	assert_string_contains(Info.plain(Info.creature(w, foe)), "냄새를 쫓는 중")
