class_name Banner
extends RefCounted
## The lines over the map when a run ends.

## The line holding the seed, which a click copies.
const SEED := 3
## Puts text on the clipboard; a test swaps it, since a headless run has none.
static var clipboard := DisplayServer.clipboard_set


## The lines of a run that ended in `w` with `kills` creatures put down.
static func over(w: World, kills: int, seed_value: int) -> Array[String]:
	var again: String = (Keys.keys_of(&"restart").map(Keys.label) + ["R"])[0]
	var log_key: String = (Keys.keys_of(&"log").map(Keys.label) + ["Ctrl+P"])[0]
	return [
		"사람이 되었다" if w.outcome == &"won" else _fallen(w),
		"%d층 · %d초" % [w.depth, w.round_no],
		"처치 %d" % kills,
		seed_line(seed_value, false),
		"%s키를 눌러 기록 보기" % log_key,
		"%s키를 눌러 재시작" % again,
	]


## How Miho fell, from what came just before her last wound this round. A creature
## she does not see at the end goes unnamed.
static func _fallen(w: World) -> String:
	var me := w.player()
	var wounds := 0
	for i in range(w.events.size() - 1, -1, -1):
		var e: Dictionary = w.events[i]
		if e.t == &"hurt" and e.id == me.id:
			wounds += 1
		elif wounds == 1:
			var line := _blow(w, e)
			if line != "":
				return line
		if wounds == 2:
			break
	return "쓰러졌다"


## The line for event `e` when it is what wounded Miho, or empty.
static func _blow(w: World, e: Dictionary) -> String:
	var me := w.player()
	match e.t:
		&"melee" when e.target == me.id:
			return "%s에게 쓰러졌다" % _name(w, e.id) if _name(w, e.id) != "" else ""
		&"burn" when e.id == me.id:
			return "불에 타 쓰러졌다"
		&"fall" when e.id == me.id:
			return "떨어져 쓰러졌다"
		&"hit" when e.id == me.id:
			return _by(w, e)
		&"splash":
			return _by(w, e)
	return ""


static func _by(w: World, e: Dictionary) -> String:
	var name := _name(w, e.by) if e.by != w.player().id else ""
	return "%s의 %s에 쓰러졌다" % [name, e.title] if name != "" else "%s에 쓰러졌다" % e.title


## The name of creature `id` if Miho sees it, else empty.
static func _name(w: World, id: int) -> String:
	var a := w.actor(id)
	return a.info().name if a != null and Hat.shown(w, a) else ""


static func seed_line(seed_value: int, copied: bool) -> String:
	return "시드 %d 복사했다" % seed_value if copied else "시드 %d" % seed_value


## Copies the seed; a banner showing it says so.
static func copy(seed_value: int, t: Term) -> void:
	clipboard.call(str(seed_value))
	if t.banner_lines.size() > SEED:
		t.banner_lines[SEED] = seed_line(seed_value, true)
