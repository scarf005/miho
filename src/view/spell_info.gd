class_name SpellInfo
extends RefCounted
## Every number of a spell, a talisman or a projectile in flight, as Info
## lines ([text, Color] runs): its shape, damage, speed, turn, reach, the tails
## it costs, what each element does, its light and its sound.

const LABEL := Palette.DIM
const MUZZLE := ["발사 빛", "쏜 칸"]
## The talismans that make each shape but a spray.
const RECIPE := {
	Spell.LEAP: Cards.TRIPLES[Cards.VAULT],
	Spell.WISP: [Cards.FOX],
	Spell.HOMING: [Cards.FOX, Cards.ORB],
	Spell.ORB: [Cards.ORB],
}
## The label of the tiles a second an orb gains each round it flies.
const ACCEL := "가속"
## The label of the harm a projectile does after it has flown MOMENTUM tiles.
const FAR := "%d칸 이상 날아간 뒤 피해"
## The label of the blast harm after MOMENTUM tiles.
const FAR_BLAST := "%d칸 이상 날아간 뒤 폭발 피해"
const PIERCE := ["관통", "적 모두, 벽 한 칸"]
## The guns that are named (Spell.bullet, Spell.pierces, Spell.mortar), by their talismans.
const GUNS := [
	[Cards.FOX, Cards.METAL],
	[Cards.FOX, Cards.METAL, Cards.METAL],
	[Cards.ORB, Cards.EARTH, Cards.METAL],
]
const SPRAY_NAME := "뿌리기"
const FAN_NAME := "부채꼴 %d°"
## The tiles a leap and a pond-crossing spell fly over besides creatures.
const CROSSED := [World.SKY, World.POND]
## The tiles roots cannot grow under (Spray: not walkable ground, and bridges).
const ROOT_STOPS := [World.SKY, World.POND, World.WALL, World.BRIDGE]


## The names of the tile kinds whose `column` holds (Tiles), in the language shown.
static func tiles_with(column: String) -> Array:
	var kinds := Tiles.ROWS.keys().filter(func(t): return Tiles.of(t, column))
	return kinds.map(func(t): return Lang.t(Tiles.of(t, "name")))


## A shape a spell takes: its name, the talismans that make it, and its numbers.
static func shape(kind: StringName) -> Array:
	if kind == Spell.SPRAY:
		return [
			[[Lang.t(SPRAY_NAME), Palette.TEXT]],
			_line("만드는 법", "오행 부적만"),
			_line("모양", "투사체 없이 닿는 칸")
		]
	var s := Spell.make(RECIPE[kind])
	return (
		[[[Lang.t(Spell.SHAPE_NAME[kind]), Palette.shot_color(s, Actor.FOX)]], _recipe(s)]
		+ _shape(s)
	)


## The talismans a spell is made of: "만드는 법: 물+나무+불".
static func _recipe(s: Spell) -> Array:
	return [[Lang.t("만드는 법: "), LABEL]] + _recipe_runs(s.cards)


## Talismans joined by "+", each in its colour.
static func _recipe_runs(cards: Array) -> Array:
	var runs := []
	for i in cards.size():
		runs.append([("+" if i > 0 else "") + Lang.t(Cards.NAME[cards[i]]), Palette.card(cards[i])])
	return runs


## A talisman, and what the queue becomes with it (null when it does not fit).
static func card(c: StringName, after: Spell) -> Array:
	var head := [
		[Lang.t(Cards.NAME[c]) + Lang.t(" 부적"), Palette.card(c)],
		[Lang.t(" · 꼬리: %d") % Spell.price(1), LABEL]
	]
	var lines: Array = [head] + spell(Spell.make([c])).slice(1)
	if after != null and after.cards.size() > 1:
		lines.append(
			[
				[Lang.t("넣으면: "), LABEL],
				[after.shown(), Palette.card(after.slots.back())],
				[" · " + _cost(after), LABEL]
			]
		)
	return lines


## A talisman in the 도감: one copy, then each further copy with the lines it changes.
static func stacked(c: StringName) -> Array:
	var lines := card(c, null)
	var before := spell(Spell.make([c])).slice(1).map(func(l): return Info.plain([l]))
	for n in range(2, Spell.MAX_SLOTS + 1):
		var copies := []
		copies.resize(n)
		copies.fill(c)
		var all := spell(Spell.make(copies))
		lines.append(all[0])
		var now: Array = all.slice(1).map(func(l): return Info.plain([l]))
		for k in now.size():
			if not before.has(now[k]):
				lines.append(all[k + 1])
		before = now
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
	var s := Spell.make(Cards.recipe(c))
	return [_slot_head(s, 0)] + spell(s).slice(1)


