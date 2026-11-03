class_name PondGarden
extends RefCounted
## 연못 정원: a wide garden with hardly a wall in it and a frayed edge. Its ground is cut
## into plots with nothing between them, a few of them walled houses, and ponds, bamboo
## and reeds lie over it in clumps of cellular noise (DCSS caves); a clump that cuts the
## storey apart is taken up again. The plots are the rooms things are laid in. Only the
## houses have doors, which a treasure room or a yard needs.
##
## 대숲 (`grove`): the same garden with bamboo for its ponds, and more of it. `pools` lays
## noise as ponds in the rooms of another skeleton.

## How far the garden stands from the map's edges at most, and the deepest its edge
## frays.
const MARGIN := Vector2i(3, 2)
const FRAY := 4
## How many plots are walled houses (least, most), and the largest a house is.
const HOUSES := Vector2i(3, 5)
const HOUSE_MOST := 48
## The chance that a tile of the noise starts solid, and the times it is smoothed.
const NOISE := 0.43
const PASSES := 3
const CLUMPS: Array[int] = [World.POND, World.BAMBOO, World.REEDS]
## A grove's clumps, and how many times it lays them.
const GROVE: Array[int] = [World.BAMBOO, World.BAMBOO, World.REEDS]
const GROVE_LAYS := 2
## How many lone pillars stand in the garden (least, most).
const PILLARS := Vector2i(3, 7)


## The skeleton: the plots, houses and edge first, a doorway to each house, then what
## lies on the ground, then the start and the exit.
static func draw(w: World, clumps := CLUMPS, lays := 1) -> Dictionary:
	var west := w.rng.randi_range(1, MARGIN.x)
	var north := w.rng.randi_range(1, MARGIN.y)
	var wide := Grid.W - west - w.rng.randi_range(1, MARGIN.x)
	var tall := Grid.H - north - w.rng.randi_range(1, MARGIN.y)
	var area := Rect2i(west, north, wide, tall)
	var inside := area.grow(-1)
	FloorGen._fill(w, area, World.WALL)
	FloorGen._fill(w, inside, World.FLOOR)
	var none: Array[Rect2i] = []
	FloorGen._split(w, inside, none)
	var houses := _houses(w)
	_raze(w, inside, houses)
	_fray(w, area, houses)
	w.rooms = _clipped(w, houses)
	var plan := {spots = [], links = [], goal = Rect2i(), sealed = FloorGen._doorways(w, [])}
	for i in lays:
		_clumps(w, inside, houses, clumps)
	_pillars(w, inside, houses)
	plan.goal = Skeletons.far_ends(w)
	return plan


## The garden as a grove.
static func grove(w: World) -> Dictionary:
	return draw(w, GROVE, GROVE_LAYS)


## In each room, the noise over it becomes a pond with shallows round it, off the room's
## middle; one that cuts the storey apart is drained again.
static func pools(w: World) -> void:
	var none: Array[Rect2i] = []
	for r in w.rooms:
		var laid: Array[Vector2i] = []
		for p: Vector2i in _noise(w, r):
			if _lies(w, p, none):
				w.tiles[Grid.index(p)] = World.POND
				laid.append(p)
		if not FloorGen.connected(w):
			for p in laid:
				w.tiles[Grid.index(p)] = World.FLOOR
			continue
		for p in laid:
			for d in Placement.SIDES:
				if r.has_point(p + d) and w.tile(p + d) == World.FLOOR:
					w.tiles[Grid.index(p + d)] = World.SHALLOW


## Some of the rooms, none above HOUSE_MOST tiles, that keep their walls.
static func _houses(w: World) -> Array[Rect2i]:
	var small: Array = w.rooms.filter(func(r: Rect2i): return r.get_area() <= HOUSE_MOST)
	FloorGen.shuffle(w.rng, small)
	var out: Array[Rect2i] = []
	out.assign(small.slice(0, w.rng.randi_range(HOUSES.x, HOUSES.y)))
	return out


## Takes down every wall inside `inside` that is no wall of a house.
static func _raze(w: World, inside: Rect2i, houses: Array[Rect2i]) -> void:
	for y in range(inside.position.y, inside.end.y):
		for x in range(inside.position.x, inside.end.x):
			var p := Vector2i(x, y)
			if w.tile(p) == World.WALL and not houses.any(func(h): return h.grow(1).has_point(p)):
				w.tiles[Grid.index(p)] = World.FLOOR


