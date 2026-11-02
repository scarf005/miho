class_name Built
extends RefCounted
## Storeys that tests build over and over: each is built once per process, and every call
## returns a copy (World.clone), so a test may change what it gets.

## What the current script asked for and what was built for it, in ms, by key. The shard
## plan of `just test` reads them through tools/test_times.gd: a storey is built once on
## each shard that asks for it, so scripts that ask for the same storeys go together.
static var asked := {}
static var spent := {}

static var _created := {}
static var _storeys := {}


## World.create(seed_value).
static func world(seed_value: int) -> World:
	var key := "%d" % seed_value
	asked[key] = true
	if not _created.has(seed_value):
		var started := Time.get_ticks_msec()
		_created[seed_value] = World.create(seed_value)
		spent[key] = Time.get_ticks_msec() - started
	return _created[seed_value].clone()


## Storey `depth` of a seed on `skeleton` (Skeletons.pick when none), as a test builds it:
## World.create(seed_value), its depth set, FloorGen.build. {w, made}: the world and the set
## room FloorGen.build returned.
static func made(seed_value: int, depth: int, skeleton := &"") -> Dictionary:
	var key := [seed_value, depth, skeleton]
	var name := "%d/%d/%s" % key
	asked["%d" % seed_value] = true
	asked[name] = true
	if not _storeys.has(key):
		var w := world(seed_value)
		var started := Time.get_ticks_msec()
		w.depth = depth
		_storeys[key] = {w = w, made = FloorGen.build(w, skeleton)}
		spent[name] = Time.get_ticks_msec() - started
	var row: Dictionary = _storeys[key]
	return {w = row.w.clone(), made = row.made.duplicate(true)}


## The world of `made`.
static func storey(seed_value: int, depth: int, skeleton := &"") -> World:
	return made(seed_value, depth, skeleton).w
