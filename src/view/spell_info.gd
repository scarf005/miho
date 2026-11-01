class_name SpellInfo
extends RefCounted
## Every number of a spell, a talisman or a projectile in flight, as Info
## lines ([text, Color] runs): its shape, damage, speed, turn, reach, the tails
## it costs, what each element does, its light and its sound.

const LABEL := Palette.DIM
const MUZZLE := ["쏠 때 빛", "미호 칸"]
## The talismans that make each shape but a spray.
const RECIPE := {
	Spell.LEAP: Cards.TRIPLES[Cards.VAULT],
	Spell.WISP: [Cards.FOX],
	Spell.HOMING: [Cards.FOX, Cards.ORB],
	Spell.ORB: [Cards.ORB],
}
## The guns that are named (Spell.pierces, Spell.mortar), by their talismans.
const GUNS := [[Cards.FOX, Cards.METAL, Cards.METAL], [Cards.ORB, Cards.EARTH, Cards.METAL]]
## What 도약 behind a projectile does (Leap.swap): [label, value] lines.
const SWAP := [["바꿔치기", "멈춘 칸으로"], ["맞힌 적", "자리 교환"], ["바꿔치기 소리", "두 자리에서 %d칸" % Leap.SWAP_LOUD]]
## The numbers of each status (Status) past its name and time, by key, one
## `이름: 값` line each; and what a spell that causes it says, as [label, value].
const STATUS_DOES := {
	&"wet": ["소리: %d칸" % Status.SPLASH],
	&"alight": ["초당 피해: %d" % World.FIRE_DAMAGE, "빛: %d칸" % Light.FIRE_RADIUS],
	&"frozen": ["다음 피해: ×2"],
}
const SOAK := ["젖음", "%d초" % Status.WET]
const ALIGHT_ON := ["불붙음", "%d초" % Status.ALIGHT]
const SPRAY_NAME := "뿌리기"


## A shape a spell takes: its name, the talismans that make it, and its numbers.
static func shape(kind: StringName) -> Array:
	if kind == Spell.SPRAY:
		return [[[SPRAY_NAME, Palette.TEXT]], _line("만드는 법", "오행 부적만"), _line("모양", "투사체 없이 닿는 칸")]
	var s := Spell.make(RECIPE[kind])
	return [[[Spell.SHAPE_NAME[kind], Palette.shot_color(s, Actor.FOX)]], _recipe(s)] + _shape(s)


## The talismans a spell is made of: "만드는 법: 물+나무+불".
static func _recipe(s: Spell) -> Array:
	return [["만드는 법: ", LABEL]] + _recipe_runs(s.cards)


## Talismans joined by "+", each in its colour.
static func _recipe_runs(cards: Array) -> Array:
	var runs := []
	for i in cards.size():
		runs.append([("+" if i > 0 else "") + Cards.NAME[cards[i]], Palette.card(cards[i])])
	return runs


## A talisman, and what the queue becomes with it (null when it does not fit).
static func card(c: StringName, after: Spell) -> Array:
	var head := [[Cards.NAME[c] + " 부적", Palette.card(c)], [" · 꼬리: 1", LABEL]]
	var lines: Array = [head] + spell(Spell.make([c])).slice(1)
	if after != null and after.cards.size() > 1:
		lines.append(
			[
				["넣으면: ", LABEL],
				[after.title(), Palette.card(after.slots.back())],
				[" · " + _cost(after), LABEL]
			]
		)
	return lines


## A queue slot: its talisman and its tails, then the whole spell. A lone
## plain talisman is the whole spell, so it is named once.
static func slot(s: Spell, i: int) -> Array:
	if s.cards.size() == 1:
		return spell(s)
	return [_slot_head(s, i)] + (spell(s).slice(1) if s.slots.size() == 1 else spell(s))


## A compound talisman alone: its tails and parts, then what it does.
static func combo(c: StringName) -> Array:
	var s := Spell.make(Cards.made_of(c))
	return [_slot_head(s, 0)] + spell(s).slice(1)


