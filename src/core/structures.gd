class_name Structures
extends RefCounted
## Furniture that reacts when it is hit (Terrain.hit), by what was hit. Its
## other rules are tile columns (Tiles): where it stands, whether it blocks
## sight, burns, or lights the ground.
##
## A screen (병풍) blocks sight and walking until it is knocked down to floor:
## Miho walking into it, or an orb, with a thud of World.THUD tiles. A jar
## (장독) is knocked to pieces with a clang. A water jar (물독) floods the ground round it:
## the bare floor in the 3x3 turns to shallow water, and water's own rules
## (Terrain.wash) put out fire, lanterns and a veil and wash the scent away
## there. A censer (향로) breathes incense (Gas.INCENSE) from the tile it
## stands on, while it stands; knocked over, it spills coals: the tile and the
## four beside it become hot ground for Compounds.HOT_ROUNDS, and what burns
## beside it catches fire.


## The tile at `at`, which was `was`, has just been hit.
static func broke(w: World, was: int, at: Vector2i) -> void:
	match was:
		World.WATER_JAR:
			_flood(w, at)
		World.CENSER:
			_spill(w, at)


static func _flood(w: World, at: Vector2i) -> void:
	for d: Vector2i in [Vector2i.ZERO] + Grid.DIRS:
		if w.tile(at + d) == World.FLOOR and not w.traps.has(at + d):
			w.set_tile(at + d, World.SHALLOW)
		Terrain.wash(w, at + d)


static func _spill(w: World, at: Vector2i) -> void:
	w.vents.erase(at)
	var ring: Array[Vector2i] = [at]
	for d in Placement.SIDES:
		ring.append(at + d)
	Compounds.heat(w, ring, Compounds.LAVA)
	for p in ring:
		w.ignite(p)
