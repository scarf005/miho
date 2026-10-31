class_name Info
extends RefCounted
## What the pointer is over, in a few short sentences: a creature's health,
## state, conditions, immunities, group and rival, whether it sees Miho, what her claws would do
## to it and what it strikes and casts with; a projectile (SpellInfo); a
## tile's terrain, light and sound. Every number comes from the rule
## constants. Built only from what Miho knows. Each line is a list of
## [text, Color] runs. Health is drawn as hearts (Term draws ♥ and ♡).

const STATE := ["쉬는 중", "수색 중", "추격 중"]
const WITS := ["둔함", "영리함", "교활함"]
## What a change or a body mark makes a creature do.
const NOTICE_RULE := "추격 중이 아닌 적은 처음 보면 이곳을 수색한다"
const BODY_RULE := NOTICE_RULE + ". 이 층에 남는다"
## What a drum does, a short sentence a line; %d is how far heaven runs to it.
const DRUM_NOTE := (
	"치면 층 전체에 둥 소리가 난다\n"
	+ "듣는 적은 친 적이 당신을\n"
	+ "마지막으로 본 곳을 수색한다\n"
	+ "영리한 적은 걸어서 %d칸 안에서\n"
	+ "당신을 쫓으면 달려와 친다\n"
	+ "구슬이나 몸으로 부딪치면 찢어진다"
)


## Lines for map tile p, or empty when Miho knows nothing there.
static func at(w: World, p: Vector2i) -> Array:
	if not Grid.inside(p):
		return []
	var i := Grid.index(p)
	if w.seen[i] == 1:
		var a := w.actor_at(p)
		if a != null and Hat.shown(w, a):
			return creature(w, a)
		var s := w.shot_at(p)
		if s != null:
			return SpellInfo.shot(w, s)
	if w.known[i] == 0:
		return []
	return terrain(w, p)


## A creature as the hover tells it: what it is, how it stands now (state,
## conditions, sight, the harm a claw does it now), then what it strikes and
## casts with.
static func creature(w: World, a: Actor) -> Array:
	if a.faction == Actor.FOX:
		return _miho(w, a, _head(a))
	return _profile(a) + _situation(w, a) + _site_lines(w, a) + _arms(a, w.cards)


## What a creature is, whatever its state: the 도감's text. `held` are the
## talismans Miho holds, whose drop is no news.
static func creature_facts(a: Actor, held: Array) -> Array:
	return _profile(a) + [_claws()] + _arms(a, held)


static func _head(a: Actor) -> Array:
	return [[a.info().name + " ", Palette.KIND[a.kind]], [hearts(a.hp, a.max_hp), Palette.HURT]]


## Name and health, elements, weakness and immunities.
static func _profile(a: Actor) -> Array:
	var lines := [_head(a)]
	var elements := Bestiary.elements(a.kind)
	if not elements.is_empty():
		var line := [["오행 ", Palette.DIM]]
		for c in elements:
			line.append([Cards.GLYPH[c] + "(" + Cards.NAME[c] + ") ", Palette.CARD[c]])
		lines.append(line)
		lines.append(_weakness(a.kind))
	lines.append_array(_immunities(a))
	lines.append([["무리: ", Palette.DIM], [Bestiary.GROUPS[a.info().group], Palette.TEXT]])
	lines.append([["다른 무리에게 맞으면 %d초 싸운다" % Mind.GRUDGE_ROUNDS, Palette.DIM]])
	if Bestiary.bands(a.kind):
		lines.append([["최대 %d마리 무리, 우두머리는 가장 센 적" % FloorGen.BAND, Palette.DIM]])
	return lines


## What a creature is doing. A resting one reads by what it does: asleep (eyes
## shut), on patrol, walking back home, or just resting. One hunting at 1
## health or alight runs.
static func state(a: Actor) -> String:
	if a.fleeing():
		return "도망치는 중"
	if a.alert != Actor.REST:
		return STATE[a.alert]
	if a.asleep():
		return "자는 중"
	if a.guard and a.pos == a.home:
		return "지키는 중"
	if a.following():
		return "따라가는 중"
	if a.info().get("patrol", false):
		return "순찰 중"
	return "돌아가는 중" if a.pos != a.home else STATE[Actor.REST]


