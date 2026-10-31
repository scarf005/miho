extends GutTest
## Compound sprays: each compound's shape, the plain effects of the lone elements
## after it, a preview that equals the round, the hover text and the log.

const FOX := Cards.FOX
const ORB := Cards.ORB
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
	assert_eq(_cover(w, [WATER, FIRE]), Spray.square(w, ME + E * 3), "증기 3 ahead")
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


func test_wall_splitting_fells_the_first_wall_and_its_neighbours_silently() -> void:
	var w := _world()
	for y in range(1, Grid.H - 1):
		_put(w, Vector2i(ME.x + 3, y), World.WALL)
	var tiles := _cover(w, [WOOD, EARTH])
	assert_eq(tiles, [ME + E * 3, ME + Vector2i(3, 1), ME + Vector2i(3, -1)] as Array[Vector2i])
	var events := w.act(_cast([WOOD, EARTH]))
	for p in tiles:
		assert_eq(w.tile(p), World.RUBBLE, str(p))
	assert_eq(w.tile(ME + Vector2i(3, 2)), World.WALL)
	assert_true(_of(events, &"noise").is_empty(), "silent")


func test_more_slots_after_a_compound_add_their_plain_effect() -> void:
	var mud := Spell.make([EARTH, WATER, EARTH])
	assert_eq(mud.slots, [&"mud", EARTH] as Array[StringName])
	assert_eq(mud.title(), "진흙·흙")
	var w := _world()
	var foe := _post(w, ME + Vector2i(2, 0))
	var events := w.act(_cast([EARTH, WATER, EARTH]))
	assert_eq(_of(events, &"stun")[0].rounds, Elements.STUN, "the lone 흙 stuns")
	assert_eq(foe.pos, ME + Vector2i(2, 0), "the 물 in 진흙 pushes no one")
	assert_eq(w.tile(foe.pos), World.MUD)


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
		[EARTH, WATER, EARTH],
		[WATER, FIRE, WATER, FIRE],
	]
	for pair: Array in Cards.PAIRS.values():
		queues.append(pair)
	for q in queues:
		var w := _world()
		_put(w, ME + Vector2i(2, 2), World.BAMBOO)
		_put(w, ME + Vector2i(1, -1), World.POND)
		_put(w, ME + Vector2i(3, -1), World.WALL)
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
			var b := f.after.actor(a.id)
			assert_eq(
				[b.pos, b.rooted, b.stunned], [a.pos, a.rooted, a.stunned], "%s %d" % [q, a.id]
			)
		assert_eq(f.after.tiles, w.tiles, str(q))
		assert_eq([f.after.hot, f.after.gas, f.after.burning], [w.hot, w.gas, w.burning], str(q))