static func _slot_head(s: Spell, i: int) -> Array:
	var c := s.slots[i]
	var parts := Cards.made_of(c)
	var head := [[Cards.NAME[c], Palette.card(c)], [" · 꼬리: %d" % Spell.price(parts.size()), LABEL]]
	if parts.size() > 1:
		head += [[" · ", LABEL]] + _recipe_runs(parts)
	return head


## A spell: name, cost and slots, then every number.
static func spell(s: Spell) -> Array:
	var head := [[s.title(), Palette.card(s.slots.back())], [" · " + _cost(s) + " · ", LABEL]]
	for c in s.slots:
		head.append([Cards.GLYPH[c], Palette.card(c)])
	var lines := [head]
	if s.shape == Spell.LEAP:
		lines.append_array(_shape(s))
		var then := s.rest()
		if then != null:
			lines.append([["내린 자리에서: ", LABEL], [then.title(), Palette.card(then.slots.back())]])
			lines.append_array(spell(then).slice(1))
		return lines
	if s.shape == Spell.SPRAY:
		lines.append_array(_spray(s))
		lines.append(_line(MUZZLE[0], MUZZLE[1]) if s.gun() else _line("빛", "없음"))
		return lines + _lines(_sounds(s)) + ward(s)
	lines.append_array(_shape(s))
	for e in Cards.ELEMENTS:
		if s.has(e):
			lines.append_array(_lines(_effect(s, e), Palette.CARD[e]))
	if s.has(Cards.WATER):
		lines.append(_line(SOAK[0], SOAK[1], Palette.CARD[Cards.WATER]))
	for c in s.compounds():
		if s.mortar() and c == &"shrapnel":
			lines.append_array(_lines(_mortar(s), Palette.card(c)))
			continue
		lines.append(_line(Cards.NAME[c], _carried(s, c), Palette.card(c)))
		lines.append_array(_lines(compound(c), Palette.card(c)))
	if s.swaps():
		lines.append_array(_swap())
	lines.append(_line("빛", _light(s.light(Actor.FOX))))
	if s.gun():
		lines.append(_line(MUZZLE[0], MUZZLE[1]))
	return lines + _lines(_sounds(s)) + ward(s)


## A spell that goes on Miho herself (Guise): its name and talismans, then
## what it does there.
static func own(kind: StringName) -> Array:
	var s := Spell.make(Guise.RECIPE[kind])
	return (
		[[[Guise.NAME[kind], Palette.card(s.slots.back())], [" · " + _cost(s), LABEL]], _recipe(s)]
		+ ward(s)
	)


## What `s` does cast on Miho herself, with , or a click on her; nothing for a
## spell that does not go on her.
static func ward(s: Spell) -> Array:
	var on := "자신에게"
	var kind := Guise.kind(s)
	if kind == &"":
		return []
	var name: String = Guise.NAME[kind]
	if kind == Guise.GUISE:
		return [
			_line(on, name),
			_line("모습", "마지막으로 처치한 적"),
			_line("시간", "%d초" % Guise.rounds(s)),
			_line("%s 한 장마다" % Cards.NAME[Cards.WOOD], "+%d초" % Guise.PER_WOOD),
			_line("못 알아봄", "추격 중이 아닌 적"),
			_line("발톱", "기습"),
			_line("풀림", "적 옆 %d초, 주문 시전, 맞음" % Guise.BESIDE),
			_line(name + " 소리", "없음"),
		]
	var dark: int = s.light(Actor.FOX).radius
	return [
		_line(on, name),
		_line("어둠", "둘레 %d칸" % dark),
		_line("시간", "%d초" % Spell.WISP_LIFE),
		_line("%s 한 장마다" % Cards.NAME[Cards.WATER], "+1칸"),
		_line("보임", "바로 옆에서만"),
		_line("걷힘", "둘레의 불, 켜진 등불"),
		_line(name + " 소리", "없음"),
	]