## How a creature stands now: its state, conditions, whether it sees Miho and
## what her claw does to it.
static func _situation(w: World, a: Actor) -> Array:
	var lines := []
	var doing := [[state(a), Palette.ALERT[maxi(a.alert, 1)]]]
	if a.alert == Actor.SEARCH:
		doing.append([_search_left(a), Palette.TEXT])
	lines.append(doing)
	lines.append_array(_conditions(w, a))
	if a.leader != 0:
		lines.append([["우두머리: " + _name_of(w, w.actor(a.leader)), Palette.TEXT]])
	elif w.actors.any(func(b): return b.leader == a.id):
		lines.append([["무리의 우두머리", Palette.TEXT]])
	if a.fighting():
		lines.append([[_rival(w, a) + "싸우는 중 (%d초)" % a.grudge, Palette.ALERT[2]]])
	if a.drumming():
		lines.append([["북을 치러 간다", Palette.SOUND]])
	if Guise.knows(w, a):
		lines.append([["당신을 보고 있다", Palette.HURT]])
	elif w.sees(a, w.player().pos):
		lines.append([["둔갑한 당신을 알아보지 못한다", Palette.SIDE[0]]])
	else:
		lines.append([["당신을 볼 수 없다", Palette.SIDE[0]]])
	var sneak := w.caught_unawares(a)
	lines.append(
		_amount("기습 시 피해 " if sneak else "공격 시 피해 ", World.CLAW * (World.SNEAK if sneak else 1))
	)
	return lines


## The rival `a` fights, with 와/과, named only when Miho sees it.
static func _rival(w: World, a: Actor) -> String:
	var name := _name_of(w, w.actor(a.rival))
	return name + Messages._particle(name, "과", "와") + " "


## The name of creature `b` when Miho sees it, else "무언가".
static func _name_of(w: World, b: Actor) -> String:
	return b.info().name if b != null and Hat.shown(w, b) else "무언가"


## What it strikes and casts with, what it eats and what it leaves.
static func _arms(a: Actor, held: Array) -> Array:
	var spec := a.info()
	var lines := []
	var elements := Bestiary.elements(a.kind)
	if spec.has("melee"):
		var throw: int = spec.melee.get("throw", 0)
		var after := ", %d칸 던진다)" % throw if throw > 0 else ")"
		lines.append(_amount("근접: %s (피해 " % spec.melee.name, spec.melee.damage, after))
		if throw > 0:
			lines.append([["  하늘로 던져지면 한 층 떨어진다", Palette.DIM]])
	lines.append_array(_casts(a))
	lines.append([[" · ".join(_traits(a, elements)), Palette.DIM]])
	var cry: Dictionary = spec.get("shout", {})
	if cry.is_empty():
		lines.append([["외치지 않는다", Palette.DIM]])
	else:
		var said := [[cry.word, Palette.SOUND], [" %d칸" % cry.loud, Palette.TEXT]]
		lines.append([["당신을 보면 외친다: ", Palette.TEXT]] + said)
		lines.append([["들은 적은 그곳을 수색한다", Palette.DIM]])
	if spec.get("hat", false):
		lines.append([["감투: %d칸 안이나 도깨비불이 붙으면 보임" % Hat.REACH, Palette.DIM]])
	if Bestiary.flees(a.kind):
		lines.append([["체력 1이면 도망친다", Palette.DIM]])
		lines.append([["불붙음: 도망.", Palette.DIM]])
	elif spec.get("brave", false):
		lines.append([["용감해서 도망치지 않는다", Palette.DIM]])
	var eats: StringName = spec.get("eats", &"")
	if eats != &"":
		var line := [[Cards.NAME[eats], Palette.CARD[eats]], [" 주문을 먹으면 최대 체력 ", Palette.TEXT]]
		line.append_array([["+%d" % Bestiary.GROWTH, Palette.HURT], [", 체력 ", Palette.TEXT]])
		line.append(["+%d" % Bestiary.GROWTH, Palette.HURT])
		lines.append(line)
	var drop: StringName = spec.get("drop", &"")
	if drop != &"" and not held.has(drop):
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
	var lines := [head, _tails(w), _claws(), [[_dark_sight(a), Palette.DIM]]]
	lines.append([["발소리: " + ", ".join(steps), Palette.DIM]])
	lines.append_array(_conditions(w, a))
	if a.guise > 0:
		var form: String = Bestiary.info(a.form).name
		lines.append([["둔갑: %s의 모습 (%d초)" % [form, a.guise], Palette.SIDE[0]]])
		var ends := "적 옆 %d/%d초. 주문을 쓰거나 맞으면 풀린다" % [a.beside, Guise.BESIDE]
		lines.append([[ends, Palette.DIM]])
	elif a.prey != &"" and w.cards.has(Cards.WOOD) and w.cards.has(Cards.EARTH):
		lines.append([["둔갑할 모습: " + Bestiary.info(a.prey).name, Palette.DIM]])
	lines.append(_hidden(w, a.pos))
	return lines


