extends GutTest
## Compound sprays: each compound's shape, the plain effects of the elements
## it carries, a preview that equals the round, the hover text and the log.

const FIRE := Cards.FIRE
const WATER := Cards.WATER
const WOOD := Cards.WOOD
const METAL := Cards.METAL
const EARTH := Cards.EARTH
const E := Vector2i(1, 0)
const ME := Vector2i(20, 12)


## An open hall walled at the edges, lit by lanterns two rows above Miho, who
## stands at ME with five tails.
func _world() -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	for y in range(1, Grid.H - 1):
		for x in range(1, Grid.W - 1):
			w.tiles[Grid.index(Vector2i(x, y))] = World.FLOOR
	for x in range(2, Grid.W - 2, 3):
		w.tiles[Grid.index(Vector2i(x, ME.y - 2))] = World.LANTERN
	w.rooms.assign([Rect2i(1, 1, Grid.W - 2, Grid.H - 2)])
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.hp = 3
	me.max_hp = 3
	me.pos = ME
	w.actors.append(me)
	w.depth = 13
	w.tails = 5
	w.cards.assign(Cards.ALL)
	w.sense()
	return w


func _put(w: World, p: Vector2i, t: int) -> void:
	w.tiles[Grid.index(p)] = t
	w._changed()


func _cast(cards: Array, dir := E) -> Dictionary:
	return {t = &"cast", spells = [{cards = cards, dir = dir}]}


## A creature that neither moves nor casts: a 장승 (no element, 3 health).
func _post(w: World, at: Vector2i) -> Actor:
	var a := FloorGen.spawn(w, &"jangseung", at)
	a.cooldown = 99
	return a


func _cover(w: World, cards: Array, dir := E) -> Array[Vector2i]:
	return Spray.cover(w, w.player(), Spell.make(cards), dir)


func _of(events: Array, t: StringName) -> Array:
	return events.filter(func(e): return e.t == t)


func test_every_compound_has_its_shape() -> void:
	var w := _world()
	assert_eq(_cover(w, [WATER, FIRE]), Spray.square(w, ME + E * 2), "증기 2 ahead")
	assert_eq(_cover(w, [EARTH, WATER]), Spray.square(w, ME + E * 2), "진흙 2 ahead")
	assert_eq(_cover(w, [WATER, WOOD]), Spray.square(w, ME + E * 3), "단비 3 ahead")
	assert_eq(_cover(w, [EARTH, METAL]), Spray.square(w, ME + E * 3), "유탄 3 ahead")
	assert_eq(_cover(w, [WOOD, FIRE]).size(), 15, "들불: a fan of radius 3")
	assert_eq(_cover(w, [METAL, WOOD]).size(), 8, "가시: a fan of radius 2")
	for c in [[FIRE, EARTH], [METAL, WATER], [FIRE, METAL]]:
		assert_eq(_cover(w, c), Spray.line(w, ME, E, 4, false, 0), str(c))
		assert_eq(_cover(w, c).size(), 4)
	assert_true(_cover(w, [WOOD, EARTH]).is_empty(), "벽 가르기 with no wall near")
	assert_eq(Spray.square(w, ME).size(), 9)


func test_a_burst_lands_short_of_a_wall_or_on_a_creature() -> void:
	var w := _world()
	_put(w, ME + E * 2, World.WALL)
	assert_eq(_cover(w, [WATER, WOOD]), Spray.square(w, ME + E), "short of the wall")
	assert_false(_cover(w, [WATER, WOOD]).has(ME + E * 2), "the wall is left out")
	w = _world()
	_post(w, ME + E)
	assert_eq(_cover(w, [EARTH, METAL]), Spray.square(w, ME + E))
	assert_eq(_cover(w, [FIRE, EARTH]), [ME + E] as Array[Vector2i], "a line stops at it")


func test_wall_splitting_cracks_the_first_wall_and_its_neighbours() -> void:
	var w := _world()
	for y in range(1, Grid.H - 1):
		_put(w, Vector2i(ME.x + 3, y), World.WALL)
	var tiles := _cover(w, [WOOD, EARTH])
	assert_eq(tiles, [ME + E * 3, ME + Vector2i(3, 1), ME + Vector2i(3, -1)] as Array[Vector2i])
	w.act(_cast([WOOD, EARTH]))
	for p in tiles:
		assert_eq(w.tile(p), World.WALL_CRACKED, str(p))
	assert_eq(w.tile(ME + Vector2i(3, 2)), World.WALL)


func test_steam_douses_and_pushes_and_thorns_hurt_and_root() -> void:
	var w := _world()
	_put(w, ME + E * 3, World.BOARD)
	w.ignite(ME + E * 3)
	var foe := _post(w, ME + Vector2i(2, 1))
	w.act(_cast([WATER, FIRE]))
	assert_false(w.burning.has(ME + E * 3), "doused")
	assert_eq(foe.pos, ME + Vector2i(3, 1), "pushed 1 along the line")
	assert_eq(foe.hp, foe.max_hp, "steam has no 쇠")
	w = _world()
	foe = _post(w, ME + Vector2i(2, 0))
	var events := w.act(_cast([METAL, WOOD]))
	assert_eq(foe.hp, foe.max_hp - 1)
	assert_eq(_of(events, &"root")[0].rounds, Elements.ROOT)