func test_hover_tells_every_number_of_every_spray() -> void:
	var rows := {
		[FIRE]: ["불 불길 · 꼬리 1개", "반지름 2", "불: 가연성 칸에 불", "소리: 쓸 때 2칸"],
		[FIRE, FIRE]: ["반지름 3", "다음 초부터 매 초 %d" % World.FIRE_DAMAGE],
		[FIRE, FIRE, FIRE]: ["반지름 4", "늘 번짐"],
		[WATER]: ["곧게 4칸, 첫 적에서 멈춤", "1칸 밀침", "소리: 없음"],
		[WATER, WATER]: ["곧게 6칸", "2칸 밀침"],
		[WATER, WATER, WATER]: ["곧게 8칸, 적을 꿰뚫음", "3칸 밀침"],
		[METAL]: ["권총. 곧게 7칸", "피해: 1\n", "빛: 쏠 때 미호 칸", "9칸"],
		[METAL, METAL]: ["산탄", "반지름 3", "바로 옆 적은 2"],
		[METAL, METAL, METAL]: ["철갑탄. 곧게 8칸", "벽 하나", "적마다 2"],
		[EARTH]: ["둘레 1칸", "1초 기절", "9칸"],
		[EARTH, EARTH]: ["둘레 2칸", "흙: 벽에 금"],
		[EARTH, EARTH, EARTH]: ["둘레 3칸", "2초 기절", "금 간 벽은 무너짐"],
		[WOOD]: ["4걸음 안", "적 1명", "2초 묶음", "소리: 없음"],
		[WOOD, WOOD]: ["6걸음 안", "적 2명", "3초 묶음"],
		[WOOD, WOOD, WOOD]: ["8걸음 안", "적 모두", "4초 묶음"],
		[WATER, FIRE]:
		[
			"증기 · 꼬리 2개",
			"3칸 앞 3×3",
			"증기: 양 %d/%d" % [Compounds.STEAM, Gas.MAX],
			"위에서 매 초 피해 %d" % Gas.of(Gas.STEAM, "harm"),
			"소리: 없음",
		],
		[WATER, FIRE, WATER, FIRE]: ["증기×2", "3칸 앞 5×5"],
		[METAL, WOOD]:
		["가시", "반지름 2", "적마다 피해 %d. 지날 때 피해 %d" % [Compounds.THORN, Compounds.THORN]],
		[WOOD, EARTH]: ["3칸 안 첫 벽과 그 양옆", "벽을 소리 없이 무너뜨림", "소리: 없음"],
		[WOOD, EARTH, WOOD, EARTH]: ["4칸 안 첫 벽과 그 양옆"],
		[FIRE, EARTH]:
		[
			"용암",
			"곧게 4칸",
			"뜨거운 땅 %d초" % Compounds.HOT_ROUNDS,
			"매 초 피해 %d" % Compounds.HOT[Compounds.LAVA].harm,
		],
		[FIRE, METAL]:
		[
			"뜨거운 쇠 %d초" % Compounds.HOT_ROUNDS,
			"매 초 피해 %d" % Compounds.HOT[Compounds.MOLTEN].harm,
		],
		[WOOD, FIRE]: ["들불", "반지름 3", "들불: 늘 번짐", "소리: 쓸 때 %d칸" % Spray.HUSH],
		[EARTH, METAL]:
		["유탄", "3칸 앞 3×3", "적마다 피해 %d" % Compounds.SHRAPNEL, "%d칸" % Spray.GUN_LOUD],
		[METAL, WATER]: ["서리", "곧게 4칸", "얼어붙음 %d초" % Compounds.FROST, "연못이 얼음이 됨"],
		[WATER, WOOD]: ["단비", "3칸 앞 3×3", "단비: %d초 묶음" % Compounds.RAIN, "불, 등불 끔"],
		[EARTH, WATER]: ["진흙", "2칸 앞 3×3", "걷는 데 %d초, 발소리 없음" % Compounds.MUD],
		[EARTH, WATER, EARTH]: ["진흙·흙", "흙: %d초 기절" % Elements.STUN],
		[FOX, WATER, FIRE]: ["증기 여우불", "멈춘 곳 3×3", "증기: 양 %d/%d" % [Compounds.STEAM, Gas.MAX]],
		[ORB, WOOD, EARTH]: ["멈춘 곳에서 1칸 안 첫 벽과 그 양옆"],
		[ORB, METAL, WATER, METAL, WATER]: ["서리×2 구슬", "멈춘 곳 5×5"],
	}
	for q: Array in rows:
		var text := Info.plain(SpellInfo.spell(Spell.make(q)))
		for part: String in rows[q]:
			assert_string_contains(text, part)
	var card := Info.plain(SpellInfo.card(FIRE, Spell.make([FIRE, FIRE])))
	assert_true(card.begins_with("불 부적 · 꼬리 1개"), card)
	assert_string_contains(card, "반지름 2")
	assert_string_contains(card, "넣으면: 불×2 불길 · 꼬리 2개")


func test_the_log_tells_the_harm_a_spray_deals() -> void:
	var w := _world()
	var foe := _post(w, ME + Vector2i(2, 0))
	w.sense()
	var before := w.clone()
	var events := w.act(_cast([METAL]))
	var lines: Array = Messages.of(before, w, events).map(Messages.plain)
	assert_has(lines, "%s에게 피해를 1 주었다" % foe.info().name)