## Shape and effect of a spray, with every number, a short line each.
static func _spray(s: Spell) -> Array:
	var level := s.level()
	if level == 0:
		return _compound(s)
	var i := level - 1
	var c := s.slots[0]
	var color: Color = Palette.CARD[c]
	match c:
		Cards.FIRE:
			var out := _lines(_fan(Spray.FAN[i])) + [_line("불", "가연성 칸", color)]
			out.append(_line("켬", "꺼진 등불", color))
			if level >= 3:
				out.append(_line(ALIGHT_ON[0], ALIGHT_ON[1], color))
				out.append(_line("초당 피해", "%d" % World.FIRE_DAMAGE, Palette.HURT))
				out.append(_line("번짐", "늘", color))
			return out
		Cards.WATER:
			return [
				_line("모양", "곧게 %d칸" % Spray.JET[i]),
				_line("꿰뚫음", "적") if level >= 3 else _line("멈춤", "첫 적"),
				_line("밀침", "%d칸" % Spray.PUSH[i], color),
				_line("끔", "불, 등불", color),
				_line("적심", "북", color),
				_line(SOAK[0], SOAK[1], color),
			]
		Cards.METAL:
			return _gun(level)
		Cards.EARTH:
			var out := [
				_line("모양", "둘레 %d칸" % Spray.QUAKE[i]),
				_line("기절", "%d초" % Spray.QUAKE_STUN[i], color),
			]
			if level >= 2:
				out.append(_line("벽", "금", color))
			if level >= 3:
				out.append(_line("금 간 벽", "무너짐", color))
			return out
	var who := "모두" if Spray.ROOT_COUNT[i] == 0 else "%d명" % Spray.ROOT_COUNT[i]
	return [
		_line("모양", "땅속 뿌리"),
		_line("거리", "%d걸음" % Spray.ROOT_REACH[i]),
		_line("대상", "보이는 가까운 적 " + who),
		_line("묶음", "%d초" % Spray.ROOT_ROUNDS[i], color),
		_line("막힘", "하늘, 연못, 벽, 하늘다리"),
	]


## A fan of radius r, as [label, value] lines.
static func _fan(r: int, name := "") -> Array:
	return [["모양", name + "부채꼴 90°, 반지름 %d" % r], ["닿음", "보이는 칸만"]]


static func _gun(level: int) -> Array:
	if level >= 2:
		var near := _line("바로 옆 적 피해", "2", Palette.HURT)
		return _lines(_fan(Spray.shotgun(level), "산탄, ")) + [_line("피해", "1", Palette.HURT), near]
	return [
		_line("모양", "권총, 곧게 %d칸" % Spray.PISTOL), _line("멈춤", "첫 적"), _line("피해", "1", Palette.HURT)
	]


## A compound's shape, then what each compound in it does, then the plain
## effect of each lone element.
static func _compound(s: Spell) -> Array:
	var shape: Array = Spray.SHAPE[s.slots[0]]
	var lines := _lines(_form(s))
	for c in s.compounds():
		lines.append_array(_lines(compound(c), Palette.card(c)))
	var plain := {
		Cards.FIRE: [["불", "가연성 칸, 나무 적"], ["켬", "꺼진 등불"]],
		Cards.WATER: [["끔", "불, 등불"], ["밀침", "%d칸" % (1 + s.extra(Cards.WATER))]],
		Cards.WOOD: [["묶음", "%d초" % (Elements.ROOT + s.extra(Cards.WOOD))]],
		Cards.METAL: [["피해", "%d" % s.count(Cards.METAL)]],
		Cards.EARTH: [["기절", "%d초" % (Elements.STUN + s.extra(Cards.EARTH))]],
	}
	if shape[0] == Spray.CLEAVE:
		plain[Cards.EARTH].append(["벽", "금"])
	for e in Cards.ELEMENTS:
		if s.has(e):
			lines.append_array(_lines(plain[e], Palette.CARD[e]))
	if s.has(Cards.WATER):
		lines.append(_line(SOAK[0], SOAK[1], Palette.CARD[Cards.WATER]))
	return lines


