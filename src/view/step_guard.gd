class_name StepGuard
extends RefCounted
## What keeps Miho from losing a run or walking into harm by accident. A step
## onto a plate she has found, onto fire or off an edge asks first: the prompt
## waits in `asking` (the direction) until the same direction again, or Y, makes
## the step; anything else cancels it. A held key never steps there. A held
## direction key also stops once a creature is in sight that was not when the key
## went down (`sighted`). This is view state: a prompt takes no turn and is not
## in the save.

## The direction a step waits to be confirmed in, or zero.
var asking := Vector2i.ZERO
## Ids of the creatures in sight at the last fresh key press.
var sighted := {}


## Whether stepping `d`, forecast as `f`, is onto a found plate, fire she sees or a
## drop. A plate asks whatever the forecast says: the round of the step shows no
## harm from a fire or vine plate, and an alarm plate harms nobody.
static func danger(w: World, d: Vector2i, f: Forecast) -> bool:
	if f == null:
		return false
	var to := w.player().pos + d
	var burns := w.seen[Grid.index(to)] == 1 and w.burning.has(to)
	return f.drops_me() or burns or Tiles.of(w.tile(to), "trap")


## What is asked before stepping `d`; the keys answer it unless `touch`.
static func question(w: World, d: Vector2i, touch: bool) -> String:
	var to := w.player().pos + d
	var name: String = "불타는 칸" if w.burning.has(to) else Tiles.of(w.tile(to), "name")
	var text := toward(name) + " 갈까?"
	return text if touch else text + " Y/N"


## `word` with 로 after a vowel or ㄹ, else 으로.
static func toward(word: String) -> String:
	var c := word.unicode_at(word.length() - 1) - 0xAC00
	return word + ("로" if c % 28 in [0, 8] else "으로")


## Whether a creature is in sight that was not at the last fresh key press.
func startled(w: World) -> bool:
	return Travel.in_sight(w).keys().any(func(id): return not sighted.has(id))
