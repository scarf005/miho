class_name Leap
extends RefCounted
## 멀리뛰기 (Spell.LEAP): Miho leaps up to Spell.leap() tiles along one of the
## eight lines. She clears sky, ponds and creatures, and stops short of what a
## projectile cannot fly over or a closed door, such as a wall or a lantern.
## She lands on the farthest tile she clears that she can stand on
## (World.vacant), never on the sky: with none the leap cannot be cast, nor
## while she is rooted. The landing is a step onto that tile (World.move and
## World.arrive: stairs, traps, mud), heard LOUD tiles but on mud, and lays her
## scent there alone, so a hunter on her trail loses it. A wall right past the landing
## takes one hit for each tile of the leap left, as a pushed creature's does (Fall.slam),
## and the leaper none. The rest of the spell
## is cast from the landing, unless she has left the storey or fallen. She
## vents steam to fly: Compounds.STEAM of it lies on the tiles she leaves, from the
## one she starts on up to the third last, so that it does not spread onto her.
##
## 바꿔치기 (Spell.swaps): when a projectile with 도약 behind it strikes a
## creature, they trade places; when it stops anywhere else, Miho goes to
## where it is, unless she cannot stand there (the sky). Each trade is a step
## (World.move) and heard SWAP_LOUD tiles at both tiles. The 도약 is spent on the
## first stop or strike either way: the projectile goes on as the spell
## without it.

const LOUD := 3
const WORD := "탁"
const SWAP_LOUD := 5
## What a 도약 behind a projectile is called.
const SWAP_NAME := "바꿔치기"
const SWAP_WORD := "펑"


## Where a leap from `from` along `dir` lands, or `from` when it lands nowhere.
static func landing(w: World, from: Vector2i, dir: Vector2i, reach: int) -> Vector2i:
	var to := from
	for i in range(1, reach + 1):
		var p := from + dir * i
		if not w.open_air(p) or w.tile(p) == World.DOOR:
			break
		if w.vacant(p):
			to = p
	return to


## Whether `a` can cast `spell` along `dir`, one of the eight, or on itself
## with none (Guise): a leap lands somewhere, while `a` is not rooted; a copy has
## room (Bunsin); anything else is thrown there (Terrain.throwable).
static func open(w: World, a: Actor, spell: Spell, dir: Vector2i) -> bool:
	if Guise.mixed(spell):
		return false
	if dir == Vector2i.ZERO or Guise.ANYWHERE.has(Guise.kind(spell)):
		return Guise.why(a, spell) == ""
	if not Grid.DIRS.has(dir):
		return false
	if spell.has(Cards.BUNSIN):
		return Bunsin.open(w, a.pos + dir)
	if spell.shape != Spell.LEAP:
		return Terrain.throwable(w, spell, a.pos + dir, dir)
	return a.rooted <= 0 and landing(w, a.pos, dir, spell.leap()) != a.pos


## The one tile `spell` along `d` from `from` ends on, when it names one: the landing
## of a leap, the tile a copy steps out onto.
static func aimed(w: World, from: Vector2i, d: Vector2i, spell: Spell) -> Vector2i:
	return from + d if spell.has(Cards.BUNSIN) else landing(w, from, d, spell.leap())


static func cast(w: World, a: Actor, spell: Spell, dir: Vector2i) -> void:
	var to := landing(w, a.pos, dir, spell.leap())
	if a.rooted > 0 or to == a.pos:
		return
	var depth := w.depth
	var left := spell.leap() - Grid.cheb(a.pos, to)
	w.emit({t = &"leap", id = a.id, from = a.pos, to = to})
	for i in Grid.cheb(a.pos, to) - 1:
		Gas.add(w, a.pos + dir * i, Gas.STEAM, Compounds.STEAM)
	w.move(a, to)
	if w.depth != depth or not a.alive():
		return
	w.noise(to, 0 if w.tile(to) == World.MUD else LOUD, WORD, a.faction == Actor.FOX, a.id)
	if left > 0 and Fall.WALLS.has(w.tile(to + dir)):
		Fall.slam(w, to + dir, left, a.id)
	if a.is_miho():
		Scent.lay(w, to)
		if w.arrive(a):
			return
	var rest := spell.rest()
	if rest != null:
		w.cast(a, rest, dir)


## Projectile `s` has ended at its tile, where `a` stands (or null): its caster
## swaps in (see above).
static func swap(w: World, s: Shot, a: Actor) -> void:
	var me := w.actor(s.caster)
	if not s.spell.swaps() or me == null or not me.alive():
		return
	s.spell = s.spell.spent()
	var trade := a != null and a != me and a.alive()
	var to := a.pos if trade else s.pos
	if not (w.open_floor(to) if trade else w.vacant(to)):
		return
	var from := me.pos
	var depth := w.depth
	w.emit({t = &"swap", id = me.id, from = from, to = to, other = a.id if trade else 0})
	if trade:
		w.move(a, from)
	w.move(me, to)
	if trade:
		Fall.traded(w, a, me, depth)
	if w.depth != depth or not me.alive():
		return
	for p in [from, to]:
		w.noise(p, SWAP_LOUD, SWAP_WORD, me.faction == Actor.FOX, me.id)
	if me.is_miho():
		Scent.lay(w, to)
		w.arrive(me)
