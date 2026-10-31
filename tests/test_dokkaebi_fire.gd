extends GutTest
## 도깨비불, named so wherever it is told: the plain dokkaebi's is a lone wisp
## with no element and no harm, 부지깽이 도깨비's foxfire with fire.

const WAIT := {t = &"wait"}
const ME := Vector2i(4, 8)
const FOE := Vector2i(6, 8)
const WEST := Vector2i(-1, 0)


## An open hall, Miho at ME.
func _world() -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	for y in range(1, Grid.H - 1):
		for x in range(1, Grid.W - 1):
			w.tiles[Grid.index(Vector2i(x, y))] = World.FLOOR
	w.rooms.assign([Rect2i(1, 1, Grid.W - 2, Grid.H - 2)])
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.hp = 3
	me.max_hp = 3
	me.pos = ME
	w.actors.append(me)
	w.depth = 4
	w.sense()
	return w


func _foe(w: World, kind: StringName) -> Actor:
	var a := FloorGen.spawn(w, kind, FOE)
	a.cooldown = 99
	w.sense()
	return a


func test_the_plain_dokkaebi_casts_a_lone_wisp_with_no_element() -> void:
	assert_eq(Bestiary.info(&"dokkaebi").casts, [[Cards.FOX]])
	assert_eq(Bestiary.elements(&"dokkaebi"), [] as Array[StringName])
	assert_eq(Bestiary.weak_to(&"dokkaebi"), [] as Array[StringName])


func test_the_plain_dokkaebi_s_wisp_sticks_to_miho_and_does_no_harm() -> void:
	var w := _world()
	var foe := _foe(w, &"dokkaebi")
	w.cast(foe, Bestiary.spell(foe.kind, foe.info().casts[0]), WEST)
	var events := w.act(WAIT)
	assert_true(events.any(func(e): return e.t == &"stick" and e.id == w.player().id))
	assert_false(events.any(func(e): return e.t in [&"ignite", &"hurt"]))
	assert_eq(w.player().hp, 3)


func test_the_poker_dokkaebi_casts_foxfire_with_fire_and_comes_deeper() -> void:
	assert_eq(Bestiary.info(&"bujigaengi").casts, [[Cards.FOX, Cards.FIRE]])
	assert_eq(Bestiary.elements(&"bujigaengi"), [Cards.FIRE] as Array[StringName])
	assert_eq(Bestiary.weak_to(&"bujigaengi"), [Cards.WATER] as Array[StringName])
	var first := {}
	for tier in range(9, 0, -1):
		for kind in FloorGen.PLAN[tier]:
			first[kind] = tier
	assert_gt(first[&"bujigaengi"], first[&"dokkaebi"])


func test_its_wisp_sets_miho_alight_where_it_strikes() -> void:
	var w := _world()
	var foe := _foe(w, &"bujigaengi")
	w.cast(foe, Bestiary.spell(foe.kind, foe.info().casts[0]), WEST)
	var events := w.act(WAIT)
	assert_true(
		events.any(func(e): return e.t == &"ignite" and e.at == ME), "the tile under Miho burns"
	)
	assert_true(
		events.any(func(e): return e.t == &"hurt" and e.at == ME and e.n == 1),
		"the wisp hits for 1"
	)
	assert_true(w.burning.has(ME), "and the fire stays")


func test_its_wisp_leaves_bare_floor_unburnt_while_it_flies_and_hovers() -> void:
	var w := _world()
	var foe := _foe(w, &"bujigaengi")
	for y in range(1, Grid.H - 1):
		w.tiles[Grid.index(Vector2i(5, y))] = World.WALL
	w.cast(foe, Bestiary.spell(foe.kind, foe.info().casts[0]), WEST)
	for i in 6:
		w.act(WAIT)
	assert_true(w.burning.is_empty())
	assert_eq(w.player().hp, 3)


func test_hover_names_the_spell_its_element_harm_and_the_weakness() -> void:
	var w := _world()
	var poker := Info.plain(Info.creature(w, _foe(w, &"bujigaengi")))
	assert_string_contains(poker, "주술: 도깨비불 (")
	assert_false(poker.contains("여우불"))
	assert_string_contains(poker, "원소 불")
	assert_string_contains(poker, "피해 1")
	assert_string_contains(poker, "약점: 물 (피해 ×2)")
	var other := _world()
	var plain := Info.plain(Info.creature(other, _foe(other, &"dokkaebi")))
	assert_string_contains(plain, "주술: 도깨비불 (")
	assert_string_contains(plain, "피해 없음")
	assert_false(plain.contains("원소"))
	assert_false(plain.contains("약점"))


func test_the_charge_line_and_the_projectile_hover_name_it() -> void:
	for kind in [&"dokkaebi", &"bujigaengi"]:
		var w := _world()
		var foe := _foe(w, kind)
		var cards: Array = foe.info().casts[0]
		var charge := {t = &"charge", id = foe.id, cards = cards, dir = WEST}
		var line := "%s가 도깨비불을 모으고 있다" % foe.info().name
		assert_eq(Messages.of(w, w, [charge]).map(Messages.plain), [line])
		w.cast(foe, Bestiary.spell(foe.kind, cards), WEST)
		var text := Info.plain(SpellInfo.shot(w, w.shots[0]))
		assert_string_contains(text, "적의 도깨비불")
		assert_eq(text.contains("원소 불"), kind == &"bujigaengi", kind)
		assert_string_contains(text, "피해 %d" % (1 if kind == &"bujigaengi" else 0))


func test_mihos_own_fox_and_fire_keeps_its_title() -> void:
	var own := Spell.make([Cards.FOX, Cards.FIRE])
	assert_eq(own.title(), "불 여우불")
	var w := _world()
	var foe := _foe(w, &"bulgae")
	var charge := {t = &"charge", id = foe.id, cards = [Cards.FOX, Cards.FIRE], dir = WEST}
	assert_eq(Messages.of(w, w, [charge]).map(Messages.plain), ["불개가 불 여우불을 모으고 있다"])
	w.cast(foe, Bestiary.spell(foe.kind, foe.info().casts[0]), WEST)
	assert_string_contains(Info.plain(SpellInfo.shot(w, w.shots[0])), "적의 불 여우불")
	w.cast(w.player(), own, Vector2i(1, 0))
	assert_string_contains(Info.plain(SpellInfo.shot(w, w.shots[1])), "당신의 불 여우불")
