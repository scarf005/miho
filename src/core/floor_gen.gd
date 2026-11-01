class_name FloorGen
extends RefCounted
## Builds each storey on a skeleton (Skeletons). One is two to four pavilions in open
## sky, joined by skybridges, with windows in their outer walls. Pavilions that stand
## close get ledges of 마루 on their facing walls, a few tiles of sky apart, for a leap. A
## pavilion is a floor plan: its inside is cut into rooms by walls one tile
## thick (binary space partition), and one cut of a wide pavilion may be a
## gallery, a hall one tile wide between two walls.
## Doorways in those walls join every room, with a few extra loops where the walk
## round is long; some hold sliding doors (some start open).
## A few walls between rooms far apart are hidden doors (Traps). On some
## storeys one room is an event room, such as a treasure room behind a wall
## that three dark lanterns in front of it bring down (EventRooms). Lanterns
## light some rooms. Some other rooms get a bamboo patch, a pond, or
## floorboards (a pavilion hall).
## Patches of grass, leaves, straw, reeds, shallow water and pillars lie in rooms
## by storey (Placement).
## From storey 2 a lit room may hold a war drum. Galleries stay plain and dark.
## One room may then be made a set room (SetRooms).
## Miho starts in the skeleton's first room (on pavilions, the westmost); the stairs
## (the elixir on the top storey) sit in the room its plan names or the one farthest
## from her, which is always lit. Watchers that never
## move stand by lanterns. The creatures that walk come in bands (`bands`): those
## of one group stand together in one room, and follow the strongest of them.

## The creatures of each storey; a boss only comes to the last storey.
const PLAN := {
	1: [&"dokkaebi", &"dokkaebi", &"dokkaebi", &"dokkaebi", &"jangseung", &"jangseung"],
	2:
	[
		&"bulgae",
		&"oedari",
		&"dokkaebi",
		&"dokkaebi",
		&"dokkaebi",
		&"dokkaebi",
		&"jangseung",
		&"jangseung",
	],
	3:
	[
		&"haetae",
		&"imugi",
		&"imugi",
		&"oedari",
		&"bujigaengi",
		&"dokkaebi",
		&"jangseung",
		&"jangseung",
	],
	4:
	[
		&"cheonha",
		&"jiha",
		&"bitjaru",
		&"bujigaengi",
		&"dokkaebi",
		&"dokkaebi",
		&"imugi",
		&"imugi",
		&"imugi",
		&"imugi",
	],
	5:
	[
		&"imugi",
		&"imugi",
		&"imugi",
		&"imugi",
		&"oedari",
		&"bitjaru",
		&"dokkaebi",
		&"gamtu",
		&"jangseung",
		&"jangseung",
	],
	6:
	[
		&"bulgasari",
		&"oedari",
		&"bujigaengi",
		&"bitjaru",
		&"dokkaebi",
		&"gamtu",
		&"imugi",
		&"imugi",
		&"jangseung",
		&"jangseung",
	],
	7:
	[
		&"oedari",
		&"oedari",
		&"bujigaengi",
		&"bitjaru",
		&"dokkaebi",
		&"gamtu",
		&"imugi",
		&"imugi",
		&"imugi",
		&"imugi",
		&"jangseung",
		&"jangseung",
	],
	8:
	[
		&"haetae",
		&"haetae",
		&"oedari",
		&"bitjaru",
		&"dokkaebi",
		&"gamtu",
		&"imugi",
		&"imugi",
		&"jangseung",
		&"jangseung",
		&"jangseung",
		&"jangseung",
	],
	9:
	[
		&"cheonnyeon",
		&"haetae",
		&"haetae",
		&"haetae",
		&"oedari",
		&"bujigaengi",
		&"dokkaebi",
		&"imugi",
	],
}
## Peaches grow on every odd storey from the third.
const FIRST_PEACH_FLOOR := 3
const MIN_ROOMS := 9
## How many times a storey starts over when what is laid in it spoils it.
const BUILDS := 20
## A room is at least ROOM_LEAST tiles across; one that fits in ROOM_MOST stays
## whole at the chance WHOLE, and is cut again otherwise.
const ROOM_LEAST := 3
const ROOM_MOST := Vector2i(12, 8)
const WHOLE := 0.4
## The chance that a pavilion's first cut is a gallery.
const GALLERIES := 0.6
## The most doorways opened beyond those that join every room, and the least walk
## between the two sides of one, or of a bridge beyond the first of a pair; the share
## of doorways that hold a sliding door.
const LOOPS := 6
const APART := 14
const DOORS := 0.6
## A hidden door joins two rooms at least this many steps apart without it.
const SHORTCUT := 10
const LIT_ROOMS := 0.45
const FOE_DISTANCE := 12
## The most creatures in a band, and how far from its leader a follower stands
## and keeps.
const BAND := 3
const BAND_SPREAD := 2
## Nothing is placed within this many tiles of the start, even through a wall.
const START_CLEAR := 3
const BAMBOO_ROOMS := 0.25
const POND_ROOMS := 0.2
const HALL_ROOMS := 0.15
## Gap between pavilions in tiles (min, max); least width of a pavilion; least height.
const SKY_GAP := Vector2i(3, 6)
## The sky between two facing ledges (min, max), and a ledge's length.
const LEAP := Vector2i(2, 3)
const LEDGE_LENGTH := Vector2i(3, 6)
const MIN_WIDTH := 9
const MIN_HEIGHT := 14
## First and last row a bridge may cross on; every pavilion spans them.
const BRIDGE_ROWS := Vector2i(10, 17)
const WINDOWS := 0.35
## The share of doors that start open.
const OPEN_DOORS := 0.3


