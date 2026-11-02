class_name Messages
extends RefCounted
## The message log: a round's events as sentences, from what Miho perceived
## only: events where she saw them, and noises she heard out of sight. Hidden
## events and kinds of event it does not know give no line. Each line is a list
## of [text, Color] runs, with names, harm and sound words in their colours.
## What she perceived is Perceived's: the map's popups read the same facts.
## A line repeated right after itself or in its own round is counted instead of
## written again. A line is kept in every language (`variants`), so the log
## follows a change of language. A sentence is a message id with `{0}`, `{1}`
## for the names and numbers in it (Lang.runs); a Korean particle pair follows
## a placeholder as `이/가`.

const KEEP := 2000
const TEXT := Palette.TEXT
## What a creature's map mark says, for one that comes into sight marked.
const STATE := {
	"!": "추격을 시작했다",
	"?": "수색을 시작했다",
	"x": "눈이 멀었다",
}
## How a creature is told to be freed of what held it, by event.
const FREED := {&"unroot": "풀려났다", &"unstun": "정신을 차렸다", &"unblind": "다시 볼 수 있게 되었다"}

## What a jar's effect does, as the log ends the line (Jars).
const JAR_DOES := {
	&"water": "쏟아졌다",
	Jars.KIMCHI: "나왔다",
	&"effigy": "찢어졌다",
	&"scarecrow": "쓰러졌다",
	&"salt": "흩어졌다",
	&"beans": "쏟아졌다",
	&"coals": "쏟아졌다",
}

## {variants: {language: runs}, text, round, n}; `text` is the Korean line, and
## `shown` the painted runs of each language, once.
var lines: Array[Dictionary] = []


## Adds a line that reads the same in every language.
func add(runs: Array, round_no: int) -> void:
	_push(_all(func(_code): return runs), round_no)


## Adds a line saying `text`: a message id, or a Callable that makes the line in the
## language it is called in.
func add_text(text: Variant, round_no: int) -> void:
	_push(
		_all(func(_code): return [[text.call() if text is Callable else Lang.t(text), TEXT]]),
		round_no
	)


## Adds the lines of a round (`of`), each in every language.
func add_round(before: World, after: World, events: Array) -> void:
	var told := _told(before, after, events)
	var by_code := {}
	for code in Lang.NAMES:
		Lang.forced = code
		by_code[code] = _render(before, after, told)
	Lang.forced = &""
	for k in by_code[&"ko"].size():
		_push(_all(func(code): return by_code[code][k]), after.round_no)


func _all(runs_of: Callable) -> Dictionary:
	var out := {}
	for code in Lang.NAMES:
		Lang.forced = code
		out[code] = runs_of.call(code)
	Lang.forced = &""
	return out


func _push(variants: Dictionary, round_no: int) -> void:
	var text := plain(variants[&"ko"])
	var i := lines.size() - 1
	while i >= 0 and (i == lines.size() - 1 or lines[i].round == round_no):
		if lines[i].text == text:
			lines[i].n += 1
			lines[i].round = round_no
			lines[i].erase("shown")
			return
		i -= 1
	lines.append({variants = variants, text = text, round = round_no, n = 1})
	if lines.size() > KEEP:
		lines = lines.slice(-KEEP)


## The line as shown, in the language shown, with its count, painted once: a long
## log is reopened often.
static func shown(line: Dictionary) -> Array:
	var code := Lang.active()
	if not line.has("shown"):
		line.shown = {}
	if not line.shown.has(code):
		var runs: Array = line.variants[code]
		line.shown[code] = Keywords.paint(
			runs if line.n == 1 else runs + [[" ×%d" % line.n, Palette.DIM]]
		)
	return line.shown[code]


## A line's text without its colours.
static func plain(runs: Array) -> String:
	return "".join(runs.map(func(r): return r[0]))


## Lines for one round from `before` to `after`: one per fact Miho is told.
static func of(before: World, after: World, events: Array) -> Array:
	return _render(before, after, _told(before, after, events))


