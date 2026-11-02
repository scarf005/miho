class_name Storeys
extends RefCounted
## The storeys Miho has left, kept by depth in World.storeys as she left them:
## the tiles, the creatures, the plates and hidden doors, fire, gas, the event
## rooms, what she knew of the map and the storey's clock. Coming back by the
## stairs or by a fall finds the storey so; nothing happens on a storey she is
## not on. Projectiles in flight and scent are not kept, and her 그림자 rides on
## with her. A kept storey is never changed, so World.clone shares them.

## The World fields that belong to the storey Miho is on, but its creatures.
const FIELDS: Array[String] = [
	"tiles",
	"rooms",
	"start",
	"stairs",
	"elixir",
	"peaches",
	"jars",
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
## the first time. Her scent and her projectiles but her 그림자 stay behind.
static func enter(w: World, depth: int) -> void:
	w.depth = depth
	w.scent.clear()
	w.strong.clear()
	var riding := Guise.shadows(w, w.player())
	for s in w.shots:
		s.gone = true
	if w.storeys.has(depth):
		_restore(w, depth)
	else:
		FloorGen.build(w)
	w.shots.assign(riding)
	for s in riding:
		s.gone = false
	carry(w)


## Her 그림자 stands where she stands.
static func carry(w: World) -> void:
	for s in Guise.shadows(w, w.player()):
		s.pos = w.player().pos
	w._changed()


## Puts back the storey kept at `depth`, with Miho at its start.
static func _restore(w: World, depth: int) -> void:
	var kept: Dictionary = w.storeys[depth]
	w.storeys.erase(depth)
	for f in FIELDS:
		w.set(f, _copy(kept[f]))
	var me := w.player()
	w.shots.clear()
	w.actors.assign(kept.actors.map(func(a): return a.clone()))
	var spot := FloorGen.nearest_free(w, w.start)
	w.actors.push_front(me)
	Status.release(w, me)
	me.pos = spot if spot.x >= 0 else w.start
	w._changed()


## The tiles of the storey below, or none when it is not kept.
static func below(w: World) -> PackedByteArray:
	return w.storeys.get(w.depth - 1, {}).get("tiles", PackedByteArray())


static func _copy(v: Variant) -> Variant:
	if v is Array or v is Dictionary:
		return v.duplicate(true)
	return v.duplicate() if v is PackedByteArray else v
