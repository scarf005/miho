class_name Aim
extends RefCounted
## Where projectiles go: the line a heaven creature casts along, at Miho or at
## a dark spot it searches, and the turn a homing orb takes each tile.


## An attack along a line at Miho, when it sees her: {cards, dir}, or empty.
static func at_miho(w: World, a: Actor) -> Dictionary:
	var cast := a.next_cast()
	var spell := Spell.make(cast)
	var me := w.player()
	if spell.homing():
		return _homing(w, a, cast)
	if not spell.strikes():
		return {}
	var d := Grid.line_dir(a.pos, me.pos)
	var r := Grid.cheb(a.pos, me.pos)
	if (
		d != Vector2i.ZERO
		and r >= 2
		and w.clear_line(a.pos, me.pos)
		and (spell.orb or r <= Spell.RANGE)
	):
		return {cards = cast, dir = d}
	return {}


## A homing orb leaves towards Miho, or beside her line when a wall is in the way.
static func _homing(w: World, a: Actor, cast: Array) -> Dictionary:
	var me := w.player()
	if Grid.cheb(a.pos, me.pos) > 6:
		return {}
	var i := Grid.DIRS.find(Grid.nearest_dir(me.pos - a.pos))
	for turn in [0, -1, 1]:
		var dir := Grid.DIRS[(i + turn + 8) % 8]
		if w.open_floor(a.pos + dir):
			return {cards = cast, dir = dir}
	return {}


## A wisp thrown at a dark spot it is searching.
static func searchlight(w: World, a: Actor) -> Dictionary:
	var cast := a.next_cast()
	var spell := Spell.make(cast)
	if spell == null or not spell.wisp or spell.orb or w.lit(a.target):
		return {}
	var r := Grid.cheb(a.pos, a.target)
	if r < 2 or r > Spell.RANGE:
		return {}
	var dir := Grid.nearest_dir(a.target - a.pos)
	if not w.open_floor(a.pos + dir):
		return {}
	return {cards = cast, dir = dir}


## A homing orb turns at most one step a tile towards the nearest foe.
static func steer(w: World, s: Shot) -> Vector2i:
	var target: Actor = null
	for a in w.actors:
		if a.alive() and a.faction != s.faction:
			if (
				target == null
				or Vector2(a.pos - s.pos).length() < Vector2(target.pos - s.pos).length()
			):
				target = a
	if target == null:
		return s.dir
	var i := Grid.DIRS.find(s.dir)
	var best := s.dir
	var best_len := Vector2(target.pos - (s.pos + s.dir)).length()
	for turn in [-1, 1]:
		var d := Grid.DIRS[(i + turn + 8) % 8]
		var length := Vector2(target.pos - (s.pos + d)).length()
		if length < best_len - 0.001:
			best = d
			best_len = length
	return best
