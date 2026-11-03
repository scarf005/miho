class_name Labyrinth
extends RefCounted
## 미궁: half a storey is a maze with walls of 기둥, which nothing breaks, so that no hit cuts a
## way to its prize; the other half is ordinary rooms with the exit. A bridge over the sky joins
## them, to a door that may be hidden. A talisman and peaches lie deep inside, far along the
## walk and never at a middle that can be guessed, and creatures of heaven patrol it.
##
## The maze comes in six kinds, each asking something else of the player:
## ORTHODOX, a perfect maze in the dark: remember the way, leave the dead ends. Tread patches
##   and jars at its ends are the noise and the small finds of a long walk.
## ISLAND, a maze round a lit island in a walled sky, over rotten boards that fall behind Miho.
##   She leaves by a pit down a storey (DCSS Gauntlet's one way and the ceiling exit of its old
##   labyrinth; Brogue "Collapsing floor area").
## CIRCUIT, a maze with no dead end (Brogue addLoops), lit in spots: keep clear of the patrols.
## BAMBOO, corridors of 대숲: nothing is seen but the next tile, no scent lies, every step is
##   heard, and a fire runs the corridors like a fuse.
## PLATES, galleries three tiles wide full of hidden plates, mostly pits, with always a way
##   round them (Brogue "Pit traps"): a hunter that goes over them falls.
## CELLS, chambers behind doors (DCSS gauntlet arena chambers): each door is a noise and a
##   blind corner.

const ORTHODOX := &"orthodox"
const ISLAND := &"island"
const CIRCUIT := &"circuit"
const BAMBOO := &"bamboo"
const PLATES := &"plates"
const CELLS := &"cells"
const CONCEPTS: Array[StringName] = [ORTHODOX, ISLAND, CIRCUIT, BAMBOO, PLATES, CELLS]
## The site of the talisman inside: it gives what a yard's stand gives (Yard.arrive).
const PRIZE := &"maze_prize"
## How wide the maze may be and how tall it is: a cell and its wall `step` tiles, with one wall
## more.
const WIDE: Array[int] = [21, 25, 29]
const TALL: Array[int] = [21, 25]
## The sky between the maze and the rooms (least, most).
const GAP := Vector2i(3, 5)
## A room of the rooms' half that fits in this may stay whole: half a storey needs small ones.
const ROOM_MOST := Vector2i(9, 6)
## The share of a maze's dead ends with a jar, of its links that are doors in CIRCUIT, of its
## wall corners that are lamps in CIRCUIT; of its cells that open one more link in BAMBOO and
## CELLS; of its gallery tiles with a plate in PLATES, and what share of those are not pits.
const JARS := 0.45
const CIRCUIT_DOORS := 0.12
const CIRCUIT_LAMPS := 0.08
const LOOPS := 0.15
const PLATE_SHARE := 0.2
const NOT_PITS := 0.3
## How many patches of noisy floor an ORTHODOX maze has, and the floors they are of.
const PATCHES := 7
const PATCH_FLOORS: Array[int] = [World.LEAVES, World.SHALLOW, World.STRAW]
## The share of CELLS' chambers with a pillar and the chance of a door standing open there.
const CHAMBER_PILLARS := 0.25
const OPEN_DOORS := 0.25
## ISLAND: how many cells wide its walled sky is, how far from the sky's wall its floor stands,
## and how far apart the windows in that wall are.
const BLOCK := 7
const ISLAND_IN := 3
const WINDOW_EVERY := 3
## How many peaches lie in a maze and how many creatures live in it (least, most), and how many
## steps from the door they start, at least.
const PEACHES := Vector2i(2, 3)
const GUARDS := Vector2i(2, 3)
const GUARD_FAR := 8
## Who patrols a maze, by the last storey it does so on; deeper, the last of them.
const GUARD_KINDS := [[4, &"bitjaru"], [6, &"dueoksini"], [World.FLOORS, &"eodeopsini"]]


