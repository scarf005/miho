class_name EventRooms
extends RefCounted
## Event rooms (사건 방), built by hand on some storeys: at most one a storey,
## in a room that is neither the start room nor the goal room, and it leaves
## World.rooms, so no creature, patch, plate or lantern is placed in it. Each
## has a condition, a reward used on the spot (nothing is carried) and a risk,
## and the hover tells all three. A room that cannot be built leaves the storey
## as it was. A room's state lives in World.sites, and `tick` ends every round.
##
## 세 등불 보물방 (Vault): a room shut by a plain wall that three dark
## lanterns in a row in front of it bring down, with two peaches inside. It is tried first,
## with the world's generator; the other rooms (ROWS) draw from a generator of
## their own, seeded from the world's, so that they leave the draws of what is
## laid after them as they were on a storey they do not appear on.
## 혼불 제단 (Altar): three creatures of heaven fall around the altar.
## 도깨비불 장막 (Veil): a line of fire splits a room; water or frost puts it out.
## 장승 마당 (Yard): a lit yard with a guard and a talisman.
## 삐걱 마루 (Creak): a room of creaking boards and a sleeping 해태.
## 서고 (Library): a dark room behind closed doors; its scrolls show the map.

## The chance of a treasure room.
const VAULTS := 0.45
## The other rooms: the first storey each appears on, and the chance, tried in order.
const ROWS := [
	{kind = &"altar", tier = 1, chance = 0.3},
	{kind = &"veil", tier = 1, chance = 0.3},
	{kind = &"yard", tier = 1, chance = 0.3},
	{kind = &"creak", tier = 3, chance = 0.3},
	{kind = &"library", tier = 2, chance = 0.3},
]


## At each chance, a room but `home` becomes that event room; the first that can
## be built is the storey's only one.
static func build(w: World, home: Rect2i) -> void:
	if w.rng.randf() < VAULTS and _try(w, home, w.rng, &"vault"):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = w.rng.state
	for row: Dictionary in ROWS:
		if w.depth >= row.tier and rng.randf() < row.chance and _try(w, home, rng, row.kind):
			return


## Builds a `kind` room in the first room but `home`, in a shuffled order, that
## has no hidden door and can hold one; it leaves w.rooms.
static func _try(w: World, home: Rect2i, rng: RandomNumberGenerator, kind: StringName) -> bool:
	var rooms := w.rooms.filter(func(r): return r != home)
	FloorGen.shuffle(rng, rooms)
	for r: Rect2i in rooms:
		if not doorways(w, r).any(func(p): return w.secrets.has(p)) and _make(w, kind, r, rng):
			w.rooms.erase(r)
			w._changed()
			return true
	return false


static func _make(w: World, kind: StringName, r: Rect2i, rng: RandomNumberGenerator) -> bool:
	match kind:
		&"vault":
			return Vault.make(w, r)
		&"altar":
			return Altar.make(w, r)
		&"veil":
			return Veil.make(w, r, rng)
		&"yard":
			return Yard.make(w, r, rng)
		&"creak":
			return Creak.make(w, r)
		&"library":
			return Library.make(w, r, rng)
	return false


## The open tiles and hidden doors of the wall ring round room r, corners left
## out: the ways in.
static func doorways(w: World, r: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in range(r.position.x, r.end.x):
		out.append(Vector2i(x, r.position.y - 1))
		out.append(Vector2i(x, r.end.y))
	for y in range(r.position.y, r.end.y):
		out.append(Vector2i(r.position.x - 1, y))
		out.append(Vector2i(r.end.x, y))
	return out.filter(func(p): return w.open_floor(p) or w.secrets.has(p))


## Miho has come onto her tile (Walk.arrive).
static func arrive(w: World, me: Actor) -> void:
	Yard.arrive(w, me)
	Library.arrive(w, me)


## The end of a round: every room checks what happened in it.
static func tick(w: World) -> void:
	if w.outcome != &"":
		return
	Veil.tick(w)
	for site: Dictionary in w.sites.duplicate():
		match site.kind:
			&"altar":
				Altar.tick(w, site)
			&"creak":
				Creak.tick(w, site)
