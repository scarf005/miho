class_name Homing
extends RefCounted
## How wisps and homing orbs pick their creatures and find their way to them.
## Miho's projectiles go for every creature but her; heaven's go for Miho, or
## for the rival the caster fights (Mind).
##
## At the cast the caster's foes in its sight line up by (distance, id). A
## homing orb takes the nearest. Wisps fill each foe in turn up to what its
## health needs (harmless wisps all take the nearest), and the wisps left over
## go to the nearest. A projectile whose creature has fallen, or that had none,
## takes the nearest foe it sees from where it is; others keep theirs.
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
## and steers no more, nor does one that hovers (World._step).

## Turns tried, in steps of Spell.TURN_STEP from the heading.
const TURNS := [0, -1, 1, -2, 2, -3, 3, 4]


## The creature id each projectile of `spell` cast by `caster` goes for, 0 for none.
static func targets(w: World, caster: Actor, spell: Spell) -> Array[int]:
	var out: Array[int] = []
	out.resize(spell.shots())
	if spell.turn() == 0:
		return out
	var rival := caster.rival if caster.fighting() else 0
	var foes := w.actors.filter(
		func(a):
			var foe: bool = a.id == rival if rival != 0 else a.faction != caster.faction
			return a.alive() and foe and Hat.sees(w, caster, a)
	)
	foes.sort_custom(func(a, b): return _closer(caster.pos, a, b))
	if foes.is_empty():
		return out
	var i := 0
	for a: Actor in foes:
		var need := ceili(float(a.hp) / maxi(1, spell.damage(0)))
		for k in mini(need, out.size() - i):
			out[i + k] = a.id
		i += mini(need, out.size() - i)
	for k in range(i, out.size()):
		out[k] = foes[0].id
	return out


static func _closer(from: Vector2i, a: Actor, b: Actor) -> bool:
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
			if best == null or _closer(s.pos, a, best):
				best = a
	return best.id if best != null else 0


## Whether a projectile at `from` makes out tile p: in its line of sight, and
## lit or next to it, and not inside bamboo but from beside it.
static func sees(w: World, from: Vector2i, p: Vector2i) -> bool:
	var near := Grid.cheb(from, p) <= 1
	return w.fov(from)[Grid.index(p)] == 1 and (near or w.lit(p) and not w.hides(p))
