class_name SpellInfo
extends RefCounted
## Every number of a spell, a talisman or a projectile in flight, as Info
## lines ([text, Color] runs): its shape, damage, speed, turn, reach, the tails
## it costs, what each element does, its light and its sound.

const LABEL := Palette.DIM
const MUZZLE := "발사 시 당신 칸을 밝힌다"
## The talismans that make each shape but a spray.
const RECIPE := {
	Spell.LEAP: Cards.TRIPLES[Cards.VAULT],
	Spell.WISP: [Cards.FOX],
	Spell.HOMING: [Cards.FOX, Cards.ORB],
	Spell.ORB: [Cards.ORB],
}
## What 도약 behind a projectile does (Leap.swap): [label, value] lines.
const SWAP := [["바꿔치기", "멈춘 칸으로 이동"], ["맞힌 적", "자리 교환"], ["바꿔치기 소리", "%d칸" % Leap.SWAP_LOUD]]
## The numbers of each status (Status) past its name and time, by key, and
## what a spell that causes it says.
const STATUS_DOES := {
	&"wet": "%s %d칸." % [Status.SPLASH_WORD, Status.SPLASH],
	&"alight": "매 초 피해 %d. 빛 %d칸." % [World.FIRE_DAMAGE, Light.FIRE_RADIUS],
	&"frozen": "다음 피해 ×2.",
}
const SOAK := "젖음 %d초." % Status.WET
const ALIGHT_ON := "맞은 적 불붙음 %d초." % Status.ALIGHT
const SPRAY_NAME := "뿌리기"
const SPRAY_NOTE := "오행 부적만 쓰면 투사체 없이 닿는 칸을 덮는다"


## A shape a spell takes: its name, the talismans that make it, and its numbers.
static func shape(kind: StringName) -> Array:
	if kind == Spell.SPRAY:
		return [[[SPRAY_NAME, Palette.TEXT]], [[SPRAY_NOTE, LABEL]]]
	var s := Spell.make(RECIPE[kind])
	return [[[Spell.SHAPE_NAME[kind], Palette.shot_color(s, Actor.FOX)]], _recipe(s)] + _shape(s)


## The talismans a spell is made of: "만드는 법: 물+나무+불".
static func _recipe(s: Spell) -> Array:
	var made := [["만드는 법: ", LABEL]]
	for i in s.cards.size():
		made.append([("+" if i > 0 else "") + Cards.NAME[s.cards[i]], Palette.card(s.cards[i])])
	return made


## A talisman, and what the queue becomes with it (null when it does not fit).
static func card(c: StringName, after: Spell) -> Array:
	var head := [[Cards.NAME[c] + " 부적", Palette.card(c)], [" 꼬리: 1", LABEL]]
	var lines: Array = [head] + spell(Spell.make([c])).slice(1)
	if after != null and after.cards.size() > 1:
		lines.append(
			[
				["넣으면 ", LABEL],
				[after.title(), Palette.card(after.slots.back())],
				[" " + _cost(after), LABEL]
			]
		)
	return lines


## A queue slot: its talisman and its tails, then the whole spell.
static func slot(s: Spell, i: int) -> Array:
	return [_slot_head(s, i)] + spell(s)


## A compound talisman alone: its tails and parts, then what it does.
static func combo(c: StringName) -> Array:
	var s := Spell.make(Cards.made_of(c))
	return [_slot_head(s, 0)] + spell(s).slice(1)


static func _slot_head(s: Spell, i: int) -> Array:
	var c := s.slots[i]
	var parts := Cards.made_of(c)
	var head := [[Cards.NAME[c], Palette.card(c)], [" 꼬리: %d" % parts.size(), LABEL]]
	if parts.size() > 1:
		head.append([" (%s)" % "+".join(parts.map(func(e): return Cards.NAME[e])), LABEL])
	return head


