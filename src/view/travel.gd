class_name Travel
extends RefCounted
## Walks of many rounds, planned only from what Miho knows: shortest paths in
## eight directions over known open tiles that step around creatures in
## sight, the nearest edge of the unexplored, and the reasons a walk stops.


## A known open tile with no creature or fire Miho sees on it.
static func walkable(w: World, p: Vector2i) -> bool:
	var i := Grid.index(p)
	if w.known[i] == 0 or not w.open_floor(p):
		return false
	if w.seen[i] == 0:
		return true
	var a := w.actor_at(p)
	return (a == null or a.faction == Actor.FOX) and not w.burning.has(p)


## Whether Miho sees fire on p or next to it.
static func near_fire(w: World, p: Vector2i) -> bool:
	for d: Vector2i in [Vector2i.ZERO] + Grid.DIRS:
		var q := p + d
		if Grid.inside(q) and w.seen[Grid.index(q)] == 1 and w.burning.has(q):
			return true
	return false


## Breadth-first steps from Miho over walkable tiles (Grid.search, plus `from`).
static func search(w: World) -> Dictionary:
	var found := Grid.search(w.player().pos, func(p): return walkable(w, p))
	found.from = w.player().pos
	return found


## The tiles from Miho to `to`, not counting where she stands; empty when it
## cannot be reached or is where she stands. Among shortest walks it keeps
## closest to the straight line, so it does not zigzag.
static func route(found: Dictionary, to: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var dist: PackedInt32Array = found.dist
	if not Grid.inside(to) or dist[Grid.index(to)] <= 0:
		return out
	var line := Vector2(to - found.from)
	var p := to
	while p != found.from:
		out.push_front(p)
		var best := p
		var off := INF
		for d in Grid.DIRS:
			var q := p + d
			if Grid.inside(q) and dist[Grid.index(q)] == dist[Grid.index(p)] - 1:
				var o := absf(line.cross(Vector2(q - found.from)))
				if o < off:
					best = q
					off = o
		p = best
	return out


## The nearest reachable tile beside a tile Miho has never made out (the
## straighter of equal walks), or (-1, -1).
static func frontier(w: World, found: Dictionary) -> Vector2i:
	var dist: PackedInt32Array = found.dist
	var best := Vector2i(-1, -1)
	var best_cost := INF
	for i in dist.size():
		var p := Grid.at(i)
		var cost := dist[i] + Vector2(p - found.from).length() * 0.01
		if dist[i] > 0 and cost < best_cost and _borders_unknown(w, p):
			best = p
			best_cost = cost
	return best


static func _borders_unknown(w: World, p: Vector2i) -> bool:
	for d in Grid.DIRS:
		var q := p + d
		if Grid.inside(q) and w.known[Grid.index(q)] == 0:
			return true
	return false


## The stairs, or the elixir on the top storey, once Miho has seen it; else (-1, -1).
static func exit(w: World) -> Vector2i:
	for p in [w.stairs, w.elixir]:
		if Grid.inside(p) and w.known[Grid.index(p)] == 1:
			return p
	return Vector2i(-1, -1)


## The step exploring takes: towards the nearest unexplored edge, or once
## everything reachable is known, towards the exit, stopping beside it so
## leaving the storey stays Miho's own choice. Zero when there is nowhere to go.
static func explore_step(w: World, found: Dictionary) -> Vector2i:
	var path := route(found, frontier(w, found))
	if path.is_empty():
		path = route(found, exit(w))
		path.pop_back()
	return path[0] - w.player().pos if not path.is_empty() else Vector2i.ZERO


## Ids of the creatures of heaven Miho sees.
static func in_sight(w: World) -> Dictionary:
	var out := {}
	for a in w.actors:
		if a.alive() and a.faction != Actor.FOX and w.seen[Grid.index(a.pos)] == 1:
			out[a.id] = true
	return out


## Whether a walk must stop after a round from `before` to `after`: a creature
## of heaven came into sight that was not in sight when the walk began (ids in
## `sighted`), one Miho sees noticed her, she was hurt, heard a noise, picked
## up a talisman, or the storey or the game ended.
static func interrupted(before: World, after: World, events: Array, sighted: Dictionary) -> bool:
	if after.depth != before.depth or after.outcome != &"" or not after.heard.is_empty():
		return true
	var me := after.player().id
	for e in events:
		match e.t:
			&"hurt":
				if e.id == me:
					return true
			&"card":
				return true
			&"notice":
				var i := Grid.index(e.at)
				if before.seen[i] == 1 or after.seen[i] == 1:
					return true
	for id in in_sight(after):
		if not sighted.has(id):
			return true
	return false
