class_name Scent
extends RefCounted
## The trail Miho leaves. World.scent holds, for each tile, the round (plus one)
## in which she last stood there; 0 is never. A hunter that has lost sight of
## her steps to the neighbouring tile with the freshest scent, as long as it is
## fresher than its own tile and at most TRAIL_AGE rounds old. Scentless tiles (bamboo)
## and flames hold no scent, and a water spell washes it away. Only Miho lays scent.
## While her scent is strong (World.pungent, after kimchi), the tiles she walks hold
## it STRONG_EXTRA rounds longer (World.strong).

const TRAIL_AGE := 12
const STRONG_EXTRA := 12


static func _ready(w: World) -> void:
	if w.scent.size() != w.tiles.size():
		w.scent.resize(w.tiles.size())


## Miho stands on `p`.
static func lay(w: World, p: Vector2i) -> void:
	_ready(w)
	if not Tiles.of(w.tile(p), "scentless") and not w.burning.has(p):
		w.scent[Grid.index(p)] = w.round_no + 1
		if w.pungent > 0:
			w.strong[p] = true
		else:
			w.strong.erase(p)


## How many rounds old the scent on `p` can be and still be followed.
static func reach(w: World, p: Vector2i) -> int:
	return TRAIL_AGE + (STRONG_EXTRA if w.strong.has(p) else 0)


## The tiles whose scent a hunter would still follow, each with its freshness, 1.0 laid this
## round and falling to 0 at the end of its reach. With `known_only`, only tiles Miho has seen.
static func fresh(w: World, known_only := false) -> Dictionary:
	var out := {}
	if w.scent.size() != w.tiles.size():
		return out
	for i in w.scent.size():
		if w.scent[i] == 0 or (known_only and w.known[i] != 1):
			continue
		var p := Grid.at(i)
		var age := w.round_no + 1 - w.scent[i]
		var limit := reach(w, p)
		if age <= limit:
			out[p] = 1.0 - float(age) / (limit + 1)
	return out


static func clear(w: World, p: Vector2i) -> void:
	_ready(w)
	w.scent[Grid.index(p)] = 0
	w.strong.erase(p)


## The tile `a` follows next, or its own when the trail is cold.
static func next(w: World, a: Actor) -> Vector2i:
	if a.info().get("move", &"static") == &"static" or w.scent.size() != w.tiles.size():
		return a.pos
	return _fresher(w, a, a.pos)


## The tile `steps` along the trail from `a`, or the last one the trail reaches.
static func ahead(w: World, a: Actor, steps: int) -> Vector2i:
	var at := next(w, a)
	if at == a.pos:
		return at
	for i in steps - 1:
		at = _fresher(w, a, at)
	return at


## The neighbour of `from` `a` can step to with the freshest scent, or `from` when none is
## fresher.
static func _fresher(w: World, a: Actor, from: Vector2i) -> Vector2i:
	var best := from
	var best_stamp := w.scent[Grid.index(from)]
	for d in Grid.DIRS:
		var p := from + d
		if not Grid.inside(p) or not w.vacant(p) or w.burning.has(p) or Traps.bars(w, a, p):
			continue
		var stamp := w.scent[Grid.index(p)]
		if stamp > best_stamp and w.round_no + 1 - stamp <= reach(w, p):
			best = p
			best_stamp = stamp
	return best