## What Miho perceived of a round, in no language.
static func _told(before: World, after: World, events: Array) -> Dictionary:
	var perceived := Perceived.of(before, after, events)
	return {facts = perceived.facts, spotted = Perceived.spotted(before, after)}


static func _render(before: World, after: World, told: Dictionary) -> Array:
	var out := []
	var last := {}
	for f in told.facts:
		if f.t == &"noise":
			out.append(_t("멀리서 {0} 소리를 들었다", [[f.word, Palette.SOUND]]))
			continue
		if f.t == &"gas" and last.get("t") == &"gas" and last.kind == f.kind:
			continue
		var line := _line(before, after, f, last)
		if f.t != &"hurt":
			last = f
		if not line.is_empty():
			out.append(line)
	for p in told.spotted:
		out.append(_spotted(after, p))
	if after.max_tails() > before.max_tails():
		var tails := [str(after.max_tails()), Palette.SIDE[0]]
		out.append(Lang.runs("꼬리가 {0}개로 늘었다", [tails], Palette.SIDE[0]))
	out.map(Lang.capitalize)
	return out


## The thing Miho has just come to see at `p` (Perceived.spotted), as a line.
static func _spotted(w: World, p: Vector2i) -> Array:
	var name: String = Tiles.of(w.tile(p), "name")
	if p == w.stairs:
		name = "계단"
	elif p == w.elixir:
		name = "영약"
	elif w.peaches.has(p):
		name = "복숭아"
	elif Jars.spots(w).has(p):
		name = Jars.name_of(Jars.KIMCHI)
	elif Scrolls.card_at(w, p) != &"":
		name = Lang.t("%s 주문서") % Lang.t(Cards.NAME[Scrolls.card_at(w, p)])
	return _t("{0}을/를 발견했다", [[name, TEXT]])


