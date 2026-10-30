class_name Sight
extends RefCounted
## Symmetric shadowcasting (Albert Ford, 2021). A floor tile is visible when a
## line from the centre of the origin reaches its centre; walls are visible
## when any part of them is. For floor tiles sight is symmetric: a creature
## sees Miho's tile exactly when Miho sees its tile. Light uses the same field.


## A mask with 1 for every tile visible from `origin` within `radius` (Euclidean).
static func field(origin: Vector2i, radius: int, opaque: Callable) -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(Grid.W * Grid.H)
	if not Grid.inside(origin):
		return seen
	seen[Grid.index(origin)] = 1
	for quadrant in 4:
		_scan(seen, origin, quadrant, 1, -1.0, 1.0, radius, opaque)
	return seen


static func _tile(origin: Vector2i, quadrant: int, depth: int, col: int) -> Vector2i:
	match quadrant:
		0:
			return origin + Vector2i(col, -depth)
		1:
			return origin + Vector2i(depth, col)
		2:
			return origin + Vector2i(col, depth)
	return origin + Vector2i(-depth, col)


static func _scan(
	seen: PackedByteArray,
	origin: Vector2i,
	quadrant: int,
	depth: int,
	start: float,
	end: float,
	radius: int,
	opaque: Callable
) -> void:
	if depth > radius:
		return
	var reach := (radius + 0.5) * (radius + 0.5)
	var prev := -1
	for col in range(floori(depth * start + 0.5), ceili(depth * end - 0.5) + 1):
		var p := _tile(origin, quadrant, depth, col)
		var wall: bool = not Grid.inside(p) or opaque.call(p)
		var symmetric := col >= depth * start and col <= depth * end
		if Grid.inside(p) and (wall or symmetric) and depth * depth + col * col <= reach:
			seen[Grid.index(p)] = 1
		var slope := (2.0 * col - 1.0) / (2.0 * depth)
		if prev == 1 and not wall:
			start = slope
		if prev == 0 and wall:
			_scan(seen, origin, quadrant, depth + 1, start, slope, radius, opaque)
		prev = 1 if wall else 0
	if prev == 0:
		_scan(seen, origin, quadrant, depth + 1, start, end, radius, opaque)
