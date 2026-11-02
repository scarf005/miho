class_name Storeys
extends RefCounted
## The storeys Miho has left, kept by depth in World.storeys as she left them:
## the tiles, the creatures, the plates and hidden doors, fire, gas, the event
## rooms, what she knew of the map and the storey's clock. Coming back by the
## stairs or by a fall finds the storey so; nothing happens on a storey she is
## not on. Projectiles in flight and scent are not kept, and her 그림자 rides on
## with her. A kept storey is never changed, so World.clone shares them. An ally
## by her when she takes the stairs comes along (`followers`, DCSS _tag_follower_at),
## and any other stays there as a creature does, as what rose by 사령술 always does
## (Raise). 사령술 ends here on any way off a storey (`enter`).

## How near the stairs an ally stands to come along. She climbs on the step itself, so
## one right behind her is this far off when the step ends.
const FOLLOW := 2
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
	"curses",
]


## Keeps the storey Miho is on as it is now.
static func leave(w: World) -> void:
	var kept := {}
	for f in FIELDS:
		kept[f] = _copy(w.get(f))
	kept.actors = w.actors.slice(1).map(func(a): return a.clone())
	w.storeys[w.depth] = kept


## Whether an ally goes along with Miho: it can move, and is no risen one.
static func _follows(a: Actor) -> bool:
	return a.ally() and a.info().get("move", &"static") != &"static" and not Raise.risen(a)


## Takes the allies by Miho off the storey (FOLLOW), to `bring` to the next, but the risen.
static func followers(w: World) -> Array[Actor]:
	var me := w.player()
	var party: Array[Actor] = []
	party.assign(
		w.actors.filter(func(a): return _follows(a) and Grid.cheb(a.pos, me.pos) <= FOLLOW)
	)
	w.actors.assign(w.actors.filter(func(a): return not party.has(a)))
	return party


## Puts `party` round Miho, nearest first. One with no room left stays behind for good.
static func bring(w: World, party: Array[Actor]) -> void:
	for a in party:
		var spot := FloorGen.nearest_free(w, w.player().pos)
		if spot.x < 0:
			continue
		a.pos = spot
		a.home = spot
		a.post = spot
		a.rival = 0
		a.grudge = 0
		a.intent.clear()
		w.actors.append(a)
	Bunsin.cap(w)
	w._changed()


## Puts Miho at the start of storey `depth`: the one kept there, or a new one
## the first time. Her scent and her projectiles but her 그림자 stay behind.
static func enter(w: World, depth: int) -> void:
	if w.player().raise:
		Guise.dispel(w, w.player(), Guise.RAISE)
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
