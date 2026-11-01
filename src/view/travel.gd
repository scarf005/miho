class_name Travel
extends RefCounted
## Walks of many rounds, planned only from what Miho knows: shortest paths in
## eight directions over known open tiles that step around creatures in
## sight, the nearest edge of the unexplored, and the reasons a walk stops.


## A known open tile that is no thorns and holds no plate she has found, with no
## creature, fire, hot ground or harmful gas Miho sees on it.
static func walkable(w: World, p: Vector2i) -> bool:
	var i := Grid.index(p)
	if w.known[i] == 0 or not w.open_floor(p) or w.tile(p) == World.THORNS:
		return false
	if Tiles.of(w.tile(p), "trap"):
		return false
	if w.seen[i] == 0:
		return true
	var a := w.actor_at(p)
	var harms := w.burning.has(p) or w.hot.has(p) or Gas.harms(w, p) or Veil.scorches(w, p)
	return (a == null or a.faction == Actor.FOX) and not harms


## Whether Miho sees fire on p or next to it.
static func near_fire(w: World, p: Vector2i) -> bool:
	for d: Vector2i in [Vector2i.ZERO] + Grid.DIRS:
		var q := p + d
		if Grid.inside(q) and w.seen[Grid.index(q)] == 1 and w.burning.has(q):
			return true
	return false


## Breadth-first steps from Miho over walkable tiles that are not in `avoid`
## (tile -> true, the travel exclusions) (Grid.search, plus `from`).
static func search(w: World, avoid := {}) -> Dictionary:
	var found := Grid.search(w.player().pos, open(w, avoid))
	found.from = w.player().pos
	return found


## `walkable` and not in `avoid`, for every tile (a mask for Grid.search).
static func open(w: World, avoid := {}) -> PackedByteArray:
	var test := func(p): return walkable(w, p) and not avoid.has(p)
	var out := Masks.floor_of(w, Masks.odd(w) + avoid.keys(), test)
	for i in out.size():
		out[i] &= w.known[i]
	return out


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


## The reachable one of `tiles` fewest steps away, or (-1, -1). Unknown tiles
## are never reached (search walks known ones only).
static func _nearest(found: Dictionary, tiles: Array) -> Vector2i:
	var dist: PackedInt32Array = found.dist
	var best := Vector2i(-1, -1)
	for p: Vector2i in tiles:
		var d := dist[Grid.index(p)]
		if d > 0 and (best.x < 0 or d < dist[Grid.index(best)]):
			best = p
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


## The step exploring takes: towards the nearest peach or scroll she knows of (DCSS
## explore_greedy), else the nearest unexplored edge, or once everything
## reachable is known, towards the exit, stopping beside it so leaving the
## storey stays Miho's own choice. Zero when there is nowhere to go, or while an
## awake creature is in sight (`watched`): its tile and the ground it blocks change
## with every round, which turns the walk back and forth between two tiles.
static func explore_step(w: World, found: Dictionary) -> Vector2i:
	if watched(w):
		return Vector2i.ZERO
	var path := route(found, _nearest(found, w.peaches + Scrolls.spots(w)))
	if path.is_empty():
		path = route(found, frontier(w, found))
	if path.is_empty():
		path = route(found, exit(w))
		path.pop_back()
	return path[0] - w.player().pos if not path.is_empty() else Vector2i.ZERO


## Ids of the creatures of heaven Miho sees.
static func in_sight(w: World) -> Dictionary:
	var out := {}
	for a in w.actors:
		if a.alive() and a.faction != Actor.FOX and Hat.shown(w, a):
			out[a.id] = true
	return out


## Whether Miho sees an awake creature of heaven, so exploring does not start
## (DCSS): one blocking the only way on would turn the walk back and forth. One
## that cannot walk (a 장승) counts only while it hunts: it cannot come into her way.
static func watched(w: World) -> bool:
	return in_sight(w).keys().any(func(id): return _watching(w.actor(id)))


static func _watching(a: Actor) -> bool:
	var stands: bool = a.info().get("move", &"static") == &"static"
	return not a.asleep() and (a.alert == Actor.HUNT or not stands)


## Whether a walk must stop after a round from `before` to `after`: a creature
## of heaven came into sight that was not in sight when the walk began (ids in
## `sighted`), one Miho sees noticed her, she was hurt, heard a noise, picked
## up a talisman, found a plate in the floor, saw one go off, first saw a
## useful thing (Perceived.spotted), or the storey or the game ended.
static func interrupted(before: World, after: World, events: Array, sighted: Dictionary) -> bool:
	if after.depth != before.depth or after.outcome != &"" or not after.heard.is_empty():
		return true
	if not Perceived.spotted(before, after).is_empty():
		return true
	var me := after.player().id
	for e in events:
		match e.t:
			&"hurt":
				if e.id == me:
					return true
			&"card", &"find":
				return true
			&"notice", &"trap":
				var i := Grid.index(e.at)
				if before.seen[i] == 1 or after.seen[i] == 1:
					return true
	for id in in_sight(after):
		if not sighted.has(id):
			return true
	return false