static func _slot_head(s: Spell, i: int) -> Array:
	var c := s.slots[i]
	var parts := Cards.recipe(c)
	var head := [
		[Lang.t(Cards.NAME[c]), Palette.card(c)],
		[Lang.t(" · 꼬리: %d") % Spell.price(parts.size()), LABEL]
	]
	if parts.size() > 1:
		head += [[" · ", LABEL]] + _recipe_runs(parts)
	return head


## A spell: name, cost and slots, then every number.
static func spell(s: Spell) -> Array:
	var head := [[s.shown(), Palette.card(s.slots.back())], [" · " + _cost(s) + " · ", LABEL]]
	for c in s.slots:
		head.append([Lang.t(Cards.GLYPH[c], "talisman"), Palette.card(c)])
	var lines := [head]
	if Guise.ANYWHERE.has(Guise.kind(s)):
		return lines + ward(s)
	if s.has(Cards.BUNSIN) and s.slots.size() == 1:
		return lines + _does(Cards.BUNSIN)
	if s.shape == Spell.LEAP:
		lines.append_array(_shape(s))
		var then := s.rest()
		if then != null:
			lines.append(
				[[Lang.t("착지 후: "), LABEL], [then.shown(), Palette.card(then.slots.back())]]
			)
			lines.append_array(spell(then).slice(1))
		return lines
	lines.append_array(_nature(s))
	if s.shape == Spell.SPRAY:
		lines.append_array(_spray(s))
		if s.level() > 0:
			lines.append_array(_lines(_reacts(s, s.slots[0]), Palette.CARD[s.slots[0]]))
		if not _flame(s):
			lines.append(_pair(MUZZLE) if s.gun() else _line("빛", "없음"))
		return lines + _lines(_sounds(s)) + ward(s)
	lines.append_array(_shape(s))
	if s.edged():
		lines.append_array(_lines(blast(s), Palette.HURT))
	for e in Cards.ELEMENTS:
		if s.has(e):
			lines.append_array(_lines(_effect(s, e) + _reacts(s, e, true), Palette.CARD[e]))
	if s.has(Cards.WATER):
		lines.append(_pair(_soak(), Palette.CARD[Cards.WATER]))
	for c in s.compounds():
		if s.mortar() and c == &"shrapnel":
			lines.append_array(_lines(_mortar(s), Palette.card(c)))
			continue
		if Guise.ALONE.has(c):
			continue
		lines.append(_line(Cards.NAME[c], _carried(s, c), Palette.card(c)))
		lines.append_array(_does(c))
	if s.swaps():
		lines.append_array(_swap())
	lines.append(_line("빛", _light(s.light(Actor.FOX))))
	if s.gun():
		lines.append(_pair(MUZZLE))
	return lines + _lines(_sounds(s)) + ward(s)


## A spell that goes on Miho herself (Guise): its name and talismans, then
## what it does there.
static func own(kind: StringName) -> Array:
	var s := Spell.make(Guise.RECIPE[kind])
	return (
		[
			[[Lang.t(Guise.NAME[kind]), Palette.card(s.slots.back())], [" · " + _cost(s), LABEL]],
			_recipe(s)
		]
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
			[[Info._text(Info.NOT_FOOLED), Palette.TEXT]],
			_line("발톱", "기습"),
			_line("풀림", Lang.t("적 옆에서 %d초, 주문 사용, 피해") % Guise.BESIDE),
			_line(Lang.t("%s 소음") % Lang.t(name), "없음"),
		]
	if kind == Guise.TALON:
		return [
			_line(on, name),
			_line("발톱 피해", "+%d" % Guise.TALON_HARM),
			_line(
				Lang.t("%s 면역인 적") % Lang.t(Cards.NAME[Cards.METAL]), "+%d" % Guise.TALON_ABSORBED
			),
			_line(Lang.t("%s 소음") % Lang.t(name), "없음"),
		]
	if kind == Guise.CLOAK:
		return [
			_line(on, name),
			_pair(hat_seen()),
			[[Info._text(Info.CLOAK_SMELT), Palette.TEXT]],
			[[Info._text(Info.CLOAK_SHOT), Palette.TEXT]],
			_line(Lang.t("%s 소음") % Lang.t(name), "없음"),
		]
	if kind == Guise.FLAME:
		return (
			[_line(on, name)]
			+ Info.nature(Guise.FLAME_KIND)
			+ [
				_line("불 주문 피해", "+%d" % Guise.FLAME_HARM),
				_line(Lang.t("%s 소음") % Lang.t(name), "없음"),
			]
		)
	if kind == Guise.RAISE:
		return Raise.TOLD.map(func(l): return [[Info._text(l), Palette.TEXT]])
	var dark: int = Guise.dark(s).light(Actor.FOX).radius
	return [
		_line(on, name),
		_line("어둠", Lang.t("둘레 %d칸") % dark),
		_line(
			Lang.t("%s 한 장마다") % Lang.t(Cards.NAME[Cards.WATER]),
			Lang.t("+%d칸") % Spell.DARK_PER_WATER
		),
		_line("보임", "바로 옆에서만"),
		_line("풀림", "둘레의 불, 켜진 등불"),
		_line(Lang.t("%s 소음") % Lang.t(name), "없음"),
	]