## One seen event as a line, or empty. `last` is the seen event before it
## other than harm: harm after a claw or melee blow was told by that line, harm
## after a creature caught fire is told as burning, and harm from Miho's
## spells is told as harm she dealt.
static func _line(before: World, after: World, e: Dictionary, last: Dictionary) -> Array:
	var id: int = e.get("id", -1)
	var who := _who(before, after, id)
	match e.t:
		&"notice":
			return _t("{0}에게 들켰다", [who])
		&"state":
			var mark: String = STATE[e.mark]
			var run := _ill(after, id, mark) if e.mark == "x" else [mark, TEXT]
			return _sub(before, after, id, "{0}이/가 {1}", "{0}", [run])
		&"claw":
			return _harm_to(before, after, e.target, e.n)
		&"melee":
			var melee: Dictionary = _actor(before, after, id).info().melee
			var args := [who, [melee.name, TEXT], [melee.hit, TEXT]]
			if e.target == after.player().id:
				return _t("{0}의 {1}에 {2} 피해를 {3} 입었다", args + [[str(e.n), Palette.HURT]])
			var foe := _who(before, after, e.target)
			args = [who, [melee.name, TEXT], foe, [melee.hit, TEXT], [str(e.n), Palette.HURT]]
			return _t("{0}의 {1}에 {2}이/가 {3} 피해를 {4} 입었다", args)
		&"feud":
			return _t("{0}이/가 {1}에게 덤벼들었다", [who, _who(before, after, e.rival)])
		&"shout":
			return _t("{0}이/가 {1} 소리쳤다", [who, [e.word, Palette.SOUND]])
		&"truce":
			return _t("{0}이/가 싸움을 멈췄다", [who])
		&"grow":
			var eaten: String = Cards.NAME[_actor(before, after, id).info().eats]
			return _t("{0}이/가 {1}을/를 먹고 커졌다", [who, [eaten, TEXT]])
		&"hurt":
			return _hurt_line(before, after, e, last)
		&"die":
			if last.get("t") == &"fall":
				return []
			return _sub(before, after, id, "{0}이/가 {1}", "{0}", [["쓰러졌다", TEXT]])
		&"fall":
			if e.has("depth"):
				var floor_no := [Lang.t("%d층") % e.depth, Palette.KIND[&"miho"]]
				return _t("하늘로 떨어져 {0}으로 내려왔다", [floor_no])
			return _t("{0}이/가 하늘로 떨어졌다", [who])
		&"card":
			var talisman := [Lang.t("%s 부적") % Lang.t(Cards.NAME[e.card]), Palette.CARD[e.card]]
			return _t("{0}을 얻었다", [talisman])
		&"scroll":
			var scroll := [Lang.t("%s 주문서") % Lang.t(Cards.NAME[e.card]), Palette.CARD[e.card]]
			return _t("{0}가 떨어졌다", [scroll])
		&"heal":
			if e.get("kimchi", false):
				return _kimchi(e.n)
			var one := [["1", Palette.HURT]]
			var healed := _t("체력을 {0} 회복했다", one)
			if e.get("grew", false):
				healed = _t("최대 체력이 {0} 늘었다", one)
			var plain: bool = last.get("t") == &"ascend" or e.get("spell", false)
			return healed if plain else _t("복숭아를 먹었다. ", []) + healed
		&"jar":
			var what := [Jars.name_of(e.what), TEXT]
			return _t("{0}이/가 {1}", [what, [JAR_DOES[e.what], TEXT]])
		&"blind":
			return _sub(before, after, id, "{0}의 {1}", "{0}", [_ill(after, id, "눈이 멀었다")])
		&"root":
			return _sub(before, after, id, "{0}이/가 {1}", "{0}", [_ill(after, id, "묶였다")])
		&"unroot", &"unstun", &"unblind":
			return _sub(before, after, id, "{0}이/가 {1}", "{0}", [[FREED[e.t], TEXT]])
		&"stun":
			return _sub(before, after, id, "{0}이/가 {1}", "{0}", [_ill(after, id, "기절했다")])
		&"push":
			return _sub(before, after, id, "{0}이/가 {1}", "{0}", [["밀려났다", TEXT]])
		&"leap":
			return _sub(before, after, id, "{0}이/가 {1}", "{0}", [["멀리 뛰었다", TEXT]])
		&"swap":
			if e.other == 0:
				var moved := [["주문이 멈춘 자리로 옮겨 갔다", TEXT]]
				return _sub(before, after, id, "{0}이/가 {1}", "{0}", moved)
			return _t("{0}과/와 자리를 바꿨다", [_who(before, after, e.other)])
		&"sprout":
			return _t("{0}이/가 자랐다", [_named(Tiles.of(World.WOOD_WALL, "name"))])
		&"freeze":
			return _sub(before, after, id, "{0}이/가 {1}", "{0}", [_ill(after, id, "얼어붙었다")])
		&"wet":
			return _sub(before, after, id, "{0}이/가 {1}", "{0}", [_ill(after, id, "젖었다")])
		&"dry":
			return _sub(before, after, id, "{0}이/가 {1}", "{0}", [["말랐다", TEXT]])
		&"alight":
			return _t("{0}에게 {1}", [who, _ill(after, id, "불이 붙었다")])
		&"quench":
			return _t("{0}의 불이 꺼졌다", [who])
		&"thaw":
			return _sub(before, after, id, "{0}이/가 {1}", "{0}", [["녹았다", TEXT]])
		&"become":
			var name := _named(Tiles.of(e.tile, "name"))
			if e.has("was"):
				return _t("{0}이/가 {1}이/가 되었다", [_named(Tiles.of(e.was, "name")), name])
			return _t("{0}이/가 생겼다", [name])
		&"heat":
			return _t("{0}이/가 남았다", [_named(Compounds.HOT[e.kind].name)])
		&"cool":
			return _t("{0}이/가 식었다", [_named(Compounds.HOT[e.kind].name)])
		&"absorb":
			return _t("{0}에게는 통하지 않았다", [who])
		&"resist":
			var taken := [Lang.t(Cards.NAME[e.taken[0]]), Palette.CARD[e.taken[0]]]
			return _t("{0}이/가 {1}을/를 일부 막았다", [who, taken])
		&"heed":
			var what: String = Notice.LABEL[e.kind]
			return _t("{0}이/가 {1}을/를 보고 살피러 갔다", [who, [what, TEXT]])
		&"calm":
			return _t("{0}이/가 수색을 멈췄다", [who])
		&"charge":
			var spell := Bestiary.spell(_actor(before, after, id).kind, e.cards)
			var title := [spell.shown(), Palette.card(spell.slots.back())]
			return _t("{0}이/가 {1}을/를 모으기 시작했다", [who, title])
		&"stick":
			var spell := Spell.make(e.cards)
			var title := [_title(e), Palette.card(spell.slots.back())]
			if id == after.player().id:
				return _t("{0}이/가 붙었다", [title])
			return _t("{0}이/가 {1}에게 붙었다", [title, who])
		&"yelp":
			return _t("여우불이 {0} 울었다", [[Lure.WORD, Palette.SOUND]])
		&"guise":
			var form := [Bestiary.info(e.kind).name, Palette.KIND[e.kind]]
			return Lang.runs("{0}의 모습으로 둔갑했다", [form], Palette.GOOD)
		&"unmask":
			return _t("{0}이/가 풀렸다", [_named(Guise.NAME[Guise.GUISE])])
		&"talon":
			return _t("{0}이/가 돋았다", [_named(Guise.NAME[Guise.TALON])])
		&"untalon":
			return _t("{0}이/가 사라졌다", [_named(Guise.NAME[Guise.TALON])])
		&"cloak":
			return _t("{0}했다", [_named(Guise.NAME[Guise.CLOAK])])
		&"uncloak":
			return _t("{0}이/가 풀렸다", [_named(Guise.NAME[Guise.CLOAK])])
		&"sleep":
			return _t("{0}이/가 잠들었다", [who])
		&"fade":
			if e.get("dropped", false):
				return _t("{0}이/가 사라졌다", [[_title(e), TEXT]])
			if not e.get("lit", false):
				return []
			return _t("{0}이/가 불빛에 사라졌다", [[_title(e), TEXT]])
		&"open", &"close":
			var opened: bool = e.t == &"open"
			if id == after.player().id:
				return _t("문을 열었다" if opened else "문을 닫았다")
			if not _in_sight(before, after, id):
				return _t("문이 열렸다" if opened else "문이 닫혔다")
			return _t("{0}이/가 문을 열었다" if opened else "{0}이/가 문을 닫았다", [who])
		&"drum":
			return _t("{0}이/가 젖은 북을 쳤다" if e.wet else "{0}이/가 북을 쳤다", [who])
		&"soak":
			return _t("북이 젖었다")
		&"gas":
			return _t("{0}이/가 피어올랐다", [_gas(e.kind)])
		&"find":
			return _t("{0}을/를 찾았다", [_named(Tiles.of(e.kind, "name"))])
		&"trap":
			var plate := _named(Tiles.of(e.kind, "name"))
			return _sub(before, after, id, "{0}이/가 {1}을/를 밟았다", "{0}을/를 밟았다", [plate])
		&"trample":
			return _t("{0}이/가 쓰러졌다", [_named(Tiles.of(e.was, "name"))])
		&"collapse":
			return _t("벽이 무너졌다")
		&"altar":
			var altar := _named(Tiles.of(World.ALTAR, "name"))
			return _t("{0}이/가 타올랐다. 꼬리가 모두 돌아오고 하나 더 돋았다", [altar])
		&"read":
			return _t("두루마리를 읽었다. 이 층의 지도가 드러났다")
		&"creak":
			return _t("꼬리가 모두 돌아왔다")
		&"ascend":
			return _t("{0}으로 올라갔다", [[Lang.t("%d층") % e.depth, Palette.KIND[&"miho"]]])
		&"omen":
			var saja := [Bestiary.info(&"saja").name, Palette.KIND[&"saja"]]
			return _t("{0}이/가 오고 있다", [saja])
		&"arrive":
			return _t("{0}이/가 나타났다", [who])
		&"blast":
			return _t("{0}이/가 폭발했다", [_gas(e.kind)])
		&"crumble":
			return _t("{0}이/가 꺼졌다", [_named(Tiles.of(e.was, "name"))])
		&"wake":
			return _t("{0}이/가 깨어났다", [_named(Tiles.of(World.STATUE, "name"))])
		&"cheat":
			return _cheat(e)
		&"won":
			var human := [["사람이 되었다", Palette.KIND[&"miho"]]]
			return _t("영약을 마시고 {0}", human)
		&"ignite":
			var fierce := Tiles.fierce[before.tile(e.at)] == 1
			var flame: Array = Palette.FIERCE_BURNING if fierce else Palette.BURNING
			var burn := ["맹렬한 불이 붙었다" if fierce else "불이 붙었다", flame[1]]
			return _t("{0}에 {1}", [_tile(before, e.at), burn])
		&"burnout":
			if Tiles.burns[before.tile(e.at)] == 0:
				return []
			return _t("{0}이/가 재가 되었다", [_tile(before, e.at)])
		&"douse":
			if before.tile(e.at) == World.LANTERN:
				return _t("등불이 꺼졌다")
			return _t("{0}의 불이 꺼졌다", [_tile(before, e.at)])
		&"relight":
			if id >= 0:
				return _t("{0}이/가 등불을 다시 켰다", [who])
			return _t("등불이 다시 켜졌다")
		&"smash":
			return _smash(e)
	return []


