class_name Impact
extends RefCounted
## What a shot does where it ends, drawn as it touches (Term.play).

const DOES := [&"splash", &"sprout", &"become", &"heat"]
## What starts another shot's or creature's doing, and so ends the look for what it does.
const ENDS := [&"fly", &"hit", &"burst", &"spawn", &"spray", &"cast"]
## Seconds between one ring of a blast and the next.
const WAVE := 0.07


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


## What a blast flashes, as [tile, colour, delay]: a 비격진 throws a wave of sparks out from a
## white-hot core, a fire orb a burst of flame, any other orb only a short shock round it.
static func flashes(e: Dictionary) -> Array:
	var spell := Spell.make(e.cards)
	var at: Vector2i = e.at
	var out := []
	if spell.mortar() and e.has("r"):
		out.append([at, Color(1.0, 1.0, 0.9, 1.0), 0.0])
		for p in Spray.ring(at, e.r):
			var far := Grid.cheb(p, at)
			out.append([p, Color(1.0, 0.75 - 0.2 * far, 0.2, 1.1 - 0.2 * far), WAVE * far])
		out.append([at, Color(1.0, 0.5, 0.1, 0.9), WAVE * (e.r + 1)])
	elif spell.has(Cards.FIRE):
		out.append([at, Color(1.0, 0.95, 0.7, 0.95), 0.0])
		for d in Grid.DIRS:
			out.append([at + d, Color(Palette.BURNING[1], 0.85), WAVE])
		out.append([at, Color(Palette.BURNING[1], 0.9), WAVE * 2])
	else:
		for d in Grid.DIRS:
			out.append([at + d, Color(1, 1, 1, 0.35), 0.0])
	return out


static func _touches(e: Dictionary, at: Vector2i) -> bool:
	return e.at == at or e.get("tiles", []).has(at)
