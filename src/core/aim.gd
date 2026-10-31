class_name Aim
extends RefCounted
## Where projectiles go: the line a heaven creature casts along, at Miho (or a
## rival it fights) or at a dark spot it searches. Homing projectiles find their
## own way (Homing).


## An attack at `foe`, when it sees it: {cards, dir}, or empty. An orb needs a
## clear line; wisps and homing orbs only the foe in reach.
static func at(w: World, a: Actor, foe: Actor) -> Dictionary:
	var cast := a.next_cast()
	var spell := Spell.make(cast)
	if spell.turn() > 0:
		return _homing(w, a, cast, Spell.RANGE if spell.shape == Spell.WISP else 6, foe)
	var d := Grid.line_dir(a.pos, foe.pos)
	var r := Grid.cheb(a.pos, foe.pos)
	if d != Vector2i.ZERO and r >= 2 and w.clear_line(a.pos, foe.pos):
		return {cards = cast, dir = d}
	return {}


## A homing projectile leaves towards `foe`, or beside its line when a wall is in the way.
static func _homing(w: World, a: Actor, cast: Array, reach: int, foe: Actor) -> Dictionary:
	if Grid.cheb(a.pos, foe.pos) > reach:
		return {}
	var i := Grid.DIRS.find(Grid.nearest_dir(foe.pos - a.pos))
	for turn in [0, -1, 1]:
		var dir := Grid.DIRS[(i + turn + 8) % 8]
		if w.open_air(a.pos + dir):
			return {cards = cast, dir = dir}
	return {}


## A wisp thrown at a dark spot it is searching.
static func searchlight(w: World, a: Actor) -> Dictionary:
	var cast := a.next_cast()
	var spell := Spell.make(cast)
	if spell == null or spell.shape != Spell.WISP or w.lit(a.target):
		return {}
	var r := Grid.cheb(a.pos, a.target)
	if r < 2 or r > Spell.RANGE:
		return {}
	var dir := Grid.nearest_dir(a.target - a.pos)
	if not w.open_air(a.pos + dir):
		return {}
	return {cards = cast, dir = dir}


## The first step towards the nearest tile 3 to 6 tiles from Miho with a clear
## line to her: its own tile when it stands on one, (-1, -1) when none is reachable.
static func lineup(w: World, a: Actor, walk: PackedByteArray) -> Vector2i:
	var me := w.player()
	var good := func(q: Vector2i) -> bool:
		var r := Grid.cheb(q, me.pos)
		return r >= 3 and r <= 6 and w.clear_line(q, me.pos)
	if good.call(a.pos):
		return a.pos
	var found := Grid.search(a.pos, walk)
	var dist: PackedInt32Array = found.dist
	var best := -1
	for i in dist.size():
		if dist[i] > 0 and good.call(Grid.at(i)) and (best < 0 or dist[i] < dist[best]):
			best = i
	if best < 0:
		return Vector2i(-1, -1)
	return Grid.first_step(found, a.pos, Grid.at(best))
