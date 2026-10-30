class_name Grid
extends RefCounted
## Board geometry: a 32x16 storey, eight directions, breadth-first paths.

const W := 32
const H := 16
const DIRS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, -1),
	Vector2i(1, 0),
	Vector2i(1, 1),
	Vector2i(0, 1),
	Vector2i(-1, 1),
	Vector2i(-1, 0),
	Vector2i(-1, -1),
]


static func inside(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < W and p.y < H


static func index(p: Vector2i) -> int:
	return p.y * W + p.x


static func at(i: int) -> Vector2i:
	return Vector2i(i % W, i / W)


static func cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## Unit direction from a toward b when b lies on one of a's eight lines, else zero.
static func line_dir(a: Vector2i, b: Vector2i) -> Vector2i:
	var d := b - a
	if d == Vector2i.ZERO:
		return Vector2i.ZERO
	if d.x == 0 or d.y == 0 or absi(d.x) == absi(d.y):
		return Vector2i(signi(d.x), signi(d.y))
	return Vector2i.ZERO


## The direction among the eight closest in angle to the offset d.
static func nearest_dir(d: Vector2i) -> Vector2i:
	if d == Vector2i.ZERO:
		return Vector2i.ZERO
	var best := DIRS[0]
	var best_dot := -INF
	var v := Vector2(d).normalized()
	for dir in DIRS:
		var dot := Vector2(dir).normalized().dot(v)
		if dot > best_dot + 0.0001:
			best_dot = dot
			best = dir
	return best


## Breadth-first search from `from`. `open(p)` says whether p may be entered;
## `stop(p)` marks reachable tiles that are not expanded further (targets).
## Returns {dist: PackedInt32Array, parent: PackedInt32Array}; unreached tiles have -1.
static func search(
	from: Vector2i, open: Callable, stop: Callable = func(_p): return false
) -> Dictionary:
	var dist := PackedInt32Array()
	dist.resize(W * H)
	dist.fill(-1)
	var parent := dist.duplicate()
	dist[index(from)] = 0
	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size():
		var p := queue[head]
		head += 1
		if p != from and stop.call(p):
			continue
		for d in DIRS:
			var q := p + d
			if inside(q) and dist[index(q)] < 0 and open.call(q):
				dist[index(q)] = dist[index(p)] + 1
				parent[index(q)] = index(p)
				queue.append(q)
	return {dist = dist, parent = parent}


## First step from the search origin toward `to`, following `parent` links.
static func first_step(found: Dictionary, from: Vector2i, to: Vector2i) -> Vector2i:
	var parent: PackedInt32Array = found.parent
	var i := index(to)
	while parent[i] >= 0 and parent[i] != index(from):
		i = parent[i]
	return at(i)
