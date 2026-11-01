class_name Storeys
extends RefCounted
## The storeys Miho has left, kept by depth in World.storeys as she left them:
## the tiles, the creatures, the plates and hidden doors, fire, gas, the event
## rooms, what she knew of the map and the storey's clock. Coming back by the
## stairs or by a fall finds the storey so; nothing happens on a storey she is
## not on. Projectiles in flight and scent are not kept. A kept storey is never
## changed, so World.clone shares them.

## The World fields that belong to the storey Miho is on, but its creatures.
const FIELDS: Array[String] = [
	"tiles",
	"rooms",
	"start",
	"stairs",
	"elixir",
	"peaches",
	"burning",
	"wild",
	"gas",
	"vents",
	"wet",
	"hot",
	"traps",
	"secrets",
	"seals",
	"sites",
	"tail_bonus",
	"changes",
	"bodies",
	"known",
	"round_no",
]


## Keeps the storey Miho is on as it is now.
static func leave(w: World) -> void:
	var kept := {}
	for f in FIELDS:
		kept[f] = _copy(w.get(f))
	kept.actors = w.actors.slice(1).map(func(a): return a.clone())
	w.storeys[w.depth] = kept


## Puts Miho at the start of storey `depth`: the one kept there, or a new one
## the first time. Her projectiles and scent stay behind.
static func enter(w: World, depth: int) -> void:
	w.depth = depth
	w.scent.clear()
	for s in w.shots:
		s.gone = true
	if not w.storeys.has(depth):
		FloorGen.build(w)
		return
	var kept: Dictionary = w.storeys[depth]
	w.storeys.erase(depth)
	for f in FIELDS:
		w.set(f, _copy(kept[f]))
	var me := w.player()
	w.shots.clear()
	w.actors.assign(kept.actors.map(func(a): return a.clone()))
	var spot := FloorGen.nearest_free(w, w.start)
	w.actors.push_front(me)
	me.pos = spot if spot.x >= 0 else w.start
	me.rooted = 0
	me.stunned = 0
	me.blind = 0
	w._changed()


## The tiles of the storey below, or none when it is not kept.
static func below(w: World) -> PackedByteArray:
	return w.storeys.get(w.depth - 1, {}).get("tiles", PackedByteArray())


static func _copy(v: Variant) -> Variant:
	if v is Array or v is Dictionary:
		return v.duplicate(true)
	return v.duplicate() if v is PackedByteArray else v
