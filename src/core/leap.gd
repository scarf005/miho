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

const LOUD := 3
const WORD := "탁"


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


## Whether `a` can leap with `spell` along `dir`.
static func can(w: World, a: Actor, spell: Spell, dir: Vector2i) -> bool:
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
