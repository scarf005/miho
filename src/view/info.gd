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


## The rules many things share, by the tag their hover shows instead: the
## 도감's glossary (Codex).
static func glossary() -> Dictionary:
	var spread := roundi(Tiles.DEFAULT.spread * 100)
	return {
		"가연성": "%d초 타고 재. 이웃으로 초당 %d%%" % [World.BURN_ROUNDS, spread],
		"함정": "밝은 칸이나 %d칸 안에서 드러남. 적은 피해 감" % Traps.REACH,
		"흔적": "처음 본 적이 그곳을 수색. 추격 중인 적은 제외",
		"약점": "그 원소가 든 주문의 피해 ×2",
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
	return _profile(a) + _situation(w, a) + _site_lines(w, a) + _arms(a, w.cards)


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
	if a.fighting():
		var rival := _name_of(w, w.actor(a.rival))
		lines.append([["싸우는 중: %s, %d초" % [rival, a.grudge], Palette.ALERT[2]]])
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
		var throw: int = spec.melee.get("throw", 0)
		var after := ", %d칸 던짐" % throw if throw > 0 else ""
		lines.append(_amount("근접: %s, 피해 " % spec.melee.name, spec.melee.damage, after))
	lines.append_array(_casts(a))
	lines.append([[" · ".join(_traits(a, elements)), Palette.DIM]])
	if not spec.get("shout", {}).is_empty():
		lines.append([["말할 수 있다.", Palette.DIM]])
	if spec.get("hat", false):
		lines.append([["감투: %d칸 안이나 도깨비불이 붙었을 때만 보임" % Hat.REACH, Palette.DIM]])
	if Bestiary.flees(a.kind):
		lines.append([["도망: 체력 1, 불붙음", Palette.DIM]])
	elif spec.get("brave", false):
		lines.append([["용감함: 도망치지 않는다", Palette.DIM]])
	var eats: StringName = spec.get("eats", &"")
	if eats != &"":
		var line := [["먹이: ", Palette.TEXT], [Cards.NAME[eats], Palette.CARD[eats]]]
		line.append_array([[" 주문. 최대 체력 ", Palette.TEXT], ["+%d" % Bestiary.GROWTH, Palette.HURT]])
		line.append_array([[", 체력 ", Palette.TEXT], ["+%d" % Bestiary.GROWTH, Palette.HURT]])
		lines.append(line)
	var drop: StringName = spec.get("drop", &"")
	if drop != &"" and not held.has(drop):
		lines.append([["처치: ", Palette.TEXT], [Cards.NAME[drop] + " 부적", Palette.CARD[drop]]])
	return lines


## Miho herself: tails, claws, sight, conditions and how visible she is. Her
## footsteps are each tile's own (`_notes`).
static func _miho(w: World, a: Actor, head: Array) -> Array:
	var lines := [head, _tails(w), _claws(), [[_dark_sight(a), Palette.DIM]]]
	lines.append_array(_conditions(w, a))
	if a.guise > 0:
		var form: String = Bestiary.info(a.form).name
		lines.append([["둔갑: %s, %d초" % [form, a.guise], Palette.SIDE[0]]])
		lines.append([["적 옆: %d/%d초" % [a.beside, Guise.BESIDE], Palette.DIM]])
	elif a.prey != &"" and w.cards.has(Cards.WOOD) and w.cards.has(Cards.EARTH):
		lines.append([["둔갑할 모습: " + Bestiary.info(a.prey).name, Palette.DIM]])
	lines.append(_hidden(w, a.pos))
	return lines


## What Miho's claws do: plain, and to a creature caught unawares.
static func _claws() -> Array:
	var line := _amount("발톱: 피해 ", World.CLAW, ", 기습 ")
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
	return "어둠 시야: %d칸" % (World.NIGHT[a.faction] + (1 if a.wary > 0 else 0))


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
		return " · 남은 둘러보기: 경계 끝까지"
	return " · 남은 둘러보기: %d번" % left


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
		out.append(_amount("불타는 칸 위: %d초. 피해: 매 초 " % w.burning[a.pos], World.FIRE_DAMAGE))
	if (
		Veil.scorches(w, a.pos)
		and not Bestiary.absorbs(a.kind, Spell.make([Cards.FOX, Cards.FIRE]))
	):
		out.append(_amount("도깨비불 장막 곁. 피해: 매 초 ", World.FIRE_DAMAGE))
	for s in w.shots:
		if s.host == a.id and not s.gone:
			var runs := [[s.spell.title(), Palette.card(s.spell.slots.back())]]
			out.append(runs + [[" 붙음: %d초" % s.life, Palette.TEXT]])
	if w.hot.has(a.pos):
		var h: Vector2i = w.hot[a.pos]
		var spec: Dictionary = Compounds.HOT[h.x]
		out.append(_amount("%s 위: %d초. 피해: 매 초 " % [spec.name, h.y], spec.harm))
	out.append_array(_gas(w, a.pos))
	return out


## The status it holds (Status), with the seconds left and what it does.
static func _status(a: Actor) -> Array:
	var key := Status.of(a)
	if key == &"":
		return []
	var line := [[Status.NAME[key], Palette.STATUS[key][1]]]
	line.append([": %d초. %s" % [Status.rounds(a), SpellInfo.STATUS_DOES[key]], Palette.TEXT])
	return [line]


## Each spell it casts, with its cooldown, harm and noise.
static func _casts(a: Actor) -> Array:
	var out := []
	for cast: Array in a.info().get("casts", []):
		var spell := Bestiary.spell(a.kind, cast)
		var line: Array = [
			["주술: ", Palette.TEXT], [spell.title(), Palette.card(spell.slots.back())]
		]
		line.append([", %d초마다" % a.info().cd, Palette.TEXT])
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
	var harm := "피해: %d" % near if near > 0 else "피해: 없음"
	if far > near:
		harm += ", %d칸 이상 날면 %d" % [Spell.MOMENTUM, far]
	var out: Array[String] = [harm]
	if s.orb and s.has(Cards.FIRE):
		out.append("폭발 피해: %d" % (World.FIRE_DAMAGE + s.extra(Cards.FIRE)))
	for c in s.compounds():
		for part in SpellInfo.compound(c):
			out.append("%s: %s" % [Cards.NAME[c], part])
	out.append("소리: " + SpellInfo._sound(s))
	return out


static func _traits(a: Actor, elements: Array) -> Array:
	var spec := a.info()
	var out := [WITS[Bestiary.wits(a.kind)]]
	if spec.get("patrol", false):
		out.append("순찰")
	if a.guard:
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
		notes = ["체력: +%d. 꼬리: 모두 회복" % World.HEAL]
	elif p == w.elixir:
		name = "영약"
		notes = ["사람이 된다."]
	elif w.peaches.has(p):
		name = "복숭아"
		notes = ["체력: +%d, 가득 찼을 때 최대 체력 +%d" % [World.HEAL, World.HEAL]]
	for seal: Vector2i in w.seals:
		var lanterns: Array = w.seals[seal]
		var lit := (
			"%d/%d"
			% [lanterns.filter(func(q): return w.tile(q) == World.LANTERN).size(), lanterns.size()]
		)
		if seal == p:
			notes.append("켜진 등불: " + lit)
		elif lanterns.has(p):
			notes.append("봉인문 등불: " + lit)
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
		lines.append([["%s: %d초 남음" % [spec.name, h.y], Palette.HURT]])
		lines.append(_amount("피해: 매 초 ", spec.harm))
	lines.append_array(_gas(w, p, now))
	if w.vents.has(p):
		var vent := [
			["뿜는 기체: ", Palette.DIM], [Gas.of(w.vents[p], "name"), Palette.GAS[w.vents[p]][1]]
		]
		lines.append(vent + [[", 매 초 양 %d까지" % Gas.VENT_LEVEL, Palette.DIM]])
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
		return [["젖음: %d초. 소리 없음" % w.wet[p], Palette.SIDE[0]]]
	return [["물: %d초 소리 없음" % Drums.WET_ROUNDS, Palette.DIM]]


## What the creature's fall would bring in an event room (Creak).
static func _site_lines(w: World, a: Actor) -> Array:
	var out := []
	for site: Dictionary in w.sites:
		if site.kind == &"creak" and site.id == a.id:
			out.append([["마루의 해태. 처치: 꼬리 모두 회복", Palette.TEXT]])
	return out


## How the event room whose tile p is stands now (EventRooms).
static func _sites(w: World, p: Vector2i) -> Array[String]:
	var out: Array[String] = []
	for site: Dictionary in w.sites:
		if site.at == p and site.kind == &"altar":
			out.append("쓰러진 생물: %d/%d" % [site.fallen, Altar.NEED])
		if site.at == p and site.kind == &"yard":
			var card := Yard.prize(w, site)
			out.append("얻는 부적: %s" % (Cards.NAME[card] if card != &"" else "없음"))
	return out


## What a kind of tile does, an `이름: 값` line or a tag each; numbers from the
## rules, a shared rule as its glossary tag.
static func _notes(t: int, breakable: bool, burns: bool) -> Array[String]:
	var out: Array[String] = []
	match t:
		World.SEAL:
			out.append("막음: 길, 시야, 빛. 부술 수 없음")
			out.append("열림: 앞방의 꺼진 등불 셋이 모두 켜질 때")
			out.append("영영 닫힘: 등불이 하나라도 부서질 때")
		World.ALTAR:
			out.append("막음: 길, 주문")
			var lit := "타오름: 주위 %d칸 안에서 하늘의 생물 %d번 쓰러짐, 추락 포함"
			out.append(lit % [Altar.REACH, Altar.NEED])
			out.append("타오르면: 꼬리 모두 회복, 이 층에서 꼬리 +1")
		World.ALTAR_LIT:
			out.append("막음: 길, 주문")
			out.append("빛: %d칸" % Light.SOUL_RADIUS)
		World.LAMP:
			out.append("막음: 길, 주문. 부술 수 없음. 꺼지지 않음")
			out.append("빛: %d칸" % Light.LANTERN_RADIUS)
		World.TALISMAN:
			out.append("밟으면: 아직 없는 원소 부적 하나, 한 번")
		World.SHELF:
			out.append("밟으면: 이 층의 지도, 서고에서 한 번")
		World.VEIL:
			out.append("막음: 길, 주문")
			out.append("빛: %d칸" % Light.LANTERN_RADIUS)
			out.append("곁 피해: 매 초 %d" % World.FIRE_DAMAGE)
			out.append("물: 재가 됨. 서리: 얼음이 됨")
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
			out.append("막음: 시야. 밟으면: 쓰러짐")
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
			out.append("타격: 주위 8칸 얕은 물. 불, 냄새 지움")
		World.CENSER:
			out.append("막음: 길")
			var coals: Dictionary = Compounds.HOT[Compounds.LAVA]
			out.append("%s: 양 %d까지" % [Gas.of(Gas.INCENSE, "name"), Gas.VENT_LEVEL])
			out.append("타격: %s, 이 칸과 옆 4칸. 옆 가연성 칸에 불" % coals.name)
			out.append("%s: %d초, 피해 %d" % [coals.name, Compounds.HOT_ROUNDS, coals.harm])
		World.COURTYARD:
			out.append("달빛에 드러남.")
		World.BOARD_ROTTEN:
			out.append("벗어난 뒤: 하늘")
			out.append("소리: %d칸" % Terrain.CRACK)
		World.STATUE:
			out.append("막음: 길")
			out.append("깨어남: %s, %d칸 안" % [Bestiary.info(Statues.KIND).name, Statues.REACH])
		World.POND:
			out.append("넘어감: 주문, 멀리뛰기만")
		World.SKY:
			out.append("넘어감: 주문, 멀리뛰기만")
			out.append("추락: 적은 사라짐, 미호는 한 층 아래")
		World.WINDOW:
			out.append("막음: 길")
		World.BRIDGE:
			out.append("달빛에 드러남. 불에 타지 않음.")
		World.THORNS:
			out.append("피해: 지날 때 %d" % Compounds.THORN)
		World.MUD:
			out.append("걸음: %d초. 발소리 없음" % Compounds.MUD)
		World.TRAP_ALARM:
			out.append("밟으면: 층 전체에 소리")
		World.TRAP_COLLAPSE:
			out.append("밟으면: 하늘로 추락")
		World.TRAP_FIRE:
			out.append("밟으면: 밟은 방향 앞 %d칸에 불" % Traps.FLAME_REACH)
		World.TRAP_VINE:
			var side := 2 * Traps.VINE_REACH + 1
			out.append("밟으면: 주위 %d×%d 모두 %d초 묶음" % [side, side, Traps.ROOT_ROUNDS])
	if Tiles.of(t, "trap"):
		out.append("함정.")
	if Terrain.wall(t) and breakable:
		out.append("부서짐: 구슬. 소리: %d칸" % World.THUD)
		if Tiles.of(t, "breaks_to") != World.RUBBLE:
			out.append("%s, %s 구슬: 한 번에 무너짐" % [Cards.NAME[Cards.EARTH], Cards.NAME[Cards.METAL]])
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
	if Gas.of(g.x, "explodes"):
		out.append(_amount("폭발 피해: ", Gas.BLAST))
		out.append([["폭발 범위: 이어진 구름 전체", Palette.DIM]])
	if Gas.of(g.x, "erases"):
		out.append([["냄새: 지움", Palette.DIM]])
	return out


## A burning tile: time left, harm, light and noise.
static func _burning(left: int) -> Array:
	return [
		[["불타는 중: %d초 남음" % left, Palette.HURT]],
		_amount("피해: 매 초 ", World.FIRE_DAMAGE),
		[["빛: %d칸. 소리: %d칸" % [Light.FIRE_RADIUS, World.CRACKLE], Palette.DIM]],
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
		["꼬리: %d/%d" % [w.tails, w.max_tails()], Palette.SIDE[0]],
		[". 회복: %d초마다 1개" % World.TAIL_REGROW, Palette.DIM],
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