## A spell: name, cost and slots, then every number.
static func spell(s: Spell) -> Array:
	var head := [[s.title(), Palette.card(s.slots.back())], [" " + _cost(s) + " ", LABEL]]
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
		lines.append(_line("빛", MUZZLE if s.gun() else "없음"))
		lines.append(_line("소리", _sound(s)))
		return lines + ward(s)
	lines.append_array(_shape(s))
	for e in Cards.ELEMENTS:
		if s.has(e):
			lines.append(_line(Cards.NAME[e], _effect(s, e), Palette.CARD[e]))
	if s.has(Cards.WATER):
		lines.append(_line(Cards.NAME[Cards.WATER], SOAK, Palette.CARD[Cards.WATER]))
	for c in s.compounds():
		lines.append(_line(Cards.NAME[c], _carried(s, c), Palette.card(c)))
		for part in compound(c):
			lines.append(_line(Cards.NAME[c], part, Palette.card(c)))
	if s.swaps():
		lines.append_array(_swap())
	var light := _light(s.light(Actor.FOX))
	lines.append(_line("빛", light + (". " + MUZZLE if s.gun() else "")))
	lines.append(_line("소리", _sound(s)))
	return lines + ward(s)


## A spell that goes on Miho herself (Guise): its name and talismans, then
## what it does there.
static func own(kind: StringName) -> Array:
	var s := Spell.make(Guise.RECIPE[kind])
	return (
		[[[Guise.NAME[kind], Palette.card(s.slots.back())], [" " + _cost(s), LABEL]], _recipe(s)]
		+ ward(s)
	)


