class_name Info
extends RefCounted
## What the pointer is over, in a few short sentences: a creature's health,
## state, whether it sees Miho, what her claws would do to it and what it
## casts; a projectile's harm; a tile's terrain and light; a talisman's or a
## spell's effect. Built only from what Miho knows. Each line is a list of
## [text, Color] runs. Health is drawn as hearts (Term draws ♥ and ♡).

const STATE := ["쉬는 중", "수색 중", "추격 중"]
const WITS := ["둔함", "영리함", "교활함"]
## What a door does when it slides, and burns.
const DOOR_NOTE := "드르륵 소리 %d칸. 불에 탄다" % Terrain.SLIDE
## What a drum does, a short sentence a line; %d is how far heaven runs to it.
const DRUM_NOTE := (
	"치면 층 전체에 둥 소리가 난다\n"
	+ "듣는 적은 친 적이 당신을\n"
	+ "마지막으로 본 곳을 수색한다\n"
	+ "영리한 적은 걸어서 %d칸 안에서\n"
	+ "당신을 쫓으면 달려와 친다\n"
	+ "구슬이나 몸으로 부딪치면 찢어진다\n"
	+ "불에 탄다"
)
## tile -> [name, what it does, health or 0 when it cannot break]
const TERRAIN := {
	World.FLOOR: ["바닥", "", 0],
	World.WALL: ["벽", "", 2],
	World.DOOR: ["문", "닫혀 있다\n시야는 막고 빛은 지나간다\n" + DOOR_NOTE, 1],
	World.DOOR_OPEN: ["열린 문", "시야와 빛이 지나간다\n문 닫기 키로 닫는다\n" + DOOR_NOTE, 0],
	World.LANTERN: ["등불", "주위 6칸을 밝힌다", 1],
	World.LANTERN_OUT: ["꺼진 등불", "불로 다시 켤 수 있다. 수색하는 적도 켠다", 1],
	World.BAMBOO: ["대숲", "안이 보이지 않는다. 사각 소리 2칸. 불에 탄다", 0],
	World.BOARD: ["마루", "삐걱 소리 3칸. 불에 탄다", 0],
	World.POND: ["연못", "건널 수 없다. 주문은 넘어간다", 0],
	World.ASH: ["재", "", 0],
	World.LANTERN_BROKEN: ["부서진 등불", "", 0],
	World.WALL_CRACKED: ["금 간 벽", "", 1],
	World.RUBBLE: ["무너진 벽", "", 0],
	World.SKY: ["하늘", "건널 수 없다. 주문은 넘어간다", 0],
	World.WINDOW: ["창문", "보이지만 지나갈 수 없다", 1],
	World.BRIDGE: ["하늘다리", "달빛에 드러난다. 삐걱 소리 3칸", 0],
	World.DRUM: ["북", DRUM_NOTE % Drums.REACH, 1],
	World.DRUM_TORN: ["찢어진 북", "소리가 나지 않는다", 0],
}
## What a talisman adds to any spell it is part of.
const EFFECT := {
	Cards.FOX: "여우불: 초당 3칸씩 7칸 날아가 8초 동안 떠 있다",
	Cards.ORB: "구슬: 벽까지 초당 2칸씩 곧게 날아간다",
	Cards.FIRE: "불: 여우불도 피해 1. 지나간 자리에 불을 붙인다",
	Cards.WATER: "물: 빛과 소리를 지운다. 등불과 불을 끈다",
	Cards.WOOD: "나무: 맞은 적을 2초 묶는다",
	Cards.METAL: "쇠: 멈춘 곳 2칸 안의 적을 2초 눈멀게 한다",
	Cards.EARTH: "흙: 맞은 적을 기절시킨다. 멈춘 곳에서 쿵 소리 9칸",
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
	var elements := Bestiary.elements(a.kind)
	if not elements.is_empty():
		var line := [["오행 ", Palette.DIM]]
		for c in elements:
			line.append([Cards.GLYPH[c] + "(" + Cards.NAME[c] + ") ", Palette.CARD[c]])
		lines.append(line)
		lines.append(_weakness(a.kind))
	var state := [[STATE[a.alert], Palette.ALERT[maxi(a.alert, 1)]]]
	for c in [[a.blind, "눈이 멀었다"], [a.rooted, "묶여 있다"], [a.stunned, "기절했다"]]:
		if c[0] > 0:
			state.append([". %s (%d초)" % [c[1], c[0]], Palette.TEXT])
	lines.append(state)
	if a.drumming():
		lines.append([["북을 치러 간다", Palette.SOUND]])
	var me := w.player()
	if w.sees(a, me.pos):
		lines.append([["당신을 보고 있다", Palette.HURT]])
	else:
		lines.append([["당신을 볼 수 없다", Palette.SIDE[0]]])
	var sneak := a.unaware()
	var claw := World.CLAW * (World.SNEAK if sneak else 1)
	var how := "기습 시" if sneak else "공격 시"
	lines.append([["%s 피해 " % how, Palette.TEXT], [str(claw), Palette.HURT]])
	if spec.has("club"):
		lines.append(
			[["장비: 몽둥이 (피해 ", Palette.TEXT], [str(spec.club), Palette.HURT], [")", Palette.TEXT]]
		)
	for cast: Array in spec.get("casts", []):
		lines.append(_cast(a, cast))
	var traits := _traits(a, elements)
	if not traits.is_empty():
		lines.append([[" · ".join(traits), Palette.DIM]])
	var drop: StringName = spec.get("drop", &"")
	if drop != &"" and not w.cards.has(drop):
		(
			lines
			. append(
				[
					["처치 시 ", Palette.TEXT],
					[Cards.NAME[drop] + " 부적", Palette.CARD[drop]],
					["을 얻을 수 있다", Palette.TEXT],
				]
			)
		)
	return lines


## The elements whose spells hurt a creature twice as much.
static func _weakness(kind: StringName) -> Array:
	var line := [["약점: ", Palette.DIM]]
	for c in Bestiary.weak_to(kind):
		line.append([Cards.NAME[c], Palette.CARD[c]])
		line.append([", ", Palette.DIM])
	line.pop_back()
	line.append([" (피해 ×2)", Palette.DIM])
	return line


static func _cast(a: Actor, cast: Array) -> Array:
	var spell := Spell.make(cast)
	var line: Array = [["주술: ", Palette.TEXT], [spell.title(), Palette.CARD[spell.cards.back()]]]
	line.append([" (%d초마다)" % a.info().cd, Palette.TEXT])
	if not a.intent.is_empty() and Spell.make(a.intent).key() == spell.key():
		line.append([", 모으는 중", Palette.HURT])
	elif a.cooldown > 0:
		line.append([", %d초 뒤" % a.cooldown, Palette.TEXT])
	return line


static func _traits(a: Actor, elements: Array) -> Array:
	var spec := a.info()
	var out := [WITS[Bestiary.wits(a.kind)]]
	if a.wary > 0:
		out.append("경계 중 (%d초)" % a.wary)
	if spec.get("move", &"") == &"static":
		out.append("이동 불가")
	if spec.get("patrol", false):
		out.append("순찰")
	if spec.get("deaf", false):
		out.append("청각 없음")
	if spec.get("step", 0) > 0:
		out.append("발소리 %d칸" % spec.step)
	match spec.get("absorb", &""):
		&"fire":
			out.append("불 면역")
		&"nofire":
			out.append("불로만 피해")
	if elements.has(Cards.WOOD):
		out.append("불에 탐")
	if spec.get("hunts", false):
		out.append("당신 위치를 앎")
	return out


static func shot(s: Shot) -> Array:
	var spell := s.spell
	var side := "당신의 " if s.faction == Actor.FOX else "적의 "
	var lines := [
		[[side, Palette.SIDE[s.faction]], [spell.title(), Palette.shot_color(spell, s.faction)]]
	]
	var harm := spell.damage(s.distance())
	if harm > 0:
		lines.append([["피해 ", Palette.TEXT], [str(harm), Palette.HURT]])
	else:
		lines.append([["피해 없음", Palette.DIM]])
	if s.life > 0:
		lines.append([["%d초 뒤 사라진다" % s.life, Palette.DIM]])
	return lines


static func terrain(w: World, p: Vector2i) -> Array:
	var spec: Array = TERRAIN[w.tile(p)]
	var name: String = spec[0]
	var note: String = spec[1]
	var health: int = spec[2] if Terrain.breakable(w, p) else 0
	if p == w.stairs:
		name = "계단"
		note = "위층으로 올라갈 수 있다"
	elif p == w.elixir:
		name = "영약"
		note = "사람이 된다"
	elif w.peaches.has(p):
		name = "복숭아"
		note = "체력 1 회복. 가득 찼으면 최대 체력 +1"
	var head := [[name, Palette.TEXT]]
	if health > 0:
		head.append([" " + hearts(health, health), Palette.HURT])
	var lines := [head]
	for part in note.split("\n", false):
		lines.append([[part, Palette.DIM]])
	if w.tile(p) == World.DRUM:
		lines.append(_drum_line(w, p))
	if w.burning.has(p):
		lines.append([["불타는 중. %d초 뒤 재가 된다" % w.burning[p], Palette.HURT]])
	if not Terrain.wall(w.tile(p)):
		lines.append(_light_line(w, p))
	return lines


## Whether a drum would sound: wet ones are silent, for how long.
static func _drum_line(w: World, p: Vector2i) -> Array:
	if w.wet.has(p):
		return [["젖어서 소리가 나지 않는다 (%d초)" % w.wet[p], Palette.SIDE[0]]]
	return [["물에 젖으면 %d초 동안 소리가 없다" % Drums.WET_ROUNDS, Palette.DIM]]


static func _light_line(w: World, p: Vector2i) -> Array:
	var i := Grid.index(p)
	if w.seen[i] == 0:
		if w.dim[i] == 1:
			var what := "대숲이라" if w.hides(p) else "어두워서"
			return [[what + " 누가 있는지 알 수 없다", Palette.DIM]]
		return [["지금은 보이지 않는다", Palette.DIM]]
	return _hidden(w, p)


## Whether heaven would see Miho standing on p.
static func _hidden(w: World, p: Vector2i) -> Array:
	if w.hides(p):
		return [["대숲 속. 바로 옆에서만 보인다", Palette.SIDE[0]]]
	if w.lit(p):
		return [["밝다. 멀리서도 보인다", Palette.ALERT[1]]]
	return [["어둡다. 바로 옆에서만 보인다", Palette.SIDE[0]]]


static func _tails(w: World) -> Array:
	return [
		["꼬리 %d/%d" % [w.tails, w.max_tails()], Palette.SIDE[0]],
		[". %d초마다 1개 회복" % World.TAIL_REGROW, Palette.DIM],
	]


## A talisman: what it adds to a spell; a form alone is already a spell.
static func card(c: StringName) -> Array:
	var head := [[Cards.NAME[c] + " 부적", Palette.CARD[c]], [" 꼬리 1개", Palette.DIM]]
	if Cards.FORMS.has(c):
		return [head] + spell(Spell.make([c])).slice(1)
	return [
		head, [[EFFECT[c].get_slice(": ", 1), Palette.TEXT]], [["여우불이나 구슬과 함께 쓴다", Palette.DIM]]
	]


## A spell: its name, cost, and what each of its talismans makes it do.
static func spell(s: Spell) -> Array:
	var head := [[s.title(), Palette.CARD[s.cards.back()]], [" 꼬리 %d개 " % s.cost(), Palette.DIM]]
	for c in s.cards:
		head.append([Cards.GLYPH[c], Palette.CARD[c]])
	var lines := [head]
	if s.homing():
		lines.append([["가장 가까운 적을 쫓아 초당 2칸씩 날아간다. 6초 뒤 사라진다", Palette.TEXT]])
	elif s.orb:
		lines.append([[EFFECT[Cards.ORB].get_slice(": ", 1), Palette.TEXT]])
	else:
		lines.append([[EFFECT[Cards.FOX].get_slice(": ", 1), Palette.TEXT]])
	if s.orb and s.has(Cards.FIRE):
		lines.append([["불: 터지면 주위 8칸에 피해 1, 불을 붙인다", Palette.TEXT]])
	for c in s.elements():
		if not (s.orb and c == Cards.FIRE):
			lines.append([[EFFECT[c], Palette.TEXT]])
	var harm := "피해 1, 4칸 넘게 날면 2" if s.orb else ("피해 1" if s.damage(0) > 0 else "피해 없음")
	var noise := s.cast_noise()
	var sound := "소리 없음" if noise == 0 else "소리 %d칸" % noise
	if s.burst_noise() > 0:
		sound += ", 터질 때 %d칸" % s.burst_noise()
	lines.append([[harm + ". " + sound, Palette.DIM]])
	return lines


## Health as hearts: one full heart per point left, an empty one per point lost.
static func hearts(n: int, of: int) -> String:
	return "♥".repeat(maxi(0, n)) + "♡".repeat(maxi(0, of - maxi(0, n)))


## The lines as plain text, for tests.
static func plain(lines: Array) -> String:
	return "\n".join(lines.map(func(l): return "".join(l.map(func(r): return r[0]))))