static func draw(w: World) -> Dictionary:
	var concept: StringName = RunPlan.labyrinth(w.rng.seed).concept
	var wide: int = WIDE[w.rng.randi_range(0, WIDE.size() - 1)]
	var gap := w.rng.randi_range(GAP.x, GAP.y)
	var on_west := w.rng.randf() < 0.5
	var tall: int = TALL[w.rng.randi_range(0, TALL.size() - 1)]
	var top := w.rng.randi_range(1, Grid.H - 1 - tall)
	var area := Rect2i(1 if on_west else Grid.W - 1 - wide, top, wide, tall)
	var hall_x := area.end.x + gap if on_west else 1
	var hall_end := Grid.W - 1 if on_west else area.position.x - gap
	var hall := Rect2i(hall_x, 1, hall_end - hall_x, Grid.H - 2)
	FloorGen._fill(w, area, World.PILLAR)
	var maze := _maze(w, area, concept)
	var galleries: Array[Rect2i] = []
	FloorGen._fill(w, hall, World.WALL)
	FloorGen._fill(w, hall.grow(-1), World.FLOOR)
	FloorGen._split(w, hall.grow(-1), galleries, w.rng.randf() < FloorGen.GALLERIES, ROOM_MOST)
	var plan := {spots = [], links = [], goal = Rect2i(), maze = maze}
	plan.sealed = FloorGen._loops(w, FloorGen._doorways(w, galleries), plan.links)
	var home: Rect2i = w.rooms[w.rng.randi_range(0, w.rooms.size() - 1)]
	Skeletons._first(w, home)
	plan.goal = FloorGen._farthest(w, FloorGen._centre(home))
	var door := _door(w, area, hall, on_west)
	w.sites.append({kind = &"labyrinth", at = door, area = area, island = maze.island})
	maze.door = door
	return plan


## The site of a maze on the storey, or an empty one.
static func site(w: World) -> Dictionary:
	for s: Dictionary in w.sites:
		if s.kind == &"labyrinth":
			return s
	return {}


# --- the door ----------------------------------------------------------------


## A bridge from the rooms to a row of the maze with floor behind the wall on both sides, a
## door in the maze's wall at its end, hidden at the chance of a coin, and the door tile.
static func _door(w: World, area: Rect2i, hall: Rect2i, on_west: bool) -> Vector2i:
	var west := area if on_west else hall
	var east := hall if on_west else area
	var rows := []
	for y in range(area.position.y + 1, area.end.y - 1):
		var a := Vector2i(west.end.x - 2, y)
		var b := Vector2i(east.position.x + 1, y)
		var hall_in := b if on_west else a
		var maze_in := a if on_west else b
		if Tiles.walk[w.tile(maze_in)] == 1 and w.tile(hall_in) == World.FLOOR:
			rows.append(y)
	if rows.is_empty():
		return Vector2i(-1, -1)
	var y: int = rows[w.rng.randi_range(0, rows.size() - 1)]
	FloorGen._bridge(w, west, east, y)
	var door := Vector2i(west.end.x - 1 if on_west else east.position.x, y)
	var mouth := Vector2i(east.position.x if on_west else west.end.x - 1, y)
	FloorGen._doorway(w, mouth)
	FloorGen._doorway(w, door)
	if w.rng.randf() < 0.5:
		w.tiles[Grid.index(door)] = World.WALL
		w.secrets[door] = true
	return door


# --- the mazes ---------------------------------------------------------------


## Carves the maze of `concept` in `area`: {concept, area, step, links, island, door}, its links
## between cells by Winding._dig, the rect of its island or an empty one, and its door, for
## `draw` to fill in.
static func _maze(w: World, area: Rect2i, concept: StringName) -> Dictionary:
	var step := 4 if concept == PLATES or concept == CELLS else 2
	var cells := Vector2i((area.size.x - 1) / step, (area.size.y - 1) / step)
	var free := {}
	for y in cells.y:
		for x in cells.x:
			free[Vector2i(x, y)] = true
	var block := Rect2i()
	if concept == ISLAND:
		block = _block_of(w.rng, cells)
		for y in range(block.position.y, block.end.y):
			for x in range(block.position.x, block.end.x):
				free.erase(Vector2i(x, y))
	var cell_list := free.keys()
	var from: Vector2i = cell_list[w.rng.randi_range(0, cell_list.size() - 1)]
	var links := Winding._dig(w.rng, from, free)
	var m := {
		concept = concept,
		area = area,
		step = step,
		links = links,
		island = Rect2i(),
		door = Vector2i(-1, -1),
	}
	match concept:
		CIRCUIT:
			_braid(w.rng, links)
		BAMBOO, CELLS:
			_loops(w.rng, links)
	for c: Vector2i in links:
		FloorGen._fill(w, _tiles_of(m, c), World.FLOOR)
		if concept != CELLS:
			for n: Vector2i in links[c]:
				FloorGen._fill(w, _tiles_of(m, c).merge(_tiles_of(m, n)), World.FLOOR)
	match concept:
		ORTHODOX:
			_patches(w, m)
			_jars(w, m)
		ISLAND:
			_island(w, m, block)
		CIRCUIT:
			_circuit(w, m)
		BAMBOO:
			_bamboo(w, area)
		CELLS:
			_chambers(w, m)
	return m


