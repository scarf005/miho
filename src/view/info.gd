class_name Info
extends RefCounted
## What the pointer is over, as `이름: 값` lines and bare tags: a creature's
## health, state, conditions, immunities, rival, whether it sees Miho, what
## her claws would do to it and what it strikes and casts with; a projectile
## (SpellInfo); a tile's terrain, light and sound. Every number comes from the
## rule constants; a rule many things share is a tag here and told once in
## the 도감 (Glossary). Built only from what Miho knows. Each line is a list
## of [text, Color] runs. Health is drawn as hearts (Term draws ♥ and ♡).

const STATE := ["쉬는 중", "수색 중", "추격 중"]
const WITS := ["둔함", "영리함", "교활함"]
## WITS as a word before a noun: 교활한 적, which the 도감 links to 교활함 (Keywords).
const WITS_WHO := ["둔한", "영리한", "교활한"]
## The tag of a creature that follows Miho by her scent (Bestiary tracks), told in the glossary.
const SMELL := "후각이 뛰어나다"
const SMELL_WHO := "후각이 뛰어난"
## Who 둔갑 does not fool, and how a creature finds her under 은신.
const NOT_FOOLED := ["%s 적, %s 적, 추격 중인 적에게는 효과가 없다.", WITS_WHO[Guise.SEES_THROUGH], SMELL_WHO]
const CLOAK_SMELT := ["%s 적은 쫓아온다.", SMELL_WHO]
const CLOAK_SHOT := [
	"%s 적과 %s 적은 의심 가는 칸에 도깨비불을 쏜다.", WITS_WHO[Bestiary.SHARP], WITS_WHO[Bestiary.CUNNING]
]
## The tag of a change creatures notice (Notice), told in the glossary.
const TRACE := "흔적."
## The tag of a creature of Miho's side (Actor.ally), told in the glossary.
const ALLY := "아군"
## The tag of 전기 (Cards.ELECTRIC), told in the glossary.
const ELECTRIC := "전기"
## The state of a sleeper (Actor.asleep), and the tag of a creature that never
## sleeps (Actor.sleeps).
const ASLEEP := "자는 중"
const NO_SLEEP := "잠들지 않음"
## The conditions a creature or Miho holds besides the statuses (Status), by the
## name `_conditions` shows, one `이름: 값` line each: the 도감's 상태이상.
const CONDITIONS := {
	"묶임": ["움직일 수 없다."],
	"기절": ["움직일 수도, 주문을 쓸 수도 없다.", "모으던 주문: 취소"],
	"경계": [["시간: %d초", World.WARY_ROUNDS], "수색 끝: 경계가 끝난 뒤", ["어두운 곳 시야: +%d칸", World.WARY_SIGHT]],
	"둔갑":
	[
		["풀림: 피해, 주문, 적 옆 %d초 연속", Guise.BESIDE],
		NOT_FOOLED,
	],
	Guise.NAME[Guise.TALON]:
	[
		["발톱 피해: +%d", Guise.TALON_HARM],
		["%s 면역인 적: +%d", Cards.NAME[Cards.METAL], Guise.TALON_ABSORBED],
	],
	Guise.NAME[Guise.CLOAK]:
	[
		["보임: %d칸 안, 도깨비불 붙음", Hat.REACH],
		CLOAK_SMELT,
		CLOAK_SHOT,
	],
	Guise.NAME[Guise.FLAME]: [["불 주문 피해: +%d", Guise.FLAME_HARM]],
	Guise.NAME[Guise.RAISE]: Raise.TOLD,
	Curse.NAME[Curse.REAPER]: Curse.TOLD[Curse.REAPER],
	Curse.NAME[Curse.SIGHT]: Curse.TOLD[Curse.SIGHT],
}
## How a clever creature looks for Miho under her 은신 (Aim.suspected).
const SUSPECTS := "은신한 당신을 놓치면: 의심 가는 칸에 도깨비불을 쏨"


## The lines a jar's entry adds in the 도감: each thing it can hold with its chance
## (Jars.chances) and what it does. The hover over a jar does not tell them.
static func jar_facts() -> Array:
	var curses: Array = Curse.NAME.values().map(func(n): return Lang.t(n))
	curses.append(Lang.t("%d초 뒤 되살아나는 시체") % Curse.RISE_ROUNDS)
	var does := {
		&"empty": "",
		&"water":
		(
			Lang.t(", 주위 %d칸 %s, 불과 냄새 지움")
			% [Grid.DIRS.size(), Lang.t(Tiles.of(World.SHALLOW, "name"))]
		),
		Jars.KIMCHI: Lang.t(", 체력 +%d") % World.HEAL,
		&"effigy": Lang.t(", 무작위 저주: %s") % ", ".join(curses),
		&"scarecrow": Lang.t(", 보는 적이 이 칸 수색"),
		&"salt": Lang.t(", 냄새 지움"),
		&"beans": Lang.t(", 주위 %d칸 적 기절 %d초") % [Grid.DIRS.size(), Jars.BEANS_STUN],
		&"coals":
		(
			Lang.t(", 이 칸과 옆 %d칸 %s")
			% [Placement.SIDES.size(), Lang.t(Compounds.HOT[Compounds.LAVA].name)]
		),
	}
	var chances := Jars.chances()
	var out := []
	for k in Jars.ROWS.size():
		var row: Dictionary = Jars.ROWS[k]
		out.append(
			[[Lang.t("%s: %d%%%s") % [Lang.t(row.name), chances[k], does[row.id]], Palette.DIM]]
		)
	return out


