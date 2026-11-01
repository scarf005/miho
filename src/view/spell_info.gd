class_name SpellInfo
extends RefCounted
## Every number of a spell, a talisman or a projectile in flight, as Info
## lines ([text, Color] runs): its shape, damage, speed, turn, reach, the tails
## it costs, what each element does, its light and its sound.

const LABEL := Palette.DIM
const MUZZLE := ["발사 빛", "미호 칸"]
## The talismans that make each shape but a spray.
const RECIPE := {
	Spell.LEAP: Cards.TRIPLES[Cards.VAULT],
	Spell.WISP: [Cards.FOX],
	Spell.HOMING: [Cards.FOX, Cards.ORB],
	Spell.ORB: [Cards.ORB],
}
## The label of the harm a projectile does after it has flown MOMENTUM tiles.
const FAR := "%d칸 이상 날아간 뒤 피해"
const PIERCE := ["관통", "적 모두, 벽 한 칸"]
## The guns that are named (Spell.bullet, Spell.pierces, Spell.mortar), by their talismans.
const GUNS := [
	[Cards.FOX, Cards.METAL],
	[Cards.FOX, Cards.METAL, Cards.METAL],
	[Cards.ORB, Cards.EARTH, Cards.METAL],
]
## What 도약 behind a projectile does (Leap.swap): [label, value] lines.
const SWAP := [
	[Leap.SWAP_NAME, "멈춘 칸으로"],
	["맞힌 적", "자리 교환"],
	[Leap.SWAP_NAME + " 소음", "두 곳에서 %d" % Leap.SWAP_LOUD]
]
## The numbers of each status (Status) past its name and time, by key, one
## `이름: 값` line each; and what a spell that causes it says, as [label, value].
const STATUS_DOES := {
	&"wet": ["소음: %d" % Status.SPLASH],
	&"alight": ["초당 피해: %d" % World.FIRE_DAMAGE, "빛: %d칸" % Light.FIRE_RADIUS],
	&"frozen": ["다음 피해: ×%d" % Status.SHATTER],
}
const SOAK := ["젖음", "%d초" % Status.WET]
## What the hat of 감투 도깨비 and 은신 do to sight (Hat).
const HAT_SEEN := ["보임", "%d칸 안, 도깨비불 붙음" % Hat.REACH]
const ALIGHT_ON := ["불붙음", "%d초" % Status.ALIGHT]
const SPRAY_NAME := "뿌리기"
const FAN_NAME := "부채꼴 %d°" % Spray.FAN_ANGLE
## The tiles a leap and a pond-crossing spell fly over besides creatures.
const CROSSED := [World.SKY, World.POND]
## The tiles roots cannot grow under (Spray: not walkable ground, and bridges).
const ROOT_STOPS := [World.SKY, World.POND, World.WALL, World.BRIDGE]


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
	var head := [[Cards.NAME[c] + " 부적", Palette.card(c)], [" · 꼬리: %d" % Spell.price(1), LABEL]]
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