## What a blow left of a tile.
static func _smash(e: Dictionary) -> Array:
	var broken := {
		World.WALL: "벽에 금이 갔다",
		World.WALL_CRACKED: "금 간 벽이 무너졌다",
		World.WINDOW: "창문이 깨졌다",
		World.SCREEN: "병풍이 쓰러졌다",
		World.JAR: "장독이 깨졌다",
		World.CENSER: "향로가 쓰러졌다",
	}
	if e.was == World.LANTERN and e.left == World.LANTERN_OUT:
		return _t("등불이 꺼졌다")
	if broken.has(e.was):
		return _t(broken[e.was])
	return _t("{0}이/가 부서졌다", [_named(Tiles.of(e.was, "name"))])


## A debug command (Cheat) as a line: a toggle says which way it went.
static func _cheat(e: Dictionary) -> Array:
	var name := [Cheat.NAME[e.cmd], TEXT]
	var kind := [Bestiary.info(e.kind).name if e.has("kind") else "", TEXT]
	match e.cmd:
		&"teleport":
			return _t("순간이동했다")
		&"kill":
			return _t("{0}을/를 없앴다", [kind])
		&"kill_all":
			return _t("적을 모두 없앴다")
		&"move_foe":
			return _t("{0}을/를 옮겼다", [kind])
		&"floor":
			return _t("{0}으로 이동했다", [[Lang.t("%d층") % e.depth, Palette.KIND[&"miho"]]])
		&"summon":
			return _t("{0}을/를 불러냈다", [kind])
		&"heal":
			return _t("체력을 모두 회복했다")
	return _t("{0}을/를 켰다" if e.on else "{0}을/를 껐다", [name])


