class_name Info
extends RefCounted
## What the pointer is over, as `이름: 값` lines and bare tags: a creature's
## health, state, conditions, immunities, rival, whether it sees Miho, what
## her claws would do to it and what it strikes and casts with; a projectile
## (SpellInfo); a tile's terrain, light and sound. Every number comes from the
## rule constants; a rule many things share is a tag here and told once in
## the 도감 (`glossary`). Built only from what Miho knows. Each line is a list
## of [text, Color] runs. Health is drawn as hearts (Term draws ♥ and ♡).

const STATE := ["쉬는 중", "수색 중", "추격 중"]
const WITS := ["둔함", "영리함", "교활함"]
## The tag of a change creatures notice (Notice), told in the glossary.
const TRACE := "흔적."


## The rules many things share, by the tag their hover shows instead, one
## `이름: 값` line each: the 도감's glossary (Codex).
static func glossary() -> Dictionary:
	var spread := roundi(Tiles.DEFAULT.spread * 100)
	return {
		"가연성": ["탐: %d초" % World.BURN_ROUNDS, "그 뒤: 재", "번짐: 이웃으로 초당 %d%%" % spread],
		"함정": ["드러남: 밝은 칸이나 %d칸 안" % Traps.REACH, "적: 피해 감"],
		"흔적": ["수색: 처음 본 적", "제외: 추격 중인 적"],
		"약점": ["피해: ×2", "대상: 그 원소가 든 주문"],
	}


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
	return _profile(a) + _situation(w, a) + _arms(a, w.cards)


## What a creature is, whatever its state: the 도감's text. `held` are the
## talismans Miho holds, whose drop is no news.
static func creature_facts(a: Actor, held: Array) -> Array:
	return _profile(a) + _arms(a, held)


static func _head(a: Actor) -> Array:
	return [[a.info().name + " ", Palette.KIND[a.kind]], [hearts(a.hp, a.max_hp), Palette.HURT]]


## Name and health, elements, weakness and immunities.
static func _profile(a: Actor) -> Array:
	var lines := [_head(a)]
	var elements := Bestiary.elements(a.kind)
	if not elements.is_empty():
		var line := [["오행: ", Palette.DIM]]
		for c in elements:
			line.append([Cards.GLYPH[c] + "(" + Cards.NAME[c] + ") ", Palette.CARD[c]])
		lines.append(line)
		lines.append(_weakness(a.kind))
	lines.append_array(_immunities(a))
	return lines


## What a creature is doing. A resting one reads by what it does: asleep (eyes
## shut), on patrol, walking back home, or just resting.
static func state(a: Actor) -> String:
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
	lines.append([[state(a), Palette.ALERT[maxi(a.alert, 1)]]])
	if a.alert == Actor.SEARCH:
		lines.append([[_search_left(a), Palette.TEXT]])
	lines.append_array(_conditions(w, a))
	if a.fighting():
		var rival := _name_of(w, w.actor(a.rival))
		lines.append([["싸우는 중: " + rival, Palette.ALERT[2]]])
		lines.append([["  남은 시간: %d초" % a.grudge, Palette.ALERT[2]]])
	if a.drumming():
		lines.append([["북 치러 가는 중.", Palette.SOUND]])
	if Guise.knows(w, a):
		lines.append([["미호를 본다.", Palette.HURT]])
	elif w.sees(a, w.player().pos):
		lines.append([["둔갑한 미호를 못 알아본다.", Palette.SIDE[0]]])
	else:
		lines.append([["미호를 못 본다.", Palette.SIDE[0]]])
	if w.caught_unawares(a):
		lines.append(_amount("기습 피해: ", World.CLAW * World.SNEAK))
	return lines


## The name of creature `b` when Miho sees it, else "무언가".
static func _name_of(w: World, b: Actor) -> String:
	return b.info().name if b != null and Hat.shown(w, b) else "무언가"