## What a talisman on the status rows shows: a compound as in the 도감, else the
## talisman and what it makes with the queue `picked`.
static func hovered(c: StringName, picked: Array[StringName]) -> Array:
	if Cards.compounds().has(c):
		return combo(c)
	return card(c, Spell.make(picked + [c]))


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
	if Guise.ANYWHERE.has(Guise.kind(s)):
		return lines + ward(s)
	if s.shape == Spell.LEAP:
		lines.append_array(_shape(s))
		var then := s.rest()
		if then != null:
			lines.append([["착지 후: ", LABEL], [then.title(), Palette.card(then.slots.back())]])
			lines.append_array(spell(then).slice(1))
		return lines
	if s.shape == Spell.SPRAY:
		lines.append_array(_spray(s))
		if not _flame(s):
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
		if Guise.ANYWHERE.has(c):
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
			_line("속는 적", "추격 중이 아닌 적"),
			_line("발톱", "기습"),
			_line("해제", "적 옆에서 %d초, 주문 사용, 피해" % Guise.BESIDE),
			_line(name + " 소음", "없음"),
		]
	if kind == Guise.TALON:
		return [
			_line(on, name),
			_line("시간", "%d초" % Guise.TALON_ROUNDS),
			_line("발톱 피해", "+%d" % Guise.TALON_HARM),
			_line(name + " 소음", "없음"),
		]
	if kind == Guise.CLOAK:
		return [
			_line(on, name),
			_line("시간", "%d초" % Guise.CLOAK_ROUNDS),
			_line(HAT_SEEN[0], HAT_SEEN[1]),
			_line("속는 적", "모든 적"),
			_line(name + " 소음", "없음"),
		]
	var dark: int = s.light(Actor.FOX).radius
	return [
		_line(on, name),
		_line("어둠", "둘레 %d칸" % dark),
		_line("시간", "%d초" % Spell.WISP_LIFE),
		_line("%s 한 장마다" % Cards.NAME[Cards.WATER], "+%d칸" % Spell.DARK_PER_WATER),
		_line("보임", "바로 옆에서만"),
		_line("해제", "둘레의 불, 켜진 등불"),
		_line(name + " 소음", "없음"),
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
			return [
				_line("범위", "%d칸" % Spray.FAN[i]),
				_line("모양", FAN_NAME),
				_line("소음", _noise(s.cast_noise())),
				_line("피해", "0", Palette.HURT),
				[["가연성.", Palette.TEXT]],
			]
		Cards.WATER:
			return [
				_line("모양", "곧게 %d칸" % Spray.JET[i]),
				_line("관통", "적") if level >= Spray.THROUGH_LEVEL else _line("멈춤", "첫 적"),
				_line("밀침", "%d칸" % Spray.PUSH[i], color),
				_line("꺼짐", "불, 등불", color),
				_line("북", "젖음", color),
				_line(SOAK[0], SOAK[1], color),
			]
		Cards.METAL:
			return _gun(level)
		Cards.EARTH:
			var out := [
				_line("모양", "둘레 %d칸" % Spray.QUAKE[i]),
				_line("기절", "%d초" % Spray.QUAKE_STUN[i], color),
			]
			if level >= Spray.CRACK_LEVEL:
				out.append(_line("벽", "금이 감", color))
			if level >= Spray.FELL_LEVEL:
				out.append(_line("금 간 벽", "무너짐", color))
			return out
	var who := "모두" if Spray.ROOT_COUNT[i] == 0 else "%d명" % Spray.ROOT_COUNT[i]
	return [
		_line("모양", "땅속 덩굴"),
		_line("거리", "%d걸음" % Spray.ROOT_REACH[i]),
		_line("대상", "보이는 가까운 적 " + who),
		_line("묶임", "%d초" % Spray.ROOT_ROUNDS[i], color),
		_line("막는 것", _names(ROOT_STOPS)),
	]


## A fan of radius r, as [label, value] lines.
static func _fan(r: int, name := "") -> Array:
	return [["모양", name + FAN_NAME + ", 반지름 %d" % r], ["범위", "보이는 칸만"]]


static func _gun(level: int) -> Array:
	var name: String = Spray.NAME[Cards.METAL][level - 1]
	var harm := _line("피해", "%d" % Spray.GUN_HARM, Palette.HURT)
	if level >= Spray.SHOTGUN_LEVEL:
		var near := _line("바로 옆 적 피해", "%d" % Spray.GUN_NEAR_HARM, Palette.HURT)
		return _lines(_fan(Spray.shotgun(level), name + ", ")) + [harm, near]
	return [_line("모양", "%s, 곧게 %d칸" % [name, Spray.PISTOL]), _line("멈춤", "첫 적"), harm]


## A compound's shape, then what each compound in it does, then the plain
## effect of each lone element.
static func _compound(s: Spell) -> Array:
	var shape: Array = Spray.SHAPE[s.slots[0]]
	var lines := _lines(_form(s))
	for c in s.compounds():
		lines.append_array(_lines(compound(c), Palette.card(c)))
	var plain := {
		Cards.FIRE: [["불타는 칸", "가연성·인화성 칸"], ["불붙음", "나무 적"], ["다시 켜짐", "꺼진 등불"]],
		Cards.WATER: [["꺼짐", "불, 등불"], ["밀침", "%d칸" % (Spray.PLAIN_PUSH + s.extra(Cards.WATER))]],
		Cards.WOOD: [["묶임", "%d초" % (Elements.ROOT + s.extra(Cards.WOOD))]],
		Cards.METAL: [["피해", "%d" % s.count(Cards.METAL)]],
		Cards.EARTH: [["기절", "%d초" % (Elements.STUN + s.extra(Cards.EARTH))]],
	}
	if shape[0] == Spray.CLEAVE:
		plain[Cards.EARTH].append(["벽", "금이 감"])
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
			return [["모양", "%d칸 앞 %s" % [shape[1], size]], ["멈춤", "벽 앞, 첫 적"]]
		Spray.ACROSS:
			var wide: int = shape[2] + s.grown(lead)
			return [["모양", "%d칸 앞에서 직각으로 %d칸" % [shape[1], wide]], ["멈춤", "벽 앞, 첫 적"]]
		Spray.AROUND:
			return [["모양", "둘레 %d칸" % n]]
		Spray.SIGHT:
			return [["대상", "보이는 적 모두" + (", 미호" if shape.size() > 2 else "")]]
		Spray.ROOTS:
			var deepest := Spray.ROOTS_LEVEL - 1
			return [
				["모양", "땅속 덩굴"],
				["거리", "%d걸음" % Spray.ROOT_REACH[deepest]],
				["대상", "보이는 적 모두"],
			]
		Spray.STRIKE:
			return [["모양", "곧게 %d칸" % n], ["관통", "적"]]
	return [["모양", "%d칸 안 첫 벽과 그 양옆" % n]]


## What compound `c` does where it reaches, as [label, value] lines (Compounds).
static func compound(c: StringName) -> Array:
	var harm := func(n: int) -> Array: return ["초당 피해", "%d" % n]
	var hot := func(kind: int) -> Array:
		var spec: Dictionary = Compounds.HOT[kind]
		return [[spec.name, "%d초" % Compounds.HOT_ROUNDS], harm.call(spec.harm)]
	match c:
		&"wildfire":
			return [
				["불타는 칸", "가연성·인화성 칸"],
				["번질 확률", "100%"],
				ALIGHT_ON,
				["초당 피해", "%d" % World.FIRE_DAMAGE]
			]
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
				["젖은 적 " + frozen, "%d초" % (Status.FROZEN_WET * Compounds.FROST)],
				[Tiles.of(World.POND, "name"), "%s이 됨" % Tiles.of(World.ICE, "name")]
			]
		&"rain":
			return [["묶임", "%d초" % Compounds.RAIN], ["꺼짐", "불, 등불"], ["북", "젖음"], SOAK]
		&"steam":
			var gas := [Gas.of(Gas.STEAM, "name") + " 양", "%d/%d" % [Compounds.STEAM, Gas.MAX]]
			return [gas, harm.call(Gas.of(Gas.STEAM, "harm")), ["북", "젖음"], SOAK]
		&"thorn":
			var name: String = Tiles.of(World.THORNS, "name")
			return [
				[name, "생김"], ["피해", "%d" % Compounds.THORN], ["지날 때 피해", "%d" % Compounds.THORN]
			]
		&"rift":
			return [["벽", "소음 없이 무너짐"]]
		&"mud":
			var name: String = Tiles.of(World.MUD, "name")
			return [
				["꺼짐", "불, 등불"], ["땅", name], ["밟으면", "묶임 %d초" % Compounds.MUD], ["발소리", "없음"], SOAK
			]
		&"volcano":
			return hot.call(Compounds.LAVA) + [["불타는 칸", "가연성·인화성 칸"], ALIGHT_ON]
		&"furnace":
			return hot.call(Compounds.MOLTEN) + [["끝 벽", "무너짐"]]
		&"hail":
			var frozen: String = Status.NAME[&"frozen"]
			return [
				["피해", "%d" % Compounds.HAIL],
				[frozen, "%d초" % Compounds.FROST],
				["젖은 적 " + frozen, "%d초" % (Status.FROZEN_WET * Compounds.FROST)],
			]
		&"frostbloom":
			return [
				[Tiles.of(World.THORNS, "name"), "생김"],
				["지날 때 피해", "%d" % Compounds.THORN],
				[Tiles.of(World.POND, "name"), "%s이 됨" % Tiles.of(World.ICE, "name")],
				["묶임", "%d초" % Compounds.BLOOM],
			]
		&"swamp":
			return compound(&"rift") + compound(&"mud") + [["묶임", "%d초" % Compounds.SWAMP]]
		&"geyser":
			return [["밀침", "%d칸" % Compounds.GEYSER]] + compound(&"steam")
		&"hypnosis":
			return [[Info.ASLEEP, "첫 적"], ["면역", Info.NO_SLEEP]]
		&"palisade":
			return [[_wall() + " 체력", "%d" % Tiles.of(World.WOOD_WALL, "health")]]
		&"beacon":
			return (
				compound(&"wildfire") + [["다시 켜짐", "보이는 꺼진 등불"], ["끝 칸 소음", "%d" % Compounds.BOOM]]
			)
		&"bind":
			return [["묶임", "%d초" % Compounds.BIND], ["피해", "%d" % Compounds.BIND_HARM]]
		&"magpie":
			return [[_names(CROSSED), Tiles.of(World.BRIDGE, "name")]]
		&"mist":
			var name: String = Gas.of(Gas.FOG, "name") + " 양"
			return [[name, "%d/%d" % [Gas.MAX, Gas.MAX]], ["냄새", "지워짐"]]
		&"sinkhole":
			return [
				["땅", Tiles.of(World.SKY, "name")],
				["그 칸의 적", "추락"],
				["꺼지지 않는 칸", "미호 칸, 계단으로 가는 길이 끊기는 칸"],
			]
		&"newmoon":
			return [["꺼짐", "불, 등불"]]
		&"discord":
			return [["싸움", "가까운 적끼리 둘씩"], ["시간", "%d초" % Mind.GRUDGE_ROUNDS]]
		&"thunder":
			return [
				["피해", "%d" % Compounds.THUNDER],
				["기절", "%d초" % Compounds.THUNDER_STUN],
			]
		&"stillness":
			return [["추격 중인 적", "제자리 수색"], ["냄새", "지워짐"]]
		Cards.SAMSARA:
			return [["체력", "+%d" % World.HEAL], ["기절", "%d초" % Compounds.SAMSARA_STUN]]
		Cards.CONQUEST:
			return [
				["피해", "%d" % Compounds.CONQUEST_HARM],
				["약점인 적 피해", "%d" % (Elements.WEAK * Compounds.CONQUEST_HARM)],
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
		["폭발 반지름", "%d" % Compounds.reach(s, &"shrapnel")],
		["폭발 피해", "%d" % (Compounds.MORTAR + s.count(Cards.METAL))],
		["주위 벽", "금이 감"],
	]