## A glossary term as the 도감 tells it: the tag, then its rules.
static func term_facts(term: String) -> Array:
	var rules: Array = Glossary.rows()[term]
	return (
		[[[Lang.t(term) + ".", Palette.TEXT]]]
		+ rules.map(func(r): return [[Lang.t(r), Palette.DIM]])
	)


## A status (Status), by its key, as the 도감 tells it: name, time, what it does.
static func status_facts(key: StringName) -> Array:
	var time := {&"wet": Status.WET, &"alight": Status.ALIGHT, &"frozen": Compounds.FROST}
	var lines: Array = [Lang.t("시간: %d초") % time[key]]
	if key == &"frozen":
		lines.append(Lang.t("젖은 적 시간: %d초") % (Status.FROZEN_WET * Compounds.FROST))
	lines.append_array(SpellInfo.status_does(key))
	return [[[Lang.t(Status.NAME[key]), Palette.STATUS[key][1]]]] + _tags(lines)


## A condition (`CONDITIONS`), by its name, as the 도감 tells it.
static func condition_facts(name: String) -> Array:
	var lines := [[[Lang.t(name), Palette.TEXT]]]
	if name == Guise.NAME[Guise.FLAME]:
		lines.append_array(nature(Guise.FLAME_KIND))
	lines.append_array(_tags(CONDITIONS[name]))
	return lines


## Lines of text: a string, or a format string and its numbers; each in the language shown.
static func _tags(lines: Array) -> Array:
	return lines.map(func(l): return [[_text(l), Palette.TEXT]])


static func _text(line: Variant) -> String:
	if not line is Array:
		return Lang.t(line)
	return Lang.t(line[0]) % line.slice(1).map(func(a): return Lang.t(a) if a is String else a)


## Lines for map tile p, or empty when Miho knows nothing there.
static func at(w: World, p: Vector2i) -> Array:
	if not Grid.inside(p):
		return []
	var i := Grid.index(p)
	if w.seen[i] == 1:
		var a := w.actor_at(p)
		if a != null and Hat.shown(w, a):
			return creature(w, a)
		var s := shot_at(w, p)
		if s != null:
			return SpellInfo.shot(w, s)
	if w.known[i] == 0:
		return []
	return terrain(w, p)


## The projectile `at` shows for map tile p: one in sight with no creature shown on its tile.
static func shot_at(w: World, p: Vector2i) -> Shot:
	var a := w.actor_at(p)
	if not Grid.inside(p) or w.seen[Grid.index(p)] != 1 or (a != null and Hat.shown(w, a)):
		return null
	return w.shot_at(p)


## A creature as the hover tells it: what it is, how it stands now (state,
## conditions, sight, the harm a claw does it now), then what it strikes and
## casts with.
static func creature(w: World, a: Actor) -> Array:
	if a.is_miho():
		return _miho(w, a, _head(a))
	return _profile(a) + _situation(w, a) + _arms(a, w.cards)


## What a creature is, whatever its state: the 도감's text. `held` are the
## talismans Miho holds, whose drop is no news.
static func creature_facts(a: Actor, held: Array) -> Array:
	return _profile(a) + _arms(a, held)


static func _head(a: Actor) -> Array:
	var head := [
		[Lang.t(a.info().name) + " ", Palette.KIND[a.kind]], [hearts(a.hp, a.max_hp), Palette.HURT]
	]
	Lang.capitalize(head)
	return head


## Name and health, elements, weakness and immunities.
static func _profile(a: Actor) -> Array:
	return [_head(a)] + nature(a.nature_kind())


## The elements of a creature of `kind`, what beats them and what it takes no
## harm from (DCSS `_monster_stat_description`).
static func nature(kind: StringName) -> Array:
	var lines := []
	var elements := Bestiary.elements(kind)
	if not elements.is_empty():
		var line := [[Lang.t("오행: "), Palette.DIM]]
		for c in elements:
			line.append(
				[
					Lang.t("{0}({1}) ").format(
						[Lang.t(Cards.GLYPH[c], "talisman"), Lang.t(Cards.NAME[c])]
					),
					Palette.CARD[c]
				]
			)
		lines.append(line)
		lines.append(_weakness(kind))
	lines.append_array(_immunities(kind))
	return lines


## What a creature is doing. A resting one reads by what it does: asleep (eyes
## shut), on patrol, walking back home, or just resting.
static func state(a: Actor) -> String:
	if a.alert != Actor.REST:
		return Lang.t(STATE[a.alert])
	if a.asleep():
		return Lang.t(ASLEEP)
	if a.guard and a.pos == a.home:
		return Lang.t("지키는 중")
	if a.following():
		return Lang.t("따라가는 중")
	if a.info().get("patrol", false):
		return Lang.t("순찰 중")
	return Lang.t("돌아가는 중" if a.pos != a.home else STATE[Actor.REST])