## What it strikes and casts with, what it eats and what it leaves.
static func _arms(a: Actor, held: Array) -> Array:
	var spec := a.info()
	var lines := []
	var elements := Bestiary.elements(a.kind)
	if spec.has("melee"):
		lines.append([["근접: " + spec.melee.name, Palette.TEXT]])
		lines.append(_amount("  피해: ", spec.melee.damage))
		var throw: int = spec.melee.get("throw", 0)
		if throw > 0:
			lines.append([["  던짐: %d칸" % throw, Palette.TEXT]])
		var root: int = spec.melee.get("root", 0)
		if root > 0:
			lines.append([["  묶음: %d초" % root, Palette.TEXT]])
	lines.append_array(_casts(a))
	var traits := _traits(a, elements)
	var tags := traits.filter(func(t): return not t.contains(": "))
	lines.append([[" · ".join(tags), Palette.DIM]])
	for t: String in traits.filter(func(t): return t.contains(": ")):
		lines.append([[t, Palette.DIM]])
	if not spec.get("shout", {}).is_empty():
		lines.append([["말할 수 있다.", Palette.DIM]])
	if spec.get("hat", false):
		lines.append([["보임: %d칸 안, 도깨비불 붙음" % Hat.REACH, Palette.DIM]])
	var eats: StringName = spec.get("eats", &"")
	if eats != &"":
		lines.append([["먹이: ", Palette.TEXT], [Cards.NAME[eats] + " 주문", Palette.CARD[eats]]])
		lines.append([["  최대 체력: ", Palette.TEXT], ["+%d" % Bestiary.GROWTH, Palette.HURT]])
		lines.append([["  체력: ", Palette.TEXT], ["+%d" % Bestiary.GROWTH, Palette.HURT]])
	var drop: StringName = spec.get("drop", &"")
	if drop != &"" and not held.has(drop):
		lines.append([["처치: ", Palette.TEXT], [Cards.NAME[drop] + " 부적", Palette.CARD[drop]]])
	return lines


## Miho herself: tails, claws, conditions and how visible she is. Her footsteps
## are each tile's own (`_notes`).
static func _miho(w: World, a: Actor, head: Array) -> Array:
	var lines := [head] + _tails(w) + _claws()
	lines.append_array(_conditions(w, a))
	if a.guise > 0:
		var form: String = Bestiary.info(a.form).name
		lines.append([["둔갑: " + form, Palette.SIDE[0]]])
		lines.append([["  남은 시간: %d초" % a.guise, Palette.SIDE[0]]])
		lines.append([["적 옆: %d/%d초" % [a.beside, Guise.BESIDE], Palette.DIM]])
	elif a.prey != &"" and w.cards.has(Cards.WOOD) and w.cards.has(Cards.EARTH):
		lines.append([["둔갑할 모습: " + Bestiary.info(a.prey).name, Palette.DIM]])
	lines.append(_hidden(w, a.pos))
	return lines


## What Miho's claws do: plain, and to a creature caught unawares; a line each.
static func _claws() -> Array:
	return [_amount("발톱 피해: ", World.CLAW), _amount("기습 피해: ", World.CLAW * World.SNEAK)]


## A line of text with a harm number in the middle: `before`, n, `after`.
static func _amount(before: String, n: int, after := "") -> Array:
	var line := [[before, Palette.TEXT], [str(n), Palette.HURT]]
	if after != "":
		line.append([after, Palette.TEXT])
	return line


## The elements whose spells hurt a creature twice as much.
static func _weakness(kind: StringName) -> Array:
	var line := [["약점: ", Palette.DIM]]
	for c in Bestiary.weak_to(kind):
		line.append([Cards.NAME[c], Palette.CARD[c]])
		line.append([", ", Palette.DIM])
	line.pop_back()
	if Bestiary.info(kind).get("absorb", &"") == &"nofire":
		line.append([" (불과 함께)", Palette.DIM])
	return line


## Everything the creature takes no harm or effect from, one "면역" line each,
## and that it never moves.
static func _immunities(a: Actor) -> Array:
	var spec := a.info()
	var out := []
	match spec.get("absorb", &""):
		&"fire":
			out.append(_immune("불 주문, 불타는 칸", Palette.CARD[Cards.FIRE]))
		&"nofire":
			out.append(_immune("불 없는 주문", Palette.DIM))
	if spec.get("deaf", false):
		out.append(_immune("소리", Palette.SOUND))
	if spec.get("move", &"") == &"static":
		out.append([["움직이지 않는다.", Palette.DIM]])
	return out


