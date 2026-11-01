class_name Skeletons
extends RefCounted
## The skeletons a storey is built on: what its tiles and rooms look like before
## anything is laid in them (FloorGen). Every plan draws rooms on World.rooms, the
## start room first, and returns {spots, links, goal}: the wall tiles left that
## could still be doorways (FloorGen._doorways), the far links it cut, and the room
## that holds the exit (empty for the room farthest from the start). Halls are not
## on World.rooms, so nothing is laid in them and they stay walkable.
##
## 누각 (pavilions): pavilions in a row joined by bridges (FloorGen._pavilions).

const PAVILIONS := &"pavilions"
## What a storey may be built on; `pick` draws from it.
const ALL: Array[StringName] = [PAVILIONS]
## Tiles this near the start room and the exit room may lie on both routes (`two_ways`).
const NEAR_ENDS := 3


## The skeleton of the storey being built. A table of skeletons by storey replaces
## this draw once every skeleton exists.
static func pick(w: World) -> StringName:
	return ALL[w.rng.randi_range(0, ALL.size() - 1)]


## Draws a storey on `skeleton`.
static func draw(w: World, _skeleton: StringName) -> Dictionary:
	return FloorGen.pavilions(w)


## Whether the walk from the middle of `home` to the middle of `goal` has two routes
## that share no tile but near those rooms (NEAR_ENDS): no block of 3 by 3 tiles
## away from them cuts it. A block that cuts it stands on every route, so only
## those on the shortest one are tried.
static func two_ways(w: World, home: Rect2i, goal: Rect2i) -> bool:
	var open := Masks.floor_of(w, w.traps.keys(), func(_p): return false)
	var from := home.position + home.size / 2
	var to := Grid.index(goal.position + goal.size / 2)
	var found := Grid.search(from, open)
	if found.dist[to] < 0:
		return false
	var tried := {}
	var at: int = to
	while at >= 0:
		for d in Grid.DIRS + [Vector2i.ZERO]:
			var mid: Vector2i = Grid.at(at) + d
			if tried.has(mid) or home.grow(NEAR_ENDS).has_point(mid):
				continue
			if goal.grow(NEAR_ENDS).has_point(mid):
				continue
			tried[mid] = true
			if Grid.search(from, _without(open, mid)).dist[to] < 0:
				return false
		at = found.parent[at]
	return true


## `open` with the 3 by 3 tiles round `mid` shut.
static func _without(open: PackedByteArray, mid: Vector2i) -> PackedByteArray:
	var out := open.duplicate()
	for d in Grid.DIRS + [Vector2i.ZERO]:
		if Grid.inside(mid + d):
			out[Grid.index(mid + d)] = 0
	return out