## How a creature stands now: its state, conditions, whether it sees Miho and
## what her claw does to it.
static func _situation(w: World, a: Actor) -> Array:
	var lines := []
	if a.ally():
		lines.append([[Lang.t(ALLY) + ".", Palette.SIDE[0]]])
		if Raise.risen(a):
			lines.append([[Lang.t("이 층에 남는다."), Palette.DIM]])
	lines.append([[state(a), Palette.ALERT[maxi(a.alert, 1)]]])
	if a.alert == Actor.SEARCH:
		lines.append([[_search_left(a), Palette.TEXT]])
	lines.append_array(_conditions(w, a))
	if a.fighting():
		var rival := _name_of(w, w.actor(a.rival))
		lines.append([[Lang.t("싸우는 중: %s") % rival, Palette.ALERT[2]]])
		lines.append([[Lang.t("  남은 시간: %d초") % a.grudge, Palette.ALERT[2]]])
	if a.drumming():
		lines.append([[Lang.t("북 치러 가는 중."), Palette.SOUND]])
	if a.ally():
		return lines
	if Guise.knows(w, a):
		lines.append([[Lang.t("당신을 볼 수 있다"), Palette.HURT]])
	elif w.sees(a, w.player().pos):
		var kind := Guise.GUISE if Guise.fools(a, w.player()) else Guise.CLOAK
		lines.append([[Lang.t("%s한 당신을 알아볼 수 없다") % Lang.t(Guise.NAME[kind]), Palette.SIDE[0]]])
	else:
		lines.append([[Lang.t("당신을 볼 수 없다"), Palette.SIDE[0]]])
	if w.caught_unawares(a):
		lines.append(_amount("기습 피해: ", w.claw_harm(w.player(), true, a)))
	return lines


## The name of creature `b` when Miho sees it, else "무언가".
static func _name_of(w: World, b: Actor) -> String:
	return Lang.t(b.info().name if b != null and Hat.shown(w, b) else "무언가")


## What it is like, what it strikes with, what it eats and what it leaves, then
## the spells it casts: the list that grows longest comes last (DCSS
## `_monster_stat_description`). Its attack and each spell are one row.
static func _arms(a: Actor, held: Array) -> Array:
	var spec := a.info()
	var lines := []
	var traits := _traits(a, Bestiary.elements(a.kind))
	var tags := traits.filter(func(t): return not t.contains(": "))
	if not tags.is_empty():
		lines.append(_row(tags.map(func(t): return [[t, Palette.DIM]])))
	for t: String in traits.filter(func(t): return t.contains(": ")):
		lines.append([[t, Palette.DIM]])
	if not spec.get("shout", {}).is_empty():
		lines.append([[Lang.t("말할 수 있다."), Palette.DIM]])
	if spec.get("hat", false):
		lines.append([[Lang.t("은신."), Palette.DIM]])
	if spec.has("melee"):
		lines.append(_melee(spec.melee))
	var eats: StringName = spec.get("eats", &"")
	if eats != &"":
		lines.append(
			[
				[Lang.t("먹이: "), Palette.TEXT],
				[Lang.t("%s 주문") % Lang.t(Cards.NAME[eats]), Palette.CARD[eats]]
			]
		)
		lines.append([[Lang.t("  최대 체력: "), Palette.TEXT], ["+%d" % Bestiary.GROWTH, Palette.HURT]])
		lines.append([[Lang.t("  체력: "), Palette.TEXT], ["+%d" % Bestiary.GROWTH, Palette.HURT]])
	var drop: StringName = spec.get("drop", &"")
	if drop != &"" and not held.has(drop):
		lines.append(
			[
				[Lang.t("소지품: "), Palette.TEXT],
				[Lang.t("%s 부적") % Lang.t(Cards.NAME[drop]), Palette.CARD[drop]]
			]
		)
	lines.append_array(_casts(a))
	return lines


## Parts (each a list of runs) on one row, a " · " between them.
static func _row(parts: Array) -> Array:
	var out := []
	for part: Array in parts:
		if not out.is_empty():
			out.append([Codex.SEP, Palette.DIM])
		out.append_array(part)
	return out


## Its attack as one row: how it strikes, then the harm, the throw and the roots
## it has (DCSS `_monster_attacks_description`).
static func _melee(melee: Dictionary) -> Array:
	var parts := [[[Lang.t("근접: %s") % Lang.t(melee.name), Palette.TEXT]]]
	if melee.damage > 0:
		parts.append(SpellInfo._line("피해", str(melee.damage), Palette.HURT))
	if melee.get("throw", 0) > 0:
		parts.append(SpellInfo._line("던짐", Lang.t("%d칸") % melee.throw))
	if melee.get("root", 0) > 0:
		parts.append(SpellInfo._line("묶임", Lang.t("%d초") % melee.root))
	if melee.get("pull", false):
		parts.append([[Lang.t("끌어당김"), Palette.TEXT]])
	return _row(parts)


