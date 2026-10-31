class_name Info
extends RefCounted
## What the pointer is over, in a few short sentences: a creature's health,
## state, conditions, immunities, whether it sees Miho, what her claws would do
## to it and what it strikes and casts with; a projectile's harm; a tile's
## terrain, light and sound; a talisman's or a spell's effect. Every number
## comes from the rule constants. Built only from what Miho knows. Each line is
## a list of [text, Color] runs. Health is drawn as hearts (Term draws ♥ and ♡).

const STATE := ["쉬는 중", "수색 중", "추격 중"]
const WITS := ["둔함", "영리함", "교활함"]
## What a drum does, a short sentence a line; %d is how far heaven runs to it.
const DRUM_NOTE := (
	"치면 층 전체에 둥 소리가 난다\n"
	+ "듣는 적은 친 적이 당신을\n"
	+ "마지막으로 본 곳을 수색한다\n"
	+ "영리한 적은 걸어서 %d칸 안에서\n"
	+ "당신을 쫓으면 달려와 친다\n"
	+ "구슬이나 몸으로 부딪치면 찢어진다"
)
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
	var head := [[spec.name + " ", Palette.KIND[a.kind]], [hearts(a.hp, a.max_hp), Palette.HURT]]
	if a.faction == Actor.FOX:
		return _miho(w, a, head)
	var lines := [head]
	var elements := Bestiary.elements(a.kind)
	if not elements.is_empty():
		var line := [["오행 ", Palette.DIM]]
		for c in elements:
			line.append([Cards.GLYPH[c] + "(" + Cards.NAME[c] + ") ", Palette.CARD[c]])
		lines.append(line)
		lines.append(_weakness(a.kind))
	lines.append_array(_immunities(a))
	lines.append([[STATE[a.alert], Palette.ALERT[maxi(a.alert, 1)]]])
	lines.append_array(_conditions(w, a))
	if a.drumming():
		lines.append([["북을 치러 간다", Palette.SOUND]])
	if w.sees(a, w.player().pos):
		lines.append([["당신을 보고 있다", Palette.HURT]])
	else:
		lines.append([["당신을 볼 수 없다", Palette.SIDE[0]]])
	var sneak := a.unaware()
	lines.append(
		_amount("기습 시 피해 " if sneak else "공격 시 피해 ", World.CLAW * (World.SNEAK if sneak else 1))
	)
	if spec.has("melee"):
		lines.append(_amount("근접: %s (피해 " % spec.melee.name, spec.melee.damage, ")"))
	lines.append_array(_casts(a))
	lines.append([[" · ".join(_traits(a, elements)), Palette.DIM]])
	var eats: StringName = spec.get("eats", &"")
	if eats != &"":
		var line := [[Cards.NAME[eats], Palette.CARD[eats]], [" 주문을 먹으면 최대 체력 ", Palette.TEXT]]
		line.append_array([["+%d" % Bestiary.GROWTH, Palette.HURT], [", 체력 ", Palette.TEXT]])
		line.append(["+%d" % Bestiary.GROWTH, Palette.HURT])
		lines.append(line)
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


## Miho herself: tails, claws, sight, footsteps, conditions and how visible she is.
static func _miho(w: World, a: Actor, head: Array) -> Array:
	var steps := (
		Tiles
		. ROWS
		. keys()
		. filter(func(t): return Tiles.of(t, "tread")[0] > 0)
		. map(func(t): return "%s %d칸" % [Tiles.of(t, "name"), Tiles.of(t, "tread")[0]])
	)
	var claws := _amount("발톱: 피해 ", World.CLAW, ", 기습 시 ")
	claws.append([str(World.CLAW * World.SNEAK), Palette.HURT])
	var lines := [head, _tails(w), claws, [[_dark_sight(a), Palette.DIM]]]
	lines.append([["발소리: " + ", ".join(steps), Palette.DIM]])
	lines.append_array(_conditions(w, a))
	lines.append(_hidden(w, a.pos))
	return lines


## A line of text with a harm number in the middle: `before`, n, `after`.
static func _amount(before: String, n: int, after := "") -> Array:
	var line := [[before, Palette.TEXT], [str(n), Palette.HURT]]
	if after != "":
		line.append([after, Palette.TEXT])
	return line


## How far a creature sees in the dark: heaven one tile, Miho two, one more when wary.
static func _dark_sight(a: Actor) -> String:
	return "어둠 속 시야 %d칸" % (World.NIGHT[a.faction] + (1 if a.wary > 0 else 0))


## The elements whose spells hurt a creature twice as much.
static func _weakness(kind: StringName) -> Array:
	var line := [["약점: ", Palette.DIM]]
	for c in Bestiary.weak_to(kind):
		line.append([Cards.NAME[c], Palette.CARD[c]])
		line.append([", ", Palette.DIM])
	line.pop_back()
	var only_fire: bool = Bestiary.info(kind).get("absorb", &"") == &"nofire"
	line.append([" (피해 ×2%s)" % (", 불과 함께" if only_fire else ""), Palette.DIM])
	return line


