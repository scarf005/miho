class_name Info
extends RefCounted
## What the pointer is over, in a few short sentences: a creature's health,
## state, whether it sees Miho, what her claws would do to it and what it
## casts; a projectile's harm; a tile's terrain and light; a talisman's or a
## spell's effect. Built only from what Miho knows. Each line is a list of
## [text, Color] runs. Health is drawn as hearts (Term draws ♥ and ♡).

const STATE := ["쉬고 있다", "무언가를 찾고 있다", "미호를 쫓고 있다"]
## tile -> [name, what it does, health or 0 when it cannot break]
const TERRAIN := {
	World.FLOOR: ["바닥", "", 0],
	World.WALL: ["벽", "", 0],
	World.DOOR: ["문", "닫혀 있으면 빛과 시야를 막는다. 구슬에 맞으면 부서진다", 1],
	World.LANTERN: ["등불", "주위 6칸을 밝힌다. 부딪히거나 구슬에 맞으면 꺼진다", 1],
	World.LANTERN_OUT: ["꺼진 등불", "불 주문으로 다시 켤 수 있다. 수색하던 적도 켠다", 0],
	World.BAMBOO: ["대숲", "안이 들여다보이지 않는다. 밟으면 2칸까지 사각 소리가 난다. 불에 탄다", 0],
	World.BOARD: ["마루", "밟으면 3칸까지 삐걱 소리가 난다. 불에 탄다", 0],
	World.POND: ["연못", "걸어서 건널 수 없다. 주문은 위로 날아간다", 0],
	World.ASH: ["재", "다 타고 남은 자리다", 0],
}
## What a talisman adds to any spell it is part of.
const EFFECT := {
	Cards.FOX: "여우불: 다치게 하지 않는 빛이다. 초당 3칸씩 7칸 날아가 8초 동안 떠서 주위를 밝힌다",
	Cards.ORB: "구슬: 벽에 닿을 때까지 초당 2칸씩 곧게 날아간다. 맞으면 피해 1, 4칸 넘게 날아왔으면 2",
	Cards.FIRE: "불: 여우불도 피해를 1 준다. 지나간 곳과 닿은 곳에 불을 붙인다",
	Cards.WATER: "물: 빛을 지우고 소리를 내지 않는다. 등불과 불을 끈다",
	Cards.WOOD: "나무: 맞은 적을 2초 동안 덩굴로 묶는다",
	Cards.METAL: "쇠: 멈춘 곳 2칸 안의 적을 섬광으로 2초 동안 눈멀게 한다",
	Cards.EARTH: "흙: 맞은 적을 기절시키고 멈춘 곳에서 9칸까지 쿵 소리를 낸다",
}


## Lines for map tile p, or empty when Miho knows nothing there.
static func at(w: World, p: Vector2i) -> Array:
	if not Grid.inside(p):
		return []
	var i := Grid.index(p)
	if w.seen[i] == 1:
		var a := w.actor_at(p)
		if a != null:
			return creature(w, a)
		var s := w.shot_at(p)
		if s != null:
			return shot(s)
	if w.known[i] == 0:
		return []
	return terrain(w, p)