## Miho herself: tails, claws, conditions and how visible she is. Her footsteps
## are each tile's own (`_notes`).
static func _miho(w: World, a: Actor, head: Array) -> Array:
	var lines := [head] + _tails(w) + _claws(w, a)
	lines.append_array(_conditions(w, a))
	lines.append_array(_tags(Curse.worn(w).map(func(c): return Curse.NAME[c])))
	lines.append_array(nature(a.nature_kind()))
	if a.flame:
		lines.append([[Lang.t("불 주문 피해: +%d") % Guise.FLAME_HARM, Palette.TEXT]])
	if a.guise:
		var form: String = Lang.t(Bestiary.info(a.form).name)
		lines.append([[Lang.t("둔갑"), Palette.TEXT], [": " + form, Palette.SIDE[0]]])
		lines.append([[Lang.t("적 옆: %d/%d초") % [a.beside, Guise.BESIDE], Palette.DIM]])
	elif a.prey != &"" and w.cards.has(Cards.WOOD) and w.cards.has(Cards.EARTH):
		lines.append([[Lang.t("둔갑할 모습: %s") % Lang.t(Bestiary.info(a.prey).name), Palette.DIM]])
	lines.append(_hidden(w, a.pos))
	return lines


## What Miho's claws do: plain, and to a creature caught unawares; a line each.
static func _claws(w: World, a: Actor) -> Array:
	return [_amount("발톱 피해: ", w.claw_harm(a, false)), _amount("기습 피해: ", w.claw_harm(a, true))]


## A line of text with a harm number in the middle: `before`, n, `after`.
static func _amount(before: String, n: int, after := "") -> Array:
	var line := [[Lang.t(before), Palette.TEXT], [str(n), Palette.HURT]]
	if after != "":
		line.append([Lang.t(after), Palette.TEXT])
	return line


## The elements whose spells hurt a creature twice as much.
static func _weakness(kind: StringName) -> Array:
	var line := [[Lang.t("약점: "), Palette.DIM]]
	for c in Bestiary.weak_to(kind):
		line.append([Lang.t(Cards.NAME[c]), Palette.CARD[c]])
		line.append([", ", Palette.DIM])
	line.pop_back()
	if Bestiary.info(kind).get("absorb", &"") == &"nofire":
		line.append([Lang.t(" (불과 함께)"), Palette.DIM])
	return line


## Everything the creature takes no harm or effect from, one "면역" line each.
static func _immunities(kind: StringName) -> Array:
	var spec := Bestiary.info(kind)
	var out := []
	match spec.get("absorb", &""):
		&"fire":
			out.append(_immune("불 주문, 불타는 칸", Palette.CARD[Cards.FIRE]))
			out.append(
				[[Lang.t("피해 절반: "), Palette.DIM], [Lang.t("불이 섞인 주문"), Palette.CARD[Cards.FIRE]]]
			)
		&"nofire":
			out.append(_immune("불 없는 주문", Palette.DIM))
	if spec.get("deaf", false):
		out.append(_immune("소음", Palette.SOUND))
	return out


static func _immune(what: String, color: Color) -> Array:
	return [[Lang.t("면역: "), Palette.DIM], [Lang.t(what), color]]


## What holds it now, with the seconds left: blind, rooted, stunned, wary, and
## standing in fire unless it eats fire.
## How many more looks around its spot a searching creature takes before it
## rests (Mind.search); a wary one keeps looking until it is no longer wary.
static func _search_left(a: Actor) -> String:
	var left := World.SEARCH_ROUNDS + 1 - a.lost
	if a.wary > 0 and left <= 1:
		return Lang.t("수색: 경계가 끝날 때까지")
	return Lang.t("수색: %d번 더") % left


static func _conditions(w: World, a: Actor) -> Array:
	var out := []
	for c in [
		[a.blind, "눈멂"],
		[a.rooted, "묶임"],
		[a.stunned, "기절"],
		[a.wary, "경계"],
	]:
		if c[0] > 0:
			out.append([[Lang.t("%s: %d초") % [Lang.t(c[1]), c[0]], Palette.TEXT]])
	for kind in [Guise.TALON, Guise.CLOAK, Guise.FLAME, Guise.RAISE]:
		if a.get(kind):
			out.append([[Lang.t(Guise.NAME[kind]), Palette.TEXT]])
	out.append_array(_status(a))
	if (
		w.burning.has(a.pos)
		and a.alight <= 0
		and not Bestiary.absorbs(a.nature_kind(), Spell.make([Cards.FOX, Cards.FIRE]))
	):
		var fierce := Tiles.fierce[w.tile(a.pos)] == 1
		var fire := Lang.t("맹렬한 불" if fierce else "불타는 칸")
		out.append([[Lang.t("%s 위: %d초") % [fire, w.burning[a.pos]], Palette.TEXT]])
		out.append(_amount("  초당 피해: ", _fire_damage(fierce)))
	if (
		Veil.scorches(w, a.pos)
		and not Bestiary.absorbs(a.nature_kind(), Spell.make([Cards.FOX, Cards.FIRE]))
	):
		out.append(_amount("도깨비불 장막 옆 칸 초당 피해: ", World.FIRE_DAMAGE))
	for s in w.shots:
		if s.host == a.id and not s.gone:
			var runs := [[s.spell.shown(), Palette.card(s.spell.slots.back())]]
			var clings := Lang.t(" 붙음: %d초") % s.life if s.life > 0 else Lang.t(" 붙음")
			out.append(runs + [[clings, Palette.TEXT]])
	if (
		w.hot.has(a.pos)
		and not Bestiary.absorbs(a.nature_kind(), Spell.make([Cards.FOX, Cards.FIRE]))
	):
		var h: Vector2i = w.hot[a.pos]
		var spec: Dictionary = Compounds.HOT[h.x]
		out.append([[Lang.t("%s 위: %d초") % [Lang.t(spec.name), h.y], Palette.TEXT]])
		out.append(_amount("  초당 피해: ", spec.harm))
	out.append_array(_gas(w, a.pos))
	return out


