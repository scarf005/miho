class_name Bubbles
extends RefCounted
## The bubbles on the water over a creature that lives there and that Miho does not
## see, rising one at a time. They are only drawn: nothing in the world changes.

## Seconds between two bubbles, how long one lasts, and how far from the creature it rises.
const EVERY := 0.5
const LIFE := 1.0
const REACH := 2

var _wait := 0.0


## The water tiles Miho sees within REACH of a creature hidden under them.
static func spots(w: World) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for a in w.actors:
		if a.alive() and Bestiary.swims(a.kind) and Hat.hidden(w, a, w.player().pos):
			for x in range(-REACH, REACH + 1):
				for y in range(-REACH, REACH + 1):
					var p: Vector2i = a.pos + Vector2i(x, y)
					if (
						Grid.inside(p)
						and w.seen[Grid.index(p)] == 1
						and Tiles.of(w.tile(p), "water")
					):
						out.append(p)
	return out


## The popups (Term) of the bubbles that rise as `delta` seconds pass at the time `now`.
func rise(w: World, delta: float, now: float) -> Array:
	if w == null:
		return []
	_wait += delta
	if _wait < EVERY:
		return []
	_wait = 0.0
	var at := spots(w)
	if at.is_empty():
		return []
	return [
		{
			text = "°",
			at = at[randi() % at.size()],
			color = Palette.BUBBLE,
			above = 0.6,
			life = LIFE,
			born = now
		}
	]