static func _immune(what: String, color: Color) -> Array:
	return [["면역: ", Palette.DIM], [what, color]]


## What holds it now, with the seconds left: blind, rooted, stunned, wary, and
## standing in fire unless it eats fire.
## How many more looks around its spot a searching creature takes before it
## rests (Mind.search); a wary one keeps looking until it is no longer wary.
static func _search_left(a: Actor) -> String:
	var left := World.SEARCH_ROUNDS + 1 - a.lost
	if a.wary > 0 and left <= 1:
		return "수색: 경계 끝까지"
	return "수색: %d번 더" % left


static func _conditions(w: World, a: Actor) -> Array:
	var out := []
	for c in [[a.blind, "눈멂"], [a.rooted, "묶임"], [a.stunned, "기절"], [a.wary, "경계"]]:
		if c[0] > 0:
			out.append([["%s: %d초" % [c[1], c[0]], Palette.TEXT]])
	out.append_array(_status(a))
	if (
		w.burning.has(a.pos)
		and a.alight <= 0
		and not Bestiary.absorbs(a.kind, Spell.make([Cards.FOX, Cards.FIRE]))
	):
		out.append([["불타는 칸 위: %d초" % w.burning[a.pos], Palette.TEXT]])
		out.append(_amount("  피해: 매 초 ", World.FIRE_DAMAGE))
	if (
		Veil.scorches(w, a.pos)
		and not Bestiary.absorbs(a.kind, Spell.make([Cards.FOX, Cards.FIRE]))
	):
		out.append(_amount("도깨비불 장막 곁 피해: 매 초 ", World.FIRE_DAMAGE))
	for s in w.shots:
		if s.host == a.id and not s.gone:
			var runs := [[s.spell.title(), Palette.card(s.spell.slots.back())]]
			out.append(runs + [[" 붙음: %d초" % s.life, Palette.TEXT]])
	if w.hot.has(a.pos):
		var h: Vector2i = w.hot[a.pos]
		var spec: Dictionary = Compounds.HOT[h.x]
		out.append([["%s 위: %d초" % [spec.name, h.y], Palette.TEXT]])
		out.append(_amount("  피해: 매 초 ", spec.harm))
	out.append_array(_gas(w, a.pos))
	return out


## The status it holds (Status), with the seconds left and what it does.
static func _status(a: Actor) -> Array:
	var key := Status.of(a)
	if key == &"":
		return []
	var line := [
		[Status.NAME[key], Palette.STATUS[key][1]], [": %d초" % Status.rounds(a), Palette.TEXT]
	]
	return [line] + SpellInfo.STATUS_DOES[key].map(func(d): return [["  " + d, Palette.TEXT]])


## Each spell it casts at its rank, with its cooldown, harm and noise, and how
## many it casts at once from Bestiary.DOUBLES. One with tails shows its tails and
## each spell's price on a line of its own.
static func _casts(a: Actor) -> Array:
	var out := []
	var tailed := Bestiary.tails(a.kind) > 0
	if tailed:
		out.append([["꼬리: %d/%d" % [a.tails, Bestiary.tails(a.kind)], Palette.SIDE[0]]])
		out.append([["회복: %d초마다 1개" % World.TAIL_REGROW, Palette.DIM]])
	if (a.rank >= Bestiary.DOUBLES or tailed) and a.repertoire().size() > 1:
		out.append([["동시 주술: 2개", Palette.TEXT]])
	for cast: Array in a.repertoire():
		var spell := Bestiary.spell(a.kind, cast)
		var line: Array = [
			["주술: ", Palette.TEXT], [spell.title(), Palette.card(spell.slots.back())]
		]
		if tailed:
			line.append([" · 꼬리: %d" % spell.cost(), Palette.DIM])
		out.append(line)
		if tailed:
			continue
		out.append([["  간격: %d초" % a.info().cd, Palette.DIM]])
		if a.intent.any(func(plan): return Spell.make(plan.cards).key() == spell.key()):
			out.append([["  모으는 중.", Palette.HURT]])
		elif a.cooldown > 0:
			out.append([["  다음: %d초 뒤" % a.cooldown, Palette.DIM]])
		for detail in _spell_details(spell):
			out.append([["  " + detail, Palette.DIM]])
	return out