## Everything the creature takes no harm or effect from, one "면역" line each.
static func _immunities(a: Actor) -> Array:
	var spec := a.info()
	var out := []
	match spec.get("absorb", &""):
		&"fire":
			out.append(_immune(Cards.NAME[Cards.FIRE], Palette.CARD[Cards.FIRE], "불이 든 주문, 불타는 칸"))
		&"nofire":
			out.append(_immune("불이 없는 모든 주문", Palette.DIM, ""))
	if spec.get("deaf", false):
		out.append(_immune("소리", Palette.SOUND, "경보를 듣지 못한다"))
	if spec.get("move", &"") == &"static":
		out.append(_immune("묶기", Palette.CARD[Cards.WOOD], "움직이지 못한다"))
	return out


static func _immune(what: String, color: Color, why: String) -> Array:
	var line := [["면역: ", Palette.DIM], [what, color]]
	if why != "":
		line.append([" (%s)" % why, Palette.DIM])
	return line


## What holds it now, with the seconds left: blind, rooted, stunned, wary, and
## standing in fire unless it eats fire.
static func _conditions(w: World, a: Actor) -> Array:
	var out := []
	for c in [[a.blind, "눈이 멀었다"], [a.rooted, "묶여 있다"], [a.stunned, "기절했다"], [a.wary, "경계 중"]]:
		if c[0] > 0:
			out.append([["%s (%d초)" % [c[1], c[0]], Palette.TEXT]])
	if w.burning.has(a.pos) and not Bestiary.absorbs(a.kind, Spell.make([Cards.FOX, Cards.FIRE])):
		out.append(_amount("불타는 칸 위 (%d초). 매 초 피해 " % w.burning[a.pos], World.FIRE_DAMAGE))
	return out


## Each spell it casts, with its cooldown, harm and noise.
static func _casts(a: Actor) -> Array:
	var out := []
	for cast: Array in a.info().get("casts", []):
		var spell := Spell.make(cast)
		var line: Array = [
			["주술: ", Palette.TEXT], [spell.title(), Palette.CARD[spell.cards.back()]]
		]
		line.append([" (%d초마다)" % a.info().cd, Palette.TEXT])
		if not a.intent.is_empty() and Spell.make(a.intent).key() == spell.key():
			line.append([", 모으는 중", Palette.HURT])
		elif a.cooldown > 0:
			line.append([", %d초 뒤" % a.cooldown, Palette.TEXT])
		out.append(line)
		for detail in _spell_details(spell):
			out.append([["  " + detail, Palette.DIM]])
	return out


## Harm, the burst of a fire orb and noise of a spell, one short line each.
static func _spell_details(s: Spell) -> Array[String]:
	var near := s.damage(0)
	var far := s.damage(Spell.MOMENTUM)
	var harm := "피해 %d" % near if near > 0 else "피해 없음"
	if far > near:
		harm += " (%d칸 이상 날면 %d)" % [Spell.MOMENTUM, far]
	var out: Array[String] = [harm]
	if s.orb and s.has(Cards.FIRE):
		out.append("터지면 주위 피해 %d" % World.FIRE_DAMAGE)
	var noise := "소리 없음" if s.cast_noise() == 0 else "소리 %d칸" % s.cast_noise()
	if s.burst_noise() > 0:
		noise += ", 터질 때 %d칸" % s.burst_noise()
	out.append(noise)
	return out


static func _traits(a: Actor, elements: Array) -> Array:
	var spec := a.info()
	var out := [WITS[Bestiary.wits(a.kind)]]
	if spec.get("patrol", false):
		out.append("순찰")
	if spec.get("step", 0) > 0:
		out.append("발소리 %d칸" % spec.step)
	if elements.has(Cards.WOOD):
		out.append("불에 탐")
	if spec.get("hunts", false):
		out.append("당신 위치를 앎")
	out.append(_dark_sight(a))
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
	if s.faction == Actor.HEAVEN:
		lines.append([["다른 적도 맞힌다. 약점과 면역은 똑같이 적용된다", Palette.DIM]])
	if s.life > 0:
		lines.append([["%d초 뒤 사라진다" % s.life, Palette.DIM]])
	return lines


static func terrain(w: World, p: Vector2i) -> Array:
	var t := w.tile(p)
	var name: String = Tiles.of(t, "name")
	var breakable := Terrain.breakable(w, p)
	var burns := w.burning.has(p) and w.seen[Grid.index(p)] == 1
	var notes := _notes(t, breakable, burns)
	var health: int = Tiles.of(t, "health") if breakable else 0
	if p == w.stairs:
		name = "계단"
		notes = ["위층으로 올라간다. 체력 %d 회복, 꼬리가 모두 돌아온다" % World.HEAL]
	elif p == w.elixir:
		name = "영약"
		notes = ["사람이 된다"]
	elif w.peaches.has(p):
		name = "복숭아"
		notes = ["체력 %d 회복. 가득 찼으면 최대 체력 +%d" % [World.HEAL, World.HEAL]]
	var head := [[name, Palette.TEXT]]
	if health > 0:
		head.append([" " + hearts(health, health), Palette.HURT])
	var lines := [head]
	for note in notes:
		lines.append([[note, Palette.DIM]])
	if burns:
		lines.append_array(_burning(w.burning[p]))
	if t == World.DRUM:
		lines.append(_drum_line(w, p))
	lines.append_array(_change_lines(w, p))
	if not Terrain.wall(t):
		lines.append(_light_line(w, p))
	return lines