## Builds the storey on `skeleton` (Skeletons.pick when none is given); returns the
## set room it made, {kind, room}, or {} (SetRooms.build). A storey that what is laid
## in its rooms has spoiled (`_sound`) starts over.
static func build(w: World, skeleton := &"") -> Dictionary:
	if skeleton == &"":
		skeleton = Skeletons.pick(w)
	var set_room := {}
	for attempt in BUILDS:
		set_room = _build(w, skeleton)
		if _sound(w, skeleton):
			break
	return set_room


## Whether no plate shuts a tile in, the exit can be walked to with nothing to break
## or put out on the way, the start is dark and the exit lit, and a skeleton that has
## two routes still has them.
static func _sound(w: World, skeleton: StringName) -> bool:
	w._changed()
	var exit := w.elixir if w.depth >= World.FLOORS else w.stairs
	var open := Masks.floor_of(w, w.traps.keys(), func(_p): return false)
	return (
		connected(w, w.traps.keys())
		and Grid.search(w.start, open).dist[Grid.index(exit)] >= 0
		and not w.lit(w.start)
		and w.lit(exit)
		and (skeleton == Skeletons.PAVILIONS or Skeletons.two_ways(w, w.rooms[0], room_at(w, exit)))
	)


static func _build(w: World, skeleton: StringName) -> Dictionary:
	var me := w.player()
	w.actors.assign([me])
	w.shots.clear()
	w.peaches.clear()
	w.burning.clear()
	w.hot.clear()
	w.gas.clear()
	w.vents.clear()
	w.traps.clear()
	w.changes.clear()
	w.bodies.clear()
	w.round_no = 0
	w.known = PackedByteArray()
	w.seen = PackedByteArray()
	w.dim = PackedByteArray()
	me.rooted = 0
	me.stunned = 0
	me.blind = 0
	var goal := Rect2i()
	for attempt in 100:
		goal = _carve(w, skeleton).goal
		if (
			w.rooms.size() >= MIN_ROOMS
			and w.secrets.size() == hidden_doors(w.depth)
			and connected(w)
			and (not goal.has_area() or Skeletons.two_ways(w, w.rooms[0], goal))
		):
			break
	w._changed()
	var home := w.rooms[0]
	w.start = _centre(home)
	me.pos = w.start
	w.rooms.erase(goal)
	EventRooms.build(w, home)
	if goal.has_area():
		w.rooms.append(goal)
	else:
		goal = _farthest(w, w.start)
	w.elixir = Vector2i(-1, -1)
	w.stairs = Vector2i(-1, -1)
	if w.depth >= World.FLOORS:
		w.elixir = _centre(goal)
	else:
		w.stairs = _centre(goal)
	_lanterns(w, home, goal)
	_features(w, goal)
	Placement.scatter(w, goal)
	_drum(w)
	var set_room := SetRooms.build(w, home, goal)
	_creatures(w)
	if w.depth >= FIRST_PEACH_FLOOR and w.depth % 2 == 1:
		var spot := _random_spot(w, 6)
		if spot.x >= 0:
			w.peaches.append(spot)
	return set_room


