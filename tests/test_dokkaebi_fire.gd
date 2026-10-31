extends GutTest
## The dokkaebi hurls 도깨비불: foxfire with fire, named so wherever it is told.

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


func test_the_dokkaebi_casts_foxfire_with_fire() -> void:
	assert_eq(Bestiary.info(&"dokkaebi").casts, [[Cards.FOX, Cards.FIRE]])
	assert_eq(Bestiary.elements(&"dokkaebi"), [Cards.FIRE] as Array[StringName])
	assert_eq(Bestiary.weak_to(&"dokkaebi"), [Cards.WATER] as Array[StringName])


func test_its_wisp_sets_miho_alight_where_it_strikes() -> void:
	var w := _world()
	var foe := _foe(w, &"dokkaebi")
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
	var foe := _foe(w, &"dokkaebi")
	for y in range(1, Grid.H - 1):
		w.tiles[Grid.index(Vector2i(5, y))] = World.WALL
	w.cast(foe, Bestiary.spell(foe.kind, foe.info().casts[0]), WEST)
	for i in 6:
		w.act(WAIT)
	assert_true(w.burning.is_empty())
	assert_eq(w.player().hp, 3)


func test_hover_names_the_spell_and_the_weakness() -> void:
	var w := _world()
	var foe := _foe(w, &"dokkaebi")
	var text := Info.plain(Info.creature(w, foe))
	assert_string_contains(text, "주술: 도깨비불\n")
	assert_false(text.contains("여우불"))
	assert_string_contains(text, "약점: 물\n")


func test_the_charge_line_and_the_projectile_hover_name_it() -> void:
	var w := _world()
	var foe := _foe(w, &"dokkaebi")
	var cards: Array = foe.info().casts[0]
	var charge := {t = &"charge", id = foe.id, cards = cards, dir = WEST}
	assert_eq(Messages.of(w, w, [charge]).map(Messages.plain), ["도깨비가 도깨비불을 모으고 있다"])
	w.cast(foe, Bestiary.spell(foe.kind, cards), WEST)
	assert_string_contains(Info.plain(SpellInfo.shot(w, w.shots[0])), "적의 도깨비불")


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
	assert_string_contains(Info.plain(SpellInfo.shot(w, w.shots[1])), "미호의 불 여우불")
