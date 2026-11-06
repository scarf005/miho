class_name MirrorHall
extends RefCounted
## 좌우 대칭 전각: the west half of a building drawn and turned over onto the east (DCSS
## layout_cathedral_of_symmetry for the idea). A lit nave down its middle holds pillars and
## lanterns, with the exit behind a door at its end. A door between two rooms of the west
## wing that has wall where its other side should be has a hidden door there, so that the
## west teaches where the east hides them: the hidden doors are all in the east.

## How far a floor of the wing stands in from the map's edge (least, most), and how tall a
## floor is with one wall.
const STEP := Vector2i(1, 9)
const FLOOR_TALL := Vector2i(5, 9)
## Half of the nave's width, how deep the exit's room is (least, most), how far apart its
## pillars stand and its lanterns.
const NAVE := Vector2i(3, 4)
const GOAL_DEEP := Vector2i(4, 6)
const PILLAR_EVERY := 3
const LAMP_EVERY := 7


static func draw(w: World) -> Dictionary:
	var half := w.rng.randi_range(NAVE.x, NAVE.y)
	var wall := Grid.W / 2 - half - 1
	var top := w.rng.randi_range(1, 2)
	var bottom := Grid.H - 1 - w.rng.randi_range(1, 2)
	var deep := w.rng.randi_range(GOAL_DEEP.x, GOAL_DEEP.y)
	var north := w.rng.randf() < 0.5
	_wing(w, wall, top, bottom)
	var mid := Rect2i(wall + 1, top + 1, half, bottom - top - 1)
	var nave := Rect2i(mid.position.x, mid.position.y, half, mid.size.y - deep - 1)
	var goal := Rect2i(mid.position.x, mid.end.y - deep, half, deep)
	if north:
		goal.position.y = mid.position.y
		nave.position.y = goal.end.y + 1
	FloorGen._fill(w, Rect2i(wall, top, half + 1, bottom - top + 1), World.WALL)
	FloorGen._fill(w, nave, World.FLOOR)
	FloorGen._fill(w, goal, World.FLOOR)
	var plan := {spots = [], links = [], goal = Rect2i()}
	var left := FloorGen._doorways(w, [nave])
	_side_door(w, goal)
	FloorGen.shuffle(w.rng, left)
	var open := Masks.floor_of(w)
	var hidden := []
	for s: Array in left:
		if hidden.size() >= FloorGen.hidden_doors(w.depth):
			break
		var p: Vector2i = s[0]
		var d: Vector2i = s[1]
		var rooms := FloorGen.room_at(w, p - d).has_area() and FloorGen.room_at(w, p + d).has_area()
		if (
			rooms
			and FloorGen._walled(w, p, d)
			and Grid.distance(p - d, open, p + d) >= FloorGen.SHORTCUT
		):
			FloorGen._doorway(w, p)
			hidden.append(p)
	left = left.filter(func(s): return not hidden.has(s[0]))
	FloorGen._loops(w, left, [])
	_turn_over(w)
	for p: Vector2i in hidden:
		var east := _mirror(p)
		w.tiles[Grid.index(east)] = World.WALL
		w.secrets[east] = true
	var whole_goal := Rect2i(goal.position, Vector2i(half * 2, goal.size.y))
	var whole_nave := Rect2i(nave.position, Vector2i(half * 2, nave.size.y))
	_double_door(w, goal, nave, north)
	_dress(w, whole_nave)
	w.rooms.append(whole_goal)
	plan.goal = _ends(w, whole_goal)
	return plan


## The floors of the west wing, each its own distance from the map's edge, with their rooms.
static func _wing(w: World, wall: int, top: int, bottom: int) -> void:
	var none: Array[Rect2i] = []
	var y := top
	while y < bottom:
		var tall := w.rng.randi_range(FLOOR_TALL.x, FLOOR_TALL.y)
		if bottom - y - tall < FLOOR_TALL.x:
			tall = bottom - y
		var x := w.rng.randi_range(STEP.x, STEP.y)
		var r := Rect2i(x, y, wall - x + 1, tall + 1)
		FloorGen._fill(w, r, World.WALL)
		FloorGen._fill(w, r.grow(-1), World.FLOOR)
		FloorGen._split(w, r.grow(-1), none)
		y += tall


## A door from a room of the wing into the exit's room, on the wall between them.
static func _side_door(w: World, goal: Rect2i) -> void:
	for r: Rect2i in w.rooms:
		if Skeletons._door(w, r, goal):
			return


## Copies the west half over the east, its rooms too.
static func _turn_over(w: World) -> void:
	for y in Grid.H:
		for x in Grid.W / 2:
			w.tiles[Grid.index(_mirror(Vector2i(x, y)))] = w.tiles[Grid.index(Vector2i(x, y))]
	for r: Rect2i in w.rooms.duplicate():
		w.rooms.append(Rect2i(Grid.W - r.end.x, r.position.y, r.size.x, r.size.y))


static func _mirror(p: Vector2i) -> Vector2i:
	return Vector2i(Grid.W - 1 - p.x, p.y)


## A door of two tiles in the middle of the wall between `goal` and `nave`.
static func _double_door(w: World, goal: Rect2i, nave: Rect2i, north: bool) -> void:
	var y := goal.end.y if north else nave.end.y
	FloorGen._doorway(w, Vector2i(Grid.W / 2 - 1, y))
	w.tiles[Grid.index(Vector2i(Grid.W / 2, y))] = w.tiles[Grid.index(Vector2i(Grid.W / 2 - 1, y))]


## Pillars down both sides of the nave, a tile off its walls, and lanterns down its middle.
static func _dress(w: World, nave: Rect2i) -> void:
	var left := nave.position.x + 1
	var right := nave.end.x - 2
	for y in range(nave.position.y + 1, nave.end.y - 1, PILLAR_EVERY):
		w.tiles[Grid.index(Vector2i(left, y))] = World.PILLAR
		w.tiles[Grid.index(Vector2i(right, y))] = World.PILLAR
	for y in range(nave.position.y + 2, nave.end.y - 2, LAMP_EVERY):
		w.tiles[Grid.index(Vector2i(Grid.W / 2 - 1, y))] = World.LANTERN
		w.tiles[Grid.index(Vector2i(Grid.W / 2, y))] = World.LANTERN


## Makes a random room of the wings with two routes to `goal` the start, none with a hidden
## door on it; returns `goal`, or an empty rect when none has.
static func _ends(w: World, goal: Rect2i) -> Rect2i:
	var homes := w.rooms.filter(func(r): return r != goal)
	homes = homes.filter(
		func(r): return w.secrets.keys().all(func(p): return not r.grow(1).has_point(p))
	)
	FloorGen.shuffle(w.rng, homes)
	for home: Rect2i in homes.slice(0, Skeletons.ENDS_TRIED):
		if Skeletons.two_ways(w, home, goal):
			Skeletons._first(w, home)
			return goal
	return Rect2i()