## What a creature's spell asks the player to dodge, as [label, value, color]:
## the element a name does not tell, the harm of a hit when it has any, how far
## a homing orb turns, and how far a spray reaches. Everything else of it is in
## its own 도감 entry.
static func cast(s: Spell) -> Array:
	var gun := s.shape == Spell.SPRAY and s.level() > 0 and s.slots[0] == Cards.METAL
	var harm := (
		Spray.GUN_HARM if gun else (0 if s.shape in [Spell.SPRAY, Spell.LEAP] else s.damage(0))
	)
	var out := []
	if _tells_nature(s):
		out.append(["오행", _nature_text(s), Palette.TEXT])
	if harm > 0:
		out.append(["피해", str(harm), Palette.HURT])
	if s.homing():
		out.append(["회전", Lang.t("칸당 %s") % Lang.t(_turn(s.turn())), Palette.TEXT])
	if s.shape == Spell.SPRAY and Spray.reach(s) > 0:
		var unit := "%d걸음" if Spray.form(s) == Spray.ROOTS else "%d칸"
		out.append(["범위", Lang.t(unit) % Spray.reach(s), Palette.TEXT])
	return out


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
				_line("범위", Lang.t("%d칸") % Spray.FAN[i]),
				_line("모양", Lang.t(FAN_NAME) % Spray.FAN_ANGLE),
				_line("소음", _noise(s.cast_noise())),
				_line("피해", "0", Palette.HURT),
				[[Lang.t("가연성."), Palette.TEXT]],
			]
		Cards.WATER:
			var out := [
				_line("모양", Lang.t("곧게 %d칸") % Spray.JET[i]),
				_line("밀침", Lang.t("%d칸") % Spray.PUSH[i], color),
				_line("꺼짐", "불, 등불", color),
				_line("맞은 북", "젖음", color),
				_pair(_soak(), color),
			]
			if level >= Spray.THROUGH_LEVEL:
				out.insert(1, _line("관통", "적"))
			return out
		Cards.METAL:
			return _gun(level)
		Cards.EARTH:
			var out := [
				_line("모양", Lang.t("둘레 %d칸") % Spray.QUAKE[i]),
				_line("기절", Lang.t("%d초") % Spray.QUAKE_STUN[i], color),
			]
			if level >= Spray.CRACK_LEVEL:
				out.append(_line("벽", "금이 감", color))
			if level >= Spray.FELL_LEVEL:
				out.append(_line("무너짐", "금 간 벽", color))
			return out
	var who := Lang.t("모두") if Spray.ROOT_COUNT[i] == 0 else Lang.t("%d명") % Spray.ROOT_COUNT[i]
	return [
		_line("모양", "땅속 덩굴"),
		_line("거리", Lang.t("%d걸음") % Spray.ROOT_REACH[i]),
		_line("대상", Lang.t("보이는 가까운 적 %s") % who),
		_line("묶임", Lang.t("%d초") % Spray.ROOT_ROUNDS[i], color),
		_line("막는 것", _names(ROOT_STOPS)),
	]


## A fan of radius r, as [label, value] lines.
static func _fan(r: int, name := "") -> Array:
	return [
		["모양", name + Lang.t(FAN_NAME) % Spray.FAN_ANGLE + Lang.t(", 반지름 %d") % r], ["범위", "보이는 칸만"]
	]


static func _gun(level: int) -> Array:
	var name: String = Spray.NAME[Cards.METAL][level - 1]
	var harm := _line("피해", "%d" % Spray.GUN_HARM, Palette.HURT)
	if level >= Spray.SHOTGUN_LEVEL:
		var near := _line("바로 옆 적 피해", "%d" % Spray.GUN_NEAR_HARM, Palette.HURT)
		return _lines(_fan(Spray.shotgun(level), Lang.t(name) + ", ")) + [harm, near]
	return [_line("모양", Lang.t("%s, 곧게 %d칸") % [Lang.t(name), Spray.PISTOL]), harm]