## Where a compound carried on a projectile reaches.
static func _carried(s: Spell, c: StringName) -> String:
	var r := Compounds.reach(s, c)
	if c == &"rift":
		return "멈춘 곳에서 %d칸 안 첫 벽과 그 양옆" % r
	return "멈춘 곳 " + _square(r)


static func _square(r: int) -> String:
	return "%d×%d" % [2 * r + 1, 2 * r + 1]


## The names of tile kinds, joined: "하늘, 연못".
static func _names(tiles: Array) -> String:
	return ", ".join(tiles.map(func(t): return Tiles.of(t, "name")))


## What a wooden wall is called.
static func _wall() -> String:
	return Tiles.of(World.WOOD_WALL, "name")


## Where a 도약 goes behind a projectile: "여·구 뒤 맨 끝".
static func behind() -> String:
	return "%s 뒤 맨 끝" % "·".join(Cards.FORMS.map(func(c): return Cards.GLYPH[c]))


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
		lines.append(_line("회전", _turn(s.turn)))
	lines.append(_line("속도", "초당 %d칸" % spell.speed() if s.dir != Vector2i.ZERO else "정지"))
	if s.life > 0:
		lines.append(_line("남은 시간", "%d초" % s.life))
	if spell.swaps():
		lines.append_array(_swap())
	if s.faction == Actor.FOX and Lure.lures(spell):
		lines.append_array(_lure(spell))
	lines.append(_line("빛", _light(spell.light(s.faction))))
	if spell.burst_noise() > 0:
		lines.append(_line("충돌 소음", "%d" % spell.burst_noise()))
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
		return "제한 없음"
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


