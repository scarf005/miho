class_name Notice
extends RefCounted
## Changes a heaven creature can notice. The world records a change (a lantern
## that went out or broke, a door or wall that broke, a tile burnt to ash, a
## creature that fell, a scarecrow from a jar) with its tile and round. A creature
## that is not hunting and sees the tile of a change it has not seen before goes to
## search there, whatever its wits; each creature reacts to each change once. A fallen
## creature also leaves a body mark that stays for the storey.

const LABEL := {
	&"lantern_out": "꺼진 등불",
	&"lantern_broken": "부서진 등불",
	&"door": "부서진 문",
	&"wall": "부서진 벽",
	&"ash": "재",
	&"body": "시체",
	&"scarecrow": "쓰러진 허수아비",
}
## What a smash leaves: the change kind by the tile that was hit.
const SMASHED := {
	World.LANTERN: &"lantern_out",
	World.LANTERN_OUT: &"lantern_broken",
	World.DOOR: &"door",
	World.WALL: &"wall",
	World.WALL_CRACKED: &"wall",
}


## Records a change at `at` this round: {id, kind, at, round}.
static func record(w: World, kind: StringName, at: Vector2i) -> void:
	w.changes.append({id = w.changes.size(), kind = kind, at = at, round = w.round_no})


## A tile was hit: records the change it made, if it is one creatures notice.
static func smashed(w: World, was: int, at: Vector2i) -> void:
	if SMASHED.has(was):
		record(w, SMASHED[was], at)


## A heaven creature fell on its tile: records it and leaves a body mark there.
static func fallen(w: World, a: Actor) -> void:
	lay(w, a.kind, a.pos)


## A body of `kind` lies at `at` from now on, and creatures can notice it, unless one there
## is about to rise (Curse). Returns the mark.
static func lay(w: World, kind: StringName, at: Vector2i) -> Dictionary:
	record(w, &"body", at)
	if not w.bodies.get(at, {}).has("rises"):
		w.bodies[at] = {kind = kind, round = w.round_no, met = false}
	return w.bodies[at]


## The body marks Miho has seen.
static func known(w: World) -> Dictionary:
	var out := {}
	for p: Vector2i in w.bodies:
		if w.bodies[p].met:
			out[p] = w.bodies[p].duplicate()
	return out


## Body marks Miho has seen stay on her map.
static func remember(w: World) -> void:
	for p: Vector2i in w.bodies:
		if w.seen[Grid.index(p)] == 1:
			w.bodies[p].met = true


## The latest change at p, or empty.
static func at(w: World, p: Vector2i) -> Dictionary:
	for i in range(w.changes.size() - 1, -1, -1):
		if w.changes[i].at == p:
			return w.changes[i]
	return {}


## `a` looks at every change it sees and has not seen before, then searches the
## latest of them. A walled-in tile is searched from the floor next to it.
static func react(w: World, a: Actor) -> void:
	var fresh := w.changes.filter(func(c): return not a.brain.marked.has(c.id) and w.sees(a, c.at))
	if fresh.is_empty():
		return
	for c in fresh:
		a.brain.marked.append(c.id)
	var c: Dictionary = fresh.back()
	a.brain.alert = Actor.SEARCH
	a.brain.target = _spot(w, a, c.at)
	a.brain.lost = 0
	w.emit({t = &"heed", id = a.id, at = a.pos, kind = c.kind})


static func _spot(w: World, a: Actor, at: Vector2i) -> Vector2i:
	if w.open_floor(at):
		return at
	var best := at
	for d in Grid.DIRS:
		if (
			w.open_floor(at + d)
			and (best == at or Grid.cheb(a.pos, at + d) < Grid.cheb(a.pos, best))
		):
			best = at + d
	return best
