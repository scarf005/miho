class_name Homing
extends RefCounted
## How wisps and homing orbs pick their creatures and find their way to them.
## Miho's projectiles go for every creature but her; heaven's go for Miho, or
## for the rival the caster fights (Mind).
##
## At the cast the caster's foes in its sight line up by (distance, id). A
## homing orb takes the nearest. Wisps fill each foe in turn up to what its
## health needs (harmless wisps all take the nearest), and the wisps left over
## go to the nearest. The orbs of a cast of several (Spell.shots) spread among
## the foes within an arc round the cast line instead (`spread`), each leaving
## straight at its own (`headings`), one on the line of another trailing it;
## wisps keep their own way, which reads health and not the line. A projectile
## whose creature has fallen, or that had none,
## takes the nearest foe it sees from where it is; others keep theirs.
##
## Each wisp of a cast leaves the caster on a tile of its own next to it, as
## DCSS foxfire (spl-summoning.cc cast_foxfire): the first on the aimed one;
## each after it on the free tile left (open, no creature) nearest its
## creature, in TURNS order on a tie or with no creature; once none is left,
## on the aimed one. A wisp off the aimed line flies straight to its tile and
## faces its creature there, never back at its caster; with none it flies on
## away from the caster.
##
## Each tile, a breadth-first search from the creature over the tiles a
## projectile may fly through (Masks.fly) gives the distance of every tile to
## it, and the projectile takes the neighbour one tile nearer, within its turn:
## straight on first, then the smallest turns, left before right.
## Its turn is a bank of degrees: every tile it gains Shot.turn, holding no
## more than that or Spell.TURN_STEP, whichever is more, and each 45° step of a
## turn spends Spell.TURN_STEP. A homing orb so turns Shot.turn every tile; a
## lone wisp (30°) one step at most every second tile.
## With no such neighbour it flies straight on, and so may lose its creature
## round a corner it cannot turn. A wisp that has struck sticks to its creature
## and steers no more, nor does one that hovers (Flight.step).

## Turns tried, in steps of Spell.TURN_STEP from the heading.
const TURNS := [0, -1, 1, -2, 2, -3, 3, 4]
## The arcs, in degrees across the line of a cast, that the orbs of one cast
## spread among (`spread`): the narrowest that holds as many creatures as it
## has orbs, else the widest.
const ARCS := [30, 45, 90, 120, 180]
## Degrees of slack, so a creature exactly on the edge of an arc is inside it.
const ARC_SLACK := 0.001


## The creature id each projectile of `spell` cast by `caster` along `dir` goes
## for, 0 for none. The orbs of a cast of several spread among the creatures in
## an arc round `dir` (`spread`).
static func targets(w: World, caster: Actor, spell: Spell, dir := Vector2i.ZERO) -> Array[int]:
	var out: Array[int] = []
	out.resize(spell.shots())
	var twins := spell.orb and out.size() > 1 and (caster.faction == Actor.FOX or spell.turn() > 0)
	if spell.turn() == 0 and not twins:
		return out
	var rival := caster.rival if caster.fighting() else 0
	var foes := w.actors.filter(
		func(a):
			var foe: bool = a.id == rival if rival != 0 else a.faction != caster.faction
			return a.alive() and foe and Hat.sees(w, caster, a)
	)
	foes.sort_custom(func(a, b): return closer(caster.pos, a, b))
	if foes.is_empty():
		return out
	if twins:
		return spread(caster, foes, dir, out.size())
	var i := 0
	for a: Actor in foes:
		var need := ceili(float(a.hp) / maxi(1, spell.damage(0)))
		for k in mini(need, out.size() - i):
			out[i + k] = a.id
		i += mini(need, out.size() - i)
	for k in range(i, out.size()):
		out[k] = foes[0].id
	return out


## The creature id each of `n` orbs goes for: the creatures of `foes` (nearest
## first) within the narrowest of ARCS round `dir` that holds `n` of them, one
## orb each in turn; none when no creature lies in the widest arc.
static func spread(caster: Actor, foes: Array, dir: Vector2i, n: int) -> Array[int]:
	var aim := dir if dir != Vector2i.ZERO else Grid.nearest_dir(foes[0].pos - caster.pos)
	var inside := []
	for arc: int in ARCS:
		inside = foes.filter(func(a): return _off(caster.pos, aim, a.pos) <= arc / 2.0 + ARC_SLACK)
		if inside.size() >= n:
			break
	var out: Array[int] = []
	out.resize(n)
	if not inside.is_empty():
		for i in n:
			out[i] = inside[i % inside.size()].id
	return out


