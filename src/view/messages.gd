class_name Messages
extends RefCounted
## The message log: a round's events as short lines, from what Miho perceived
## only: events where she saw them, and noises she heard out of sight. Hidden
## events and kinds of event it does not know give no line. A line repeated
## right after itself is counted instead of written again.

const KEEP := 40

## {text, round, n}
var lines: Array[Dictionary] = []


func add(text: String, round_no: int) -> void:
	if not lines.is_empty() and lines.back().text == text:
		lines.back().n += 1
		lines.back().round = round_no
	else:
		lines.append({text = text, round = round_no, n = 1})
	if lines.size() > KEEP:
		lines = lines.slice(-KEEP)


## The line as shown, with its count.
static func shown(line: Dictionary) -> String:
	return line.text if line.n == 1 else "%s x%d" % [line.text, line.n]


## Lines for one round from `before` to `after`.
static func of(before: World, after: World, events: Array) -> Array[String]:
	var vis := before.seen.duplicate()
	for i in vis.size():
		vis[i] |= after.seen[i]
	var where := {}
	for w: World in [after, before]:
		for a in w.actors:
			where[a.id] = a.pos
	var out: Array[String] = []
	var last := {}
	for e in events:
		if e.t == &"move" and where.has(e.id):
			where[e.id] = e.to
		var at: Vector2i = e.get("to", e.get("at", where.get(e.get("id", -1), Vector2i(-1, -1))))
		var seen: bool = (
			not Grid.inside(at) and not e.has("id")
			or _in(vis, at)
			or (e.has("from") and _in(vis, e.from))
		)
		if e.t == &"noise":
			if e.heard and not _in(vis, e.at):
				out.append("멀리서 " + e.word)
			continue
		if not seen:
			continue
		var text := _line(before, after, e, last)
		last = e
		if text != "":
			out.append(text)
	return out


static func _in(vis: PackedByteArray, p: Vector2i) -> bool:
	return Grid.inside(p) and vis[Grid.index(p)] == 1


## One seen event as a line, or empty. Harm right after a claw or club was
## told by that line; harm right after a creature caught fire is told as burns.
static func _line(before: World, after: World, e: Dictionary, last: Dictionary) -> String:
	var who := _name(before, after, e.get("id", -1))
	match e.t:
		&"notice":
			return _subject(who) + " 미호를 봤다"
		&"claw":
			var target := _name(before, after, e.target)
			return "%s발톱 %d %s" % ["기습 " if e.sneak else "", e.n, target]
		&"club":
			return "%s 몽둥이 %d" % [who, e.n]
		&"hurt":
			if last.get("target", -1) == e.id:
				return ""
			var how := " 불" if last.get("t") == &"burn" and last.id == e.id else ""
			return "%s%s 피해 %d" % [who, how, e.n]
		&"die":
			return who + " 쓰러짐"
		&"card":
			return Cards.NAME[e.card] + " 부적을 얻었다"
		&"heal":
			return "복숭아 체력 +1"
		&"blind":
			return who + " 눈멂"
		&"root":
			return who + " 묶임"
		&"stun":
			return who + " 기절"
		&"absorb":
			return who + "에게 안 통한다"
		&"calm":
			return _subject(who) + " 수색을 멈췄다"
		&"charge":
			return "%s %s 모은다" % [_subject(who), _object(Spell.make(e.cards).title())]
		&"ascend":
			return "%d층" % e.depth
		&"omen":
			return _subject(Bestiary.info(&"saja").name) + " 온다"
		&"arrive":
			return _subject(who) + " 왔다"
		&"won":
			return "사람이 되었다"
		&"ignite":
			return "불이 붙었다"
		&"burnout":
			return "불이 꺼졌다"
		&"douse":
			return "등불이 꺼졌다" if before.tile(e.at) == World.LANTERN else "불이 꺼졌다"
		&"relight":
			return "등불이 켜졌다"
		&"smash":
			return "등불이 깨졌다" if before.tile(e.at) == World.LANTERN else "문이 부서졌다"
	return ""


static func _name(before: World, after: World, id: int) -> String:
	for w in [after, before]:
		var a: Actor = w.actor(id)
		if a != null:
			return a.info().name
	return ""


## A name with the subject particle: 이 after a final consonant, else 가.
static func _subject(name: String) -> String:
	return name + ("이" if _closed(name) else "가")


static func _object(name: String) -> String:
	return name + ("을" if _closed(name) else "를")


static func _closed(word: String) -> bool:
	var c := word.unicode_at(word.length() - 1) if word != "" else 0
	return c >= 0xAC00 and c <= 0xD7A3 and (c - 0xAC00) % 28 != 0