static func creature(w: World, a: Actor) -> Array:
	var spec := a.info()
	var color: Color = Palette.KIND[a.kind]
	var head := [[spec.name + " ", color], [hearts(a.hp, a.max_hp), Palette.HURT]]
	if a.faction == Actor.FOX:
		return [head, _tails(w), _hidden(w, a.pos)]
	var lines := [head]
	var elements := _elements(spec)
	if not elements.is_empty():
		var line := [["오행 ", Palette.DIM]]
		for c in elements:
			line.append([Cards.GLYPH[c] + "(" + Cards.NAME[c] + ") ", Palette.CARD[c]])
		lines.append(line)
	var state := [[STATE[a.alert], Palette.ALERT[maxi(a.alert, 1)]]]
	for c in [[a.blind, "눈이 멀었다"], [a.rooted, "묶여 있다"], [a.stunned, "기절했다"]]:
		if c[0] > 0:
			state.append([". %s (%d초)" % [c[1], c[0]], Palette.TEXT])
	lines.append(state)
	var me := w.player()
	if w.sees(a, me.pos):
		lines.append([["미호를 보고 있다", Palette.HURT]])
	else:
		lines.append([["미호를 보지 못한다", Palette.SIDE[0]]])
	var sneak := a.alert != Actor.HUNT or a.blind > 0
	var claw := World.CLAW * (World.SNEAK if sneak else 1)
	var how := "기습하면" if sneak else "할퀴면"
	lines.append([["%s 피해 " % how, Palette.TEXT], [str(claw), Palette.HURT]])
	if spec.has("club"):
		lines.append([["붙어 있으면 몽둥이로 때린다. 피해 ", Palette.TEXT], [str(spec.club), Palette.HURT]])
	for cast: Array in spec.get("casts", []):
		lines.append(_cast(a, cast))
	for t in _traits(spec):
		lines.append([[t, Palette.DIM]])
	var drop: StringName = spec.get("drop", &"")
	if drop != &"" and not w.cards.has(drop):
		(
			lines
			. append(
				[
					["쓰러뜨리면 ", Palette.TEXT],
					[Cards.NAME[drop] + " 부적", Palette.CARD[drop]],
					["을 얻는다", Palette.TEXT],
				]
			)
		)
	return lines