static func _centre(r: Rect2i) -> Vector2i:
	return r.position + r.size / 2


## Clears the storey and draws it on `skeleton`, with its far doorways, hidden doors
## and windows; returns the plan (Skeletons.draw) with every link it cut in `links`,
## in order, each {at, a, b}: the tile that makes the link, and the tiles it joins.
static func _carve(w: World, skeleton: StringName) -> Dictionary:
	w.tiles = PackedByteArray()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.SKY)
	w.rooms.clear()
	w.secrets.clear()
	w.seals.clear()
	w.sites.clear()
	w.tail_bonus = 0
	var plan := Skeletons.draw(w, skeleton)
	_hide_doors(w, _loops(w, plan.spots, plan.links))
	_windows(w)
	return plan


## The pavilions skeleton: the rooms sorted west to east, doorways, and bridges and
## ledges between neighbours. Bridges beyond the first of a pair must be far_apart.
static func pavilions(w: World) -> Dictionary:
	var blocks := _pavilions(w)
	var galleries: Array[Rect2i] = []
	for b in blocks:
		_fill(w, b, World.WALL)
		_fill(w, b.grow(-1), World.FLOOR)
		_split(w, b.grow(-1), galleries, w.rng.randf() < GALLERIES)
	w.rooms.sort_custom(func(a: Rect2i, b: Rect2i): return _centre(a).x < _centre(b).x)
	var plan := {spots = _doorways(w, galleries), links = [], goal = Rect2i()}
	for i in range(1, blocks.size()):
		var leap := _leap(blocks[i - 1], blocks[i])
		var rows := _bridge_rows(w, blocks[i - 1], blocks[i], leap >= LEAP.x and leap <= LEAP.y)
		for y in rows:
			link_far(w, blocks[i - 1], blocks[i], y, plan.links)
		_ledges(w, blocks[i - 1], blocks[i], rows)
	return plan


## A bridge on row y between `west` and `east`, when it joins what is not yet joined
## or saves a walk of at least APART steps; the second joins `links`. False when it
## stays uncut.
static func link_far(w: World, west: Rect2i, east: Rect2i, y: int, links: Array) -> bool:
	var a := Vector2i(west.end.x - 2, y)
	var b := Vector2i(east.position.x + 1, y)
	var dist: int = Grid.search(a, Masks.floor_of(w)).dist[Grid.index(b)]
	if dist >= 0 and dist < APART:
		return false
	if dist >= 0:
		links.append({at = a + Vector2i.RIGHT * 2, a = a, b = b})
	_bridge(w, west, east, y)
	return true


## The pavilions, west to east, standing in sky: 2 to 4 of them (more on higher
## storeys), SKY_GAP apart, each tall enough to span BRIDGE_ROWS so that a
## straight bridge on those rows meets any two neighbours. One pair, at random,
## stands far enough apart for ledges LEAP apart.
static func _pavilions(w: World) -> Array[Rect2i]:
	var n := clampi(2 + (w.depth - 1) / 4 + w.rng.randi_range(0, 1), 2, 4)
	var gaps: Array[int] = []
	var spare := Grid.W - 2 - MIN_WIDTH * n
	var leap := w.rng.randi_range(0, n - 2)
	for i in n - 1:
		var gap := LEAP + Vector2i(2, 2) if i == leap else SKY_GAP
		gaps.append(w.rng.randi_range(gap.x, gap.y))
		spare -= gaps[i]
	var widths: Array[int] = []
	widths.resize(n)
	widths.fill(MIN_WIDTH)
	for i in spare:
		widths[w.rng.randi_range(0, n - 1)] += 1
	var out: Array[Rect2i] = []
	var x := 1
	for i in n:
		var h := w.rng.randi_range(MIN_HEIGHT, Grid.H - 2)
		var top := w.rng.randi_range(
			maxi(1, BRIDGE_ROWS.y + 2 - h), mini(BRIDGE_ROWS.x - 1, Grid.H - 1 - h)
		)
		out.append(Rect2i(x, top, widths[i], h))
		x += widths[i] + (gaps[i] if i < n - 1 else 0)
	return out


