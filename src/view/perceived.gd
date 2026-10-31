class_name Perceived
extends RefCounted
## What Miho perceives in one round: the single account the message log and the
## map's popups and marks both read. A tile is seen if she saw it at the start
## or at the end of the round. A fact is an event she is told of: one that
## happened on a seen tile, one with no place, or a noise she heard out of
## sight, copied with `where` (the tile it happened on) and `i` (its index in
## the round's events). Anything else that happened gives no fact.
## The map also marks a creature in sight by its state, so a creature that comes
## into sight marked, or changes its mark in sight, gives a `state` fact (i is
## -1) unless the round's facts already tell it: a seen notice, heed or blinding.
## It derives from `before` and `after` only, so a replay gives the same facts.

## The mark a seen event already tells.
const TELLS := {&"notice": "!", &"heed": "?", &"blind": "x"}

## Tiles seen at the start or end of the round (1 for seen).
var vis := PackedByteArray()
## The facts, in the order of the events.
var facts: Array[Dictionary] = []


## What Miho perceives of `events`, the round from `before` to `after`.
static func of(before: World, after: World, events: Array) -> Perceived:
	var out := Perceived.new()
	out.vis = before.seen.duplicate()
	for i in out.vis.size():
		out.vis[i] |= after.seen[i]
	var where := {}
	for w: World in [after, before]:
		for a in w.actors:
			where[a.id] = a.pos
	var factions := {}
	for s in before.shots:
		factions[s.id] = s.faction
	for i in events.size():
		var e: Dictionary = events[i]
		if e.t == &"move" and where.has(e.id):
			where[e.id] = e.to
		if e.t == &"spawn" or e.t == &"spray":
			factions[e.shot] = e.faction
		if e.t == &"hit":
			e = e.merged({faction = factions.get(e.shot, Actor.HEAVEN)})
		var at: Vector2i = e.get("to", e.get("at", where.get(e.get("id", -1), Vector2i(-1, -1))))
		var told := (
			not Grid.inside(at) and not e.has("id")
			or sees(out.vis, at)
			or (e.has("from") and sees(out.vis, e.from))
		)
		if e.t == &"noise":
			told = e.heard and not sees(out.vis, e.at)
		if told:
			out.facts.append(e.merged({where = at, i = i}))
	out._tell_marks(before, after)
	return out


## A `state` fact for each creature in sight at the end whose mark Miho was
## not shown before: it was out of sight, or marked differently.
func _tell_marks(before: World, after: World) -> void:
	var covered := {}
	for f in facts:
		if TELLS.has(f.t):
			covered[[TELLS[f.t], f.id]] = true
	for a in after.actors:
		var mark := mark_of(a)
		if a.faction == Actor.FOX or not a.alive() or mark == "" or not sees(after.seen, a.pos):
			continue
		var was := before.actor(a.id)
		if was != null and was.alive() and sees(before.seen, was.pos) and mark_of(was) == mark:
			continue
		if not covered.has([mark, a.id]):
			facts.append({t = &"state", id = a.id, mark = mark, where = a.pos, i = -1})


## Whether tile p is seen in `vis`.
static func sees(vis: PackedByteArray, p: Vector2i) -> bool:
	return Grid.inside(p) and vis[Grid.index(p)] == 1


## The mark the map draws by a creature: blind x, hunting !, searching ?, or none.
static func mark_of(a: Actor) -> String:
	return "x" if a.blind > 0 else Palette.ALERT_MARK[a.alert]
