class_name Messages
extends RefCounted
## The message log: a round's events as sentences, from what Miho perceived
## only: events where she saw them, and noises she heard out of sight. Hidden
## events and kinds of event it does not know give no line. Each line is a list
## of [text, Color] runs, with names, harm and sound words in their colours.
## What she perceived is Perceived's: the map's popups read the same facts.
## A line repeated right after itself is counted instead of written again.

const KEEP := 40
const TEXT := Palette.TEXT
## What a creature's map mark says, for one that comes into sight marked.
const STATE := {"!": "당신을 쫓고 있다", "?": "수색하고 있다", "x": "눈이 멀어 있다"}

## {runs, text, round, n}
var lines: Array[Dictionary] = []


func add(runs: Array, round_no: int) -> void:
	var text := plain(runs)
	if not lines.is_empty() and lines.back().text == text:
		lines.back().n += 1
		lines.back().round = round_no
	else:
		lines.append({runs = runs, text = text, round = round_no, n = 1})
	if lines.size() > KEEP:
		lines = lines.slice(-KEEP)


## The line as shown, with its count.
static func shown(line: Dictionary) -> Array:
	return line.runs if line.n == 1 else line.runs + [[" x%d" % line.n, Palette.DIM]]


## A line's text without its colours.
static func plain(runs: Array) -> String:
	return "".join(runs.map(func(r): return r[0]))


## Lines for one round from `before` to `after`: one per fact Miho is told.
static func of(before: World, after: World, events: Array) -> Array:
	var out := []
	var last := {}
	for f in Perceived.of(before, after, events).facts:
		if f.t == &"noise":
			out.append([["멀리서 ", TEXT], [f.word, Palette.SOUND], [" 소리를 들었다", TEXT]])
			continue
		var line := _line(before, after, f, last)
		if f.t != &"hurt":
			last = f
		if not line.is_empty():
			out.append(line)
	return out


## One seen event as a line, or empty. `last` is the seen event before it
## other than harm: harm after a claw or club was told by that line, harm
## after a creature caught fire is told as burning, and harm from Miho's
## spells is told as harm she dealt.
static func _line(before: World, after: World, e: Dictionary, last: Dictionary) -> Array:
	var id: int = e.get("id", -1)
	match e.t:
		&"notice":
			return _who(before, after, id, "에게", "에게") + [[" 들켰다", TEXT]]
		&"state":
			return _subject(before, after, id) + [[STATE[e.mark], TEXT]]
		&"claw":
			var line := [["기습! ", Palette.ALERT[1]]] if e.sneak else []
			return line + _harm_to(before, after, e.target, e.n)
		&"club":
			return _who(before, after, id, "의", "의") + [[" 몽둥이에 맞아 ", TEXT]] + _took(e.n)
		&"hurt":
			var line := _hurt_line(before, after, e, last)
			if e.get("weak", false) and not line.is_empty():
				return [["약점! ", Palette.ALERT[1]]] + line
			return line
		&"die":
			return _subject(before, after, id) + [["쓰러졌다", TEXT]]
		&"card":
			return [[Cards.NAME[e.card] + " 부적", Palette.CARD[e.card]], ["을 얻었다", TEXT]]
		&"heal":
			var healed := [["체력을 ", TEXT], ["1", Palette.HURT], [" 회복했다", TEXT]]
			if e.get("grew", false):
				healed = [["최대 체력이 ", TEXT], ["1", Palette.HURT], [" 늘었다", TEXT]]
			return healed if last.get("t") == &"ascend" else [["복숭아를 먹었다. ", TEXT]] + healed
		&"blind":
			return _subject(before, after, id, "의") + [["눈이 멀었다", TEXT]]
		&"root":
			return _subject(before, after, id) + [["덩굴에 묶였다", TEXT]]
		&"stun":
			return _subject(before, after, id) + [["기절했다", TEXT]]
		&"absorb":
			return _who(before, after, id, "에게는", "에게는") + [[" 통하지 않았다", TEXT]]
		&"calm":
			return _who(before, after, id, "이", "가") + [[" 수색을 멈췄다", TEXT]]
		&"charge":
			var spell := Spell.make(e.cards)
			return (
				_who(before, after, id, "이", "가")
				+ [[" ", TEXT], [spell.title(), Palette.CARD[spell.cards.back()]]]
				+ [[_particle(spell.title(), "을", "를") + " 모으고 있다", TEXT]]
			)
		&"ascend":
			return [["%d층" % e.depth, Palette.KIND[&"miho"]], ["으로 올라갔다", TEXT]]
		&"omen":
			var saja: String = Bestiary.info(&"saja").name
			return [[saja, Palette.KIND[&"saja"]], [_particle(saja, "이", "가") + " 오고 있다", TEXT]]
		&"arrive":
			return _who(before, after, id, "이", "가") + [[" 나타났다", TEXT]]
		&"won":
			return [["영약을 마시고 ", TEXT], ["사람이 되었다", Palette.KIND[&"miho"]]]
		&"ignite":
			var a := before.actor_at(e.at)
			var what := _tile(before, e.at, "에", "에")
			if a != null and a.faction != Actor.FOX:
				what = _who(before, after, a.id, "에게", "에게")
			return what + [[" 불이 붙었다", Palette.BURNING[1]]]
		&"burnout":
			if not World.FLAMMABLE.has(before.tile(e.at)):
				return []
			return _tile(before, e.at, "이", "가") + [[" 다 타서 재가 되었다", TEXT]]
		&"douse":
			if before.tile(e.at) == World.LANTERN:
				return [["등불이 꺼졌다", TEXT]]
			return _tile(before, e.at, "의", "의") + [[" 불이 꺼졌다", TEXT]]
		&"relight":
			if id >= 0:
				return _who(before, after, id, "이", "가") + [[" 등불을 다시 켰다", TEXT]]
			return [["등불이 다시 켜졌다", TEXT]]
		&"smash":
			if e.was == World.LANTERN:
				return [["등불이 꺼졌다", TEXT]]
			if e.was == World.WALL:
				return [["벽에 금이 갔다", TEXT]]
			if e.was == World.WALL_CRACKED:
				return [["금 간 벽이 무너졌다", TEXT]]
			if e.was == World.WINDOW:
				return [["창문이 깨졌다", TEXT]]
			return _named(Info.TERRAIN[e.was][0], "이", "가") + [[" 부서졌다", TEXT]]
	return []