## The elements of a spell its title does not tell (SpellInfo.elements), harm,
## a homing orb's turn, the burst of a fire orb and noise of a spell, one short
## line each; a spray's
## shape and effect (SpellInfo._spray) in place of the harm and burst.
static func _spell_details(s: Spell) -> Array[String]:
	if s.shape == Spell.SPRAY:
		var lines: Array[String] = []
		for line: Array in SpellInfo._spray(s) + SpellInfo._lines(SpellInfo._sounds(s)):
			lines.append("".join(line.map(func(run): return run[0])))
		return lines
	var near := s.damage(0)
	var far := s.damage(Spell.MOMENTUM)
	var out: Array[String] = ["피해: %d" % near if near > 0 else "피해: 없음"]
	if far > near:
		out.append("%d칸 이상 날면 피해: %d" % [Spell.MOMENTUM, far])
	if s.homing():
		out.append("꺾임: 한 칸에 " + SpellInfo._turn(s.turn()))
	if SpellInfo.elements(s) != "":
		out.push_front("원소: " + SpellInfo.elements(s))
	if s.orb and s.has(Cards.FIRE):
		out.append("폭발 피해: %d" % (World.FIRE_DAMAGE + s.extra(Cards.FIRE)))
	for c in s.compounds():
		for part: Array in SpellInfo.compound(c):
			out.append("%s: %s" % part)
	for part: Array in SpellInfo._sounds(s):
		out.append("%s: %s" % part)
	return out


static func _traits(a: Actor, elements: Array) -> Array:
	var spec := a.info()
	var out := [WITS[Bestiary.wits(a.kind)]]
	if spec.get("patrol", false):
		out.append("순찰")
	if spec.get("move", &"static") == &"static":
		out.append("잠들지 않음")
	if spec.get("step", 0) > 0:
		out.append("발소리: %d칸" % spec.step)
	if elements.has(Cards.WOOD):
		out.append("불에 탐")
	if spec.get("hunts", false):
		out.append("미호 위치를 앎")
	if spec.get("tracks", false):
		out.append("냄새를 따라감")
	if spec.get("stokes", false):
		out.append("꺼진 등불을 켬")
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
		notes = ["체력: +%d" % World.HEAL, "꼬리: 모두 회복"]
	elif p == w.elixir:
		name = "영약"
		notes = ["사람이 된다."]
	elif w.peaches.has(p):
		name = "복숭아"
		notes = ["체력: +%d" % World.HEAL, "가득 찼을 때 최대 체력: +%d" % World.HEAL]
	elif Scrolls.card_at(w, p) != &"":
		name = Cards.NAME[Scrolls.card_at(w, p)] + " 주문서"
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
		lines.append([["%s: %d초 남음" % [spec.name, h.y], Palette.HURT]])
		lines.append(_amount("피해: 매 초 ", spec.harm))
	lines.append_array(_gas(w, p, now))
	if w.vents.has(p):
		var vent := [
			["뿜는 기체: ", Palette.DIM], [Gas.of(w.vents[p], "name"), Palette.GAS[w.vents[p]][1]]
		]
		lines.append(vent)
		lines.append([["  양: 매 초 %d까지" % Gas.VENT_LEVEL, Palette.DIM]])
	if t == World.DRUM:
		lines.append_array(_drum_line(w, p))
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
	if change.kind == &"body":
		label = "쓰러진 " + Bestiary.info(body.kind).name
		color = Palette.KIND[body.kind]
	return [
		[[label, color], [": %d초 전" % (w.round_no - change.round), Palette.DIM]],
		[[TRACE, Palette.DIM]],
	]


## Whether a drum would sound: wet ones are silent, for how long.
static func _drum_line(w: World, p: Vector2i) -> Array:
	if w.wet.has(p):
		return [[["젖음: %d초" % w.wet[p], Palette.SIDE[0]]], [["소리: 없음", Palette.SIDE[0]]]]
	return [[["젖으면: %d초 소리 없음" % Drums.WET_ROUNDS, Palette.DIM]]]