## The shape of a spray led by a compound, as [label, value] lines.
static func _form(s: Spell) -> Array:
	var lead := s.slots[0]
	var shape: Array = Spray.SHAPE[lead]
	var n: int = shape[1] + s.grown(lead)
	match shape[0]:
		Spray.FAN_SHAPE:
			return _fan(n)
		Spray.LINE, Spray.BORE:
			return [["모양", "곧게 %d칸" % n], ["멈춤", "첫 적"]]
		Spray.BURST, Spray.BREACH:
			var size := _square(shape[2] + s.grown(lead))
			return [["모양", "%d칸 앞 %s" % [shape[1], size]], ["막히면", "그 앞"]]
		Spray.ACROSS:
			var wide: int = shape[2] + s.grown(lead)
			return [["모양", "%d칸 앞 직각 %d칸" % [shape[1], wide]], ["막히면", "그 앞"]]
		Spray.AROUND:
			return [["모양", "둘레 %d칸" % n]]
		Spray.SIGHT:
			return [["대상", "보이는 적 모두" + (", 미호" if shape.size() > 2 else "")]]
		Spray.ROOTS:
			var deepest := Spray.ROOTS_LEVEL - 1
			return [
				["모양", "땅속 뿌리"],
				["거리", "%d걸음" % Spray.ROOT_REACH[deepest]],
				["대상", "보이는 적 모두"],
			]
		Spray.STRIKE:
			return [["모양", "곧게 %d칸" % n], ["꿰뚫음", "적"]]
	return [["모양", "%d칸 안 첫 벽과 그 양옆" % n]]


