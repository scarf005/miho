class_name Perceived
extends RefCounted
## What Miho perceives in one round: the single account the message log and the
## map's popups and marks both read. A tile is seen if she saw it at the start
## or at the end of the round. A fact is an event she is told of: one that
## happened on a seen tile, one with no place, or a noise she heard out of
## sight, copied with `where` (the tile it happened on) and `i` (its index in
## the round's events). Anything else that happened gives no fact.

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
		if e.t == &"spawn":
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
	return out


## Whether tile p is seen in `vis`.
static func sees(vis: PackedByteArray, p: Vector2i) -> bool:
	return Grid.inside(p) and vis[Grid.index(p)] == 1


## The mark the map draws by a creature: blind x, hunting !, searching ?, or none.
static func mark_of(a: Actor) -> String:
	return "x" if a.blind > 0 else Palette.ALERT_MARK[a.alert]