## The status it holds (Status), with the seconds left and what it does.
static func _status(a: Actor) -> Array:
	var key := Status.of(a)
	if key == &"":
		return []
	var line := [
		[Lang.t(Status.NAME[key]), Palette.STATUS[key][1]],
		[Lang.t(": %d초") % Status.rounds(a), Palette.TEXT]
	]
	return [line] + SpellInfo.status_does(key).map(func(d): return [["  " + d, Palette.TEXT]])


## Each spell it casts at its rank as one row: its name, its cooldown, the harm
## and reach for this caster (SpellInfo.cast) and whether it is charging it (DCSS
## `_describe_book`). How many it casts at once is from Bestiary.DOUBLES. One with
## mana shows its mana first and each spell's price in place of the rest: its
## thirty spells would not fit the hover otherwise.
static func _casts(a: Actor) -> Array:
	var out := []
	var has_mana := Bestiary.mana(a.kind) > 0
	var own: bool = a.info().get("tails", false)
	if has_mana:
		var left := Lang.t("꼬리: %d/%d" if own else "마력: %d/%d")
		out.append([[left % [a.mana, Bestiary.mana(a.kind)], Palette.SIDE[0]]])
		out.append([_regrows()])
	if (a.rank >= Bestiary.DOUBLES or has_mana) and a.repertoire().size() > 1:
		out.append([[Lang.t("동시 주술: %d개") % Aim.CASTS, Palette.TEXT]])
	for group: Array in _by_title(a):
		var spell: Spell = group[0]
		var parts: Array = [
			[
				[Lang.t("주문: " if own else "주술: "), Palette.TEXT],
				[spell.shown(), Palette.card(spell.slots.back())]
			]
		]
		if has_mana:
			var price := "꼬리" if own else "마력"
			parts.append(SpellInfo._line(price, _joined(group.map(func(s): return str(s.cost())))))
		else:
			parts.append(SpellInfo._line("간격", Lang.t("%d초") % a.info().cd))
		if own or not has_mana:
			parts.append_array(_effects(group))
		var keys := group.map(func(s): return s.key())
		if a.intent.any(func(plan): return Spell.make(plan.cards).key() in keys):
			parts.append([[Lang.t("모으는 중"), Palette.HURT]])
		elif a.cooldown > 0:
			parts.append(SpellInfo._line("다음", Lang.t("%d초 뒤") % a.cooldown))
		out.append(_row(parts))
	return out


## The spells of its repertoire, those of one name together, so a name shows once.
static func _by_title(a: Actor) -> Array:
	var groups := {}
	for cast: Array in a.repertoire():
		var spell := Bestiary.spell(a.kind, cast)
		if not groups.has(spell.title()):
			groups[spell.title()] = []
		groups[spell.title()].append(spell)
	return groups.values()


## The harm and reach of the spells of one name: a label once, its differing
## values joined in order.
static func _effects(group: Array) -> Array:
	var values := {}
	for spell: Spell in group:
		for e: Array in SpellInfo.cast(spell):
			values.get_or_add(e[0], [e[2], []])[1].append(e[1])
	return values.keys().map(
		func(label): return SpellInfo._line(label, _joined(values[label][1]), values[label][0])
	)


static func _joined(values: Array) -> String:
	var unique := []
	for v in values:
		if not v in unique:
			unique.append(v)
	return ", ".join(unique)


static func _traits(a: Actor, elements: Array) -> Array:
	var spec := a.info()
	var out := [] if a.ally() else [Lang.t(WITS[Bestiary.wits(a.kind)])]
	if spec.get("patrol", false):
		out.append(Lang.t("순찰"))
	if spec.get("move", &"static") == &"static":
		out.append(Lang.t("고정"))
	if Bestiary.swims(a.kind):
		out.append(Lang.t("수중"))
	if spec.get("step", 0) > 0:
		out.append(Lang.t("발소리: %d칸") % spec.step)
	if elements.has(Cards.WOOD):
		out.append(Lang.t("불에 탐"))
	if spec.get("hunts", false):
		out.append(Lang.t("위치 감지"))
	if spec.get("tracks", false):
		out.append(Lang.t(SMELL))
	if spec.get("stokes", false):
		out.append(Lang.t("등불 켜기"))
	return out


## A tile as the hover tells it: what it is, then how well it is lit and seen.
static func terrain(w: World, p: Vector2i) -> Array:
	var t := w.tile(p)
	var lines := terrain_facts(w, p, true)
	if Tiles.sight[t] == 0 or Tiles.walk[t] == 1:
		lines.append(_light_line(w, p))
	return lines