## A compound's shape, then what each compound in it does, then the plain
## effect of each lone element.
static func _compound(s: Spell) -> Array:
	var shape: Array = Spray.SHAPE[s.slots[0]]
	var lines := _lines(_form(s))
	for c in s.compounds():
		lines.append_array(_does(c))
	var plain := {
		Cards.FIRE: [["불타는 칸", "가연성·인화성 칸"], ["불붙음", "나무 적"], ["다시 켜짐", "꺼진 등불"]],
		Cards.WATER:
		[["꺼짐", "불, 등불"], ["밀침", Lang.t("%d칸") % (Spray.PLAIN_PUSH + s.extra(Cards.WATER))]],
		Cards.WOOD: [["묶임", Lang.t("%d초") % (Elements.ROOT + s.extra(Cards.WOOD))]],
		Cards.METAL: [["피해", "%d" % s.count(Cards.METAL)]],
		Cards.EARTH: [["기절", Lang.t("%d초") % (Elements.STUN + s.extra(Cards.EARTH))]],
	}
	if shape[0] == Spray.CLEAVE:
		plain[Cards.EARTH].append(["벽", "금이 감"])
	for e in Cards.ELEMENTS:
		if s.has(e):
			lines.append_array(_lines(plain[e] + _reacts(s, e), Palette.CARD[e]))
	if s.has(Cards.WATER):
		lines.append(_pair(_soak(), Palette.CARD[Cards.WATER]))
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
			return [["모양", Lang.t("곧게 %d칸") % n]]
		Spray.BURST, Spray.BREACH:
			var size := _square(shape[2] + s.grown(lead))
			return [["모양", Lang.t("%d칸 앞 %s") % [shape[1], size]]]
		Spray.ACROSS:
			var wide: int = shape[2] + s.grown(lead)
			return [["모양", Lang.t("%d칸 앞에서 직각으로 %d칸") % [shape[1], wide]]]
		Spray.AROUND:
			return [["모양", Lang.t("둘레 %d칸") % n]]
		Spray.SIGHT:
			return [["대상", "보이는 적 모두, 당신" if shape.size() > 2 else "보이는 적 모두"]]
	return [["모양", Lang.t("%d칸 안 첫 벽과 그 양옆") % n]]


## What compound `c` does, as lines in its colour: its numbers, then the tag of 전기.
static func _does(c: StringName) -> Array:
	var lines := _lines(compound(c), Palette.card(c))
	if Cards.ELECTRIC.has(c):
		lines.append([[Lang.t(Info.ELECTRIC) + ".", Palette.TEXT]])
	return lines