## What a kind of tile does, an `이름: 값` line or a tag each; numbers from the
## rules, a shared rule as its glossary tag.
static func _notes(t: int, breakable: bool, burns: bool) -> Array[String]:
	var out: Array[String] = []
	match t:
		World.ALTAR:
			out.append("막음: 길, 주문")
		World.ALTAR_LIT:
			out.append("막음: 길, 주문")
			out.append("빛: %d칸" % Light.SOUL_RADIUS)
		World.LAMP:
			out.append("막음: 길, 주문")
			out.append("부술 수 없음.")
			out.append("꺼지지 않음.")
			out.append("빛: %d칸" % Light.LANTERN_RADIUS)
		World.VEIL:
			out.append("막음: 길, 주문")
			out.append("빛: %d칸" % Light.LANTERN_RADIUS)
			out.append("곁 피해: 매 초 %d" % World.FIRE_DAMAGE)
		World.DOOR:
			out.append("막음: 시야")
			out.append("소리: 여닫을 때 %d칸" % Terrain.SLIDE)
		World.DOOR_OPEN:
			out.append("소리: 여닫을 때 %d칸" % Terrain.SLIDE)
		World.DRUM:
			out.append("소리: 칠 때 층 전체")
			out.append("들은 적: 친 적이 미호를 마지막으로 본 곳을 수색")
			out.append("치는 적: 미호를 쫓는 영리한 적, 걸어서 %d칸 안" % Drums.REACH)
			out.append("찢어짐: 구슬, 부딪침")
		World.LANTERN:
			out.append("빛: %d칸" % Light.LANTERN_RADIUS)
		World.LANTERN_OUT:
			out.append("다시 켜짐: 불, 수색하는 적")
		World.BAMBOO:
			out.append("막음: 시야, 빛")
		World.REEDS:
			out.append("막음: 시야")
			out.append("밟으면: 쓰러짐")
		World.PILLAR:
			out.append("막음: 길, 시야, 빛")
			out.append("부술 수 없음.")
		World.WOOD_WALL:
			out.append("막음: 길, 시야, 빛")
			out.append("부서짐: 구슬")
		World.SCREEN:
			out.append("막음: 길, 시야")
			out.append("타격: 쓰러짐")
		World.JAR:
			out.append("막음: 길")
			out.append("타격: 깨짐")
		World.WATER_JAR:
			out.append("막음: 길")
			out.append("타격: 주위 8칸 얕은 물")
			out.append("타격: 불, 냄새 지움")
		World.CENSER:
			out.append("막음: 길")
			var coals: Dictionary = Compounds.HOT[Compounds.LAVA]
			out.append("%s 양: %d까지" % [Gas.of(Gas.INCENSE, "name"), Gas.VENT_LEVEL])
			out.append("타격: %s, 이 칸과 옆 4칸" % coals.name)
			out.append("타격: 옆 가연성 칸에 불")
			out.append("%s: %d초" % [coals.name, Compounds.HOT_ROUNDS])
			out.append("%s 피해: 매 초 %d" % [coals.name, coals.harm])
		World.COURTYARD:
			out.append("달빛에 드러남.")
		World.BOARD_ROTTEN:
			out.append("소리: %d칸" % Terrain.CRACK)
		World.STATUE:
			out.append("막음: 길")
		World.POND:
			out.append("넘어감: 주문, 멀리뛰기만")
		World.SKY:
			out.append("넘어감: 주문, 멀리뛰기만")
			out.append("추락한 적: 사라짐")
			out.append("추락 피해: 층마다 %d" % Fall.DAMAGE)
		World.WINDOW:
			out.append("막음: 길")
		World.BRIDGE:
			out.append("달빛에 드러남.")
			out.append("불에 타지 않음.")
		World.THORNS:
			out.append("피해: 지날 때 %d" % Compounds.THORN)
		World.MUD:
			out.append("걸음: %d초" % Compounds.MUD)
			out.append("발소리: 없음")
		World.TRAP_ALARM:
			out.append("밟으면: 층 전체에 소리")
		World.TRAP_COLLAPSE:
			out.append("밟으면: 하늘로 추락")
		World.TRAP_FIRE:
			out.append("밟으면: 밟은 방향 앞 %d칸에 불" % Traps.FLAME_REACH)
		World.TRAP_VINE:
			var side := 2 * Traps.VINE_REACH + 1
			out.append("밟으면: 주위 %d×%d 모두 묶음" % [side, side])
			out.append("묶음: %d초" % Traps.ROOT_ROUNDS)
	if Tiles.of(t, "trap"):
		out.append("함정.")
	if Terrain.wall(t) and breakable:
		out.append("부서짐: 구슬")
		out.append("부서질 때 소리: %d칸" % World.THUD)
	elif Terrain.wall(t):
		out.append("부술 수 없음.")
	if Terrain.knockable(t) and t != World.DRUM:
		out.append("소리: 부딪칠 때 %d칸" % Tiles.of(t, "hit")[0])
	var tread: Array = Tiles.of(t, "tread")
	if tread[0] > 0:
		out.append("발소리: %d칸" % tread[0])
	if Tiles.of(t, "scentless"):
		out.append("냄새 안 남음.")
	if Tiles.of(t, "douses"):
		out.append("불 안 붙음.")
	if Tiles.burns[t] == 1 and not burns:
		var spread := roundi(Tiles.of(t, "spread") * 100)
		var own := spread != roundi(Tiles.DEFAULT.spread * 100)
		out.append("가연성: 이웃으로 초당 %d%%" % spread if own else "가연성.")
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
		head.append([": %d/%d" % [g.y, Gas.MAX], Palette.DIM])
	var out := [head]
	if not Gas.of(g.x, "blocks"):
		out.append([["시야 막음: 없음", Palette.DIM]])
	elif not now:
		out.append([["시야 막음: %d 이상" % Gas.OPAQUE, Palette.DIM]])
	elif g.y >= Gas.OPAQUE:
		out.append([["시야 막음.", Palette.DIM]])
	out.append([["줄어듦: 매 초 %d%% 확률로 1" % Gas.of(g.x, "decay"), Palette.DIM]])
	if Gas.of(g.x, "harm") > 0:
		out.append(_amount("피해: 매 초 ", Gas.of(g.x, "harm")))
	if Gas.of(g.x, "wets"):
		out.append([["북 적심: %d초 소리 없음" % Drums.WET_ROUNDS, Palette.DIM]])
	if Gas.of(g.x, "erases"):
		out.append([["냄새: 지움", Palette.DIM]])
	return out


