class_name Aim
extends RefCounted
## Where projectiles go: the line a heaven creature casts along, at Miho (or a
## rival it fights) or at a dark spot it searches. Homing projectiles find their
## own way (Homing). Each plan is {cards, dir}.


## The spells `a` charges at `foe`, when it sees it: a plan for each, or none.
## Below Bestiary.PICKS it tries only the next of its spells in turn
## (Actor.casts). From PICKS on it tries them all from that one, passes over
## those that miss the foe or that the foe absorbs, and takes the first the
## foe is weak to, else the first; from Bestiary.DOUBLES on also the next after
## it whose projectiles leave on tiles the first one's leave free (`_apart`).
## An orb needs a clear line; wisps and homing orbs only the foe in reach; a
## spray must cover the foe.
static func at(w: World, a: Actor, foe: Actor) -> Array[Dictionary]:
	var plans: Array[Dictionary] = []
	for cast: Array in _turn(a):
		var plan := _reach(w, a, cast, foe)
		var eaten := a.rank >= Bestiary.PICKS and Bestiary.absorbs(foe.kind, Spell.make(cast))
		if not plan.is_empty() and not eaten:
			plans.append(plan)
	if plans.is_empty():
		return plans
	var first := 0
	for i in plans.size():
		if Bestiary.weak(foe.kind, Spell.make(plans[i].cards)):
			first = i
			break
	var out: Array[Dictionary] = [plans[first]]
	if a.rank < Bestiary.DOUBLES:
		return out
	var taken := _departs(w, a, plans[first])
	for k in range(1, plans.size()):
		var then := _apart(w, a, plans[(first + k) % plans.size()], taken)
		if not then.is_empty():
			out.append(then)
			break
	return out


## The tiles next to `a` the projectiles of `plan` leave onto (Homing.headings):
## none for a spray.
static func _departs(w: World, a: Actor, plan: Dictionary) -> Array:
	var spell := Spell.make(plan.cards)
	if spell.shape == Spell.SPRAY:
		return []
	var heads := Homing.headings(w, a, plan.dir, Homing.targets(w, a, spell))
	return heads.map(func(h): return a.pos + h)


## `plan` cast after one whose projectiles leave onto `taken`, so the two do not
## meet as they leave: as it is, or a homing one turned up to 90° to leave
## on open tiles of its own; empty when it cannot.
static func _apart(w: World, a: Actor, plan: Dictionary, taken: Array) -> Dictionary:
	var spell := Spell.make(plan.cards)
	var i := Grid.DIRS.find(plan.dir)
	var turns := [0, -1, 1, -2, 2] if spell.turn() > 0 else [0]
	for turn: int in turns:
		var turned := {cards = plan.cards, dir = Grid.DIRS[(i + turn + 8) % 8]}
		var leaves := _departs(w, a, turned)
		if leaves.all(func(p): return w.open_air(p) and not taken.has(p)):
			return turned
	return {}


## Its spells in the order it tries them, from the next in turn: that one
## alone below Bestiary.PICKS.
static func _turn(a: Actor) -> Array:
	var list := a.repertoire()
	if list.is_empty():
		return []
	var start := a.casts % list.size()
	var out := list.slice(start) + list.slice(0, start)
	return out if a.rank >= Bestiary.PICKS else out.slice(0, 1)


## The plan that takes `cast` to `foe`, or empty.
static func _reach(w: World, a: Actor, cast: Array, foe: Actor) -> Dictionary:
	var spell := Spell.make(cast)
	if spell == null:
		return {}
	if spell.shape == Spell.SPRAY:
		return _spray(w, a, cast, foe)
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


## A spray that covers `foe` (Spray.cover): along its line, else the nearest
## direction to it.
static func _spray(w: World, a: Actor, cast: Array, foe: Actor) -> Dictionary:
	var spell := Spell.make(cast)
	for dir in [Grid.line_dir(a.pos, foe.pos), Grid.nearest_dir(foe.pos - a.pos)]:
		if dir != Vector2i.ZERO and Spray.cover(w, a, spell, dir).has(foe.pos):
			return {cards = cast, dir = dir}
	return {}


## A wisp thrown at a dark spot it is searching: the first of its spells in
## turn that is one (`_turn`).
static func searchlight(w: World, a: Actor) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var r := Grid.cheb(a.pos, a.target)
	var dir := Grid.nearest_dir(a.target - a.pos)
	if w.lit(a.target) or r < 2 or r > Spell.RANGE or not w.open_air(a.pos + dir):
		return out
	for cast: Array in _turn(a):
		var spell := Spell.make(cast)
		if spell != null and spell.shape == Spell.WISP:
			out.append({cards = cast, dir = dir})
			break
	return out


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