## What compound `c` does where it reaches, as [label, value] lines (Compounds).
static func compound(c: StringName) -> Array:
	var harm := func(n: int) -> Array: return ["초당 피해", "%d" % n]
	var hot := func(kind: int) -> Array:
		var spec: Dictionary = Compounds.HOT[kind]
		return [[spec.name, Lang.t("%d초") % Compounds.HOT_ROUNDS], harm.call(spec.harm)]
	match c:
		&"wildfire":
			return [
				["불타는 칸", "가연성·인화성 칸"],
				["번질 확률", "100%"],
				_alight_on(),
				["초당 피해", "%d" % World.FIRE_DAMAGE]
			]
		&"lava":
			return hot.call(Compounds.LAVA)
		&"shrapnel":
			return [["피해", "%d" % Compounds.SHRAPNEL]]
		&"frost":
			var frozen: String = Status.NAME[&"frozen"]
			return [
				[frozen, Lang.t("%d초") % Compounds.FROST],
				[
					Lang.t("젖은 적 ") + Lang.t(frozen),
					Lang.t("%d초") % (Status.FROZEN_WET * Compounds.FROST)
				],
				[
					Tiles.of(World.POND, "name"),
					Lang.t("%s이 됨") % Lang.t(Tiles.of(World.ICE, "name"))
				]
			]
		&"rain":
			return [
				["묶임", Lang.t("%d초") % Compounds.RAIN], ["꺼짐", "불, 등불"], ["맞은 북", "젖음"], _soak()
			]
		&"steam":
			var gas := [
				Lang.t("%s 양") % Lang.t(Gas.of(Gas.STEAM, "name")),
				"%d/%d" % [Compounds.STEAM, Gas.MAX]
			]
			return [gas, harm.call(Gas.of(Gas.STEAM, "harm")), ["맞은 북", "젖음"], _soak()]
		&"thorn":
			var name: String = Tiles.of(World.THORNS, "name")
			return [
				["생성", name], ["피해", "%d" % Compounds.THORN], ["지날 때 피해", "%d" % Compounds.THORN]
			]
		&"rift":
			return [["무너짐", "벽"]]
		&"mud":
			var name: String = Tiles.of(World.MUD, "name")
			return [
				["꺼짐", "불, 등불"], ["땅", name], ["밟으면", Lang.t("묶임 %d초") % Compounds.MUD], _soak()
			]
		&"furnace":
			return hot.call(Compounds.MOLTEN) + [["무너짐", "끝 벽"]]
		&"swamp":
			return compound(&"rift") + compound(&"mud") + [["묶임", Lang.t("%d초") % Compounds.SWAMP]]
		&"hypnosis":
			return [["잠듦", "맞은 적"], ["면역", Info.NO_SLEEP]]
		Cards.BUNSIN:
			var kind := Bestiary.info(c)
			return [
				["대상", "옆 빈 칸"],
				["최대 수", "%d" % Bunsin.MOST],
				["체력", "%d" % Bestiary.hp(c, 1)],
				[Lang.t("%s의 꼬리 수") % Lang.t(kind.name), "%d" % Bunsin.TAILS],
				["발톱 피해", "%d" % kind.melee.damage],
				["쓰는 주문", Lang.t("당신이 마지막에 던진 것 (꼬리 %d개 이하)") % Bunsin.TAILS],
			]
		&"palisade":
			return [[Lang.t("%s 체력") % Lang.t(_wall()), "%d" % Tiles.of(World.WOOD_WALL, "health")]]
		&"beacon":
			return (
				compound(&"wildfire") + [["다시 켜짐", "보이는 꺼진 등불"], ["끝 칸 소음", "%d" % Compounds.BOOM]]
			)
		&"magpie":
			return [[_names(CROSSED), Tiles.of(World.BRIDGE, "name")]]
		&"mist":
			var name: String = Lang.t("%s 양") % Lang.t(Gas.of(Gas.FOG, "name"))
			return [[name, "%d/%d" % [Gas.MAX, Gas.MAX]], ["지워짐", "냄새"]]
		&"sinkhole":
			return [
				["땅", Tiles.of(World.SKY, "name")],
				["그 칸의 적", "추락"],
				["꺼지지 않는 칸", "당신이 선 칸, 계단으로 가는 길이 끊기는 칸"],
			]
		&"newmoon":
			return [["꺼짐", "불, 등불"]]
		&"discord":
			return [["싸움", "가까운 적끼리 둘씩"], ["시간", Lang.t("%d초") % Mind.GRUDGE_ROUNDS]]
		&"thunder":
			return [
				["피해", "%d" % Compounds.THUNDER],
				["기절", Lang.t("%d초") % Compounds.THUNDER_STUN],
				["옮겨붙음", Lang.t("%d칸 안의 적, 최대 %d번") % [Compounds.ARC_REACH, Compounds.ARCS]],
			]
		&"stillness":
			return [["추격 중인 적", "제자리 수색"], ["지워짐", "냄새"]]
		Cards.SAMSARA:
			return [["체력", "+%d" % World.HEAL], ["기절", Lang.t("%d초") % Compounds.SAMSARA_STUN]]
		Cards.CONQUEST:
			return [
				["피해", "%d" % Compounds.CONQUEST_HARM],
				["약점인 적 피해", "%d" % (Elements.WEAK * Compounds.CONQUEST_HARM)],
			]
		Cards.DRAGON:
			return [
				["무너짐", "벽"],
				["밀침", Lang.t("%d칸, 바깥으로") % Compounds.DRAGON_PUSH],
				["기절", Lang.t("%d초") % Compounds.DRAGON_STUN],
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
		return Lang.t("멈춘 곳에서 %d칸 안 첫 벽과 그 양옆") % r
	return Lang.t("멈춘 곳 %s") % _square(r)


static func _square(r: int) -> String:
	return Lang.t("%d×%d") % [2 * r + 1, 2 * r + 1]


## The names of tile kinds, joined: "하늘, 깊은 물".
static func _names(tiles: Array) -> String:
	return ", ".join(tiles.map(func(t): return Lang.t(Tiles.of(t, "name"))))


## What a wooden wall is called.
static func _wall() -> String:
	return Tiles.of(World.WOOD_WALL, "name")


## Where a 도약 goes behind a projectile: "여·구 뒤 맨 끝".
static func behind() -> String:
	return (
		Lang.t("%s 뒤 맨 끝")
		% "·".join(Cards.FORMS.map(func(c): return Lang.t(Cards.GLYPH[c], "talisman")))
	)


## A projectile in flight, from what Miho knows of `w`.
static func shot(w: World, s: Shot) -> Array:
	var spell := s.spell
	var caster := w.actor(s.caster)
	var side := Lang.t("당신의 " if s.faction == Actor.FOX else "적의 ")
	if caster != null and caster.ally():
		side = Lang.t("%s의 ") % Lang.t(caster.info().name)
	var lines := [
		[
			[side, Palette.SIDE[s.faction]],
			[spell.shot_shown(), Palette.shot_color(spell, s.faction)]
		]
	]
	lines.append_array(_nature(spell))
	lines.append(_line("피해", str(Guise.shot_harm(w, s)), Palette.HURT))
	if s.turn > 0:
		var t := w.actor(s.target)
		lines.append(_line("대상", "없음" if t == null else Lang.t(t.info().name)))
		lines.append(_line("회전", _turn(s.turn)))
	lines.append(_line("속도", Lang.t("초당 %d칸") % s.pace() if s.dir != Vector2i.ZERO else "정지"))
	if spell.accel() > 0:
		lines.append(_line(ACCEL, Lang.t("초당 %d칸") % spell.accel()))
	if s.life > 0:
		lines.append(_line("남은 시간", Lang.t("%d초") % s.life))
	if spell.swaps():
		lines.append_array(_swap())
	if s.faction == Actor.FOX and Lure.lures(spell):
		lines.append_array(_lure(spell))
	lines.append(_line("빛", _light(spell.light(s.faction))))
	if spell.burst_noise() > 0:
		lines.append(_line("충돌 소음", "%d" % spell.burst_noise()))
	return lines


## Whether the spell tells its elements (Spell.nature): it has some and they are not
## just the talismans it is made of, which its title or recipe shows; a creature
## names its own spell, so that always tells them.
static func _tells_nature(s: Spell) -> bool:
	var held := s.cards.filter(func(c): return Cards.ELEMENTS.has(c))
	return (
		not s.nature().is_empty()
		and (s.called != "" or held.any(func(c): return not s.nature().has(c)))
	)


## The elements of the spell, "+" between them.
static func _nature_text(s: Spell) -> String:
	return "+".join(s.nature().map(func(e): return Lang.t(Cards.NAME[e])))


## "오행: 불+쇠" with each name in its colour, as the creature's line has it; no
## line for a spell with no element or one whose title names them.
static func _nature(s: Spell) -> Array:
	if not _tells_nature(s):
		return []
	var line := [[Lang.t("오행: "), LABEL]]
	for i in s.nature().size():
		var e: StringName = s.nature()[i]
		line.append([("+" if i > 0 else "") + Lang.t(Cards.NAME[e]), Palette.CARD[e]])
	return [line]


## A turn of `degrees` a tile.
static func _turn(degrees: int) -> String:
	if degrees >= Spell.TURN_STEP * Spell.TURN_FREE:
		return "제한 없음"
	return "%d°" % degrees if degrees > 0 else "없음"


static func _cost(s: Spell) -> String:
	return Lang.t("꼬리: %d") % s.cost()


static func _line(label: String, value: String, color := Palette.TEXT) -> Array:
	return [[Lang.t(label, "spell") + ": ", LABEL], [Lang.t(value), color]]


static func _pair(pair: Array, color := Palette.TEXT) -> Array:
	return _line(pair[0], pair[1], color)


## What a spell that soaks or sets alight says, as [label, value].
static func _soak() -> Array:
	return ["젖음", Lang.t("%d초") % Status.WET]


static func _alight_on() -> Array:
	return ["불붙음", Lang.t("%d초") % Status.ALIGHT]


## What the hat of 감투 도깨비 and 은신 do to sight (Hat), as [label, value].
static func hat_seen() -> Array:
	return ["보임", Lang.t("%d칸 안, 도깨비불 붙음") % Hat.REACH]


## The numbers of each status (Status) past its name and time, one `이름: 값`
## line each.
static func status_does(key: StringName) -> Array:
	match key:
		&"wet":
			return [Lang.t("소음: %d") % Status.SPLASH]
		&"alight":
			return [Lang.t("초당 피해: %d") % World.FIRE_DAMAGE, Lang.t("빛: %d칸") % Light.FIRE_RADIUS]
		&"frozen":
			return [Lang.t("다음 피해: ×%d") % Status.SHATTER]
	return []


## [label, value] pairs as lines, the value in `color`.
static func _lines(pairs: Array, color := Palette.TEXT) -> Array:
	return pairs.map(func(p): return _pair(p, color))


static func _swap() -> Array:
	return _lines(
		[
			[Leap.SWAP_NAME, "멈춘 칸으로"],
			["맞힌 적", "자리 교환"],
			[Lang.t("%s 소음") % Lang.t(Leap.SWAP_NAME), Lang.t("두 곳에서 %d") % Leap.SWAP_LOUD],
		],
		Palette.card(Cards.VAULT)
	)


## What a leap does, whoever casts it: its shape, what it crosses, what stops
## it and the sound of the landing.
static func leap(s: Spell) -> Array:
	return [
		_line("모양", Lang.t("곧게 %d칸") % s.leap()),
		_line("건너는 것", Lang.t("%s, 생물") % _names(CROSSED)),
		_line("막는 것", "벽, 닫힌 문, 등불"),
		_line("궤적", Gas.of(Gas.STEAM, "name")),
		_line("착지 소음", "%d" % Leap.LOUD),
		_line("진흙 착지 소음", "없음"),
	]


## Shape, damage, speed, turn and reach of a projectile spell; where a leap
## goes and what it is heard as.
static func _shape(s: Spell) -> Array:
	if s.shape == Spell.LEAP:
		var reach := leap(s)
		return (
			[
				reach[0],
				_line(
					"거리",
					Lang.t("%s 한 장마다 +%d칸") % [Lang.t(Cards.NAME[Cards.WOOD]), Spell.LEAP_PER_WOOD]
				)
			]
			+ reach.slice(1)
			+ [_line("냄새", "착지한 칸만"), _line(behind(), Leap.SWAP_NAME)]
		)
	var lines := []
	match s.shape:
		Spell.WISP:
			lines.append(_line("모양", Lang.t("%s %d발") % [Lang.t(s.wisp()), s.shots()]))
			lines.append(_line("대상", "보이는 적, 가까운 적부터 남은 체력만큼"))
			lines.append(
				(
					_line("발당 피해", str(s.damage(0)), Palette.HURT)
					if s.damage(0) > 0
					else _line("피해", "0", Palette.HURT)
				)
			)
			if s.pierces():
				lines.append(_line(PIERCE[0], PIERCE[1]))
			lines.append(_line("회전", Lang.t("칸당 %s") % Lang.t(_turn(s.turn()))))
			if not s.gun():
				lines.append(_line("맞히면", "달라붙음"))
			lines.append(_line("사거리", Lang.t("%d칸") % Spell.RANGE))
			lines.append(_line("지속 시간", Lang.t("%d초") % Spell.WISP_LIFE))
			if Lure.lures(s):
				lines.append_array(_lure(s))
		Spell.HOMING:
			lines.append(_line("모양", _orbs(s, Spell.SHAPE_NAME[Spell.HOMING])))
			lines.append(_line("대상", _arc() if s.shots() > 1 else "가장 가까운 적"))
			lines.append_array(_orb_harm(s))
			lines.append(_line("회전", Lang.t("칸당 %s") % Lang.t(_turn(s.turn()))))
			lines.append(_line("남은 시간", Lang.t("%d초") % Spell.HOMING_LIFE))
		Spell.ORB:
			lines.append(_line("모양", _orbs(s, Spell.SHAPE_NAME[Spell.ORB])))
			if s.shots() > 1:
				lines.append(_line("대상", _arc()))
			lines.append(_line("경로", "벽까지 직선"))
			lines.append_array(_orb_harm(s))
	lines.append(_line("속도", Lang.t("초당 %d칸") % s.speed()))
	if s.accel() > 0:
		lines.append(_line(ACCEL, Lang.t("초당 %d칸") % s.accel()))
	return lines


## An orb's shape, and how many it hurls when it hurls several.
static func _orbs(s: Spell, shape: String) -> String:
	return Lang.t("%s %d발") % [Lang.t(shape), s.shots()] if s.shots() > 1 else shape


## The creatures the orbs of one cast spread among.
static func _arc() -> String:
	return Lang.t("부채꼴 %d° 안의 적") % Homing.ARCS.back()


## What the blast of an orb that ends hurts: its radius and harm, and the harm
## after MOMENTUM tiles when that is more.
static func blast(s: Spell) -> Array:
	var near := s.blast(s.damage(0))
	var far := s.blast(s.damage(Spell.MOMENTUM))
	var out := [["폭발 반지름", "%d" % Grid.NEAR], ["폭발 피해", "%d" % near]]
	if far > near:
		out.append([Lang.t(FAR_BLAST) % Spell.MOMENTUM, "%d" % far])
	return out


## 여우 홀림: what a hovering wisp of 여 alone is heard as (Lure).
static func _lure(s: Spell) -> Array:
	var loud := _line("정지 중 소음", Lang.t("%d초마다 %d") % [Lure.EVERY, Lure.loud(s)], Palette.SOUND)
	return [loud, _line("교활한 적", "던진 곳 수색", Palette.SOUND)]


static func _orb_harm(s: Spell) -> Array:
	return [
		_line("피해", "%d" % s.damage(0), Palette.HURT),
		_line(Lang.t(FAR) % Spell.MOMENTUM, "%d" % s.damage(Spell.MOMENTUM), Palette.HURT),
	]


## What an element does on a projectile, with its numbers, as [label, value]
## lines.
static func _effect(s: Spell, e: StringName) -> Array:
	match e:
		Cards.FIRE:
			var out := [["불타는 칸", "지나간 가연성·인화성 칸"]]
			if s.orb and not s.edged():
				out.append(
					[
						"폭발",
						Lang.t("주위 %d칸, 피해 %d") % [Grid.DIRS.size(), World.FIRE_DAMAGE + s.extra(e)]
					]
				)
			if s.orb:
				out.append(["나무 적", Lang.t("%s %d초") % [Lang.t(_alight_on()[0]), Status.ALIGHT]])
			else:
				out.append(_alight_on())
			return out
		Cards.WATER:
			var out := [["꺼짐", Lang.t("멈춘 곳 %s의 불, 등불") % _square(Grid.NEAR)]]
			if s.orb:
				out.append(["밀침", Lang.t("%d칸") % (Spray.PLAIN_PUSH + s.extra(e))])
			return out
		Cards.WOOD:
			if s.orb:
				var health: int = Tiles.of(World.WOOD_WALL, "health")
				var n := Elements.WALL + s.extra(e)
				return [
					[_wall(), Lang.t("멈춘 곳에 직각으로 %d칸") % n],
					[Lang.t("%s 체력") % Lang.t(_wall()), "%d" % health]
				]
			return [["묶임", Lang.t("%d초") % (Elements.ROOT + s.extra(e))]]
		Cards.METAL:
			if s.orb:
				var fells := ["벽", "한 번에 부술 수 있다"]
				return (
					[fells] if s.mortar() else [["밀침", Lang.t("%d칸") % Elements.CANNON_PUSH], fells]
				)
			return []
	var thud := ["멈춘 곳 소음", "%d" % World.THUD]
	if s.orb:
		return [["벽", "한 번에 부술 수 있다"], thud]
	return [["기절", Lang.t("%d초") % (Elements.STUN + s.extra(e))], thud]


## What element `e` of `s` makes of the tiles it reaches (Terrain.react), as
## [what they become, tiles] lines read from the Tiles rows; `at_stop` for a
## spell that reaches the round where it stops.
static func _reacts(s: Spell, e: StringName, at_stop := false) -> Array:
	var changes := {}
	if e in Terrain.reacting(s) and e != Cards.METAL:
		for t: int in Tiles.ROWS:
			var change: Variant = Tiles.of(t, "reacts").get(e)
			if change != null and (at_stop or Spray.holds(s, t)):
				changes.get_or_add(change, []).append(Lang.t(Tiles.of(t, "name")))
	return changes.keys().map(
		func(to):
			var from := ", ".join(changes[to])
			return [
				becomes(to), Lang.t("멈춘 곳 %s의 %s") % [_square(Grid.NEAR), from] if at_stop else from
			]
	)


## The label of what turns into tile kind `to`: "바닥이 됨".
static func becomes(to: int) -> String:
	var runs := Lang.runs("{0}이/가 됨", [[Tiles.of(to, "name"), LABEL]], LABEL)
	return "".join(runs.map(func(r): return r[0]))


## A lone 불's spray, whose 소음 line is in its own lines (`_spray`).
static func _flame(s: Spell) -> bool:
	return s.shape == Spell.SPRAY and s.level() > 0 and s.slots[0] == Cards.FIRE


static func _noise(n: int) -> String:
	return str(n) if n > 0 else Lang.t("없음")


static func _light(l: Dictionary) -> String:
	if l.is_empty():
		return Lang.t("없음")
	return Lang.t("어둠 %d칸" if Light.level(l.color) <= 0.0 else "%d칸") % l.radius


## What a spell is heard as, as [label, value] lines: when cast, and when it
## hits or bursts.
static func _sounds(s: Spell) -> Array:
	if s.cast_noise() == 0:
		return [] if s.has(&"beacon") or _flame(s) else [["소음", "없음"]]
	var out := [] if _flame(s) else [["소음", "%d" % s.cast_noise()]]
	if s.burst_noise() > 0:
		out.append(["충돌 소음", "%d" % s.burst_noise()])
	return out
