class_name RunPlan
extends RefCounted
## What each storey of a run is, read from nothing but the run's seed, so that it is never
## saved and a storey left behind or a clone reads the same. No shape comes twice in a run.
## Each storey has a light (LIGHTS), and an element (Cards.GROWS) that says what lies on it.

## The shapes, each with the first storey it may stand on.
const FIRST := {
	Skeletons.AVENUE: 1,
	Skeletons.RING: 1,
	Skeletons.PAVILIONS: 1,
	Skeletons.TOWERS: 2,
	Skeletons.KEEP: 4,
	Skeletons.CITADEL: 6,
	Skeletons.GARDEN: 1,
	Skeletons.SCATTERED: 2,
	Skeletons.BROKEN: 3,
	Skeletons.RUIN: 4,
	Skeletons.GROVE: 2,
	Skeletons.FLOODED: 2,
	Skeletons.TIMBER: 3,
	Skeletons.HOLLOW: 2,
	Skeletons.CAVE: 3,
	Skeletons.ASKEW: 1,
	Skeletons.MIRROR: 1,
	Skeletons.WINDING: 1,
}
## What kind of place each shape is: two storeys in a row are never of one kind.
const FAMILY := {
	Skeletons.AVENUE: &"rooms",
	Skeletons.RING: &"rooms",
	Skeletons.PAVILIONS: &"rooms",
	Skeletons.TOWERS: &"rooms",
	Skeletons.KEEP: &"rooms",
	Skeletons.CITADEL: &"rooms",
	Skeletons.WINDING: &"rooms",
	Skeletons.GARDEN: &"ground",
	Skeletons.GROVE: &"ground",
	Skeletons.FLOODED: &"ground",
	Skeletons.SCATTERED: &"sky",
	Skeletons.HOLLOW: &"sky",
	Skeletons.BROKEN: &"sky",
	Skeletons.RUIN: &"sky",
	Skeletons.ASKEW: &"askew",
	Skeletons.MIRROR: &"askew",
	Skeletons.CAVE: &"askew",
	Skeletons.TIMBER: &"askew",
	Skeletons.LABYRINTH: &"maze",
}
## The chance a room has a lantern on a dark, a middling and a bright storey.
const LIGHTS: Array[float] = [0.1, 0.45, 0.85]
## The shapes of one element.
const ELEMENT_OF := {Skeletons.GROVE: Cards.WOOD, Skeletons.FLOODED: Cards.WATER}
## What makes the draws of a storey's light and element differ from those of its shape.
const LIGHT_SALT := 0x51ED
const ELEMENT_SALT := 0x0E1E
const MAZE_SALT := 0x3A2E
const OUTSIDE_SALT := 0x0D7E
## The share of runs with a maze and the storeys one may stand on (least, most).
const MAZE_RUNS := 0.4
const MAZE_DEPTH := Vector2i(3, 7)


## The shape of each storey of a run on `seed_value`, from the first.
static func shapes(seed_value: int) -> Array[StringName]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_value)
	var out: Array[StringName] = []
	for depth in range(1, World.FLOORS + 1):
		var open := []
		for s: StringName in FIRST:
			if (
				FIRST[s] <= depth
				and not out.has(s)
				and (out.is_empty() or FAMILY[s] != FAMILY[out[-1]])
			):
				open.append(s)
		out.append(open[rng.randi_range(0, open.size() - 1)])
	var maze := labyrinth(seed_value)
	if maze.depth > 0:
		out[maze.depth - 1] = Skeletons.LABYRINTH
	return out


## The maze of a run on `seed_value`: {depth, concept}, depth 0 for a run without one. The
## concept is drawn either way, so that a storey forced on a maze has one too.
static func labyrinth(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_value) ^ MAZE_SALT
	var comes := rng.randf() < MAZE_RUNS
	var depth := rng.randi_range(MAZE_DEPTH.x, MAZE_DEPTH.y)
	return {
		depth = depth if comes else 0,
		concept = Labyrinth.CONCEPTS[rng.randi_range(0, Labyrinth.CONCEPTS.size() - 1)],
	}


## The chance a room of storey `depth` has a lantern. No three storeys in a row share one.
static func light(seed_value: int, depth: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_value) ^ LIGHT_SALT
	var out: Array[float] = []
	for d in World.FLOORS:
		var open := LIGHTS.filter(func(l): return d < 2 or l != out[d - 1] or l != out[d - 2])
		out.append(open[rng.randi_range(0, open.size() - 1)])
	return out[mini(depth, World.FLOORS) - 1]


## The element of storey `depth` on `shape`: its own, or the one the storey below grows
## into (Cards.GROWS), from one the seed picks for the first.
static func element(seed_value: int, depth: int, shape: StringName) -> StringName:
	if ELEMENT_OF.has(shape):
		return ELEMENT_OF[shape]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_value) ^ ELEMENT_SALT
	var out: StringName = Cards.ELEMENTS[rng.randi_range(0, Cards.ELEMENTS.size() - 1)]
	for d in mini(depth, World.FLOORS) - 1:
		out = Cards.GROWS[out]
	return out


## The look of the ground round the pavilion on storey 1 of a run on `seed_value`
## (Outside.DESIGNS).
static func outside(seed_value: int) -> StringName:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_value) ^ OUTSIDE_SALT
	return Outside.DESIGNS[rng.randi_range(0, Outside.DESIGNS.size() - 1)]