## What Miho's claws do: plain, and to a creature caught unawares.
static func _claws() -> Array:
	var line := _amount("발톱: 피해 ", World.CLAW, ", 기습 시 ")
	line.append([str(World.CLAW * World.SNEAK), Palette.HURT])
	return line


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
## How many more looks around its spot a searching creature takes before it
## rests (Mind.search); a wary one keeps looking until it is no longer wary.
static func _search_left(a: Actor) -> String:
	var left := World.SEARCH_ROUNDS + 1 - a.lost
	if a.wary > 0 and left <= 1:
		return " · 경계가 끝나면 쉰다"
	return " · 그 자리를 %d번 더 둘러본다" % left


static func _conditions(w: World, a: Actor) -> Array:
	var out := []
	for c in [[a.blind, "눈이 멀었다"], [a.rooted, "묶여 있다"], [a.stunned, "기절했다"], [a.wary, "경계 중"]]:
		if c[0] > 0:
			out.append([["%s (%d초)" % [c[1], c[0]], Palette.TEXT]])
	out.append_array(_status(a))
	if (
		w.burning.has(a.pos)
		and a.alight <= 0
		and not Bestiary.absorbs(a.kind, Spell.make([Cards.FOX, Cards.FIRE]))
	):
		out.append(_amount("불타는 칸 위 (%d초). 매 초 피해 " % w.burning[a.pos], World.FIRE_DAMAGE))
	if (
		Veil.scorches(w, a.pos)
		and not Bestiary.absorbs(a.kind, Spell.make([Cards.FOX, Cards.FIRE]))
	):
		out.append(_amount("도깨비불 장막 곁. 매 초 피해 ", World.FIRE_DAMAGE))
	for s in w.shots:
		if s.host == a.id and not s.gone:
			var title := s.spell.title()
			var runs := [[title, Palette.card(s.spell.slots.back())]]
			out.append(
				(
					runs
					+ [
						[
							Messages._particle(title, "이", "가") + " 붙어 있다 (%d초)" % s.life,
							Palette.TEXT
						]
					]
				)
			)
	if w.hot.has(a.pos):
		var h: Vector2i = w.hot[a.pos]
		var spec: Dictionary = Compounds.HOT[h.x]
		out.append(_amount("%s 위 (%d초). 매 초 피해 " % [spec.name, h.y], spec.harm))
	out.append_array(_gas(w, a.pos))
	return out


## The status it holds (Status), with the seconds left and what it does.
static func _status(a: Actor) -> Array:
	var key := Status.of(a)
	if key == &"":
		return []
	var line := [[Status.NAME[key], Palette.STATUS[key][1]]]
	line.append([" %d초. %s" % [Status.rounds(a), SpellInfo.STATUS_DOES[key]], Palette.TEXT])
	return [line]