## What a leap does, whoever casts it: its shape, what it crosses, what stops
## it and the sound of the landing.
static func leap(s: Spell) -> Array:
	return [
		_line("모양", "곧게 %d칸" % s.leap()),
		_line("건너는 것", _names(CROSSED) + ", 생물"),
		_line("막는 것", "벽, 닫힌 문, 등불"),
		_line("착지 소음", "%d" % Leap.LOUD),
		_line("진흙 착지 소음", "없음"),
	]


## Shape, damage, speed, turn and reach of a projectile spell; where a leap
## goes and what it is heard as.
static func _shape(s: Spell) -> Array:
	if s.shape == Spell.LEAP:
		var reach := leap(s)
		return (
			[reach[0], _line("거리", "%s 한 장마다 +%d칸" % [Cards.NAME[Cards.WOOD], Spell.LEAP_PER_WOOD])]
			+ reach.slice(1)
			+ [_line("냄새", "착지한 칸만"), _line(behind(), Leap.SWAP_NAME)]
		)
	var lines := []
	match s.shape:
		Spell.WISP:
			lines.append(_line("모양", "%s %d발" % [s.wisp(), s.shots()]))
			lines.append(_line("대상", "보이는 적, 가까운 순으로 체력만큼 나눠 맞힘"))
			lines.append(
				(
					_line("발당 피해", str(s.damage(0)), Palette.HURT)
					if s.damage(0) > 0
					else _line("피해", "0", Palette.HURT)
				)
			)
			if s.pierces():
				lines.append(_line(PIERCE[0], PIERCE[1]))
			lines.append(_line("회전", "칸당 " + _turn(s.turn())))
			if not s.gun():
				lines.append(_line("맞히면", "%d초 동안 붙음" % Spell.WISP_LIFE))
			lines.append(_line("사거리", "%d칸" % Spell.RANGE))
			lines.append(_line("지속 시간", "%d초" % Spell.WISP_LIFE))
			if Lure.lures(s):
				lines.append_array(_lure(s))
		Spell.HOMING:
			lines.append(_line("모양", Spell.SHAPE_NAME[Spell.HOMING]))
			lines.append(_line("대상", "가장 가까운 적"))
			lines.append_array(_orb_harm(s))
			lines.append(_line("회전", "칸당 " + _turn(s.turn())))
			lines.append(_line("남은 시간", "%d초" % Spell.HOMING_LIFE))
		Spell.ORB:
			lines.append(_line("모양", Spell.SHAPE_NAME[Spell.ORB]))
			lines.append(_line("경로", "벽까지 직선"))
			lines.append_array(_orb_harm(s))
	lines.append(_line("속도", "초당 %d칸" % s.speed()))
	return lines