## A burning tile: time left, harm, light and noise.
static func _burning(left: int) -> Array:
	return [
		[["불타는 중: %d초 남음" % left, Palette.HURT]],
		_amount("피해: 매 초 ", World.FIRE_DAMAGE),
		[["빛: %d칸" % Light.FIRE_RADIUS, Palette.DIM]],
		[["소리: %d칸" % World.CRACKLE, Palette.DIM]],
	]


static func _light_line(w: World, p: Vector2i) -> Array:
	var i := Grid.index(p)
	if w.seen[i] == 0:
		if w.dim[i] == 1:
			return [["안 보임: %s" % ("대숲" if w.hides(p) else "어둠"), Palette.DIM]]
		return [["안 보임.", Palette.DIM]]
	return _hidden(w, p)


## Whether heaven would see Miho standing on p.
static func _hidden(w: World, p: Vector2i) -> Array:
	if w.hides(p):
		return [["대숲 속: 바로 옆에서만 보임", Palette.SIDE[0]]]
	if w.lit(p):
		return [["밝음.", Palette.ALERT[1]]]
	var reach: int = World.NIGHT[Actor.HEAVEN]
	return [["어두움: %d칸 안에서만 보임" % reach, Palette.SIDE[0]]]


static func _tails(w: World) -> Array:
	return [
		[["꼬리: %d/%d" % [w.tails, w.max_tails()], Palette.SIDE[0]]],
		[["회복: %d초마다 1개" % World.TAIL_REGROW, Palette.DIM]],
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
		lines.append([[how + " 피해: %d" % f.hurt_me(), Palette.HURT]])
	if f.drops_me():
		lines.append([[how + " 추락: %d층" % f.after.depth, Palette.HURT]])
	if not f.noticed.is_empty():
		var names := f.noticed.keys().map(func(id): return f.after.actor(id).info().name)
		lines.append([[how + " 들킴: " + ", ".join(names), Palette.ALERT[2]]])
	return lines
