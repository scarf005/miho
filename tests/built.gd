class_name Built
extends RefCounted
## Storeys that tests build over and over: each is built once per process, and every call
## returns a copy (World.clone), so a test may change what it gets.

static var _created := {}
static var _storeys := {}


## World.create(seed_value).
static func world(seed_value: int) -> World:
	if not _created.has(seed_value):
		_created[seed_value] = World.create(seed_value)
	return _created[seed_value].clone()


## Storey `depth` of a seed on `skeleton` (Skeletons.pick when none), as a test builds it:
## World.create(seed_value), its depth set, FloorGen.build. {w, made}: the world and the set
## room FloorGen.build returned.
static func made(seed_value: int, depth: int, skeleton := &"") -> Dictionary:
	var key := [seed_value, depth, skeleton]
	if not _storeys.has(key):
		var w := world(seed_value)
		w.depth = depth
		_storeys[key] = {w = w, made = FloorGen.build(w, skeleton)}
	var row: Dictionary = _storeys[key]
	return {w = row.w.clone(), made = row.made.duplicate(true)}


## The world of `made`.
static func storey(seed_value: int, depth: int, skeleton := &"") -> World:
	return made(seed_value, depth, skeleton).w