## A change creatures notice (Notice) and, for a fallen creature, its body mark.
static func _change_lines(w: World, p: Vector2i) -> Array:
	var change := Notice.at(w, p)
	var body: Dictionary = w.bodies.get(p, {})
	if change.is_empty() or (change.kind == &"body" and not body.get("met", false)):
		return []
	var label: String = Notice.LABEL[change.kind]
	var color := Palette.TEXT
	var rule := "추격 중이 아닌 적은 처음 보면 이곳을 수색한다"
	if change.kind == &"body":
		label = "쓰러진 " + Bestiary.info(body.kind).name
		rule += ". 이 층에 남는다"
		color = Palette.KIND[body.kind]
	return [
		[[label, color], [" · %d초 전" % (w.round_no - change.round), Palette.DIM]],
		[[rule, Palette.DIM]],
	]


## Whether a drum would sound: wet ones are silent, for how long.
static func _drum_line(w: World, p: Vector2i) -> Array:
	if w.wet.has(p):
		return [["젖어서 소리가 나지 않는다 (%d초)" % w.wet[p], Palette.SIDE[0]]]
	return [["물에 젖으면 %d초 동안 소리가 없다" % Drums.WET_ROUNDS, Palette.DIM]]


## What a kind of tile does, one short sentence each; numbers from the rules.
static func _notes(t: int, breakable: bool, burns: bool) -> Array[String]:
	var out: Array[String] = []
	match t:
		World.DOOR:
			out.append("닫혀 있다. 시야는 막고 빛은 지나간다")
			out.append("드르륵 소리 %d칸" % Terrain.SLIDE)
		World.DOOR_OPEN:
			out.append("시야와 빛이 지나간다. 문 닫기 키로 닫는다")
			out.append("드르륵 소리 %d칸" % Terrain.SLIDE)
		World.DRUM:
			out.append_array((DRUM_NOTE % Drums.REACH).split("\n"))
		World.DRUM_TORN:
			out.append("소리가 나지 않는다")
		World.LANTERN:
			out.append("주위 %d칸을 밝힌다" % Light.LANTERN_RADIUS)
		World.LANTERN_OUT:
			out.append("불로 다시 켤 수 있다. 수색하는 적도 켠다")
		World.BAMBOO:
			out.append("안이 보이지 않는다")
		World.POND, World.SKY:
			out.append("건널 수 없다. 주문은 넘어간다")
		World.WINDOW:
			out.append("보이지만 지나갈 수 없다")
		World.BRIDGE:
			out.append("달빛에 드러난다. 불에 타지 않는다")
		World.ASH:
			out.append("다시 타지 않는다")
	if Terrain.wall(t) and breakable:
		out.append("구슬로만 부술 수 있다. 쿵 소리 %d칸" % World.THUD)
	elif Terrain.wall(t):
		out.append("부술 수 없다")
	if Terrain.knockable(t) and t != World.DRUM:
		out.append("부딪히면 쨍 소리 %d칸" % World.KNOCK)
	var tread: Array = Tiles.of(t, "tread")
	if tread[0] > 0:
		out.append("밟으면 %s 소리 %d칸" % [tread[1], tread[0]])
	if Tiles.burns[t] == 1 and not burns:
		out.append("불이 붙으면 %d초 타고 재가 된다" % World.BURN_ROUNDS)
	return out


## A burning tile: time left, harm, spread, light and noise.
static func _burning(left: int) -> Array:
	var spread := roundi(World.SPREAD * 100)
	return [
		[["불타는 중. %d초 뒤 재가 된다" % left, Palette.HURT]],
		_amount("서 있으면 매 초 피해 ", World.FIRE_DAMAGE),
		[["불에 타는 주위 칸에 초당 %d%% 번진다" % spread, Palette.DIM]],
		[["주위 %d칸을 밝힌다. 타닥 소리 %d칸" % [Light.FIRE_RADIUS, World.CRACKLE], Palette.DIM]],
	]


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
	var reach: int = World.NIGHT[Actor.HEAVEN]
	return [["어둡다. %d칸 안에서만 보인다" % reach, Palette.SIDE[0]]]


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
		lines.append([["불: 터지면 주위 8칸에 피해 %d, 불을 붙인다" % World.FIRE_DAMAGE, Palette.TEXT]])
	for c in s.elements():
		if not (s.orb and c == Cards.FIRE):
			lines.append([[EFFECT[c], Palette.TEXT]])
	var harm := (
		"피해 1, %d칸 이상 날면 2" % Spell.MOMENTUM if s.orb else ("피해 1" if s.damage(0) > 0 else "피해 없음")
	)
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