## Degrees between the line `aim` and the direction from `from` to `p`.
static func _off(from: Vector2i, aim: Vector2i, p: Vector2i) -> float:
	return absf(rad_to_deg(Vector2(aim).angle_to(Vector2(p - from))))


## The direction each projectile `caster` casts towards `dir` leaves it in, for
## the creatures `targets` it goes for. The orbs of a cast of several leave
## straight at their creatures (the first of a line first, the rest trailing it),
## on `dir` for one with none.
static func headings(
	w: World, caster: Actor, spell: Spell, dir: Vector2i, targets: Array[int]
) -> Array[Vector2i]:
	if spell.orb and spell.shots() > 1:
		var lines: Array[Vector2i] = []
		for id in targets:
			var t := w.actor(id)
			lines.append(Grid.nearest_dir(t.pos - caster.pos) if t != null else dir)
		return lines
	var free: Array[Vector2i] = []
	var i := maxi(0, Grid.DIRS.find(dir))
	for k: int in TURNS.slice(1):
		var p: Vector2i = caster.pos + Grid.DIRS[(i + k + 8) % 8]
		if w.open_air(p) and w.actor_at(p) == null:
			free.append(p)
	var out: Array[Vector2i] = [dir]
	for n in range(1, targets.size()):
		var t := w.actor(targets[n])
		var best := 0
		for j in free.size():
			if t != null and Grid.cheb(free[j], t.pos) < Grid.cheb(free[best], t.pos):
				best = j
		out.append(free.pop_at(best) - caster.pos if not free.is_empty() else dir)
	return out


## The way a wisp that has just reached its own tile faces: towards its
## creature, but never back at its caster's tile.
static func facing(w: World, s: Shot) -> Vector2i:
	var t := w.actor(s.target)
	if t == null or not t.alive():
		return s.dir
	var d := Grid.nearest_dir(t.pos - s.pos)
	return s.dir if s.pos + d == s.origin else d


static func closer(from: Vector2i, a: Actor, b: Actor) -> bool:
	return [Grid.cheb(from, a.pos), a.id] < [Grid.cheb(from, b.pos), b.id]


## The direction `s` flies next, after banking this tile's turn and taking a
## new creature when it needs one.
static func steer(w: World, s: Shot) -> Vector2i:
	s.bank = mini(s.bank + s.turn, maxi(s.turn, Spell.TURN_STEP))
	var t := w.actor(s.target)
	if t == null or not t.alive():
		s.target = _nearest(w, s)
		t = w.actor(s.target)
	if t == null:
		return s.dir
	var dist: PackedInt32Array = Grid.search(t.pos, Masks.fly(w)).dist
	var here := dist[Grid.index(s.pos)]
	if here <= 0:
		return s.dir
	var i := maxi(0, Grid.DIRS.find(s.dir))
	for k: int in TURNS:
		var cost := absi(k) * Spell.TURN_STEP
		var d := Grid.DIRS[(i + k + 8) % 8]
		var p := s.pos + d
		if cost <= s.bank and Grid.inside(p) and dist[Grid.index(p)] == here - 1:
			s.bank -= cost
			return d
	return s.dir


## The nearest foe `s` sees from where it is, by (distance, id); 0 for none.
static func _nearest(w: World, s: Shot) -> int:
	var best: Actor = null
	for a in w.actors:
		if (
			a.alive()
			and a.faction != s.faction
			and sees(w, s.pos, a.pos)
			and not Hat.hidden(w, a, s.pos)
		):
			if best == null or closer(s.pos, a, best):
				best = a
	return best.id if best != null else 0


## Whether a projectile at `from` makes out tile p: in its line of sight, and
## lit or next to it, and not inside bamboo but from beside it.
static func sees(w: World, from: Vector2i, p: Vector2i) -> bool:
	var near := Grid.cheb(from, p) <= 1
	return w.fov(from)[Grid.index(p)] == 1 and (near or w.lit(p) and not w.hides(p))
