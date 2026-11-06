class_name Collapse
extends RefCounted
## While Miho carries the elixir (World.elixir_held) her storey falls apart every round, and
## 저승사자 keeps coming, as DCSS spawns monsters at random while the Orb is carried
## (`spawn_random_monsters`).
##
## From the second storey: ROT floor tiles and pillars rot (낡은 마루, 무너진 벽), FALL of the
## rotten boards turn to sky (what stands there falls, Fall.drop) and HOT walkable tiles turn
## to hot ground. The first storey has no storey under it, so only the hot ground comes. Miho's
## tile and the way to every tile of `goals` are kept, as a sinkhole keeps them. The three
## counts are scaled together by SCALE. A map of houses does not collapse (`_ruins`).
##
## Each round 저승사자 comes with the chance 1 in World.REAPER_CHANCE, on a free tile Miho can
## walk to, within World.REAPER_NEAR of her and out of her sight, and hunts her at once. It
## runs apart from the clock of Curse.

const SCALE := 1.0
const ROT := 4
const FALL := 2
const HOT := 2


## A count scaled by SCALE.
static func count(base: int) -> int:
	return roundi(base * SCALE)


## The tiles Miho must always be able to walk to: the stairs, and from the second storey the
## tile she came up on.
static func goals(w: World) -> Array:
	var tiles := []
	if Grid.inside(w.stairs):
		tiles.append(w.stairs)
	if w.depth >= 2:
		tiles.append(w.start)
	return tiles


## The end of a round.
static func tick(w: World) -> void:
	if w.outcome != &"" or not w.elixir_held:
		return
	if not _ruins(w):
		_crumble(w)
	_reaper(w)


## Whether the map is one of houses, where nothing collapses.
static func _ruins(_w: World) -> bool:
	return false


static func _crumble(w: World) -> void:
	var keep := goals(w) + [w.player().pos]
	var changed: Array[Vector2i] = []
	var gone: Array[Vector2i] = []
	if w.depth >= 2:
		changed.append_array(_rot(w, keep))
		gone = _sink(w)
		changed.append_array(gone)
	changed.append_array(_heat(w, keep))
	if not changed.is_empty():
		w._changed()
	if not gone.is_empty():
		w.emit({t = &"quake", tiles = changed})


## ROT tiles, floor and pillar alike, from the candidates in grid order.
static func _rot(w: World, keep: Array) -> Array[Vector2i]:
	var list := _tiles(
		func(p):
			return (
				w.tile(p) == World.PILLAR
				or (Compounds.open(w, p) and w.tile(p) != World.BOARD_ROTTEN and p not in keep)
			)
	)
	FloorGen.shuffle(w.rng, list)
	var rotted: Array[Vector2i] = []
	for p in list.slice(0, count(ROT)):
		w.set_tile(p, World.RUBBLE if w.tile(p) == World.PILLAR else World.BOARD_ROTTEN)
		rotted.append(p)
	return rotted


## FALL rotten boards turn to sky, and what stood on them falls.
static func _sink(w: World) -> Array[Vector2i]:
	var list := _tiles(func(p): return w.tile(p) == World.BOARD_ROTTEN)
	FloorGen.shuffle(w.rng, list)
	var gone := Compounds.sinkable(w, list, count(FALL), goals(w))
	for p in gone:
		w.hot.erase(p)
		w.traps.erase(p)
		w.set_tile(p, World.SKY)
	Scrolls.displace(w, gone)
	for a in w.actors.duplicate():
		if a.alive() and a.pos in gone:
			Fall.drop(w, a, a.pos)
	return gone


## HOT dry walkable tiles turn to hot ground, half of them hot iron.
static func _heat(w: World, keep: Array) -> Array[Vector2i]:
	var list := _tiles(
		func(p):
			return (
				w.open_floor(p)
				and not Tiles.of(w.tile(p), "douses")
				and not w.hot.has(p)
				and p not in keep
			)
	)
	FloorGen.shuffle(w.rng, list)
	var laid: Array[Vector2i] = []
	for p in list.slice(0, count(HOT)):
		Compounds.heat(w, [p], w.rng.randi_range(0, 1), false)
		laid.append(p)
	return laid


static func _reaper(w: World) -> void:
	if w.rng.randi_range(1, World.REAPER_CHANCE) != 1:
		return
	var me := w.player()
	var reach: PackedInt32Array = Grid.search(me.pos, Masks.floor_of(w)).dist
	var list := _tiles(
		func(p):
			return (
				Grid.cheb(p, me.pos) <= World.REAPER_NEAR
				and w.vacant(p)
				and not w.traps.has(p)
				and w.seen[Grid.index(p)] == 0
				and reach[Grid.index(p)] >= 0
			)
	)
	if list.is_empty():
		return
	var spot: Vector2i = list[w.rng.randi_range(0, list.size() - 1)]
	var saja := FloorGen.spawn(w, &"saja", spot)
	saja.brain.alert = Actor.HUNT
	saja.brain.target = me.pos
	w._changed()
	w.emit({t = &"arrive", id = saja.id, at = spot, kind = &"saja", anywhere = true})


## The tiles of the map in grid order that `test` takes.
static func _tiles(test: Callable) -> Array[Vector2i]:
	var list: Array[Vector2i] = []
	for i in Grid.W * Grid.H:
		if test.call(Grid.at(i)):
			list.append(Grid.at(i))
	return list