## What `s` does cast on Miho herself, with , or a click on her; nothing for a
## spell that does not go on her.
static func ward(s: Spell) -> Array:
	var on := "자신에게 (,)"
	var kind := Guise.kind(s)
	if kind == &"":
		return []
	var name: String = Guise.NAME[kind]
	if kind == Guise.GUISE:
		return [
			_line(on, "둔갑. 마지막으로 처치한 적의 모습이 %d초 동안 된다" % Guise.rounds(s)),
			_line(name, "%s 한 장마다 %d초 더. 소리가 없다" % [Cards.NAME[Cards.WOOD], Guise.PER_WOOD]),
			_line(name, "추격 중이 아닌 적은 당신을 알아보지 못한다. 발톱은 기습이 된다"),
			_line(name, "적 옆에 %d초 있거나 주문을 쓰거나 맞으면 풀린다" % Guise.BESIDE),
		]
	var dark: int = s.light(Actor.FOX).radius
	return [
		_line(on, "그림자. %d초 동안 당신 둘레 %d칸이 어두워진다" % [Spell.WISP_LIFE, dark]),
		_line(name, "%s 한 장마다 1칸 더. 소리가 없다" % Cards.NAME[Cards.WATER]),
		_line(name, "바로 옆 칸에서는 보인다"),
		_line(name, "둘레에 불이 붙거나 등불이 켜지면 걷힌다"),
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
			var out := [_line("모양", _fan(Spray.FAN[i])), _line("불", "타는 칸에 불을 붙인다", color)]
			if level >= 2:
				out.append(_line("불", ALIGHT_ON, color))
				out.append(_line("피해", "불이 붙은 다음 초부터 매 초 %d" % World.FIRE_DAMAGE, Palette.HURT))
			if level >= 3:
				out.append(_line("불", "늘 번진다", color))
			return out
		Cards.WATER:
			var reach := "적을 꿰뚫는다" if level >= 3 else "첫 적에서 멈춘다"
			return [
				_line("모양", "곧게 %d칸, %s" % [Spray.JET[i], reach]),
				_line("물", "적을 %d칸 민다" % Spray.PUSH[i], color),
				_line("물", "하늘로 밀린 적은 떨어진다", color),
				_line("물", "불과 등불을 끄고 북을 적신다", color),
				_line("물", SOAK, color),
			]
		Cards.METAL:
			return _gun(level)
		Cards.EARTH:
			var out := [
				_line("모양", "당신 둘레 %d칸. 방향 무관" % Spray.QUAKE[i]),
				_line("흙", "적을 %d초 기절시킨다" % Spray.QUAKE_STUN[i], color),
			]
			if level >= 2:
				out.append(_line("흙", ["벽에 금이 간다", "벽에 금이 가고 금 간 벽은 무너진다"][i - 1], color))
			return out
	var who := "모두" if Spray.ROOT_COUNT[i] == 0 else "%d명" % Spray.ROOT_COUNT[i]
	return [
		_line("모양", "땅속 뿌리. %d걸음 안" % Spray.ROOT_REACH[i]),
		_line("노림", "보이는 가까운 적 " + who),
		_line("나무", "%d초 묶는다" % Spray.ROOT_ROUNDS[i], color),
		_line("막힘", "하늘, 연못, 벽, 하늘다리"),
	]


static func _fan(r: int) -> String:
	return "부채꼴 90°, 반지름 %d. 보이는 칸만" % r


static func _gun(level: int) -> Array:
	var shape := "권총. 곧게 %d칸, 첫 적에서 멈춘다" % Spray.PISTOL
	var harm := "1"
	if level == 2:
		shape = "산탄. " + _fan(Spray.SHOTGUN)
		harm = "적마다 1, 바로 옆 적은 2"
	elif level >= 3:
		shape = "철갑탄. 곧게 %d칸" % Spray.PIERCE
		harm = "적마다 %d" % Spray.PIERCE_HARM
	var out := [_line("모양", shape)]
	if level >= 3:
		out.append(_line("꿰뚫음", "모든 적과 벽 하나"))
	out.append(_line("피해", harm + ". 약점 시 ×2", Palette.HURT))
	return out


## A compound's shape, then what each compound in it does, then the plain
## effect of each lone element.
static func _compound(s: Spell) -> Array:
	var lead := s.slots[0]
	var shape: Array = Spray.SHAPE[lead]
	var n: int = shape[1] + s.extra(lead)
	var text: String = {
		Spray.FAN_SHAPE: _fan(n),
		Spray.LINE: "곧게 %d칸, 첫 적에서 멈춘다" % n,
		Spray.BURST: "%d칸 앞 %s. 막힐 시 그 앞" % [shape[1], _square(1 + s.extra(lead))],
		Spray.CLEAVE: "%d칸 안 첫 벽과 그 양옆" % n,
	}[shape[0]]
	var lines := [_line("모양", text)]
	for c in s.compounds():
		for part in compound(c):
			lines.append(_line(Cards.NAME[c], part, Palette.card(c)))
	var plain := {
		Cards.FIRE: "타는 칸과 나무 적에 불을 붙인다",
		Cards.WATER: "불과 등불을 끄고 적을 %d칸 민다" % (1 + s.extra(Cards.WATER)),
		Cards.WOOD: "적을 %d초 묶는다" % (Elements.ROOT + s.extra(Cards.WOOD)),
		Cards.METAL: "적에게 피해 %d. 약점 시 ×2" % s.count(Cards.METAL),
		Cards.EARTH: "적을 %d초 기절시킨다" % (Elements.STUN + s.extra(Cards.EARTH)),
	}
	if shape[0] == Spray.CLEAVE:
		plain[Cards.EARTH] += ". 벽에 금이 간다"
	for e in Cards.ELEMENTS:
		if s.has(e):
			lines.append(_line(Cards.NAME[e], plain[e], Palette.CARD[e]))
	if s.has(Cards.WATER):
		lines.append(_line(Cards.NAME[Cards.WATER], SOAK, Palette.CARD[Cards.WATER]))
	return lines


## What compound `c` does where it reaches, a short sentence each (Compounds).
static func compound(c: StringName) -> Array[String]:
	var harm := "서 있으면 매 초 피해 %d"
	var hot := func(kind: int) -> Array[String]:
		var spec: Dictionary = Compounds.HOT[kind]
		var subject: String = spec.name + Messages._particle(spec.name, "이", "가")
		return ["%s %d초 남는다" % [subject, Compounds.HOT_ROUNDS], harm % spec.harm]
	var out: Array[String] = []
	match c:
		&"wildfire":
			out.assign(["타는 칸과 닿은 적에 불을 붙인다", "불이 늘 번진다", "붙은 다음 초부터 " + harm % World.FIRE_DAMAGE])
		&"lava":
			out.assign(hot.call(Compounds.LAVA))
		&"molten":
			out.assign(hot.call(Compounds.MOLTEN))
		&"shrapnel":
			out.assign(["적마다 피해 %d. 약점 시 ×2" % Compounds.SHRAPNEL])
		&"frost":
			var ice := "맞은 적 얼어붙음 %d초." % Compounds.FROST
			out.assign([ice, "젖은 적 %d초." % (2 * Compounds.FROST), "연못이 얼어 건널 수 있다"])
		&"rain":
			out.assign(["적을 %d초 묶는다" % Compounds.RAIN, "불과 등불을 끄고 북을 적신다", SOAK])
		&"steam":
			var gas := "증기 %d/%d. %d 이상이면 시야를 막는다" % [Compounds.STEAM, Gas.MAX, Gas.OPAQUE]
			out.assign([gas, harm % Gas.of(Gas.STEAM, "harm"), "북을 적신다", SOAK])
		&"thorn":
			var name: String = Tiles.of(World.THORNS, "name")
			(
				out
				. assign(
					[
						"%s이 자란다. 시야는 통하고 불에 탄다" % name,
						"적마다 피해 %d. 지나가면 피해 %d" % [Compounds.THORN, Compounds.THORN],
					]
				)
			)
		&"split":
			out.assign(["벽을 소리 없이 무너뜨린다"])
		&"mud":
			var name: String = Tiles.of(World.MUD, "name")
			(
				out
				. assign(
					[
						"불과 등불을 끄고 땅이 %s이 된다" % name,
						"걷는 데 %d초, 발소리가 없다" % Compounds.MUD,
						SOAK,
					]
				)
			)
	return out


## Where a compound carried on a projectile reaches.
static func _carried(s: Spell, c: StringName) -> String:
	var r := 1 + s.extra(c)
	if c == &"split":
		return "멈춘 곳에서 %d칸 안 첫 벽과 그 양옆" % r
	return "멈춘 곳 " + _square(r)


static func _square(r: int) -> String:
	return "%d×%d" % [2 * r + 1, 2 * r + 1]


## A projectile in flight, from what Miho knows of `w`.
static func shot(w: World, s: Shot) -> Array:
	var spell := s.spell
	var side := "당신의 " if s.faction == Actor.FOX else "적의 "
	var lines := [
		[[side, Palette.SIDE[s.faction]], [spell.title(), Palette.shot_color(spell, s.faction)]]
	]
	if elements(spell) != "":
		lines.append(_line("원소", elements(spell)))
	lines.append(_line("피해", str(spell.damage(s.distance())), Palette.HURT))
	if s.faction == Actor.HEAVEN:
		lines.append([["다른 적도 맞힌다. 약점과 면역은 똑같이 적용된다", LABEL]])
	if s.turn > 0:
		var t := w.actor(s.target)
		var aim := "없음" if t == null else "%s (%d,%d)" % [t.info().name, t.pos.x, t.pos.y]
		if t != null and t.faction == Actor.FOX:
			aim = "당신"
		lines.append(_line("노림", aim))
		lines.append(_line("꺾임", _turn(s.turn)))
	lines.append(_line("빠르기", "초당 %d칸" % spell.speed() if s.dir != Vector2i.ZERO else "떠 있음"))
	if s.life > 0:
		lines.append(_line("남은 시간", "%d초" % s.life))
	if spell.swaps():
		lines.append_array(_swap())
	if s.faction == Actor.FOX and Lure.lures(spell):
		lines.append(_lure(spell))
	lines.append(_line("빛", _light(spell.light(s.faction))))
	if spell.burst_noise() > 0:
		lines.append(_line("소리", "터질 때 %d칸" % spell.burst_noise()))
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
	return "%d°" % degrees if degrees > 0 else "곧게만 간다"


static func _cost(s: Spell) -> String:
	return "꼬리: %d" % s.cost()


static func _line(label: String, value: String, color := Palette.TEXT) -> Array:
	return [[label + " ", LABEL], [value, color]]


static func _swap() -> Array:
	return SWAP.map(func(l): return _line(l[0], l[1], Palette.card(Cards.VAULT)))


## Shape, damage, speed, turn and reach of a projectile spell; where a leap
## goes and what it is heard as.
static func _shape(s: Spell) -> Array:
	if s.shape == Spell.LEAP:
		return [
			_line("모양", "곧게 %d칸" % s.leap()),
			_line("거리", "+1칸/%s" % Cards.NAME[Cards.WOOD]),
			_line("넘는 것", "하늘, 연못, 생물"),
			_line("막는 것", "벽, 닫힌 문, 등불"),
			_line("소리", "%d칸. 진흙 위 없음." % Leap.LOUD),
			_line("냄새", "내린 칸만"),
			_line("여·구 뒤 끝", "바꿔치기"),
		]
	var lines := []
	match s.shape:
		Spell.WISP:
			lines.append(_line("모양", "여우불 %d발. 보이는 적을 체력만큼 나눠 쫓는다" % s.shots()))
			var harm := "발마다 %d" % s.damage(0) if s.damage(0) > 0 else "없음"
			lines.append(_line("피해", harm, Palette.HURT))
			lines.append(_line("꺾임", "한 칸에 " + _turn(s.turn())))
			if not s.gun():
				lines.append(_line("맞히면", "붙어서 %d초 빛난다" % Spell.WISP_LIFE))
			lines.append(_line("사거리", "%d칸" % Spell.RANGE))
			lines.append(_line("떠 있음", "%d초" % Spell.WISP_LIFE))
			if Lure.lures(s):
				lines.append(_lure(s))
		Spell.HOMING:
			lines.append(_line("모양", "유도 구슬. 가장 가까운 적을 쫓는다"))
			lines.append(_orb_harm(s))
			lines.append(_line("꺾임", "한 칸에 " + _turn(s.turn())))
			lines.append(_line("남은 시간", "%d초" % Spell.HOMING_LIFE))
		Spell.ORB:
			lines.append(_line("모양", "구슬. 벽까지 곧게 날아간다"))
			lines.append(_orb_harm(s))
	lines.append(_line("빠르기", "초당 %d칸" % s.speed()))
	return lines


## 여우 홀림: what a hovering wisp of 여 alone is heard as (Lure).
static func _lure(s: Spell) -> Array:
	var text := "2초마다 %s %d칸. 경보. 교활한 적은 던진 곳을 찾는다" % [Lure.WORD, Lure.loud(s)]
	return _line("떠 있으면", text, Palette.SOUND)


static func _orb_harm(s: Spell) -> Array:
	return _line(
		"피해",
		"%d, %d칸 이상 날면 %d" % [s.damage(0), Spell.MOMENTUM, s.damage(Spell.MOMENTUM)],
		Palette.HURT
	)


## What an element does on a projectile, with its numbers.
static func _effect(s: Spell, e: StringName) -> String:
	match e:
		Cards.FIRE:
			var more := " 피해 +%d." % s.extra(e) if s.extra(e) > 0 else ""
			if s.orb:
				var splash := " 터지면 주위 8칸에 %d." % (World.FIRE_DAMAGE + s.extra(e))
				return "지나간 자리에 불을 붙인다." + splash + more + " 나무 적은 불탄다"
			return "지나간 자리에 불을 붙인다." + more + " " + ALIGHT_ON
		Cards.WATER:
			var what := "소리를" if s.orb else "빛과 소리를"
			return what + " 지운다. 멈춘 곳 3×3의 등불과 불을 끈다"
		Cards.WOOD:
			if s.orb:
				var health: int = Tiles.of(World.WOOD_WALL, "health")
				var n := Elements.WALL + s.extra(e)
				return "멈춘 곳에 직각으로 나무벽 %d칸. 체력 %d, 불에 탄다" % [n, health]
			return "맞은 적을 %d초 묶는다" % (Elements.ROOT + s.extra(e))
		Cards.METAL:
			if s.orb:
				return (
					"대포알. 피해 +%d, %d칸 민다. 벽을 한 번에 부순다"
					% [Elements.CANNON + s.extra(e), Elements.CANNON_PUSH]
				)
			return "유도탄. 발마다 피해 %d. 빛이 없다" % (Elements.BULLET + s.extra(e))
	var thud := ". 멈춘 곳에서 쿵 %d칸" % World.THUD
	if s.orb:
		return "벽을 한 번에 부순다" + thud
	return "맞은 적을 %d초 기절시킨다" % (Elements.STUN + s.extra(e)) + thud


static func _light(l: Dictionary) -> String:
	if l.is_empty():
		return "없음"
	return ("어둠 %d칸" if Light.level(l.color) <= 0.0 else "%d칸 밝힘") % l.radius


static func _sound(s: Spell) -> String:
	if s.cast_noise() == 0:
		return "없음"
	var out := "쓸 때 %d칸" % s.cast_noise()
	if s.burst_noise() > 0:
		out += ", 맞거나 터질 때 %d칸" % s.burst_noise()
	return out