## 여우 홀림: what a hovering wisp of 여 alone is heard as (Lure).
static func _lure(s: Spell) -> Array:
	var loud := _line("정지 중 소음", "%d초마다 %d" % [Lure.EVERY, Lure.loud(s)], Palette.SOUND)
	return [loud, _line("교활한 적", "던진 곳 수색", Palette.SOUND)]


static func _orb_harm(s: Spell) -> Array:
	return [
		_line("피해", "%d" % s.damage(0), Palette.HURT),
		_line(FAR % Spell.MOMENTUM, "%d" % s.damage(Spell.MOMENTUM), Palette.HURT),
	]


## What an element does on a projectile, with its numbers, as [label, value]
## lines.
static func _effect(s: Spell, e: StringName) -> Array:
	match e:
		Cards.FIRE:
			var out := [["불타는 칸", "지나간 가연성·인화성 칸"]]
			if s.orb:
				out.append(
					["폭발", "주위 %d칸, 피해 %d" % [Grid.DIRS.size(), World.FIRE_DAMAGE + s.extra(e)]]
				)
			if s.orb:
				out.append(["나무 적", "%s %d초" % [ALIGHT_ON[0], Status.ALIGHT]])
			else:
				out.append(ALIGHT_ON)
			return out
		Cards.WATER:
			return [["꺼짐", "멈춘 곳 %s의 불, 등불" % _square(Grid.NEAR)]]
		Cards.WOOD:
			if s.orb:
				var health: int = Tiles.of(World.WOOD_WALL, "health")
				var n := Elements.WALL + s.extra(e)
				return [[_wall(), "멈춘 곳에 직각으로 %d칸" % n], [_wall() + " 체력", "%d" % health]]
			return [["묶임", "%d초" % (Elements.ROOT + s.extra(e))]]
		Cards.METAL:
			if s.orb:
				var fells := ["벽", "한 번에 부술 수 있다"]
				return [fells] if s.mortar() else [["밀침", "%d칸" % Elements.CANNON_PUSH], fells]
			return []
	var thud := ["멈춘 곳 소음", "%d" % World.THUD]
	if s.orb:
		return [["벽", "한 번에 부술 수 있다"], thud]
	return [["기절", "%d초" % (Elements.STUN + s.extra(e))], thud]


## A lone 불's spray, whose 소음 line is in its own lines (`_spray`).
static func _flame(s: Spell) -> bool:
	return s.shape == Spell.SPRAY and s.level() > 0 and s.slots[0] == Cards.FIRE


static func _noise(n: int) -> String:
	return str(n) if n > 0 else "없음"


static func _light(l: Dictionary) -> String:
	if l.is_empty():
		return "없음"
	return ("어둠 %d칸" if Light.level(l.color) <= 0.0 else "%d칸") % l.radius


## What a spell is heard as, as [label, value] lines: when cast, and when it
## hits or bursts.
static func _sounds(s: Spell) -> Array:
	if s.cast_noise() == 0:
		return [] if s.has(&"beacon") or _flame(s) else [["소음", "없음"]]
	var out := [] if _flame(s) else [["소음", "%d" % s.cast_noise()]]
	if s.burst_noise() > 0:
		out.append(["충돌 소음", "%d" % s.burst_noise()])
	return out