## A creature's elements: those of the spells it casts, in 오행 order.
static func _elements(spec: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	for c in Cards.ELEMENTS:
		if spec.get("casts", []).any(func(cast): return cast.has(c)):
			out.append(c)
	return out


static func _cast(a: Actor, cast: Array) -> Array:
	var spell := Spell.make(cast)
	var line: Array = [["%d초마다 " % a.info().cd, Palette.TEXT]]
	line.append([spell.title(), Palette.CARD[spell.cards.back()]])
	line.append([Messages._particle(spell.title(), "을", "를") + " 쏜다. ", Palette.TEXT])
	if not a.intent.is_empty() and Spell.make(a.intent).key() == spell.key():
		line.append(["지금 모으는 중", Palette.HURT])
	elif a.cooldown > 0:
		line.append(["%d초 뒤에 다시 쏜다" % a.cooldown, Palette.TEXT])
	else:
		line.append(["지금 쏠 수 있다", Palette.TEXT])
	return line


static func _traits(spec: Dictionary) -> Array:
	var out := []
	if spec.get("move", &"") == &"static":
		out.append("제자리에서 움직이지 않는다")
	if spec.get("patrol", false):
		out.append("길을 따라 순찰한다")
	if spec.get("deaf", false):
		out.append("소리를 듣지 못한다")
	if spec.get("step", 0) > 0:
		out.append("발소리가 %d칸까지 들린다" % spec.step)
	match spec.get("absorb", &""):
		&"fire":
			out.append("불이 붙은 주문은 통하지 않는다")
		&"nofire":
			out.append("불이 붙은 주문으로만 다친다")
	if spec.get("hunts", false):
		out.append("미호가 어디 있든 안다")
	return out


static func shot(s: Shot) -> Array:
	var spell := s.spell
	var side := "미호의 " if s.faction == Actor.FOX else "적의 "
	var lines := [
		[[side, Palette.SIDE[s.faction]], [spell.title(), Palette.shot_color(spell, s.faction)]]
	]
	var harm := spell.damage(s.distance())
	if harm > 0:
		lines.append([["맞으면 피해 ", Palette.TEXT], [str(harm), Palette.HURT]])
	else:
		lines.append([["맞아도 다치지 않는다", Palette.DIM]])
	if s.life > 0:
		lines.append([["%d초 뒤에 사라진다" % s.life, Palette.DIM]])
	return lines


static func terrain(w: World, p: Vector2i) -> Array:
	var spec: Array = TERRAIN[w.tile(p)]
	var name: String = spec[0]
	var note: String = spec[1]
	var health: int = spec[2]
	if p == w.stairs:
		name = "계단"
		note = "위층으로 올라갈 수 있다"
	elif p == w.elixir:
		name = "영약"
		note = "마시면 사람이 된다"
	elif w.peaches.has(p):
		name = "복숭아"
		note = "먹으면 체력을 1 되찾는다"
	var head := [[name, Palette.TEXT]]
	if health > 0:
		head.append([" " + hearts(health, health), Palette.HURT])
	var lines := [head]
	if note != "":
		lines.append([[note, Palette.DIM]])
	if w.burning.has(p):
		lines.append([["불타고 있다. %d초 뒤에 재가 된다" % w.burning[p], Palette.HURT]])
	if w.tile(p) != World.WALL:
		lines.append(_light_line(w, p))
	return lines


static func _light_line(w: World, p: Vector2i) -> Array:
	var i := Grid.index(p)
	if w.seen[i] == 0:
		if w.dim[i] == 1:
			var what := "대숲이라" if w.hides(p) else "어두워서 윤곽만 보인다."
			return [[what + " 누가 있는지 모른다", Palette.DIM]]
		return [["전에 본 곳이다. 지금은 보이지 않는다", Palette.DIM]]
	return _hidden(w, p)


## Whether heaven would see Miho standing on p.
static func _hidden(w: World, p: Vector2i) -> Array:
	if w.hides(p):
		return [["대숲 속이라 바로 옆에서만 보인다", Palette.SIDE[0]]]
	if w.lit(p):
		return [["밝아서 멀리서도 보인다", Palette.ALERT[1]]]
	return [["어두워서 바로 옆에서만 보인다", Palette.SIDE[0]]]


static func _tails(w: World) -> Array:
	return [
		["꼬리 %d/%d" % [w.tails, w.max_tails()], Palette.SIDE[0]],
		[". %d초마다 하나씩 다시 자란다" % World.TAIL_REGROW, Palette.DIM],
	]


## A talisman: what it adds, and the spells it makes with the talismans Miho has.
static func card(c: StringName) -> Array:
	var lines := [[[Cards.NAME[c] + " 부적", Palette.CARD[c]], [". 꼬리 1개", Palette.DIM]]]
	lines.append([[EFFECT[c].get_slice(": ", 1), Palette.TEXT]])
	if Cards.ELEMENTS.has(c):
		lines.append([["혼자서는 못 쓴다. 여우불이나 구슬 부적과 함께 쓴다", Palette.DIM]])
	return lines


## A spell: its name, cost, and what each of its talismans makes it do.
static func spell(s: Spell) -> Array:
	var head := [[s.title(), Palette.CARD[s.cards.back()]], [" 꼬리 %d개 " % s.cost(), Palette.DIM]]
	for c in s.cards:
		head.append([Cards.GLYPH[c], Palette.CARD[c]])
	var lines := [head]
	if s.homing():
		lines.append([["가장 가까운 적 쪽으로 한 칸에 한 번씩 꺾으며 초당 2칸씩 날아간다. 6초 뒤에 사라진다", Palette.TEXT]])
	elif s.orb:
		lines.append([[EFFECT[Cards.ORB].get_slice(": ", 1), Palette.TEXT]])
	else:
		lines.append([[EFFECT[Cards.FOX].get_slice(": ", 1), Palette.TEXT]])
	if s.orb and s.has(Cards.FIRE):
		lines.append([["불: 터지면서 주위 8칸에 불을 붙이고 피해를 1 준다", Palette.TEXT]])
	for c in s.elements():
		if not (s.orb and c == Cards.FIRE):
			lines.append([[EFFECT[c], Palette.TEXT]])
	var harm := "피해 1, 4칸 넘게 날아오면 2" if s.orb else ("피해 1" if s.damage(0) > 0 else "피해 없음")
	var noise := s.cast_noise()
	var sound := "소리 없음" if noise == 0 else "쏠 때 %d칸까지 들린다" % noise
	if s.burst_noise() > 0:
		sound += ", 터지면 %d칸" % s.burst_noise()
	lines.append([[harm + ". " + sound, Palette.DIM]])
	return lines


## Health as hearts: one full heart per point left, an empty one per point lost.
static func hearts(n: int, of: int) -> String:
	return "♥".repeat(maxi(0, n)) + "♡".repeat(maxi(0, of - maxi(0, n)))


## The lines as plain text, for tests.
static func plain(lines: Array) -> String:
	return "\n".join(lines.map(func(l): return "".join(l.map(func(r): return r[0]))))