## Cuts the floor `r` into rooms with walls one tile thick: across its longer
## side (measured against ROOM_MOST) while each part keeps ROOM_LEAST, until a
## part fits in ROOM_MOST and stays whole at the chance WHOLE. A `gallery` cut
## is two walls with a hall one tile wide between them.
static func _split(w: World, r: Rect2i, galleries: Array[Rect2i], gallery := false) -> void:
	var wide := r.size.x * ROOM_MOST.y >= r.size.y * ROOM_MOST.x
	var span := r.size.x if wide else r.size.y
	var fits := r.size.x <= ROOM_MOST.x and r.size.y <= ROOM_MOST.y
	gallery = gallery and span >= 2 * ROOM_LEAST + 3
	var cut := 3 if gallery else 1
	if span < 2 * ROOM_LEAST + cut or (fits and w.rng.randf() < WHOLE):
		w.rooms.append(r)
		return
	var at := w.rng.randi_range(ROOM_LEAST, span - ROOM_LEAST - cut)
	var axis := Vector2i(1, 0) if wide else Vector2i(0, 1)
	var across := Vector2i.ONE - axis
	var wall := Rect2i(r.position + axis * at, axis * cut + across * r.size)
	_fill(w, wall, World.WALL)
	if gallery:
		var hall := Rect2i(wall.position + axis, axis + across * r.size)
		_fill(w, hall, World.FLOOR)
		galleries.append(hall)
	_split(w, Rect2i(r.position, r.size - axis * (span - at)), galleries)
	_split(w, Rect2i(r.position + axis * (at + cut), r.size - axis * (at + cut)), galleries)


## Doorways in the walls between rooms and galleries. Parts already joined, by a
## doorway or by standing open to one another, count as one. In a random order, a
## wall tile with two different parts on opposite sides and wall on the other two
## opens when it joins parts not yet joined, until all are one. DOORS of them hold a
## sliding door, OPEN_DOORS of those open. Returns the tiles left that could still
## have been doorways: [tile, across, part, part], where parts below w.rooms.size()
## are rooms.
static func _doorways(w: World, galleries: Array[Rect2i]) -> Array:
	var parts := w.rooms.duplicate()
	parts.append_array(galleries)
	var part := PackedInt32Array()
	part.resize(w.tiles.size())
	part.fill(-1)
	for k in parts.size():
		for y in range(parts[k].position.y, parts[k].end.y):
			for x in range(parts[k].position.x, parts[k].end.x):
				part[Grid.index(Vector2i(x, y))] = k
	var joined := range(parts.size())
	var spots := []
	for i in w.tiles.size():
		var p := Grid.at(i)
		for d: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
			if Grid.inside(p - d) and Grid.inside(p + d):
				var a := part[Grid.index(p - d)]
				var b := part[Grid.index(p + d)]
				if a < 0 or b < 0 or a == b:
					continue
				if w.tiles[i] == World.WALL:
					spots.append([p, d, a, b])
				else:
					joined[_root(joined, a)] = _root(joined, b)
	shuffle(w.rng, spots)
	var left := []
	for s: Array in spots:
		var a := _root(joined, s[2])
		var b := _root(joined, s[3])
		if a == b or not _walled(w, s[0], s[1]):
			left.append(s)
			continue
		joined[a] = b
		_doorway(w, s[0])
	return left


## Up to LOOPS more doorways on `spots` (from _doorways), each only where the walk
## between its two sides is at least APART steps, so that a hunted fox has somewhere
## to slip away. Each joins `links`. Returns the spots left.
static func _loops(w: World, spots: Array, links: Array) -> Array:
	var open := Masks.floor_of(w)
	var cut := 0
	var left := []
	for s: Array in spots:
		var p: Vector2i = s[0]
		var d: Vector2i = s[1]
		if (
			cut < LOOPS
			and _walled(w, p, d)
			and Grid.search(p - d, open).dist[Grid.index(p + d)] >= APART
		):
			_doorway(w, p)
			open[Grid.index(p)] = 1
			links.append({at = p, a = p - d, b = p + d})
			cut += 1
		else:
			left.append(s)
	return left


## A doorway at p: a sliding door at the chance DOORS (open at OPEN_DOORS), else bare.
static func _doorway(w: World, p: Vector2i) -> void:
	var t := World.FLOOR
	if w.rng.randf() < DOORS:
		t = World.DOOR_OPEN if w.rng.randf() < OPEN_DOORS else World.DOOR
	w.tiles[Grid.index(p)] = t


## The part that stands for every part joined with `k`.
static func _root(joined: Array, k: int) -> int:
	while joined[k] != k:
		k = joined[k]
	return k