## What compound `c` does where it reaches, as [label, value] lines (Compounds).
static func compound(c: StringName) -> Array:
	var harm := func(n: int) -> Array: return ["초당 피해", "%d" % n]
	var hot := func(kind: int) -> Array:
		var spec: Dictionary = Compounds.HOT[kind]
		return [[spec.name, "%d초" % Compounds.HOT_ROUNDS], harm.call(spec.harm)]
	match c:
		&"wildfire":
			return [["불", "가연성 칸, 닿은 적"], ["번짐", "늘"], ["초당 피해", "%d" % World.FIRE_DAMAGE]]
		&"lava":
			return hot.call(Compounds.LAVA)
		&"molten":
			return hot.call(Compounds.MOLTEN)
		&"shrapnel":
			return [["피해", "%d" % Compounds.SHRAPNEL]]
		&"frost":
			var frozen: String = Status.NAME[&"frozen"]
			return [
				[frozen, "%d초" % Compounds.FROST],
				["젖은 적 " + frozen, "%d초" % (2 * Compounds.FROST)],
				["연못", "얼음이 됨"]
			]
		&"rain":
			return [["묶음", "%d초" % Compounds.RAIN], ["끔", "불, 등불"], ["적심", "북"], SOAK]
		&"steam":
			var gas := [Gas.of(Gas.STEAM, "name") + " 양", "%d/%d" % [Compounds.STEAM, Gas.MAX]]
			return [gas, harm.call(Gas.of(Gas.STEAM, "harm")), ["적심", "북"], SOAK]
		&"thorn":
			var name: String = Tiles.of(World.THORNS, "name")
			return [
				[name, "자람"], ["피해", "%d" % Compounds.THORN], ["지날 때 피해", "%d" % Compounds.THORN]
			]
		&"split":
			return [["벽", "소리 없이 무너짐"]]
		&"mud":
			var name: String = Tiles.of(World.MUD, "name")
			return [["끔", "불, 등불"], ["땅", name], ["걸음", "%d초" % Compounds.MUD], ["발소리", "없음"], SOAK]
		&"volcano":
			return hot.call(Compounds.LAVA) + [["불", "가연성 칸"], ALIGHT_ON]
		&"furnace":
			return hot.call(Compounds.MOLTEN) + [["끝 벽", "무너짐"]]
		&"hail":
			var frozen: String = Status.NAME[&"frozen"]
			return [
				["피해", "%d" % Compounds.HAIL],
				[frozen, "%d초" % Compounds.FROST],
				["젖은 적 " + frozen, "%d초" % (2 * Compounds.FROST)],
			]
		&"frostbloom":
			return [
				[Tiles.of(World.THORNS, "name"), "자람"],
				["지날 때 피해", "%d" % Compounds.THORN],
				["연못", "얼음이 됨"],
				["묶음", "%d초" % Compounds.BLOOM],
			]
		&"swamp":
			return compound(&"split") + compound(&"mud") + [["묶음", "%d초" % Compounds.SWAMP]]
		&"geyser":
			return [["밀침", "%d칸" % Compounds.GEYSER]] + compound(&"steam")
		&"quench":
			var gas: String = Gas.of(Gas.STEAM, "name") + " 양"
			return (
				hot.call(Compounds.MOLTEN)
				+ [
					["맞은 적 피해", "%d" % Compounds.QUENCH],
					["젖은 적 피해", "%d" % Compounds.QUENCH_WET],
					["끝 칸 " + gas, "%d/%d" % [Compounds.STEAM, Gas.MAX]],
				]
			)
		&"charthorn":
			return compound(&"thorn") + [["불", "가연성 칸"], ALIGHT_ON]
		&"palisade":
			return [["나무벽 체력", "%d" % Tiles.of(World.WOOD_WALL, "health")]]
		&"beacon":
			return compound(&"wildfire") + [["켬", "보이는 꺼진 등불"], ["끝 칸 소리", "%d칸" % Compounds.BOOM]]
		&"ironrain":
			var steam: Array = compound(&"steam")
			return hot.call(Compounds.MOLTEN) + [steam[0], ["증기 피해", steam[1][1]], SOAK]
		&"ironroot":
			return [["묶음", "%d초" % Compounds.IRONROOT], ["피해", "%d" % Compounds.IRONROOT_HARM]]
		&"magpie":
			return [["하늘, 연못", Tiles.of(World.BRIDGE, "name")]]
		&"mist":
			var name: String = Gas.of(Gas.FOG, "name") + " 양"
			return [[name, "%d/%d" % [Gas.MAX, Gas.MAX]], ["냄새", "지움"]]
		&"sinkhole":
			return [
				["땅", Tiles.of(World.SKY, "name")],
				["선 적", "떨어짐"],
				["남는 칸", "미호 칸, 계단으로 가는 길을 끊는 칸"],
			]
		&"newmoon":
			return [["끔", "불, 등불"]]
		&"discord":
			return [["싸움", "가까운 둘씩"], ["시간", "%d초" % Mind.GRUDGE_ROUNDS]]
		&"thunder":
			return [
				["피해", "%d" % Compounds.THUNDER],
				["기절", "%d초" % Compounds.THUNDER_STUN],
			]
		&"stillness":
			return [["추격 중인 적", "제 칸을 수색"], ["냄새", "지움"]]
		Cards.SAMSARA:
			return [["체력", "+%d" % World.HEAL], ["기절", "%d초" % Compounds.SAMSARA_STUN]]
		Cards.CONQUEST:
			return [
				["피해", "%d" % Compounds.CONQUEST_HARM],
				["약점인 적 피해", "%d" % (2 * Compounds.CONQUEST_HARM)],
			]
		Cards.DRAGON:
			return [
				["벽", "무너짐"],
				["밀침", "%d칸, 바깥으로" % Compounds.DRAGON_PUSH],
				["기절", "%d초" % Compounds.DRAGON_STUN],
			]
	return []


## What a 비격진 does where it ends, as [label, value] lines.
static func _mortar(s: Spell) -> Array:
	return [
		["폭발 반지름", "%d" % (1 + s.grown(&"shrapnel"))],
		["폭발 피해", "%d" % (Compounds.MORTAR + s.count(Cards.METAL))],
		["폭발 벽", "금"],
	]


## Where a compound carried on a projectile reaches.
static func _carried(s: Spell, c: StringName) -> String:
	var r := 1 + s.grown(c)
	if c == &"split":
		return "멈춘 곳에서 %d칸 안 첫 벽과 그 양옆" % r
	return "멈춘 곳 " + _square(r)


