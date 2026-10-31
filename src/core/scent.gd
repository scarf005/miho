class_name Scent
extends RefCounted
## The trail Miho leaves. World.scent holds, for each tile, the round (plus one)
## in which she last stood there; 0 is never. A hunter that has lost sight of
## her steps to the neighbouring tile with the freshest scent, as long as it is
## fresher than its own tile and at most TRAIL_AGE rounds old. Scentless tiles (bamboo)
## and flames hold no scent, and a water spell washes it away. Only Miho lays scent.

const TRAIL_AGE := 12


static func _ready(w: World) -> void:
	if w.scent.size() != w.tiles.size():
		w.scent.resize(w.tiles.size())


## Miho stands on `p`.
static func lay(w: World, p: Vector2i) -> void:
	_ready(w)
	if not Tiles.of(w.tile(p), "scentless") and not w.burning.has(p):
		w.scent[Grid.index(p)] = w.round_no + 1


static func clear(w: World, p: Vector2i) -> void:
	_ready(w)
	w.scent[Grid.index(p)] = 0


## The tile `a` follows next, or its own when the trail is cold.
static func next(w: World, a: Actor) -> Vector2i:
	if a.info().get("move", &"static") == &"static" or w.scent.size() != w.tiles.size():
		return a.pos
	var best := a.pos
	var best_stamp := w.scent[Grid.index(a.pos)]
	for d in Grid.DIRS:
		var p := a.pos + d
		if not Grid.inside(p) or not w.vacant(p) or w.burning.has(p) or w.traps.has(p):
			continue
		var stamp := w.scent[Grid.index(p)]
		if stamp > best_stamp and w.round_no + 1 - stamp <= TRAIL_AGE:
			best = p
			best_stamp = stamp
	return best