## The tiles of cell `c`, without walls.
static func _tiles_of(m: Dictionary, c: Vector2i) -> Rect2i:
	return Rect2i(m.area.position + Vector2i.ONE + c * m.step, Vector2i.ONE * (m.step - 1))


## The tile in the middle of cell `c`.
static func _mid(m: Dictionary, c: Vector2i) -> Vector2i:
	return m.area.position + Vector2i.ONE + c * m.step + Vector2i.ONE * (m.step - 2) / 2


## The cells that join only one other.
static func _dead_ends(links: Dictionary) -> Array:
	return links.keys().filter(func(c): return links[c].size() == 1)


## Links each cell in LOOPS of them to one more neighbour, when it has one.
static func _loops(rng: RandomNumberGenerator, links: Dictionary) -> void:
	for c: Vector2i in links:
		if rng.randf() < LOOPS:
			_link_more(rng, links, c)


## Links every dead end to one more neighbour: no way ends.
static func _braid(rng: RandomNumberGenerator, links: Dictionary) -> void:
	for c: Vector2i in _dead_ends(links):
		if links[c].size() == 1:
			_link_more(rng, links, c)


static func _link_more(rng: RandomNumberGenerator, links: Dictionary, c: Vector2i) -> void:
	var more: Array = (
		Placement
		. SIDES
		. map(func(d): return c + d)
		. filter(func(n): return links.has(n) and not links[c].has(n))
	)
	if not more.is_empty():
		var n: Vector2i = more[rng.randi_range(0, more.size() - 1)]
		links[c].append(n)
		links[n].append(c)


## ORTHODOX: patches of noisy floor down the corridors, each of a few cells.
static func _patches(w: World, m: Dictionary) -> void:
	var cells: Array = m.links.keys()
	FloorGen.shuffle(w.rng, cells)
	for c: Vector2i in cells.slice(0, PATCHES):
		var floor_kind: int = PATCH_FLOORS[w.rng.randi_range(0, PATCH_FLOORS.size() - 1)]
		w.tiles[Grid.index(_mid(m, c))] = floor_kind
		for n: Vector2i in m.links[c]:
			w.tiles[Grid.index((_mid(m, c) + _mid(m, n)) / 2)] = floor_kind
			w.tiles[Grid.index(_mid(m, n))] = floor_kind


## ORTHODOX: a jar at JARS of the dead ends.
static func _jars(w: World, m: Dictionary) -> void:
	for c: Vector2i in _dead_ends(m.links):
		if w.rng.randf() < JARS:
			w.tiles[Grid.index(_mid(m, c))] = World.JAR


## ISLAND: inside the block of cells, a wall with windows round a sky round the island, a door
## through the wall on a side with a corridor beyond it, and rotten boards over the sky to it.
static func _island(w: World, m: Dictionary, block: Rect2i) -> void:
	var at: Vector2i = m.area.position + block.position * m.step
	var outer := Rect2i(at, block.size * m.step + Vector2i.ONE)
	var ring := outer.grow(-1)
	FloorGen._fill(w, ring, World.WALL)
	FloorGen._fill(w, ring.grow(-1), World.SKY)
	var land := ring.grow(-ISLAND_IN)
	FloorGen._fill(w, land, World.FLOOR)
	m.island = land
	_windows(w, ring)
	var lamps := [
		land.position + Vector2i(land.size.x - 1, 0), land.position + Vector2i(0, land.size.y - 1)
	]
	for p: Vector2i in lamps:
		w.tiles[Grid.index(p)] = World.LAMP
	var ways := _island_ways(w, outer, land)
	var way: Array = ways[w.rng.randi_range(0, ways.size() - 1)]
	var mouth: Vector2i = way[0]
	var side: Vector2i = way[1]
	w.tiles[Grid.index(mouth)] = World.FLOOR
	FloorGen._doorway(w, mouth - side)
	var p := mouth - side * 2
	while not land.has_point(p):
		w.tiles[Grid.index(p)] = World.BOARD_ROTTEN
		p -= side


## The ways in: [tile of the block's `outer` wall, way out], each in line with the floor of
## `land`, off its corners, with floor beyond.
static func _island_ways(w: World, outer: Rect2i, land: Rect2i) -> Array:
	var out := []
	for x in range(land.position.x + 1, land.end.x - 1):
		out.append([Vector2i(x, outer.position.y), Vector2i.UP])
		out.append([Vector2i(x, outer.end.y - 1), Vector2i.DOWN])
	for y in range(land.position.y + 1, land.end.y - 1):
		out.append([Vector2i(outer.position.x, y), Vector2i.LEFT])
		out.append([Vector2i(outer.end.x - 1, y), Vector2i.RIGHT])
	return out.filter(func(s): return w.tile(s[0] + s[1]) == World.FLOOR)


