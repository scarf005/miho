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
}
## The chance a room has a lantern on a dark, a middling and a bright storey.
const LIGHTS: Array[float] = [0.1, 0.45, 0.85]
## The shapes of one element.
const ELEMENT_OF := {}
## What makes the draws of a storey's light and element differ from those of its shape.
const LIGHT_SALT := 0x51ED
const ELEMENT_SALT := 0x0E1E


## The shape of each storey of a run on `seed_value`, from the first.
static func shapes(seed_value: int) -> Array[StringName]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_value)
	var out: Array[StringName] = []
	for depth in range(1, World.FLOORS + 1):
		var open: Array = FIRST.keys().filter(func(s): return FIRST[s] <= depth and not out.has(s))
		out.append(open[rng.randi_range(0, open.size() - 1)])
	return out


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
