class_name EventRooms
extends RefCounted
## Event rooms (사건 방), built by hand on some storeys: at most one a storey,
## in a room that is neither the start room nor the goal room, and it leaves
## World.rooms, so no creature, patch, plate or lantern is placed in it. Each
## has a condition, a reward used on the spot (nothing is carried) and a risk,
## and the hover tells all three. A room that cannot be built leaves the storey
## as it was. A room's state lives in World.sites, and `tick` ends every round.
##
## 세 등불 보물방 (FloorGen.seal): a room shut by a seal that three dark
## lanterns in front of it open, with two peaches inside. It is tried first,
## with the world's generator; the other rooms (ROWS) draw from a generator of
## their own, seeded from the world's, so that they leave the draws of what is
## laid after them as they were on a storey they do not appear on.
## 혼불 제단 (Altar): three creatures of heaven fall around the altar.

## The chance of a treasure room.
const VAULTS := 0.4
## The other rooms: the first tier each appears on, and the chance, tried in order.
const ROWS := [
	{kind = &"altar", tier = 1, chance = 0.12},
]


## At each chance, a room but `home` becomes that event room; the first that can
## be built is the storey's only one.
static func build(w: World, home: Rect2i) -> void:
	if w.rng.randf() < VAULTS and _try(w, home, w.rng, &"vault"):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = w.rng.state
	for row: Dictionary in ROWS:
		if w.tier() >= row.tier and rng.randf() < row.chance and _try(w, home, rng, row.kind):
			return


## Builds a `kind` room in the first room but `home`, in a shuffled order, that
## can hold one; it leaves w.rooms.
static func _try(w: World, home: Rect2i, rng: RandomNumberGenerator, kind: StringName) -> bool:
	var rooms := w.rooms.filter(func(r): return r != home)
	FloorGen.shuffle(rng, rooms)
	for r: Rect2i in rooms:
		if _make(w, kind, r):
			w.rooms.erase(r)
			w._changed()
			return true
	return false


static func _make(w: World, kind: StringName, r: Rect2i) -> bool:
	match kind:
		&"vault":
			return FloorGen.seal(w, r)
		&"altar":
			return Altar.make(w, r)
	return false


## The end of a round: every room checks what happened in it.
static func tick(w: World) -> void:
	if w.outcome != &"":
		return
	for site: Dictionary in w.sites.duplicate():
		match site.kind:
			&"altar":
				Altar.tick(w, site)