## The name a tile's hover heads with, before it is translated.
static func tile_name(w: World, p: Vector2i) -> String:
	return _lies(w, p, [Tiles.of(w.tile(p), "name"), []])[0]


## What lies on tile `p` besides its own kind, as [name, notes]: the stairs, a
## pickup or a scroll; else `plain`, the same pair for the tile's kind.
static func _lies(w: World, p: Vector2i, plain: Array) -> Array:
	if p == w.stairs:
		return ["계단", [Lang.t("체력: +%d") % World.HEAL, "꼬리: 모두 회복"]]
	if p == w.elixir:
		return ["영약", ["효과: 사람이 됨"]]
	if w.peaches.has(p):
		return ["복숭아", [Lang.t("체력: +%d") % World.HEAL, Lang.t("가득 찼을 때 최대 체력: +%d") % World.HEAL]]
	if Jars.spots(w).has(p):
		return [
			Jars.name_of(Jars.KIMCHI),
			[
				Lang.t("체력: +%d") % World.HEAL,
				Lang.t("먹은 뒤 냄새: %d초 동안 진함") % Jars.PUNGENT_ROUNDS,
			]
		]
	if Scrolls.card_at(w, p) != &"":
		return [Lang.t("%s 주문서") % Lang.t(Cards.NAME[Scrolls.card_at(w, p)]), plain[1]]
	return plain


## What a tile is and does, whatever the light: the 도감's text. The hover also
## tells how much gas lies on it (`now`).
static func terrain_facts(w: World, p: Vector2i, now := false) -> Array:
	var t := w.tile(p)
	var breakable := Terrain.breakable(w, p)
	var burns := w.burning.has(p) and w.seen[Grid.index(p)] == 1
	var lies := _lies(w, p, [Tiles.of(t, "name"), _notes(t, breakable, burns, Terrain.plank(w, p))])
	var name: String = lies[0]
	var notes: Array = lies[1]
	var health: int = Tiles.of(t, "health") if breakable else 0
	var head := [[Lang.t(name), Palette.TEXT]]
	if health > 0:
		head.append([" " + hearts(health, health), Palette.HURT])
	var lines := [head]
	for note in notes:
		lines.append([[Lang.t(note), Palette.DIM]])
	if burns:
		lines.append_array(_burning(w.burning[p], Tiles.fierce[t] == 1))
	if w.hot.has(p) and w.seen[Grid.index(p)] == 1:
		var h: Vector2i = w.hot[p]
		var spec: Dictionary = Compounds.HOT[h.x]
		lines.append([[Lang.t("%s: %d초 남음") % [Lang.t(spec.name), h.y], Palette.HURT]])
		lines.append(_amount("초당 피해: ", spec.harm))
	lines.append_array(_gas(w, p, now))
	if w.vents.has(p):
		var vent := [
			[Lang.t("뿜는 기체: "), Palette.DIM],
			[Lang.t(Gas.of(w.vents[p], "name")), Palette.GAS[w.vents[p]][1]]
		]
		lines.append(vent)
		lines.append([[Lang.t("  최대 양: %d") % Gas.VENT_LEVEL, Palette.DIM]])
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
	var label := Lang.t(Notice.LABEL[change.kind])
	var color := Palette.TEXT
	if change.kind == &"body" and not body.has("rises"):
		label = Lang.t("쓰러진 %s") % Lang.t(Bestiary.info(body.kind).name)
		color = Palette.KIND[body.kind]
	return [
		[[label, color], [Lang.t(": %d초 전") % (w.round_no - change.round), Palette.DIM]],
		[[Lang.t(TRACE), Palette.DIM]],
	]


## Whether a drum would sound: wet ones are silent, for how long.
static func _drum_line(w: World, p: Vector2i) -> Array:
	if w.wet.has(p):
		return [
			[[Lang.t("젖음: %d초") % w.wet[p], Palette.SIDE[0]]], [[Lang.t("소음: 없음"), Palette.SIDE[0]]]
		]
	return [[[Lang.t("물: %d초 동안 소음 없음") % Drums.WET_ROUNDS, Palette.DIM]]]