static func _hurt_line(before: World, after: World, e: Dictionary, last: Dictionary) -> Array:
	var id: int = e.id
	if last.get("target", -1) == id:
		return []
	if last.get("t") == &"burn" and last.id == id:
		return _subject(before, after, id) + [["불에 타 ", TEXT]] + _took(e.n)
	var mine: bool = last.get("faction", -1) == Actor.FOX and last.t in [&"hit", &"splash"]
	if mine and id != after.player().id:
		return _harm_to(before, after, id, e.n)
	return _subject(before, after, id) + _took(e.n)


## "<name>에게 피해를 <n> 주었다".
static func _harm_to(before: World, after: World, id: int, n: int) -> Array:
	return (
		_who(before, after, id, "에게", "에게")
		+ [[" 피해를 ", TEXT], [str(n), Palette.HURT], [" 주었다", TEXT]]
	)


static func _took(n: int) -> Array:
	return [["피해를 ", TEXT], [str(n), Palette.HURT], [" 입었다", TEXT]]


## A creature as the subject of a line, or nothing for Miho: the player is
## the one the log speaks to. `particle` replaces 이/가 when given.
static func _subject(before: World, after: World, id: int, particle := "") -> Array:
	if id == after.player().id:
		return []
	var p := [particle, particle] if particle != "" else ["이", "가"]
	return _who(before, after, id, p[0], p[1]) + [[" ", TEXT]]


## A creature's name in its colour, then the particle that fits it: `closed`
## after a final consonant, `open` after a vowel.
static func _who(before: World, after: World, id: int, closed: String, open: String) -> Array:
	for w in [after, before]:
		var a: Actor = w.actor(id)
		if a != null:
			var name: String = a.info().name
			return [[name, Palette.KIND[a.kind]], [_particle(name, closed, open), TEXT]]
	return [["무언가", TEXT], [_particle("무언가", closed, open), TEXT]]


static func _tile(w: World, p: Vector2i, closed: String, open: String) -> Array:
	return _named(Info.TERRAIN[w.tile(p)][0], closed, open)


static func _named(name: String, closed: String, open: String) -> Array:
	return [[name + _particle(name, closed, open), TEXT]]


## `closed` after a word ending in a final consonant, else `open`.
static func _particle(word: String, closed: String, open: String) -> String:
	var c := word.unicode_at(word.length() - 1) if word != "" else 0
	return closed if c >= 0xAC00 and c <= 0xD7A3 and (c - 0xAC00) % 28 != 0 else open
