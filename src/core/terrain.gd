class_name Terrain
extends RefCounted
## Terrain that reacts to what Miho and heaven do to it.
##
## A lantern has three states: lit, out, and broken (rubble that can be walked
## over and never lit again). Each hit moves it one step on: Miho walking into
## it, with a clang, or an orb striking it. An orb also smashes the closed door
## it strikes. Water douses lit lanterns next to where it ends, silently, and
## fire relights dark ones; a searching creature relights a dark lantern it
## stands next to.
##
## Walls break only to orbs: two hits turn a wall into a cracked wall (which
## still blocks walking, sight and light) and then into rubble. Each hit thuds.
## The outermost ring of tiles never breaks.
##
## A door slides. Walking into a closed one, by Miho or a creature of heaven,
## opens it instead of stepping, with a rustle of SLIDE tiles; Miho's alarms
## heaven. Open it stays until Miho shuts it with the close action (same sound).
## A closed door blocks sight, not light. An orb smashes a closed door to floor.
## An open door burns like a closed one.

## A drum tears to a flat torn drum when Miho walks into it or an orb strikes
## it (Drums); water wets it.
##
## A window in an outer wall blocks walking but not sight or light, and breaks
## to floor with a clang when Miho walks into it or an orb strikes it.

## How far a sliding door is heard.
const SLIDE := 3

## What a hit leaves of a tile: a lit lantern goes out, a dark one breaks into
## rubble, a closed door or a window becomes floor, a wall cracks and then falls to rubble.
const BREAKS := {
	World.WALL: World.WALL_CRACKED,
	World.WALL_CRACKED: World.RUBBLE,
	World.LANTERN: World.LANTERN_OUT,
	World.LANTERN_OUT: World.LANTERN_BROKEN,
	World.DOOR: World.FLOOR,
	World.WINDOW: World.FLOOR,
	World.DRUM: World.DRUM_TORN,
}


## A lantern that is not broken: it blocks walking and a hit moves it one step on.
static func lantern(t: int) -> bool:
	return t == World.LANTERN or t == World.LANTERN_OUT


## A tile Miho knocks by walking into it: a lantern, a window or a drum.
static func knockable(t: int) -> bool:
	return lantern(t) or t == World.WINDOW or t == World.DRUM


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


## Miho walks into a lantern or window: a hit, with a clang; a drum tears.
static func knock(w: World, me: Actor, at: Vector2i) -> void:
	var word := "찌익" if w.tile(at) == World.DRUM else "쨍"
	hit(w, at)
	w.noise(at, World.KNOCK, word, true, me.id)


## `by` slides the closed door at `at` open; its move is spent.
static func open_door(w: World, by: Actor, at: Vector2i) -> void:
	_slide(w, by, at, World.DOOR_OPEN, &"open")


## Miho slides the open door at `at` shut.
static func close_door(w: World, by: Actor, at: Vector2i) -> void:
	_slide(w, by, at, World.DOOR, &"close")


static func _slide(w: World, by: Actor, at: Vector2i, to: int, event: StringName) -> void:
	w.set_tile(at, to)
	w.emit({t = event, at = at, id = by.id})
	w.noise(at, SLIDE, "드르륵", by.faction == Actor.FOX, by.id)


## An orb without water hits the lantern, closed door, window or wall it struck;
## a wall thuds and a window clangs.
static func smash(w: World, s: Shot, at: Vector2i, struck: int) -> void:
	if not s.spell.has(Cards.WATER) and w.tile(at) == struck and breakable(w, at):
		hit(w, at)
		if wall(struck):
			w.noise(at, World.THUD, "쿵", true, s.caster)
		elif struck == World.WINDOW:
			w.noise(at, World.KNOCK, "쨍", true, s.caster)


## Moves the tile one step along BREAKS; `was` is the tile it was.
static func hit(w: World, at: Vector2i) -> void:
	var was := w.tile(at)
	w.burning.erase(at)
	w.set_tile(at, BREAKS[was])
	w.emit({t = &"smash", at = at, was = was})


## Fire relights the dark lanterns next to where a spell ends, except `struck`,
## and water douses lit lanterns and flames and washes away Miho's scent there.
static func touch(w: World, s: Shot, at: Vector2i, struck: Vector2i) -> void:
	for d: Vector2i in [Vector2i.ZERO] + Grid.DIRS:
		var p := at + d
		if s.spell.has(Cards.FIRE) and w.tile(p) == World.LANTERN_OUT and p != struck:
			w.set_tile(p, World.LANTERN)
			w.emit({t = &"relight", at = p})
		if s.spell.has(Cards.WATER):
			Scent.clear(w, p)
		if s.spell.has(Cards.WATER) and w.tile(p) == World.DRUM:
			Drums.soak(w, p)
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