## Shuffles `a` with a generator of the world's, so that a seed builds the same storey.
static func shuffle(rng: RandomNumberGenerator, a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t


## p is a wall with wall on both sides across `across`, and no hidden door there.
static func _walled(w: World, p: Vector2i, across: Vector2i) -> bool:
	var side := Vector2i(across.y, across.x)
	return (
		w.tile(p) == World.WALL
		and w.tile(p + side) == World.WALL
		and w.tile(p - side) == World.WALL
		and not w.secrets.has(p + side)
		and not w.secrets.has(p - side)
	)


## The hidden doors of storey `depth`: two, and one more every third storey.
static func hidden_doors(depth: int) -> int:
	return 2 + (depth - 1) / 3


## `hidden_doors` of them, on tiles of `spots` (from _doorways)
## between two rooms at least SHORTCUT steps apart, neither the start room
## (rooms[0]), where one would be found, and let light in, at once.
static func _hide_doors(w: World, spots: Array) -> void:
	var open := Masks.floor_of(w)
	for s: Array in spots:
		if w.secrets.size() >= hidden_doors(w.depth):
			return
		var p: Vector2i = s[0]
		var d: Vector2i = s[1]
		var rooms := [mini(s[2], s[3]), maxi(s[2], s[3])]
		if rooms[0] > 0 and rooms[1] < w.rooms.size() and _walled(w, p, d):
			var dist: PackedInt32Array = Grid.search(p - d, open).dist
			if dist[Grid.index(p + d)] >= SHORTCUT:
				w.secrets[p] = true


## One or two rows (only `one` for a pair with ledges, to leave them room),
## at least 3 apart, for the bridges between pavilions `west` and `east`: rows
## of BRIDGE_ROWS with room floor just inside both their outer walls.
static func _bridge_rows(w: World, west: Rect2i, east: Rect2i, one: bool) -> Array[int]:
	var rows: Array[int] = []
	for y in range(BRIDGE_ROWS.x, BRIDGE_ROWS.y + 1):
		if (
			w.tile(Vector2i(west.end.x - 2, y)) == World.FLOOR
			and w.tile(Vector2i(east.position.x + 1, y)) == World.FLOOR
		):
			rows.append(y)
	var out: Array[int] = []
	if rows.is_empty():
		return out
	out.append(rows[w.rng.randi_range(0, rows.size() - 1)])
	var second := rows[w.rng.randi_range(0, rows.size() - 1)]
	if w.rng.randf() < 0.5 and absi(second - out[0]) >= 3 and not one:
		out.append(second)
	return out


## The sky between ledges on the facing walls of `west` and `east`.
static func _leap(west: Rect2i, east: Rect2i) -> int:
	return east.position.x - west.end.x - 2


## Ledges of 마루 outside the facing walls of `west` and `east` on the same
## rows, when the sky between them is LEAP wide: LEDGE_LENGTH rows of both
## pavilions' insides, clear of the bridge `rows` and the rows next to them.
## Each opens onto a room through a doorway in its wall; none when either
## cannot.
static func _ledges(w: World, west: Rect2i, east: Rect2i, rows: Array[int]) -> void:
	if _leap(west, east) < LEAP.x or _leap(west, east) > LEAP.y:
		return
	var free := func(y: int) -> bool: return not (rows.has(y - 1) or rows.has(y) or rows.has(y + 1))
	var last := mini(west.end.y, east.end.y) - 2
	var starts: Array[int] = []
	for y in range(maxi(west.position.y, east.position.y) + 1, last - LEDGE_LENGTH.x + 2):
		if range(y, y + LEDGE_LENGTH.x).all(free):
			starts.append(y)
	if starts.is_empty():
		return
	var top := starts[w.rng.randi_range(0, starts.size() - 1)]
	var most := top + w.rng.randi_range(LEDGE_LENGTH.x, LEDGE_LENGTH.y)
	var bottom := top + LEDGE_LENGTH.x
	while bottom < most and bottom <= last and free.call(bottom):
		bottom += 1
	var doors: Array[Vector2i] = []
	for side in [[west.end.x - 1, Vector2i.LEFT], [east.position.x, Vector2i.RIGHT]]:
		var spots: Array[Vector2i] = []
		for y in range(top, bottom):
			var p := Vector2i(side[0], y)
			if w.tile(p + side[1]) == World.FLOOR and _walled(w, p, side[1]):
				spots.append(p)
		if spots.is_empty():
			return
		doors.append(spots[w.rng.randi_range(0, spots.size() - 1)])
	for p in doors:
		_doorway(w, p)
	for y in range(top, bottom):
		w.tiles[Grid.index(Vector2i(west.end.x, y))] = World.BOARD
		w.tiles[Grid.index(Vector2i(east.position.x - 1, y))] = World.BOARD


## A plank across the sky on row y from `west` to `east`, through an opening
## in each of their outer walls.
static func _bridge(w: World, west: Rect2i, east: Rect2i, y: int) -> void:
	for x in range(west.end.x, east.position.x):
		w.tiles[Grid.index(Vector2i(x, y))] = World.BRIDGE
	w.tiles[Grid.index(Vector2i(west.end.x - 1, y))] = World.FLOOR
	w.tiles[Grid.index(Vector2i(east.position.x, y))] = World.FLOOR


## A window on some outer wall tiles that face the sky on one side only with
## room floor behind them, never two side by side and never on the map's outer
## ring.
static func _windows(w: World) -> void:
	for y in range(1, Grid.H - 1):
		for x in range(1, Grid.W - 1):
			var p := Vector2i(x, y)
			if w.tile(p) != World.WALL:
				continue
			for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var side := Vector2i(d.y, d.x)
				if (
					w.tile(p + d) == World.SKY
					and w.tile(p - d) == World.FLOOR
					and w.tile(p + side) != World.SKY
					and w.tile(p - side) != World.SKY
					and w.tile(p + side) != World.WINDOW
					and w.tile(p - side) != World.WINDOW
					and w.rng.randf() < WINDOWS
				):
					w.tiles[Grid.index(p)] = World.WINDOW
					break


static func _fill(w: World, r: Rect2i, t: int) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			w.tiles[Grid.index(Vector2i(x, y))] = t


## Whether every open tile is reachable from the first room, walking round the
## tiles in `blocked`, through whatever opens in time (Tiles.opens) and through
## the sealing walls of treasure rooms (World.seals); and every lantern of a
## sealing wall can be stood beside while the wall stands.
static func connected(w: World, blocked: Array = []) -> bool:
	var open := Masks.opened(w, blocked)
	var dist: PackedInt32Array = Grid.search(_centre(w.rooms[0]), open).dist
	for i in open.size():
		if open[i] == 1 and dist[i] < 0:
			return false
	if w.seals.is_empty():
		return true
	var shut := Masks.floor_of(w, blocked, func(_p): return false)
	var reach: PackedInt32Array = Grid.search(_centre(w.rooms[0]), shut).dist
	return w.seals.values().all(
		func(ls):
			return ls.all(
				func(l): return Grid.DIRS.any(func(d): return reach[Grid.index(l + d)] >= 0)
			)
	)


static func _farthest(w: World, from: Vector2i) -> Rect2i:
	var dist: PackedInt32Array = Grid.search(from, Masks.floor_of(w)).dist
	var best := w.rooms[0]
	for r in w.rooms:
		if dist[Grid.index(_centre(r))] > dist[Grid.index(_centre(best))]:
			best = r
	return best


## A lantern in a corner of the goal room and of some others, never the start
## room, and none that would light the start, through a doorway, with the
## others. The goal room's lantern must light the goal, beside it if no corner
## can.
static func _lanterns(w: World, home: Rect2i, goal: Rect2i) -> void:
	var target := w.elixir if w.elixir.x >= 0 else w.stairs
	for r in w.rooms:
		if r == home or (r != goal and w.rng.randf() >= LIT_ROOMS):
			continue
		var corners := [r.position, Vector2i(r.end.x - 1, r.position.y), r.end - Vector2i.ONE]
		corners.append(Vector2i(r.position.x, r.end.y - 1))
		var first := w.rng.randi_range(0, 3)
		var spots := []
		for k in corners.size():
			spots.append(corners[(first + k) % corners.size()])
		if r == goal:
			spots.append_array(Grid.DIRS.map(func(d): return target + d))
		for c: Vector2i in spots:
			if c == w.stairs or c == w.elixir or w.tile(c) != World.FLOOR:
				continue
			if r == goal and not _lights(w, c, target):
				continue
			w.set_tile(c, World.LANTERN)
			if connected(w) and not w.lit(w.start):
				break
			w.set_tile(c, World.FLOOR)


## The room that holds p, or an empty rect.
static func room_at(w: World, p: Vector2i) -> Rect2i:
	for r in w.rooms:
		if r.has_point(p):
			return r
	return Rect2i()


static func _lights(w: World, lantern: Vector2i, p: Vector2i) -> bool:
	var s := Light.spread(lantern, Light.LANTERN_RADIUS, w.light_mask())[Grid.index(p)]
	return Light.level(Light.LANTERN * s) >= Light.LIT


## Every room but the goal may get one feature. A pond that would cut the
## storey apart is drained again.
static func _features(w: World, goal: Rect2i) -> void:
	for r in w.rooms:
		if r == goal:
			continue
		var roll := w.rng.randf()
		if roll < BAMBOO_ROOMS:
			_blob(w, r, World.BAMBOO)
		elif roll < BAMBOO_ROOMS + POND_ROOMS:
			var pond := _blob(w, r, World.POND)
			if not connected(w):
				for p in pond:
					w.tiles[Grid.index(p)] = World.FLOOR
		elif roll < BAMBOO_ROOMS + POND_ROOMS + HALL_ROOMS:
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					if _bare(w, Vector2i(x, y)):
						w.tiles[Grid.index(Vector2i(x, y))] = World.BOARD


## From storey 2, at a chance, a drum on a bare tile of a lit room, unless it would
## cut the storey apart.
static func _drum(w: World) -> void:
	if w.depth < Drums.FIRST_STOREY or w.rng.randf() >= Drums.CHANCE:
		return
	w._changed()
	var spots: Array[Vector2i] = []
	for r in w.rooms:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if _bare(w, Vector2i(x, y)) and w.lit(Vector2i(x, y)):
					spots.append(Vector2i(x, y))
	if spots.is_empty():
		return
	var at := spots[w.rng.randi_range(0, spots.size() - 1)]
	w.tiles[Grid.index(at)] = World.DRUM
	if not connected(w):
		w.tiles[Grid.index(at)] = World.FLOOR


## A patch of `t` covering about a third of room r, grown tile by tile from a random one.
static func _blob(w: World, r: Rect2i, t: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var p := (
		r.position
		+ Vector2i(w.rng.randi_range(0, r.size.x - 1), w.rng.randi_range(0, r.size.y - 1))
	)
	for i in r.get_area():
		if out.size() >= r.get_area() / 3:
			break
		if r.has_point(p) and _bare(w, p) and not out.has(p):
			w.tiles[Grid.index(p)] = t
			out.append(p)
		var from := p if out.is_empty() else out[w.rng.randi_range(0, out.size() - 1)]
		p = from + Grid.DIRS[w.rng.randi_range(0, 7)]
	return out


## Plain floor that is not the start, the stairs or the elixir.
static func _bare(w: World, p: Vector2i) -> bool:
	return (
		w.tile(p) == World.FLOOR
		and p != w.start
		and p != w.stairs
		and p != w.elixir
		and not w.traps.has(p)
	)


## The bands of `kinds`: for each group, its creatures that walk (Bestiary.bands)
## strongest first, dealt round and round into as few bands as keep each within
## BAND. A band's first kind leads it.
static func bands(kinds: Array) -> Array:
	var groups := {}
	for kind in kinds:
		if Bestiary.bands(kind):
			var group: StringName = Bestiary.info(kind).group
			groups[group] = groups.get(group, []) + [kind]
	var out := []
	for members: Array in groups.values():
		var order := range(members.size())
		order.sort_custom(
			func(i, j):
				return [-Bestiary.info(members[i]).hp, i] < [-Bestiary.info(members[j]).hp, j]
		)
		var count := ceili(float(members.size()) / BAND)
		var split := []
		split.resize(count)
		for k in count:
			split[k] = []
		for k in order.size():
			split[k % count].append(members[order[k]])
		out.append_array(split)
	return out


## Standing watchers and bosses where they belong, then each band: its leader
## anywhere, its followers round it in the same room (alone where none fits).
static func _creatures(w: World) -> void:
	for kind in PLAN[w.depth]:
		if not Bestiary.bands(kind):
			_place(w, kind)
	for band in bands(PLAN[w.depth]):
		var lead := _place(w, band[0])
		for kind in band.slice(1):
			var spot := Vector2i(-1, -1)
			if lead != null:
				spot = _random_spot(w, FOE_DISTANCE - BAND_SPREAD, lead.pos)
			if spot.x < 0:
				_place(w, kind)
			else:
				var a := _arrive(w, kind, spot)
				a.leader = lead.id


## A creature of `kind` where it belongs, or null when there is no room (or a boss
## before the last storey).
static func _place(w: World, kind: StringName) -> Actor:
	var info := Bestiary.info(kind)
	if info.get("boss", false) and w.depth < World.FLOORS:
		return null
	var spot := Vector2i(-1, -1)
	if info.get("boss", false):
		spot = nearest_free(w, w.elixir + Vector2i(0, 1))
	elif info.get("move", &"static") == &"static":
		spot = _by_lantern(w)
	if spot.x < 0:
		spot = _random_spot(w, FOE_DISTANCE)
	return _arrive(w, kind, spot) if spot.x >= 0 else null


## A creature of `kind` at `at`, charging for a random while.
static func _arrive(w: World, kind: StringName, at: Vector2i) -> Actor:
	var a := spawn(w, kind, at)
	a.cooldown = w.rng.randi_range(1, Bestiary.info(kind).get("cd", 1))
	return a


static func _by_lantern(w: World) -> Vector2i:
	var dist: PackedInt32Array = Grid.search(w.start, Masks.floor_of(w)).dist
	var spots: Array[Vector2i] = []
	for i in w.tiles.size():
		if w.tiles[i] != World.LANTERN:
			continue
		for d in Grid.DIRS:
			var p: Vector2i = Grid.at(i) + d
			if (
				w.vacant(p)
				and not w.traps.has(p)
				and p != w.stairs
				and p != w.elixir
				and dist[Grid.index(p)] >= FOE_DISTANCE
				and Grid.cheb(p, w.start) > START_CLEAR
			):
				spots.append(p)
	if spots.is_empty():
		return Vector2i(-1, -1)
	return spots[w.rng.randi_range(0, spots.size() - 1)]


## A free room tile at least `min_dist` steps from the start and more than
## START_CLEAR tiles from it; within BAND_SPREAD of `near` and in its room when
## that is given.
static func _random_spot(w: World, min_dist: int, near := Vector2i(-1, -1)) -> Vector2i:
	var dist: PackedInt32Array = Grid.search(w.start, Masks.floor_of(w)).dist
	var spots: Array[Vector2i] = []
	for r in w.rooms:
		if near.x >= 0 and not r.has_point(near):
			continue
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var p := Vector2i(x, y)
				if (
					(near.x < 0 or Grid.cheb(p, near) <= BAND_SPREAD)
					and w.vacant(p)
					and dist[Grid.index(p)] >= min_dist
					and Grid.cheb(p, w.start) > START_CLEAR
					and p != w.stairs
					and p != w.elixir
					and not w.peaches.has(p)
					and not w.traps.has(p)
				):
					spots.append(p)
	if spots.is_empty():
		return Vector2i(-1, -1)
	return spots[w.rng.randi_range(0, spots.size() - 1)]


## Where a resting patrol heads next: the middle of a random room.
static func patrol_point(w: World) -> Vector2i:
	return _centre(w.rooms[w.rng.randi_range(0, w.rooms.size() - 1)])


## The free tile with no plate nearest `from` across the `open` tiles (floor
## when none are given), or (-1, -1).
static func nearest_free(w: World, from: Vector2i, open := PackedByteArray()) -> Vector2i:
	if w.vacant(from) and not w.traps.has(from):
		return from
	var mask := open if not open.is_empty() else Masks.floor_of(w)
	var dist: PackedInt32Array = Grid.search(from, mask).dist
	var best := -1
	for i in dist.size():
		var free := w.vacant(Grid.at(i)) and not w.traps.has(Grid.at(i))
		if dist[i] > 0 and free and (best < 0 or dist[i] < dist[best]):
			best = i
	return Grid.at(best) if best >= 0 else Vector2i(-1, -1)


## A creature spawned in a doorway stands in an open door.
static func spawn(w: World, kind: StringName, at: Vector2i) -> Actor:
	if w.tile(at) == World.DOOR:
		w.set_tile(at, World.DOOR_OPEN)
	var a := Actor.new()
	a.id = w.new_id()
	a.kind = kind
	a.faction = Actor.HEAVEN
	a.pos = at
	a.home = at
	a.post = at
	a.rank = Bestiary.rank(w.depth)
	a.hp = Bestiary.hp(kind, a.rank)
	a.max_hp = a.hp
	w.actors.append(a)
	return a