## Eats `area` in from each edge by a depth that wanders along it, up to FRAY, round
## the houses; what is left of the ground gets a wall, and the rest is sky.
static func _fray(w: World, area: Rect2i, houses: Array[Rect2i]) -> void:
	var eaten := {}
	for edge: Array in [
		[area.position, Vector2i.RIGHT, Vector2i.DOWN, area.size.x],
		[area.position, Vector2i.DOWN, Vector2i.RIGHT, area.size.y],
		[area.end - Vector2i.ONE, Vector2i.LEFT, Vector2i.UP, area.size.x],
		[area.end - Vector2i.ONE, Vector2i.UP, Vector2i.LEFT, area.size.y],
	]:
		var deep := w.rng.randi_range(0, FRAY)
		for along in edge[3]:
			deep = clampi(deep + w.rng.randi_range(-1, 1), 0, FRAY)
			for k in deep:
				var p: Vector2i = edge[0] + edge[1] * along + edge[2] * k
				if not _by_house(houses, p):
					eaten[p] = true
	var inside := area.grow(-1)
	var walled := {}
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var p := Vector2i(x, y)
			if eaten.has(p) or not inside.has_point(p):
				walled[p] = _by_ground(w, p, inside, eaten)
	for p: Vector2i in walled:
		w.tiles[Grid.index(p)] = World.WALL if walled[p] else World.SKY


static func _by_house(houses: Array[Rect2i], p: Vector2i) -> bool:
	for h in houses:
		if h.grow(1).has_point(p):
			return true
	return false


## Whether a tile round `p` is floor inside `inside` and not `eaten`.
static func _by_ground(w: World, p: Vector2i, inside: Rect2i, eaten: Dictionary) -> bool:
	for d: Vector2i in Grid.DIRS:
		var q := p + d
		if inside.has_point(q) and not eaten.has(q) and w.tile(q) == World.FLOOR:
			return true
	return false


## The rooms cut back to what is still ground on all four sides; a plot too small then
## is gone.
static func _clipped(w: World, houses: Array[Rect2i]) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	for r in w.rooms:
		var plot: Rect2i = r if houses.has(r) else _clip(w, r)
		if mini(plot.size.x, plot.size.y) >= FloorGen.ROOM_LEAST:
			out.append(plot)
	return out


static func _clip(w: World, r: Rect2i) -> Rect2i:
	while r.has_area():
		var last := r.end - Vector2i.ONE
		if not _bare(w, r.position, Vector2i(last.x, r.position.y)):
			r = r.grow_individual(0, -1, 0, 0)
		elif not _bare(w, Vector2i(r.position.x, last.y), last):
			r = r.grow_individual(0, 0, 0, -1)
		elif not _bare(w, r.position, Vector2i(r.position.x, last.y)):
			r = r.grow_individual(-1, 0, 0, 0)
		elif not _bare(w, Vector2i(last.x, r.position.y), last):
			r = r.grow_individual(0, 0, -1, 0)
		else:
			break
	return r


## Whether the straight line from `a` to `b` is all floor.
static func _bare(w: World, a: Vector2i, b: Vector2i) -> bool:
	var d := (b - a).sign()
	var p := a
	while p != b:
		if w.tile(p) != World.FLOOR:
			return false
		p += d
	return w.tile(b) == World.FLOOR


## Whether something may lie on `p`: bare ground off the middle of its room, clear of
## the houses and the lane round them.
static func _lies(w: World, p: Vector2i, houses: Array[Rect2i]) -> bool:
	if w.tile(p) != World.FLOOR or houses.any(func(h): return h.grow(2).has_point(p)):
		return false
	var room := FloorGen.room_at(w, p)
	return not room.has_area() or Grid.cheb(p, FloorGen._centre(room)) > 1


## Cellular noise over `area`: {tile: true} for each solid one.
static func _noise(w: World, area: Rect2i) -> Dictionary:
	var solid := {}
	for i in Native.noise(area, NOISE, PASSES, w.rng, Grid.W):
		solid[Grid.at(i)] = true
	return solid


## Each clump of the noise over `inside` becomes one of the tile kinds `kinds`; one that
## cuts the storey apart is taken up again.
static func _clumps(w: World, inside: Rect2i, houses: Array[Rect2i], kinds: Array[int]) -> void:
	var solid := _noise(w, inside)
	while not solid.is_empty():
		var clump: Array[Vector2i] = [solid.keys()[0]]
		solid.erase(clump[0])
		for p in clump:
			for d in Placement.SIDES:
				if solid.has(p + d):
					solid.erase(p + d)
					clump.append(p + d)
		var kind: int = kinds[w.rng.randi_range(0, kinds.size() - 1)]
		var laid := clump.filter(func(p): return _lies(w, p, houses))
		for p: Vector2i in laid:
			w.tiles[Grid.index(p)] = kind
		if not FloorGen.connected(w):
			for p: Vector2i in laid:
				w.tiles[Grid.index(p)] = World.FLOOR


## Lone pillars on tiles of `inside` where something may lie, each leaving the storey
## whole.
static func _pillars(w: World, inside: Rect2i, houses: Array[Rect2i]) -> void:
	for i in w.rng.randi_range(PILLARS.x, PILLARS.y):
		var p := (
			inside.position
			+ Vector2i(
				w.rng.randi_range(0, inside.size.x - 1), w.rng.randi_range(0, inside.size.y - 1)
			)
		)
		if _lies(w, p, houses):
			w.tiles[Grid.index(p)] = World.PILLAR
			if not FloorGen.connected(w):
				w.tiles[Grid.index(p)] = World.FLOOR