static func _hurt_line(before: World, after: World, e: Dictionary, last: Dictionary) -> Array:
	var id: int = e.id
	if last.get("target", -1) == id:
		return []
	var n := [str(e.n), Palette.HURT]
	var by: String = last.get("t", "")
	if by == &"burn" and last.id == id:
		var fierce: bool = last.get("fierce", false)
		var other := "{0}이/가 맹렬한 불에 타 피해를 {1} 입었다" if fierce else "{0}이/가 불에 타 피해를 {1} 입었다"
		var me := "맹렬한 불에 타 피해를 {0} 입었다" if fierce else "불에 타 피해를 {0} 입었다"
		return _sub(before, after, id, other, me, [n])
	if by == &"scald" and last.id == id:
		var gas := _gas(last.kind)
		return _sub(
			before, after, id, "{0}이/가 {1}에 데어 피해를 {2} 입었다", "{0}에 데어 피해를 {1} 입었다", [gas, n]
		)
	if by == &"sear" and last.id == id:
		var hot := [Compounds.HOT[last.kind].name, TEXT]
		return _sub(
			before, after, id, "{0}이/가 {1}에 데어 피해를 {2} 입었다", "{0}에 데어 피해를 {1} 입었다", [hot, n]
		)
	if by == &"prick" and last.id == id:
		return _sub(before, after, id, "{0}이/가 가시에 찔려 피해를 {1} 입었다", "가시에 찔려 피해를 {0} 입었다", [n])
	var mine: bool = last.get("faction", -1) == Actor.FOX and last.t in [&"hit", &"splash"]
	if mine and id != after.player().id:
		return _harm_to(before, after, id, e.n)
	var friendly: bool = (
		last.get("faction", -1) == Actor.HEAVEN
		and last.t in [&"hit", &"splash"]
		and last.get("by", id) != id
		and id != after.player().id
	)
	if friendly:
		var args := [_who(before, after, last.by), [_title(last), TEXT], _who(before, after, id), n]
		return _t("{0}의 {1}에 {2}이/가 피해를 {3} 입었다", args)
	return _took(before, after, id, n)