## Every WINDOW_EVERY-th tile round `ring` is a window.
static func _windows(w: World, ring: Rect2i) -> void:
	for k in range(1, ring.size.x - 1, WINDOW_EVERY):
		w.tiles[Grid.index(ring.position + Vector2i(k, 0))] = World.WINDOW
		w.tiles[Grid.index(ring.position + Vector2i(k, ring.size.y - 1))] = World.WINDOW
	for k in range(1, ring.size.y - 1, WINDOW_EVERY):
		w.tiles[Grid.index(ring.position + Vector2i(0, k))] = World.WINDOW
		w.tiles[Grid.index(ring.position + Vector2i(ring.size.x - 1, k))] = World.WINDOW


## Where the block of ISLAND stands: never in the middle of the cells.
static func _block_of(rng: RandomNumberGenerator, cells: Vector2i) -> Rect2i:
	var x := rng.randi_range(0, 1)
	var y := rng.randi_range(0, 1)
	return Rect2i(
		x if rng.randf() < 0.5 else cells.x - BLOCK - x,
		y if rng.randf() < 0.5 else cells.y - BLOCK - y,
		BLOCK,
		BLOCK
	)


## CIRCUIT: lamps for some of the wall's corners, doors on some of the links.
static func _circuit(w: World, m: Dictionary) -> void:
	var area: Rect2i = m.area
	for y in range(area.position.y + 2, area.end.y - 1, m.step):
		for x in range(area.position.x + 2, area.end.x - 1, m.step):
			if w.tile(Vector2i(x, y)) == World.PILLAR and w.rng.randf() < CIRCUIT_LAMPS:
				w.tiles[Grid.index(Vector2i(x, y))] = World.LAMP
	for c: Vector2i in m.links:
		for n: Vector2i in m.links[c]:
			if c < n and w.rng.randf() < CIRCUIT_DOORS:
				w.tiles[Grid.index((_mid(m, c) + _mid(m, n)) / 2)] = World.DOOR


## BAMBOO: every floor of `area` grows bamboo.
static func _bamboo(w: World, area: Rect2i) -> void:
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if w.tile(Vector2i(x, y)) == World.FLOOR:
				w.tiles[Grid.index(Vector2i(x, y))] = World.BAMBOO


## CELLS: a door on every link, a pillar in the middle of some chambers.
static func _chambers(w: World, m: Dictionary) -> void:
	for c: Vector2i in m.links:
		for n: Vector2i in m.links[c]:
			var tile := World.DOOR_OPEN if w.rng.randf() < OPEN_DOORS else World.DOOR
			if c < n:
				w.tiles[Grid.index((_mid(m, c) + _mid(m, n)) / 2)] = tile
		if m.links[c].size() > 1 and w.rng.randf() < CHAMBER_PILLARS:
			w.tiles[Grid.index(_mid(m, c))] = World.PILLAR


# --- what lies in it ---------------------------------------------------------


## Lays the talisman and the peaches of `plan`'s maze, and its plates.
static func furnish(w: World, plan: Dictionary) -> void:
	var m: Dictionary = plan.maze
	var spots: Array = _spots(w, m)
	var ends := 0 if m.concept == ISLAND else _dead_ends(m.links).size()
	var prizes: Array = spots.slice(0, maxi((ends if ends > 0 else spots.size()) / 4, 1))
	var prize: Vector2i = prizes[w.rng.randi_range(0, prizes.size() - 1)]
	spots.erase(prize)
	var card: StringName = Cards.ELEMENTS[w.rng.randi_range(0, Cards.ELEMENTS.size() - 1)]
	w.tiles[Grid.index(prize)] = World.TALISMAN
	w.sites.append({kind = PRIZE, at = prize, card = card})
	var rest: Array = spots.slice(0, maxi(spots.size() / 2, 1))
	FloorGen.shuffle(w.rng, rest)
	for p: Vector2i in rest.slice(0, w.rng.randi_range(PEACHES.x, PEACHES.y)):
		w.tiles[Grid.index(p)] = World.FLOOR
		w.peaches.append(p)
	if m.concept == ISLAND:
		_pits(w, m.island)
	elif m.concept == PLATES:
		_plates(w, m)
	w._changed()


