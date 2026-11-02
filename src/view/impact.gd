class_name Impact
extends RefCounted
## What a shot does where it ends, drawn as it touches (Term.play).

const DOES := [&"splash", &"sprout", &"become", &"heat"]
## What starts another shot's or creature's doing, and so ends the look for what it does.
const ENDS := [&"fly", &"hit", &"burst", &"spawn", &"spray", &"cast"]


## By the index of each event of a shot touching something, the later events it sets
## off there. Their pictures and sounds start with the touch, and only the time they
## hold stays where they come, so what the touch hurts is told at once.
static func of(events: Array) -> Dictionary:
	var out := {}
	for i in events.size():
		if events[i].t not in [&"hit", &"burst"] or events[i].get("through", false):
			continue
		for j in range(i + 1, events.size()):
			if events[j].t in ENDS:
				break
			if events[j].t in DOES and _touches(events[j], events[i].at):
				out.get_or_add(i, []).append(j)
	return out


static func _touches(e: Dictionary, at: Vector2i) -> bool:
	return e.at == at or e.get("tiles", []).has(at)
