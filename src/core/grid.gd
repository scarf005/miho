class_name Grid
extends RefCounted
## Board geometry: a 56x28 storey, eight directions, breadth-first paths.

const W := 56
const H := 28
## The radius of the 3x3 square a tile makes with its eight DIRS.
const NEAR := 1
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


## `p` moved `n` steps along direction `d`, kept on the board.
static func nudge(p: Vector2i, d: Vector2i, n := 1) -> Vector2i:
	return (p + d * n).clamp(Vector2i.ZERO, Vector2i(W - 1, H - 1))


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


## Breadth-first search from `from` (in Rust, rust/src/lib.rs). `open` holds 1
## for every tile that may be entered (see `mask`); a `limit` of 0 or more
## leaves tiles farther than that unreached.
## Returns {dist: PackedInt32Array, parent: PackedInt32Array}; unreached tiles have -1.
static func search(from: Vector2i, open: PackedByteArray, limit := -1) -> Dictionary:
	return Native.search(from, open, limit, W)


## `search(from, open).dist` at `to`, found without searching the rest of the board.
static func distance(from: Vector2i, open: PackedByteArray, to: Vector2i) -> int:
	return Native.distance(from, open, to, W)


## A mask of the board, one byte per tile: 1 where `test(p)` holds. Away from
## the tiles in `odd` the test must depend on the tile kind alone, as `table`
## gives it (1 at index t for kind t); at `odd` tiles `test` itself decides.
static func mask(
	tiles: PackedByteArray, table: PackedByteArray, odd: Array = [], test := Callable()
) -> PackedByteArray:
	var out := Native.mask(tiles, table)
	for p: Vector2i in odd:
		if inside(p):
			out[index(p)] = 1 if test.call(p) else 0
	return out


## A table for `mask`: 1 for every tile kind t where `kind(t)` holds.
static func table(kind: Callable) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(256)
	for t in out.size():
		out[t] = 1 if kind.call(t) else 0
	return out


## First step from the search origin toward `to`, following `parent` links.
static func first_step(found: Dictionary, from: Vector2i, to: Vector2i) -> Vector2i:
	var parent: PackedInt32Array = found.parent
	var i := index(to)
	while parent[i] >= 0 and parent[i] != index(from):
		i = parent[i]
	return at(i)