func test_more_slots_after_a_compound_strengthen_its_elements() -> void:
	var mud := Spell.make([EARTH, WATER, EARTH])
	assert_eq(mud.slots, [&"mud", EARTH] as Array[StringName])
	assert_eq(mud.title(), "진흙·흙")
	var w := _world()
	var foe := _post(w, ME + Vector2i(2, 0))
	var events := w.act(_cast([EARTH, WATER, EARTH]))
	assert_eq(_of(events, &"stun")[0].rounds, Elements.STUN + 1)
	assert_eq(foe.pos, ME + Vector2i(3, 0))


func test_a_spray_preview_equals_the_round() -> void:
	var queues := [
		[FIRE],
		[FIRE, FIRE],
		[FIRE, FIRE, FIRE],
		[WATER],
		[WATER, WATER],
		[WATER, WATER, WATER],
		[METAL],
		[METAL, METAL],
		[METAL, METAL, METAL],
		[EARTH],
		[EARTH, EARTH],
		[EARTH, EARTH, EARTH],
		[WOOD],
		[WOOD, WOOD],
		[WOOD, WOOD, WOOD],
		[WATER, FIRE],
		[METAL, WOOD],
		[EARTH, WATER, EARTH],
		[WOOD, FIRE],
	]
	for q in queues:
		var w := _world()
		_put(w, ME + Vector2i(2, 2), World.BAMBOO)
		for at in [Vector2i(1, 1), Vector2i(2, 0), Vector2i(4, 0), Vector2i(-3, 0)]:
			_post(w, ME + at)
		w.sense()
		var f := Forecast.of(w, _cast(q))
		var events := w.act(_cast(q))
		var spray: Dictionary = _of(events, &"spray")[0]
		assert_eq(f.sprays.size(), 1, str(q))
		assert_eq(f.sprays[0].tiles, spray.tiles, str(q))
		var harm := {}
		for e in _of(events, &"hurt"):
			harm[e.id] = harm.get(e.id, 0) + e.n
		assert_eq(f.harm, harm, str(q))
		for a in w.actors:
			assert_eq(f.after.actor(a.id).pos, a.pos, "%s moves %d" % [q, a.id])


func test_hover_tells_every_number_of_every_spray() -> void:
	var rows := {
		[FIRE]: ["불 불길 꼬리 1개", "반지름 2", "타는 칸에 불을 붙인다", "소리 쓸 때 2칸"],
		[FIRE, FIRE]: ["반지름 3", "불 위에서 매 초 %d" % World.FIRE_DAMAGE],
		[FIRE, FIRE, FIRE]: ["반지름 4", "늘 번진다"],
		[WATER]: ["곧게 4칸, 첫 적에서 멈춘다", "1칸 민다", "소리 없음"],
		[WATER, WATER]: ["곧게 6칸", "2칸 민다"],
		[WATER, WATER, WATER]: ["곧게 8칸, 적을 꿰뚫는다", "3칸 민다"],
		[METAL]: ["권총. 곧게 7칸", "피해 1. 약점 시 ×2", "발사 시 당신 칸을 밝힌다", "9칸"],
		[METAL, METAL]: ["산탄", "반지름 3", "바로 옆 적은 2"],
		[METAL, METAL, METAL]: ["철갑탄. 곧게 8칸", "벽 하나", "적마다 2"],
		[EARTH]: ["둘레 1칸", "1초 기절", "9칸"],
		[EARTH, EARTH]: ["둘레 2칸", "벽에 금이 간다"],
		[EARTH, EARTH, EARTH]: ["둘레 3칸", "2초 기절", "금 간 벽은 무너진다"],
		[WOOD]: ["4걸음 안", "적 1명", "2초 묶는다", "소리 없음"],
		[WOOD, WOOD]: ["6걸음 안", "적 2명", "3초 묶는다"],
		[WOOD, WOOD, WOOD]: ["8걸음 안", "적 모두", "4초 묶는다"],
		[WATER, FIRE]: ["증기", "2칸 앞 3×3", "적을 1칸 민다", "타는 칸과 나무 적에 불을 붙인다"],
		[METAL, WOOD]: ["가시", "반지름 2", "적에게 피해 1", "적을 2초 묶는다"],
		[WOOD, EARTH]: ["3칸 안 첫 벽과 그 양옆", "벽에 금이 간다"],
		[FIRE, EARTH]: ["용암", "곧게 4칸"],
	}
	for q: Array in rows:
		var text := Info.plain(SpellInfo.spell(Spell.make(q)))
		for part: String in rows[q]:
			assert_string_contains(text, part)
	var card := Info.plain(SpellInfo.card(FIRE, Spell.make([FIRE, FIRE])))
	assert_true(card.begins_with("불 부적 꼬리 1개"), card)
	assert_string_contains(card, "반지름 2")
	assert_string_contains(card, "넣으면 불×2 불길 꼬리 2개")


func test_the_log_tells_the_harm_a_spray_deals() -> void:
	var w := _world()
	var foe := _post(w, ME + Vector2i(2, 0))
	w.sense()
	var before := w.clone()
	var events := w.act(_cast([METAL]))
	var lines: Array = Messages.of(before, w, events).map(Messages.plain)
	assert_has(lines, "%s에게 피해를 1 주었다" % foe.info().name)