## What a kind of tile does, an `이름: 값` line or a tag each; numbers from the
## rules, a shared rule as its glossary tag.
static func _notes(t: int, breakable: bool, burns: bool, plank: bool) -> Array[String]:
	var out: Array[String] = []
	match t:
		World.ALTAR:
			out.append(Lang.t("막음: 길, 주문"))
		World.ALTAR_LIT:
			out.append(Lang.t("막음: 길, 주문"))
			out.append(Lang.t("빛: %d칸") % Light.SOUL_RADIUS)
		World.LAMP:
			out.append(Lang.t("막음: 길, 주문"))
			out.append(Lang.t("빛: %d칸") % Light.LANTERN_RADIUS)
		World.VEIL:
			out.append(Lang.t("막음: 길, 주문"))
			out.append(Lang.t("빛: %d칸") % Light.LANTERN_RADIUS)
			out.append(Lang.t("옆 칸 초당 피해: %d") % World.FIRE_DAMAGE)
		World.DOOR:
			out.append(Lang.t("막음: 시야"))
			out.append(Lang.t("여닫을 때 소음: %d") % Terrain.SLIDE)
		World.DOOR_OPEN:
			out.append(Lang.t("여닫을 때 소음: %d") % Terrain.SLIDE)
		World.DRUM:
			out.append(Lang.t("칠 때 소음: 층 전체"))
			out.append(Lang.t("북소리를 들은 적: 북 친 적이 당신을 마지막으로 본 곳을 수색"))
			out.append(Lang.t("북 치는 적: 당신을 쫓는 영리한 적, 걸어서 %d칸 안") % Drums.REACH)
			out.append(Lang.t("찢어짐: 구슬, 부딪침"))
		World.LANTERN:
			out.append(Lang.t("빛: %d칸") % Light.LANTERN_RADIUS)
		World.LANTERN_OUT:
			out.append(Lang.t("다시 켜짐: 불, 수색하는 적"))
		World.BAMBOO:
			out.append(Lang.t("막음: 시야, 빛"))
		World.REEDS:
			out.append(Lang.t("막음: 시야"))
			out.append(Lang.t("밟으면: 쓰러짐"))
		World.PILLAR:
			out.append(Lang.t("막음: 길, 시야, 빛"))
		World.WOOD_WALL:
			out.append(Lang.t("막음: 길, 시야, 빛"))
			out.append(Lang.t("부서짐: 구슬"))
		World.SCREEN:
			out.append(Lang.t("막음: 길, 시야"))
			out.append(Lang.t("타격: 쓰러짐"))
		World.JAR:
			out.append(Lang.t("막음: 길"))
			out.append(Lang.t("타격: 깨짐"))
		World.CENSER:
			out.append(Lang.t("막음: 길"))
			var coals: Dictionary = Compounds.HOT[Compounds.LAVA]
			out.append(
				Lang.t("%s 최대 양: %d") % [Lang.t(Gas.of(Gas.INCENSE, "name")), Gas.VENT_LEVEL]
			)
			out.append(Lang.t("타격: %s, 이 칸과 옆 %d칸") % [Lang.t(coals.name), Placement.SIDES.size()])
			out.append(Lang.t("타격: 옆 가연성·인화성 칸에 불"))
			out.append(Lang.t("%s: %d초") % [Lang.t(coals.name), Compounds.HOT_ROUNDS])
			out.append(Lang.t("%s 초당 피해: %d") % [Lang.t(coals.name), coals.harm])
		World.BOARD_ROTTEN:
			out.append(Lang.t("소음: %d") % Terrain.CRACK)
		World.STATUE:
			out.append(Lang.t("막음: 길"))
		World.POND:
			out.append(Lang.t("주문과 %s로만 건널 수 있다.") % Lang.t(Spell.SHAPE_NAME[Spell.LEAP]))
		World.SKY:
			out.append(Lang.t("주문과 %s로만 건널 수 있다.") % Lang.t(Spell.SHAPE_NAME[Spell.LEAP]))
			out.append(Lang.t("사라짐: 추락한 적"))
			out.append(Lang.t("층당 추락 피해: %d") % Fall.DAMAGE)
		World.WINDOW:
			out.append(Lang.t("막음: 길"))
		World.THORNS:
			out.append(Lang.t("지날 때 피해: %d") % Compounds.THORN)
		World.MUD:
			out.append(Lang.t("밟으면: 묶임 %d초") % Compounds.MUD)
		World.TRAP_ALARM:
			out.append(Lang.t("밟을 때 소음: 층 전체"))
		World.TRAP_COLLAPSE:
			out.append(Lang.t("밟으면: 하늘로 추락"))
		World.TRAP_FIRE:
			out.append(Lang.t("밟으면: 밟은 방향 앞 %d칸에 불") % Traps.FLAME_REACH)
		World.TRAP_VINE:
			var side := 2 * Traps.VINE_REACH + 1
			out.append(Lang.t("밟으면: 주위 %d×%d 모두 묶임") % [side, side])
			out.append(Lang.t("묶임: %d초") % Traps.ROOT_ROUNDS)
	if Tiles.of(t, "trap"):
		out.append(Lang.t("함정."))
	if Terrain.wall(t) and breakable:
		out.append(Lang.t("부서짐: 구슬"))
		out.append(Lang.t("부서질 때 소음: %d") % World.THUD)
	if Terrain.knockable(t) and t != World.DRUM:
		out.append(Lang.t("부딪칠 때 소음: %d") % Tiles.of(t, "hit")[0])
	var tread: Array = Tiles.of(t, "tread")
	if tread[0] > 0:
		out.append(Lang.t("발소리: %d칸") % tread[0])
	if Tiles.of(t, "scentless"):
		out.append(Lang.t("냄새가 남지 않음."))
	if Tiles.burns[t] == 1 and not burns:
		var spread := roundi(Tiles.of(t, "spread") * 100)
		out.append(Lang.t("인화성." if Tiles.fierce[t] == 1 else "가연성."))
		if Tiles.fierce[t] == 0 and spread != roundi(Tiles.DEFAULT.spread * 100):
			out.append(Lang.t("번질 확률: %d%%") % spread)
	if plank:
		out.append(Lang.t("불탄 뒤: %s") % Lang.t(Tiles.of(World.SKY, "name")))
	for e in Cards.ELEMENTS:
		var change: Variant = Tiles.of(t, "reacts").get(e)
		if change != null and (breakable or not Terrain.wall(t)):
			out.append("%s: %s" % [Lang.t(Cards.NAME[e]), Lang.t(Tiles.of(change, "name"))])
	return out


