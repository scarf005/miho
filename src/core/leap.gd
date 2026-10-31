class_name Leap
extends RefCounted
## 멀리뛰기 (Spell.LEAP): Miho leaps up to Spell.leap() tiles along one of the
## eight lines. She clears sky, ponds and creatures, and stops short of what a
## projectile cannot fly over or a closed door, such as a wall or a lantern.
## She lands on the farthest tile she clears that she can stand on
## (World.vacant), never on the sky: with none the leap cannot be cast, nor
## while she is rooted. The landing is a step onto that tile (World.move and
## World.arrive: stairs, traps, mud), heard LOUD tiles but on mud, and lays her
## scent there alone, so a hunter on her trail loses it. The rest of the spell
## is cast from the landing, unless she has left the storey or fallen.
##
## 바꿔치기 (Spell.swaps): when a projectile with 도 behind it strikes a
## creature, they trade places; when it stops anywhere else, Miho goes to
## where it is, unless she cannot stand there (the sky). Each trade is a step
## (World.move) and heard SWAP_LOUD tiles at both tiles. The 도 is spent on the
## first stop or strike either way: the projectile goes on as the spell
## without it.

const LOUD := 3
const WORD := "탁"
const SWAP_LOUD := 5
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


## Whether `a` can cast `spell` along `dir`: a leap lands somewhere, while `a`
## is not rooted; anything else is thrown there (Terrain.throwable).
static func open(w: World, a: Actor, spell: Spell, dir: Vector2i) -> bool:
	if spell.shape != Spell.LEAP:
		return Terrain.throwable(w, spell, a.pos + dir)
	return a.rooted <= 0 and landing(w, a.pos, dir, spell.leap()) != a.pos


static func cast(w: World, a: Actor, spell: Spell, dir: Vector2i) -> void:
	var to := landing(w, a.pos, dir, spell.leap())
	var depth := w.depth
	w.emit({t = &"leap", id = a.id, from = a.pos, to = to})
	w.move(a, to)
	if w.depth != depth or not a.alive():
		return
	w.noise(to, 0 if w.tile(to) == World.MUD else LOUD, WORD, a.faction == Actor.FOX, a.id)
	if a.faction == Actor.FOX:
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
	if not trade and not w.vacant(to):
		return
	var from := me.pos
	var depth := w.depth
	w.emit({t = &"swap", id = me.id, from = from, to = to, other = a.id if trade else 0})
	if trade:
		w.move(a, from)
	w.move(me, to)
	if w.depth != depth or not me.alive():
		return
	for p in [from, to]:
		w.noise(p, SWAP_LOUD, SWAP_WORD, me.faction == Actor.FOX, me.id)
	if me.faction == Actor.FOX:
		Scent.lay(w, to)
		w.arrive(me)
