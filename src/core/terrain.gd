class_name Terrain
extends RefCounted
## Terrain that reacts to what Miho and heaven do to it: lanterns that go out,
## light again and break, doors and walls that break. See World for the rules.

## What a hit leaves of a tile: a lit lantern goes out, a dark one breaks into
## rubble, a closed door becomes floor, a wall cracks and then falls to rubble.
const BREAKS := {
	World.WALL: World.WALL_CRACKED,
	World.WALL_CRACKED: World.RUBBLE,
	World.LANTERN: World.LANTERN_OUT,
	World.LANTERN_OUT: World.LANTERN_BROKEN,
	World.DOOR: World.FLOOR,
}


## A lantern that is not broken: it blocks walking and a hit moves it one step on.
static func lantern(t: int) -> bool:
	return t == World.LANTERN or t == World.LANTERN_OUT


## A wall, cracked or not: it blocks walking, sight and light.
static func wall(t: int) -> bool:
	return t == World.WALL or t == World.WALL_CRACKED


## A tile a hit changes. The outermost ring of the map, and beyond it, never breaks.
static func breakable(w: World, at: Vector2i) -> bool:
	var inner := at.x > 0 and at.y > 0 and at.x < Grid.W - 1 and at.y < Grid.H - 1
	return BREAKS.has(w.tile(at)) and (inner or not wall(w.tile(at)))


## An orb can be hurled at any open tile and at a breakable lantern or wall
## right next to the caster, which it strikes where it stands.
static func throwable(w: World, spell: Spell, at: Vector2i) -> bool:
	return w.open_air(at) or (spell.orb and breakable(w, at))


## Miho walks into a lantern: a hit, with a clang.
static func knock(w: World, me: Actor, at: Vector2i) -> void:
	hit(w, at)
	w.noise(at, World.KNOCK, "쨍", true, me.id)


## An orb without water hits the lantern, closed door or wall it struck; a wall
## thuds.
static func smash(w: World, s: Shot, at: Vector2i, struck: int) -> void:
	if not s.spell.has(Cards.WATER) and w.tile(at) == struck and breakable(w, at):
		hit(w, at)
		if wall(struck):
			w.noise(at, World.THUD, "쿵", true, s.caster)


## Moves the tile one step along BREAKS; `was` is the tile it was.
static func hit(w: World, at: Vector2i) -> void:
	var was := w.tile(at)
	w.burning.erase(at)
	w.set_tile(at, BREAKS[was])
	w.emit({t = &"smash", at = at, was = was})


## Fire relights the dark lanterns next to where a spell ends, except `struck`,
## and water douses lit lanterns and flames there.
static func touch(w: World, s: Shot, at: Vector2i, struck: Vector2i) -> void:
	for d: Vector2i in [Vector2i.ZERO] + Grid.DIRS:
		var p := at + d
		if s.spell.has(Cards.FIRE) and w.tile(p) == World.LANTERN_OUT and p != struck:
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