static func _square(r: int) -> String:
	return "%d×%d" % [2 * r + 1, 2 * r + 1]


## A projectile in flight, from what Miho knows of `w`.
static func shot(w: World, s: Shot) -> Array:
	var spell := s.spell
	var side := "미호의 " if s.faction == Actor.FOX else "적의 "
	var lines := [
		[[side, Palette.SIDE[s.faction]], [spell.title(), Palette.shot_color(spell, s.faction)]]
	]
	if elements(spell) != "":
		lines.append(_line("원소", elements(spell)))
	lines.append(_line("피해", str(spell.damage(s.distance())), Palette.HURT))
	if s.turn > 0:
		var t := w.actor(s.target)
		lines.append(_line("대상", "없음" if t == null else t.info().name))
		lines.append(_line("꺾임", _turn(s.turn)))
	lines.append(_line("빠르기", "초당 %d칸" % spell.speed() if s.dir != Vector2i.ZERO else "떠 있음"))
	if s.life > 0:
		lines.append(_line("남은 시간", "%d초" % s.life))
	if spell.swaps():
		lines.append_array(_swap())
	if s.faction == Actor.FOX and Lure.lures(spell):
		lines.append_array(_lure(spell))
	lines.append(_line("빛", _light(spell.light(s.faction))))
	if spell.burst_noise() > 0:
		lines.append(_line("터질 때 소리", "%d칸" % spell.burst_noise()))
	return lines


## The elements a spell a creature calls by its own name carries, "·" between
## them; "" when it carries none or its title tells them.
static func elements(s: Spell) -> String:
	var names: Array[String] = []
	for c in s.elements():
		if s.called != "" and not names.has(Cards.NAME[c]):
			names.append(Cards.NAME[c])
	return "·".join(names)


## A turn of `degrees` a tile.
static func _turn(degrees: int) -> String:
	if degrees >= Spell.TURN_STEP * Spell.TURN_FREE:
		return "마음대로"
	return "%d°" % degrees if degrees > 0 else "없음"


static func _cost(s: Spell) -> String:
	return "꼬리: %d" % s.cost()


static func _line(label: String, value: String, color := Palette.TEXT) -> Array:
	return [[label + ": ", LABEL], [value, color]]


## [label, value] pairs as lines, the value in `color`.
static func _lines(pairs: Array, color := Palette.TEXT) -> Array:
	return pairs.map(func(p): return _line(p[0], p[1], color))


static func _swap() -> Array:
	return _lines(SWAP, Palette.card(Cards.VAULT))


## Shape, damage, speed, turn and reach of a projectile spell; where a leap
## goes and what it is heard as.
static func _shape(s: Spell) -> Array:
	if s.shape == Spell.LEAP:
		return [
			_line("모양", "곧게 %d칸" % s.leap()),
			_line("거리", "%s 한 장마다 +1칸" % Cards.NAME[Cards.WOOD]),
			_line("넘어감", "하늘, 연못, 생물"),
			_line("막힘", "벽, 닫힌 문, 등불"),
			_line("내릴 때 소리", "%d칸" % Leap.LOUD),
			_line("진흙 위 소리", "없음"),
			_line("냄새", "내린 칸만"),
			_line("여·구 뒤 끝", "바꿔치기"),
		]
	var lines := []
	match s.shape:
		Spell.WISP:
			lines.append(_line("모양", "%s %d발" % [s.wisp(), s.shots()]))
			lines.append(_line("대상", "보이는 적, 체력만큼 나눠"))
			lines.append(
				(
					_line("발당 피해", str(s.damage(0)), Palette.HURT)
					if s.damage(0) > 0
					else _line("피해", "없음", Palette.HURT)
				)
			)
			if s.pierces():
				lines.append(_line("꿰뚫음", "모든 적, 벽 하나"))
			lines.append(_line("꺾임", "한 칸에 " + _turn(s.turn())))
			if not s.gun():
				lines.append(_line("맞히면", "붙어서 %d초" % Spell.WISP_LIFE))
			lines.append(_line("사거리", "%d칸" % Spell.RANGE))
			lines.append(_line("떠 있음", "%d초" % Spell.WISP_LIFE))
			if Lure.lures(s):
				lines.append_array(_lure(s))
		Spell.HOMING:
			lines.append(_line("모양", "유도 구슬"))
			lines.append(_line("대상", "가장 가까운 적"))
			lines.append_array(_orb_harm(s))
			lines.append(_line("꺾임", "한 칸에 " + _turn(s.turn())))
			lines.append(_line("남은 시간", "%d초" % Spell.HOMING_LIFE))
		Spell.ORB:
			lines.append(_line("모양", "구슬"))
			lines.append(_line("날아감", "벽까지 곧게"))
			lines.append_array(_orb_harm(s))
	lines.append(_line("빠르기", "초당 %d칸" % s.speed()))
	return lines