## Each spell it casts, with its cooldown, harm and noise.
static func _casts(a: Actor) -> Array:
	var out := []
	for cast: Array in a.info().get("casts", []):
		var spell := Bestiary.spell(a.kind, cast)
		var line: Array = [
			["주술: ", Palette.TEXT], [spell.title(), Palette.card(spell.slots.back())]
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
		out.append("터지면 주위 피해 %d" % (World.FIRE_DAMAGE + s.extra(Cards.FIRE)))
	for c in s.compounds():
		for part in SpellInfo.compound(c):
			out.append("%s: %s" % [Cards.NAME[c], part])
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
	if a.guard:
		out.append("잠들지 않음")
	if spec.get("step", 0) > 0:
		out.append("발소리 %d칸" % spec.step)
	if elements.has(Cards.WOOD):
		out.append("불에 탐")
	if spec.get("hunts", false):
		out.append("당신 위치를 앎")
	if spec.get("tracks", false):
		out.append("당신의 냄새를 따라감")
	if spec.get("stokes", false):
		out.append("깨어 있으면 꺼진 등불을 켬")
	out.append(_dark_sight(a))
	return out


## A tile as the hover tells it: what it is, then how well it is lit and seen.
static func terrain(w: World, p: Vector2i) -> Array:
	var t := w.tile(p)
	var lines := terrain_facts(w, p, true)
	if Tiles.sight[t] == 0 or Tiles.walk[t] == 1:
		lines.append(_light_line(w, p))
	return lines


## What a tile is and does, whatever the light: the 도감's text. The hover also
## tells how much gas lies on it (`now`).
static func terrain_facts(w: World, p: Vector2i, now := false) -> Array:
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
	for seal: Vector2i in w.seals:
		var lanterns: Array = w.seals[seal]
		var lit := (
			"(%d/%d)"
			% [lanterns.filter(func(q): return w.tile(q) == World.LANTERN).size(), lanterns.size()]
		)
		if seal == p:
			notes.append("켜진 등불 " + lit)
		elif lanterns.has(p):
			notes.append("봉인문의 등불 " + lit)
	notes.append_array(_sites(w, p))
	var head := [[name, Palette.TEXT]]
	if health > 0:
		head.append([" " + hearts(health, health), Palette.HURT])
	var lines := [head]
	for note in notes:
		lines.append([[note, Palette.DIM]])
	if burns:
		lines.append_array(_burning(w.burning[p]))
	if w.hot.has(p) and w.seen[Grid.index(p)] == 1:
		var h: Vector2i = w.hot[p]
		var spec: Dictionary = Compounds.HOT[h.x]
		lines.append([["%s. %d초 뒤 식는다" % [spec.name, h.y], Palette.HURT]])
		lines.append(_amount("서 있으면 매 초 피해 ", spec.harm))
	lines.append_array(_gas(w, p, now))
	if w.vents.has(p):
		var vent := [
			["뿜는 기체: ", Palette.DIM], [Gas.of(w.vents[p], "name"), Palette.GAS[w.vents[p]][1]]
		]
		lines.append(vent + [[" (매 초 양 %d까지 채운다)" % Gas.VENT_LEVEL, Palette.DIM]])
	if t == World.DRUM:
		lines.append(_drum_line(w, p))
	lines.append_array(_change_lines(w, p))
	return lines


## A change creatures notice (Notice) and, for a fallen creature, its body mark.
static func _change_lines(w: World, p: Vector2i) -> Array:
	var change := Notice.at(w, p)
	var body: Dictionary = w.bodies.get(p, {})
	if change.is_empty() or (change.kind == &"body" and not body.get("met", false)):
		return []
	var label: String = Notice.LABEL[change.kind]
	var color := Palette.TEXT
	var rule := NOTICE_RULE
	if change.kind == &"body":
		label = "쓰러진 " + Bestiary.info(body.kind).name
		rule = BODY_RULE
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


## What the creature's fall would bring in an event room (Creak).
static func _site_lines(w: World, a: Actor) -> Array:
	var out := []
	for site: Dictionary in w.sites:
		if site.kind == &"creak" and site.id == a.id:
			out.append([["마루의 해태. 쓰러지면 꼬리가 모두 돌아온다", Palette.TEXT]])
	return out


## How the event room whose tile p is stands now (EventRooms).
static func _sites(w: World, p: Vector2i) -> Array[String]:
	var out: Array[String] = []
	for site: Dictionary in w.sites:
		if site.at == p and site.kind == &"altar":
			out.append("쓰러진 생물 (%d/%d)" % [site.fallen, Altar.NEED])
		if site.at == p and site.kind == &"yard":
			var card := Yard.prize(w, site)
			out.append("얻는 부적: %s" % (Cards.NAME[card] if card != &"" else "없음. 모두 가졌다"))
	return out


## What a kind of tile does, one short sentence each; numbers from the rules.
static func _notes(t: int, breakable: bool, burns: bool) -> Array[String]:
	var out: Array[String] = []
	match t:
		World.SEAL:
			out.append("길과 시야와 빛을 막는다. 부술 수 없다")
			out.append("앞방의 꺼진 등불 셋이 모두 켜지면 열린다")
			out.append("등불이 하나라도 부서지면 영영 닫힌다")
		World.ALTAR:
			out.append("길과 주문을 막는다")
			out.append("주위 %d칸 안에서 하늘의 생물이 %d번 쓰러지면 타오른다" % [Altar.REACH, Altar.NEED])
			out.append("하늘로 밀려 떨어져도 센다")
			out.append("타오르면 꼬리가 모두 돌아오고 이 층에서 하나 더 돋는다")
		World.ALTAR_LIT:
			out.append("길과 주문을 막는다")
			out.append("주위 %d칸을 밝힌다" % Light.SOUL_RADIUS)
		World.LAMP:
			out.append("길과 주문을 막는다. 부술 수 없고 꺼지지 않는다")
			out.append("주위 %d칸을 밝힌다" % Light.LANTERN_RADIUS)
		World.TALISMAN:
			out.append("밟으면 아직 없는 원소 부적 하나를 얻는다")
			out.append("한 번뿐이다. 지키는 장승은 잠들지 않는다")
		World.SHELF:
			out.append("밟으면 두루마리를 읽어 이 층의 지도가 드러난다")
			out.append("한 번뿐이다. 서고의 서가가 모두 읽은 서가가 된다")
		World.SHELF_READ:
			out.append("이미 읽었다")
		World.VEIL:
			out.append("길과 주문을 막는다. 시야는 막지 않는다")
			out.append("주위 %d칸을 밝힌다" % Light.LANTERN_RADIUS)
			out.append("곁에 선 채 초가 끝나면 매 초 피해 %d. 불을 먹는 적은 입지 않는다" % World.FIRE_DAMAGE)
			out.append("물 주문이 닿으면 재가 되고, 서리가 닿으면 얼음이 되어 건널 수 있다")
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
		World.REEDS:
			out.append("시야를 막는다. 밟으면 쓰러져 시야가 트인다")
		World.PILLAR:
			out.append("길과 시야와 빛을 막는다. 뒤에 숨을 수 있다")
			out.append("부술 수 없다")
		World.WOOD_WALL:
			out.append("길과 시야와 빛을 막는다")
			out.append("구슬에 맞으면 부서진다")
		World.POND, World.SKY:
			out.append("걸어서 건널 수 없다")
			out.append("주문과 멀리뛰기는 넘어간다")
		World.VERANDA:
			out.append("맞은편 쪽마루는 멀리뛰기로 건넌다")
		World.WINDOW:
			out.append("보이지만 지나갈 수 없다")
		World.BRIDGE:
			out.append("달빛에 드러난다. 불에 타지 않는다")
		World.ASH:
			out.append("다시 타지 않는다")
		World.ICE:
			out.append("얼어붙은 연못. 걸어서 건넌다")
		World.THORNS:
			out.append("지나가면 피해 %d. 시야는 통한다" % Compounds.THORN)
		World.MUD:
			out.append("걷는 데 %d초 걸린다. 발소리가 나지 않는다" % Compounds.MUD)
		World.TRAP_ALARM:
			out.append("밟으면 층 전체에 징 소리가 퍼진다")
			out.append("듣는 적은 추격 중이 아니면 이 칸을 수색한다")
		World.TRAP_COLLAPSE:
			out.append("밟으면 하늘로 떨어진다")
			out.append("적은 사라지고 당신은 한 층 아래로 간다")
		World.TRAP_FIRE:
			out.append("밟은 방향 앞 %d칸에 불을 뿜는다" % Traps.FLAME_REACH)
			out.append("불이 붙은 다음 초부터 서 있으면 매 초 피해 %d" % World.FIRE_DAMAGE)
		World.TRAP_VINE:
			var side := 2 * Traps.VINE_REACH + 1
			out.append("밟으면 주위 %d×%d의 모두를 %d초 묶는다" % [side, side, Traps.ROOT_ROUNDS])
	if Tiles.of(t, "trap"):
		out.append("밝은 칸이나 %d칸 안에서만 보인다. 한번 찾으면 기억한다" % Traps.REACH)
		out.append("적은 알고 피해 다닌다")
	if t == World.WALL and breakable:
		out.append("방 사이 벽은 숨은 문일 수 있다. 밝거나 %d칸 안이면 찾는다" % Traps.REACH)
	if Terrain.wall(t) and breakable:
		out.append("구슬로만 부술 수 있다. 쿵 소리 %d칸" % World.THUD)
		if Tiles.of(t, "breaks_to") != World.RUBBLE:
			out.append(
				"%s이나 %s 구슬은 한 번에 무너뜨린다" % [Cards.NAME[Cards.EARTH], Cards.NAME[Cards.METAL]]
			)
	elif Terrain.wall(t):
		out.append("부술 수 없다")
	if Terrain.knockable(t) and t != World.DRUM:
		out.append("부딪히면 쨍 소리 %d칸" % World.KNOCK)
	var tread: Array = Tiles.of(t, "tread")
	if tread[0] > 0:
		out.append("밟으면 %s 소리 %d칸" % [tread[1], tread[0]])
	if Tiles.of(t, "scentless"):
		out.append("냄새가 남지 않는다")
	if Tiles.of(t, "douses"):
		out.append("불이 붙지 않는다")
	if Tiles.burns[t] == 1 and not burns:
		out.append("불이 붙으면 %d초 타고 재가 된다" % World.BURN_ROUNDS)
		out.append("이웃이 타면 초당 %d%% 로 옮겨 붙는다" % roundi(Tiles.of(t, "spread") * 100))
	return out


## The gas on a tile in sight: kind, how fast it thins, its harm and what it
## wets, and, when `now`, how much lies there and whether that blocks sight (the
## 도감 tells what the gas is, not how much). Tiles out of sight keep no gas.
static func _gas(w: World, p: Vector2i, now := true) -> Array:
	var g := Gas.at(w, p)
	if g.x < 0 or w.seen[Grid.index(p)] == 0:
		return []
	var color: Color = Palette.GAS[g.x][1]
	var head := [[Gas.of(g.x, "name"), color]]
	if now:
		head.append([" %d/%d" % [g.y, Gas.MAX], Palette.DIM])
	var out := [head]
	var sight := "시야를 막는다" if now and g.y >= Gas.OPAQUE else "%d 이상 모이면 시야를 막는다" % Gas.OPAQUE
	out.append([[sight, Palette.DIM]])
	out.append([["매 초 %d%% 로 1씩 줄어든다" % Gas.of(g.x, "decay"), Palette.DIM]])
	if Gas.of(g.x, "harm") > 0:
		out.append(_amount("서 있으면 매 초 피해 ", Gas.of(g.x, "harm")))
	if Gas.of(g.x, "wets"):
		out.append([["북을 적셔 %d초 동안 소리를 없앤다" % Drums.WET_ROUNDS, Palette.DIM]])
	return out


## A burning tile: time left, harm, light and noise.
static func _burning(left: int) -> Array:
	return [
		[["불타는 중. %d초 뒤 재가 된다" % left, Palette.HURT]],
		_amount("서 있으면 매 초 피해 ", World.FIRE_DAMAGE),
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


## Health as hearts: one full heart per point left, an empty one per point lost.
static func hearts(n: int, of: int) -> String:
	return "♥".repeat(maxi(0, n)) + "♡".repeat(maxi(0, of - maxi(0, n)))


## The lines as plain text, for tests.
static func plain(lines: Array) -> String:
	return "\n".join(lines.map(func(l): return "".join(l.map(func(r): return r[0]))))


## What stepping onto p (or waiting, on Miho's own tile) would bring, from the
## forecasts `ahead` by direction, as the harm number or red tint on that tile
## shows it.
static func ahead(w: World, forecasts: Dictionary, p: Vector2i) -> Array:
	var d := p - w.player().pos
	var f: Forecast = forecasts.get(d) if Grid.cheb(p, w.player().pos) <= 1 else null
	if f == null:
		return []
	var how := "기다릴 시" if d == Vector2i.ZERO else "이 칸으로 갈 시"
	var lines := []
	if f.hurt_me() > 0:
		lines.append([[how + " 피해를 %d 입는다" % f.hurt_me(), Palette.HURT]])
	if f.drops_me():
		lines.append([[how + " 하늘로 떨어져 %d층으로 내려간다" % f.after.depth, Palette.HURT]])
	if not f.noticed.is_empty():
		var names := f.noticed.keys().map(func(id): return f.after.actor(id).info().name)
		lines.append([[how + " " + ", ".join(names) + "에게 들킨다", Palette.ALERT[2]]])
	return lines
