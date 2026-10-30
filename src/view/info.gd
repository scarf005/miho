class_name Info
extends RefCounted
## What the pointer is over, in a few short lines: a creature's health, state,
## whether it sees Miho, what her claws would do to it and what it casts; a
## projectile's harm; a tile's terrain and light; a talisman's effect. Built
## only from what Miho knows. Each line is a list of [text, Color] runs.

const STATE := ["쉰다", "수색한다", "미호를 쫓는다"]
const TERRAIN := {
	World.FLOOR: ["바닥", ""],
	World.WALL: ["벽", ""],
	World.DOOR: ["문", "닫히면 빛과 시야를 막는다. 구슬에 부서진다"],
	World.LANTERN: ["등불", "주위 6칸을 밝힌다. 부딪치면 꺼진다"],
	World.LANTERN_OUT: ["꺼진 등불", "불로 켠다. 수색하는 적도 켠다"],
	World.BAMBOO: ["대숲", "속이 안 보인다. 밟으면 소리 2칸. 탄다"],
	World.BOARD: ["마루", "밟으면 삐걱 소리 3칸. 탄다"],
	World.POND: ["연못", "못 걷는다. 주문은 넘어 난다"],
	World.ASH: ["재", "타고 남았다"],
}
const EFFECT := {
	Cards.FOX: ["해 없는 빛. 7칸 날아가 8초 떠 있다", "소리 2칸"],
	Cards.ORB: ["벽까지 곧게 난다. 피해 1, 4칸 넘게 날면 2", "소리 5칸, 터지면 7칸"],
	Cards.FIRE: ["태운다. 여우불도 피해 1", "구슬은 주위 8칸도 태운다"],
	Cards.WATER: ["어둠과 침묵. 빛을 지우고", "소리를 내지 않는다"],
	Cards.WOOD: ["맞은 적을 2초 묶는다", ""],
	Cards.METAL: ["끝난 곳 2칸 안을 섬광으로", "2초 눈멀게 한다"],
	Cards.EARTH: ["맞은 적을 기절시키고", "끝난 곳에서 9칸까지 울린다"],
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
	var head := [[spec.glyph + " " + spec.name + " ", color], [_pips(a.hp, a.max_hp), Palette.HURT]]
	if a.faction == Actor.FOX:
		return [head, _tails(w), _hidden(w, a.pos)]
	var lines := [head]
	var state := [[STATE[a.alert], Palette.ALERT[maxi(a.alert, 1)]]]
	for c in [[a.blind, "눈멂"], [a.rooted, "묶임"], [a.stunned, "기절"]]:
		if c[0] > 0:
			state.append([" · %s %d초" % [c[1], c[0]], Palette.TEXT])
	lines.append(state)
	var me := w.player()
	if w.sees(a, me.pos):
		lines.append([["미호가 보인다", Palette.HURT]])
	else:
		lines.append([["미호를 못 본다", Palette.SIDE[0]]])
	var sneak := a.alert != Actor.HUNT or a.blind > 0
	var claw := World.CLAW * (World.SNEAK if sneak else 1)
	lines.append([["발톱 %d%s" % [claw, " (기습)" if sneak else ""], Palette.KIND[&"miho"]]])
	if spec.has("club"):
		lines.append([["붙으면 몽둥이 %d" % spec.club, Palette.HURT]])
	for cast: Array in spec.get("casts", []):
		lines.append(_cast(a, cast))
	var traits := _traits(spec)
	if not traits.is_empty():
		lines.append([[" · ".join(traits), Palette.DIM]])
	var drop: StringName = spec.get("drop", &"")
	if drop != &"" and not w.cards.has(drop):
		lines.append([["쓰러뜨리면 ", Palette.TEXT], [Cards.GLYPH[drop], Palette.CARD[drop]]])
	return lines


static func _cast(a: Actor, cast: Array) -> Array:
	var spell := Spell.make(cast)
	var line := []
	for c in spell.cards:
		line.append([Cards.GLYPH[c], Palette.CARD[c]])
	var when := "%d초마다" % a.info().cd
	if not a.intent.is_empty() and Spell.make(a.intent).key() == spell.key():
		when = "지금 모으는 중"
	elif a.cooldown > 0:
		when += ", %d초 뒤" % a.cooldown
	line.append([" %s %s" % [spell.title(), when], Palette.TEXT])
	return line


static func _traits(spec: Dictionary) -> Array:
	var out := []
	if spec.get("move", &"") == &"static":
		out.append("붙박이")
	if spec.get("patrol", false):
		out.append("순찰")
	if spec.get("deaf", false):
		out.append("소리 못 들음")
	if spec.get("step", 0) > 0:
		out.append("발소리 %d칸" % spec.step)
	match spec.get("absorb", &""):
		&"fire":
			out.append("불을 먹음")
		&"nofire":
			out.append("불로만 다침")
	if spec.get("hunts", false):
		out.append("미호가 어디 있든 앎")
	return out


static func shot(s: Shot) -> Array:
	var spell := s.spell
	var side := "미호의 " if s.faction == Actor.FOX else "하늘의 "
	var lines := [
		[
			[Palette.shot_glyph(spell) + " ", Palette.shot_color(spell, s.faction)],
			[side + spell.title(), Palette.TEXT],
		]
	]
	var harm := spell.damage(s.distance())
	if harm > 0:
		lines.append([["피해 %d" % harm, Palette.HURT]])
	else:
		lines.append([["해 없음", Palette.DIM]])
	if s.life > 0:
		lines.append([["%d초 뒤 사라짐" % s.life, Palette.DIM]])
	return lines


static func terrain(w: World, p: Vector2i) -> Array:
	var spec: Array = TERRAIN[w.tile(p)]
	var name: String = spec[0]
	var note: String = spec[1]
	if p == w.stairs:
		name = "계단"
		note = "밟으면 위층으로 오른다"
	elif p == w.elixir:
		name = "영약"
		note = "마시면 사람이 된다"
	elif w.peaches.has(p):
		name = "복숭아"
		note = "먹으면 체력 +1"
	var lines := [[[name, Palette.TEXT]]]
	if note != "":
		lines.append([[note, Palette.DIM]])
	if w.burning.has(p):
		lines.append([["불탄다. %d초 뒤 재가 된다" % w.burning[p], Palette.HURT]])
	if w.tile(p) != World.WALL:
		lines.append(_light_line(w, p))
	return lines


static func _light_line(w: World, p: Vector2i) -> Array:
	var i := Grid.index(p)
	if w.seen[i] == 0:
		if w.dim[i] == 1:
			var what := "대숲" if w.hides(p) else "어둠 속 윤곽"
			return [[what + ". 누가 있는지 모른다", Palette.DIM]]
		return [["기억. 지금은 안 보인다", Palette.DIM]]
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
		[" %d초마다 하나 돋는다" % World.TAIL_REGROW, Palette.DIM],
	]


static func card(c: StringName) -> Array:
	var lines := [[[Cards.GLYPH[c] + " " + Cards.NAME[c], Palette.CARD[c]], [" 꼬리 1", Palette.DIM]]]
	for text: String in EFFECT[c]:
		if text != "":
			lines.append([[text, Palette.TEXT]])
	if Cards.ELEMENTS.has(c):
		lines.append([["여우불이나 구슬과 함께 쓴다", Palette.DIM]])
	return lines


static func _pips(n: int, of: int) -> String:
	return "■".repeat(n) + "□".repeat(maxi(0, of - n))


## The lines as plain text, for tests.
static func plain(lines: Array) -> String:
	return "\n".join(lines.map(func(l): return "".join(l.map(func(r): return r[0]))))