## 여우 홀림: what a hovering wisp of 여 alone is heard as (Lure).
static func _lure(s: Spell) -> Array:
	var loud := _line("떠 있을 때 소리", "2초마다 %d칸" % Lure.loud(s), Palette.SOUND)
	return [loud, _line("교활한 적", "던진 곳을 찾음", Palette.SOUND)]


static func _orb_harm(s: Spell) -> Array:
	return [
		_line("피해", "%d" % s.damage(0), Palette.HURT),
		_line("%d칸 이상 날면 피해" % Spell.MOMENTUM, "%d" % s.damage(Spell.MOMENTUM), Palette.HURT),
	]


## What an element does on a projectile, with its numbers, as [label, value]
## lines.
static func _effect(s: Spell, e: StringName) -> Array:
	match e:
		Cards.FIRE:
			var out := [["불", "지나간 자리"]]
			if s.orb:
				out.append(["폭발", "주위 8칸, 피해 %d" % (World.FIRE_DAMAGE + s.extra(e))])
			if s.extra(e) > 0:
				out.append(["피해", "+%d" % s.extra(e)])
			if s.orb:
				out.append(["나무 적", "%s %d초" % [ALIGHT_ON[0], Status.ALIGHT]])
			else:
				out.append(ALIGHT_ON)
			return out
		Cards.WATER:
			return [["지움", "소리" if s.orb else "빛, 소리"], ["끔", "멈춘 곳 3×3 등불, 불"]]
		Cards.WOOD:
			if s.orb:
				var health: int = Tiles.of(World.WOOD_WALL, "health")
				var n := Elements.WALL + s.extra(e)
				return [["나무벽", "멈춘 곳에 직각으로 %d칸" % n], ["나무벽 체력", "%d" % health]]
			return [["묶음", "%d초" % (Elements.ROOT + s.extra(e))]]
		Cards.METAL:
			if s.orb:
				var cannon := ["피해", "+%d" % (Elements.CANNON + s.extra(e))]
				return [cannon, ["밀침", "%d칸" % Elements.CANNON_PUSH], ["벽", "한 번에 부숨"]]
			return [["발당 피해", "%d" % (Elements.BULLET + s.extra(e))]]
	var thud := ["소리", "멈춘 곳에서 %d칸" % World.THUD]
	if s.orb:
		return [["벽", "한 번에 부숨"], thud]
	return [["기절", "%d초" % (Elements.STUN + s.extra(e))], thud]


static func _light(l: Dictionary) -> String:
	if l.is_empty():
		return "없음"
	return ("어둠 %d칸" if Light.level(l.color) <= 0.0 else "%d칸") % l.radius


## What a spell is heard as, as [label, value] lines: when cast, and when it
## hits or bursts.
static func _sounds(s: Spell) -> Array:
	if s.cast_noise() == 0:
		return [] if s.has(&"beacon") else [["소리", "없음"]]
	var out := [["소리", "%d칸" % s.cast_noise()]]
	if s.burst_noise() > 0:
		out.append(["맞거나 터질 때 소리", "%d칸" % s.burst_noise()])
	return out