## The gas on a tile in sight: kind, how fast it thins, its harm and what it
## wets, and, when `now`, how much lies there and whether that blocks sight (the
## 도감 tells what the gas is, not how much). Tiles out of sight keep no gas.
static func _gas(w: World, p: Vector2i, now := true) -> Array:
	var g := Gas.at(w, p)
	if g.x < 0 or w.seen[Grid.index(p)] == 0:
		return []
	var color: Color = Palette.GAS[g.x][1]
	var head := [[Lang.t(Gas.of(g.x, "name")), color]]
	if now:
		head.append([": %d/%d" % [g.y, Gas.MAX], Palette.DIM])
	var out := [head]
	if Gas.of(g.x, "blocks") and not now:
		out.append([[Lang.t("시야 막음: %d 이상") % Gas.OPAQUE, Palette.DIM]])
	elif Gas.of(g.x, "blocks") and g.y >= Gas.OPAQUE:
		out.append([[Lang.t("시야를 막음."), Palette.DIM]])
	out.append([[Lang.t("감소: 초당 %d%%") % Gas.of(g.x, "decay"), Palette.DIM]])
	if Gas.of(g.x, "harm") > 0:
		out.append(_amount("초당 피해: ", Gas.of(g.x, "harm")))
	if Gas.of(g.x, "wets"):
		out.append([[Lang.t("북: %d초 동안 소음 없음") % Drums.WET_ROUNDS, Palette.DIM]])
	if Gas.of(g.x, "erases"):
		out.append([[Lang.t("지워짐: 냄새"), Palette.DIM]])
	return out


## What a round on a burning tile costs, fierce (Tiles.fierce) or not.
static func _fire_damage(fierce: bool) -> int:
	return World.FIERCE_DAMAGE if fierce else World.FIRE_DAMAGE


## A burning tile: time left, harm, light and noise.
static func _burning(left: int, fierce: bool) -> Array:
	return [
		[[Lang.t("%s: %d초 남음") % [Lang.t("맹렬한 불" if fierce else "불타는 중"), left], Palette.HURT]],
		_amount("초당 피해: ", _fire_damage(fierce)),
		[[Lang.t("빛: %d칸") % Light.FIRE_RADIUS, Palette.DIM]],
		[[Lang.t("소음: %d") % World.CRACKLE, Palette.DIM]],
	]


static func _light_line(w: World, p: Vector2i) -> Array:
	var i := Grid.index(p)
	if w.seen[i] == 0:
		if w.dim[i] == 1:
			return [
				[
					(
						Lang.t("가림: %s")
						% Lang.t(Tiles.of(World.BAMBOO, "name") if w.hides(p) else "어둠")
					),
					Palette.DIM
				]
			]
		return [[Lang.t("보이지 않음."), Palette.DIM]]
	return _hidden(w, p)


## Whether heaven would see Miho standing on p.
static func _hidden(w: World, p: Vector2i) -> Array:
	if w.hides(p):
		return [
			[Lang.t("%s 속: 바로 옆에서만 보임") % Lang.t(Tiles.of(World.BAMBOO, "name")), Palette.SIDE[0]]
		]
	if w.lit(p):
		return [[Lang.t("밝음."), Palette.ALERT[1]]]
	var reach: int = World.NIGHT[Actor.HEAVEN] + Curse.sight_bonus(w)
	return [[Lang.t("어두움: %d칸 안에서만 보임") % reach, Palette.SIDE[0]]]


## The run telling how fast tails, or mana, grow back.
static func _regrows() -> Array:
	return [Lang.t("회복: %d초마다 %d") % [World.TAIL_REGROW, World.TAIL_REGROWN], Palette.DIM]


static func _tails(w: World) -> Array:
	return [
		[[Lang.t("꼬리: %d/%d") % [w.tails, w.max_tails()], Palette.SIDE[0]]],
		[_regrows()],
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
	var wait := d == Vector2i.ZERO
	var lines := []
	if f.hurt_me() > 0:
		var hurt := Lang.t("기다릴 때 피해: %d" if wait else "이 칸으로 이동할 때 피해: %d")
		lines.append([[hurt % f.hurt_me(), Palette.HURT]])
	if f.drops_me():
		var drop := Lang.t("기다릴 때 추락: %d층" if wait else "이 칸으로 이동할 때 추락: %d층")
		lines.append([[drop % f.after.depth, Palette.HURT]])
	if not f.noticed.is_empty():
		var names := f.noticed.keys().map(func(id): return Lang.t(f.after.actor(id).info().name))
		var noticed := Lang.t("기다릴 때 들킴: %s" if wait else "이 칸으로 이동할 때 들킴: %s")
		lines.append([[noticed % ", ".join(names), Palette.ALERT[2]]])
	return lines