## The tiles a prize may lie on: the island's in a random order, or the middle of each dead end
## and then of each other cell, each farthest along the walk from the door first.
static func _spots(w: World, m: Dictionary) -> Array:
	var out := []
	if m.concept == ISLAND:
		var land: Rect2i = m.island
		for y in range(land.position.y + 1, land.end.y - 1):
			for x in range(land.position.x + 1, land.end.x - 1):
				out.append(Vector2i(x, y))
		FloorGen.shuffle(w.rng, out)
		return out
	var ends := _dead_ends(m.links)
	var others: Array = m.links.keys().filter(func(c): return not ends.has(c))
	var dist := _walk_from_door(w, m)
	for cells: Array in [ends, others]:
		var tiles: Array = cells.map(func(c): return _mid(m, c))
		FloorGen.shuffle(w.rng, tiles)
		tiles.sort_custom(func(a, b): return dist[Grid.index(a)] > dist[Grid.index(b)])
		out.append_array(tiles)
	return out


## How many steps every tile lies from the door.
static func _walk_from_door(w: World, m: Dictionary) -> PackedInt32Array:
	return Grid.search(m.door, _walls_open(w, m)).dist


## The walkable tiles with the maze's door among them, and its jars.
static func _walls_open(w: World, m: Dictionary) -> PackedByteArray:
	var open := Masks.opened(w)
	open[Grid.index(m.door)] = 1
	var i := w.tiles.find(World.JAR)
	while i >= 0:
		open[i] = 1
		i = w.tiles.find(World.JAR, i + 1)
	return open


## ISLAND: the two pits at the corners of its floor the lamps do not stand on.
static func _pits(w: World, land: Rect2i) -> void:
	w.traps[land.position] = World.TRAP_COLLAPSE
	w.traps[land.end - Vector2i.ONE] = World.TRAP_COLLAPSE


## PLATES: hidden plates on PLATE_SHARE of the gallery's tiles, none that would cut anything off
## from the door.
static func _plates(w: World, m: Dictionary) -> void:
	var tiles := []
	var area: Rect2i = m.area
	for y in range(area.position.y + 1, area.end.y - 1):
		for x in range(area.position.x + 1, area.end.x - 1):
			if w.tile(Vector2i(x, y)) == World.FLOOR:
				tiles.append(Vector2i(x, y))
	FloorGen.shuffle(w.rng, tiles)
	var open := _walls_open(w, m)
	var side := Vector2i.LEFT if m.door.x == area.position.x else Vector2i.RIGHT
	for p: Vector2i in tiles.slice(0, int(tiles.size() * PLATE_SHARE)):
		var i := Grid.index(p)
		if p == m.door - side or w.peaches.has(p):
			continue
		open[i] = 0
		if Native.whole(m.door, open, Grid.W):
			w.traps[p] = _plate_kind(w.rng)
		else:
			open[i] = 1


static func _plate_kind(rng: RandomNumberGenerator) -> int:
	if rng.randf() >= NOT_PITS:
		return World.TRAP_COLLAPSE
	return World.TRAP_ALARM if rng.randf() < 0.5 else World.TRAP_VINE


## The creatures of the maze: two or three of the storey's kind, far along the walk from the door.
static func settle(w: World, plan: Dictionary) -> void:
	var m: Dictionary = plan.maze
	var kind: StringName = GUARD_KINDS[-1][1]
	for row: Array in GUARD_KINDS:
		if w.depth <= row[0]:
			kind = row[1]
			break
	var dist := _walk_from_door(w, m)
	var open := _free_tiles(w, m).filter(func(p): return dist[Grid.index(p)] >= GUARD_FAR)
	FloorGen.shuffle(w.rng, open)
	for p: Vector2i in open.slice(0, w.rng.randi_range(GUARDS.x, GUARDS.y)):
		FloorGen._arrive(w, kind, p)


## Where a patrol of the maze heads next: a random floor tile off its island.
static func patrol_point(w: World, s: Dictionary) -> Vector2i:
	var tiles := _free_tiles(w, s)
	return tiles[w.rng.randi_range(0, tiles.size() - 1)] if not tiles.is_empty() else s.at


## The tiles of a maze (a site or a plan's maze) a creature may stand on and walk to, off its
## island.
static func _free_tiles(w: World, m: Dictionary) -> Array:
	var out := []
	var area: Rect2i = m.area
	for y in range(area.position.y + 1, area.end.y - 1):
		for x in range(area.position.x + 1, area.end.x - 1):
			var p := Vector2i(x, y)
			var away: bool = not m.island.has_area() or not m.island.grow(ISLAND_IN).has_point(p)
			var clear := not w.traps.has(p) and not w.peaches.has(p) and w.tile(p) != World.TALISMAN
			if away and clear and w.vacant(p):
				out.append(p)
	return out
