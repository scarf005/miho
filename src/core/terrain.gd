class_name Terrain
extends RefCounted
## Terrain that reacts to what Miho and heaven do to it: lanterns that go out
## and light again, doors that break. See World for the rules.


## An orb can be hurled at any open tile and at a lantern right next to the
## caster, which it smashes where it stands.
static func throwable(w: World, spell: Spell, at: Vector2i) -> bool:
	return w.open_air(at) or (spell.orb and w.tile(at) == World.LANTERN)


## Miho walks into a lantern: it goes out, with a clang.
static func knock(w: World, me: Actor, at: Vector2i) -> void:
	w.set_tile(at, World.LANTERN_OUT)
	w.emit({t = &"smash", at = at})
	w.noise(at, World.KNOCK, "쨍", true, me.id)


## An orb without water breaks the lit lantern or the closed door it struck.
static func smash(w: World, s: Shot, at: Vector2i, struck: int) -> void:
	if (
		s.spell.has(Cards.WATER)
		or w.tile(at) != struck
		or (struck != World.LANTERN and struck != World.DOOR)
	):
		return
	w.burning.erase(at)
	w.set_tile(at, World.LANTERN_OUT if struck == World.LANTERN else World.FLOOR)
	w.emit({t = &"smash", at = at})


## Fire relights the lanterns next to where a spell ends, and water douses
## lanterns and flames there.
static func touch(w: World, s: Shot, at: Vector2i) -> void:
	for d: Vector2i in [Vector2i.ZERO] + Grid.DIRS:
		var p := at + d
		if s.spell.has(Cards.FIRE) and w.tile(p) == World.LANTERN_OUT:
			w.set_tile(p, World.LANTERN)
			w.emit({t = &"relight", at = p})
		if s.spell.has(Cards.WATER) and (w.tile(p) == World.LANTERN or w.burning.has(p)):
			w.burning.erase(p)
			w.set_tile(p, World.LANTERN_OUT if w.tile(p) == World.LANTERN else w.tile(p))
			w.emit({t = &"douse", at = p})


## A searching creature lights a lantern that went out next to it; true when it did.
static func relight_beside(w: World, a: Actor) -> bool:
	for d in Grid.DIRS:
		if w.tile(a.pos + d) == World.LANTERN_OUT:
			w.set_tile(a.pos + d, World.LANTERN)
			w.emit({t = &"relight", at = a.pos + d, id = a.id})
			return true
	return false
