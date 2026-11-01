class_name Aim
extends RefCounted
## Where projectiles go: the line a heaven creature casts along, at Miho (or a
## rival it fights) or at a dark spot it searches. Homing projectiles find their
## own way (Homing). Each plan is {cards, dir}.

## The most spells a creature charges at once.
const CASTS := 2


## The spells `a` charges at `foe`, when it sees it: a plan for each, or none.
## Below Bestiary.PICKS it tries only the next of its spells in turn
## (Actor.casts). From PICKS on it tries them all from that one, passes over
## those that miss the foe or that the foe absorbs, and takes the first the
## foe is weak to, else the first; from Bestiary.DOUBLES on also the next after
## it whose projectiles leave on tiles the first one's leave free (`_apart`).
## An orb needs a clear line; wisps and homing orbs only the foe in reach; a
## spray must cover the foe. A creature with mana buys its spells (`_buy`).
static func at(w: World, a: Actor, foe: Actor) -> Array[Dictionary]:
	if Bestiary.mana(a.kind) > 0:
		return _buy(w, a, foe)
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
			if out.size() >= CASTS:
				break
	return out


## What a creature with mana casts at `foe` (Bestiary mana): the dearest spell
## it can pay for that reaches the foe, that the foe does not absorb and that is
## not moot (`_moot`); then, with the mana left, the dearest after it that
## leaves on open tiles of its own (`_apart`).
static func _buy(w: World, a: Actor, foe: Actor) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var first := _dearest(w, a, foe, a.mana, [])
	if first.is_empty():
		return out
	out.append(first)
	var left := a.mana - Spell.price(first.cards.size())
	var taken := _departs(w, a, first)
	var skip := [first.cards]
	while true:
		var next := _dearest(w, a, foe, left, skip)
		if next.is_empty():
			break
		skip.append(next.cards)
		var then := _apart(w, a, next, taken)
		if not then.is_empty():
			out.append(then)
			if out.size() >= CASTS:
				break
	return out


## The dearest spell of `a` that costs at most `mana` and is not in `skip`,
## reaching `foe`, as a plan, or empty. Equal prices keep the order of its list.
static func _dearest(w: World, a: Actor, foe: Actor, mana: int, skip: Array) -> Dictionary:
	var best := {}
	var best_price := 0
	for cast: Array in a.repertoire():
		var price := Spell.price(cast.size())
		var spell := Spell.make(cast)
		if price <= best_price or price > mana or skip.has(cast) or _moot(spell, foe):
			continue
		if Bestiary.absorbs(foe.kind, spell):
			continue
		var plan := _reach(w, a, cast, foe)
		if not plan.is_empty():
			best = plan
			best_price = price
	return best


## Whether a spray adds nothing to `foe`: every element it holds is a mark the
## foe already bears (rooted by 나무, wet by 물, alight by 불).
static func _moot(spell: Spell, foe: Actor) -> bool:
	if spell.shape != Spell.SPRAY:
		return false
	var marks := {Cards.WOOD: foe.rooted, Cards.WATER: foe.wet, Cards.FIRE: foe.alight}
	var held: Array = spell.slots.reduce(func(all, slot): return all + Cards.parts(slot), [])
	return held.all(func(e): return marks.get(e, 0) > 0)


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


## The lone fire (Bestiary.KINDLE) of `a` when `foe` stands beside it on a tile
## that burns, or none.
static func kindle(w: World, a: Actor, foe: Actor) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if a.repertoire().has(Bestiary.KINDLE) and Tiles.burns[w.tile(foe.pos)] == 1:
		var plan := _spray(w, a, Bestiary.KINDLE, foe)
		if not plan.is_empty():
			out.append(plan)
	return out


## Its spells in the order it tries them, from the next in turn: that one
## alone below Bestiary.PICKS, the lone fire aside (`kindle`). One with mana
## tries those it can pay for, the cheapest first, and none of 수's darkness.
static func _turn(a: Actor) -> Array:
	var list := a.repertoire()
	if Bestiary.mana(a.kind) > 0:
		return _cheap(a, list)
	if a.rank < Bestiary.PICKS:
		list = list.filter(func(c): return c != Bestiary.KINDLE)
	if list.is_empty():
		return []
	var start := a.casts % list.size()
	var out := list.slice(start) + list.slice(0, start)
	return out if a.rank >= Bestiary.PICKS else out.slice(0, 1)


## The spells in `list` that `a` can pay for and that are no darkness, the cheapest first.
static func _cheap(a: Actor, list: Array) -> Array:
	var out := []
	for n in range(1, Spell.MAX_SLOTS + 1):
		if Spell.price(n) > a.mana:
			break
		out.append_array(list.filter(func(c): return c.size() == n and not _dark(c)))
	return out


static func _dark(cast: Array) -> bool:
	return Spell.make(cast).holds(Cards.WATER)


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
## line to her: its own tile when it stands on one, or when she stands in the dark,
## where stepping back would lose sight of her; (-1, -1) when none is reachable.
static func lineup(w: World, a: Actor, walk: PackedByteArray) -> Vector2i:
	var me := w.player()
	if not w.lit(me.pos):
		return a.pos
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
