class_name SpellInfo
extends RefCounted
## Every number of a spell, a talisman or a projectile in flight, as Info
## lines ([text, Color] runs): its shape, damage, speed, turn, reach, the tails
## it costs, what each element does, its light and its sound.

const LABEL := Palette.DIM
const TURN_NAME := ["곧게만 간다", "45°", "90°", "135°", "마음대로"]


## A talisman, and what the queue becomes with it (null when it does not fit).
static func card(c: StringName, after: Spell) -> Array:
	var head := [[Cards.NAME[c] + " 부적", Palette.card(c)], [" 꼬리 1개", LABEL]]
	var alone := Spell.make([c])
	var lines := [head]
	if alone != null:
		lines += spell(alone).slice(1)
	else:
		lines.append([["여우불이나 구슬과 함께 쓴다", LABEL]])
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
	var c := s.slots[i]
	var tails := 2 if Cards.PAIRS.has(c) else 1
	var head := [[Cards.NAME[c], Palette.card(c)], [" 꼬리 %d개" % tails, LABEL]]
	if Cards.PAIRS.has(c):
		var parts: Array = Cards.PAIRS[c]
		head.append([" (%s+%s)" % [Cards.NAME[parts[0]], Cards.NAME[parts[1]]], LABEL])
	return [head] + spell(s)


## A spell: name, cost and slots, then every number.
static func spell(s: Spell) -> Array:
	var head := [[s.title(), Palette.card(s.slots.back())], [" " + _cost(s) + " ", LABEL]]
	for c in s.slots:
		head.append([Cards.GLYPH[c], Palette.card(c)])
	var lines := [head]
	lines.append_array(_shape(s))
	for e in Cards.ELEMENTS:
		if s.has(e):
			lines.append(_line(Cards.NAME[e], _effect(s, e), Palette.CARD[e]))
	lines.append(_line("빛", _light(s.light(Actor.FOX))))
	lines.append(_line("소리", _sound(s)))
	return lines


## A projectile in flight, from what Miho knows of `w`.
static func shot(w: World, s: Shot) -> Array:
	var spell := s.spell
	var side := "당신의 " if s.faction == Actor.FOX else "적의 "
	var lines := [
		[[side, Palette.SIDE[s.faction]], [spell.title(), Palette.shot_color(spell, s.faction)]]
	]
	lines.append(_line("피해", str(spell.damage(s.distance())), Palette.HURT))
	if s.faction == Actor.HEAVEN:
		lines.append([["다른 적도 맞힌다. 약점과 면역은 똑같이 적용된다", LABEL]])
	if s.turn > 0:
		var t := w.actor(s.target)
		var aim := "없음" if t == null else "%s (%d,%d)" % [t.info().name, t.pos.x, t.pos.y]
		if t != null and t.faction == Actor.FOX:
			aim = "당신"
		lines.append(_line("노림", aim))
		lines.append(_line("꺾임", TURN_NAME[s.turn]))
	lines.append(_line("빠르기", "초당 %d칸" % spell.speed() if s.dir != Vector2i.ZERO else "떠 있음"))
	if s.life > 0:
		lines.append(_line("남은 시간", "%d초" % s.life))
	lines.append(_line("빛", _light(spell.light(s.faction))))
	if spell.burst_noise() > 0:
		lines.append(_line("소리", "터질 때 %d칸" % spell.burst_noise()))
	return lines


static func _cost(s: Spell) -> String:
	return "꼬리 %d개" % s.cost()


static func _line(label: String, value: String, color := Palette.TEXT) -> Array:
	return [[label + " ", LABEL], [value, color]]


## Shape, damage, speed, turn and reach of a projectile spell.
static func _shape(s: Spell) -> Array:
	var lines := []
	match s.shape:
		Spell.WISP:
			lines.append(_line("모양", "여우불 %d발. 보이는 적을 체력만큼 나눠 쫓는다" % s.shots()))
			lines.append(_line("피해", "발마다 %d" % s.damage(0), Palette.HURT))
			lines.append(_line("노릴 적이 없으면", "%d칸 날아가 %d초 떠 있는다" % [Spell.RANGE, Spell.WISP_LIFE]))
		Spell.HOMING:
			lines.append(_line("모양", "유도 구슬. 가장 가까운 적을 쫓는다"))
			lines.append(_orb_harm(s))
			lines.append(_line("꺾임", "한 칸에 " + TURN_NAME[s.turn()]))
			lines.append(_line("남은 시간", "%d초" % Spell.HOMING_LIFE))
		Spell.ORB:
			lines.append(_line("모양", "구슬. 벽까지 곧게 날아간다"))
			lines.append(_orb_harm(s))
	lines.append(_line("빠르기", "초당 %d칸" % s.speed()))
	return lines


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
			var splash := " 터지면 주위 8칸에 %d." % (World.FIRE_DAMAGE + s.extra(e)) if s.orb else ""
			return "지나간 자리에 불을 붙인다." + splash + more + " 나무 적은 불탄다"
		Cards.WATER:
			return "빛과 소리를 지운다. 멈춘 곳 둘레의 등불과 불을 끈다"
		Cards.WOOD:
			return "맞은 적을 %d초 묶는다" % (Elements.ROOT + s.extra(e))
		Cards.METAL:
			return "멈춘 곳 %d칸 안의 적을 %d초 눈멀게 한다" % [World.FLASH, Elements.BLIND + s.extra(e)]
	return "맞은 적을 %d초 기절시킨다. 멈춘 곳에서 쿵 %d칸" % [Elements.STUN + s.extra(e), World.THUD]


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