## Miho eats kimchi.
static func _kimchi(healed: int) -> Array:
	var args := [[Jars.name_of(Jars.KIMCHI), TEXT], [str(healed), Palette.HURT]]
	return _t("{0}을/를 먹었다. 체력을 {1} 회복했다", args)


## "<name>에게 피해를 <n> 주었다".
static func _harm_to(before: World, after: World, id: int, n: int) -> Array:
	return _t("{0}에게 피해를 {1} 주었다", [_who(before, after, id), [str(n), Palette.HURT]])


## "<name>이 피해를 <n> 입었다"; Miho is the one the log speaks to.
static func _took(before: World, after: World, id: int, n: Array) -> Array:
	return _sub(before, after, id, "{0}이/가 피해를 {1} 입었다", "피해를 {0} 입었다", [n])


## A status that harms its holder, as a run: Miho's in BAD, another creature's
## plainer (BAD_FOE), which Miho is glad of.
static func _ill(after: World, id: int, text: String) -> Array:
	return [text, Palette.BAD if id == after.player().id else Palette.BAD_FOE]


## A sentence in the plain text colour.
static func _t(template: String, args := []) -> Array:
	return Lang.runs(template, args, TEXT)


## A sentence about creature `id`: `other` has it as {0} and `args` after it. Miho
## is the one the log speaks to, so `me` (with `args` from {0}) leaves her out.
static func _sub(
	before: World, after: World, id: int, other: String, me: String, args: Array
) -> Array:
	if id == after.player().id:
		return _t(me, args)
	return _t(other, [_who(before, after, id)] + args)


## The title of the spell an event tells of, in the language shown.
static func _title(e: Dictionary) -> String:
	return Spell.from_tag(e.spell).shown() if e.has("spell") else Lang.t(e.title)


## A gas's name in its colour.
static func _gas(kind: int) -> Array:
	return [Gas.of(kind, "name"), Palette.GAS[kind][1]]


## Whether Miho saw the creature at the start or the end of the round.
static func _in_sight(before: World, after: World, id: int) -> bool:
	for w: World in [before, after]:
		var a := w.actor(id)
		if a != null and Hat.shown(w, a):
			return true
	return false


## A creature's name in its colour. One out of her sight is 무언가.
static func _who(before: World, after: World, id: int) -> Array:
	var a := _actor(before, after, id)
	if a != null and (id == after.player().id or _in_sight(before, after, id)):
		return [a.info().name, Palette.KIND[a.kind]]
	return ["무언가", TEXT]


## The creature in the world after the round, else before it.
static func _actor(before: World, after: World, id: int) -> Actor:
	return after.actor(id) if after.actor(id) != null else before.actor(id)


static func _tile(w: World, p: Vector2i) -> Array:
	return _named(Tiles.of(w.tile(p), "name"))


static func _named(name: String) -> Array:
	return [name, TEXT]
