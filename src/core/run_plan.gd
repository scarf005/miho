class_name RunPlan
extends RefCounted
## What each storey of a run is, read from nothing but the run's seed, so that it is never
## saved and a storey left behind or a clone reads the same. No shape comes twice in a run.

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


## The shape of each storey of a run on `seed_value`, from the first.
static func shapes(seed_value: int) -> Array[StringName]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_value)
	var out: Array[StringName] = []
	for depth in range(1, World.FLOORS + 1):
		var open: Array = FIRST.keys().filter(func(s): return FIRST[s] <= depth and not out.has(s))
		out.append(open[rng.randi_range(0, open.size() - 1)])
	return out
