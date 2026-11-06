class_name Gas
extends RefCounted
## The gas layer (Brogue CE updateVolumetricMedia). A tile holds one kind of gas
## in an amount of 1 to MAX; `World.gas` maps each such tile to Vector2i(kind,
## amount). Each round, in `tick`:
##
## - every burning tile breathes out SMOKE_PUFF smoke, and every vent (World.vents)
##   is topped up to VENT_LEVEL of its gas;
## - every tile takes the average of its own amount and its neighbours' (the
##   eight around it that gas can lie on), the remainder going to chance, and the
##   kind of the strongest of them;
## - each tile loses 1 with the decay chance of its kind;
## - whoever stands in a harmful gas takes its harm, and whoever stands in a
##   wetting gas, and a drum there, gets wet (Status); Miho's scent is lost on a
##   tile of a gas that erases it.
##
## A tile with OPAQUE or more of a gas that blocks sight blocks sight
## (World.opaque). Gas lies only where
## Tiles.gas allows, so walls, closed doors, windows, pillars and sky stop it,
## and never on the outermost ring of the map. The spreading runs in Rust
## (rust/src/lib.rs), drawing its chance from the World's generator once a round.
##
## name: what the hover text calls it. decay: the percent chance each round that
## a tile loses 1. harm: damage a round to who stands in it. wets: it wets
## drums and creatures. blocks: thick enough, it blocks sight. erases: Miho's
## scent is lost where it lies. explodes: fire on a tile of it sets off the whole
## cloud at once (`light`): BLAST harm to whoever stands in it, which is then alight.
## boils: the kind that fire on its tile turns it to, of the same amount, with
## full heat. cools: the kind it turns to, of the same amount, when its heat is
## spent.
##
## A gas with cools also has a heat of 1 to MAX per tile (`World.gas_heat`; a tile
## without one has MAX). Spreading gives a tile the greater of its own heat and
## that of the hottest neighbouring tile of its gas less 1, so heat runs out
## one tile from where it was laid for each tile of spreading, and the gas that
## is left with none is of the kind it cools to.

const FOG := 0
const STEAM := 1
const SMOKE := 2
const INCENSE := 3
const MARSH := 4
const ROWS := {
	FOG: {name = "안개", decay = 20, boils = STEAM},
	STEAM: {name = "증기", decay = 50, harm = 1, wets = true, cools = FOG},
	SMOKE: {name = "연기", decay = 50, erases = true},
	INCENSE: {name = "향 연기", decay = 20, blocks = false, erases = true},
	MARSH: {name = "늪 기체", decay = 20, blocks = false, explodes = true},
}
const DEFAULT := {
	name = "",
	decay = 0,
	harm = 0,
	wets = false,
	blocks = true,
	erases = false,
	explodes = false,
	boils = -1,
	cools = -1
}
## The harm of a blast to each creature in the cloud, and how far it is heard.
const BLAST := 2
const BLAST_LOUD := 8
const MAX := 9
const OPAQUE := 3
const SMOKE_PUFF := 4
const VENT_LEVEL := 5
## What a tile with no gas holds: no kind, no amount.
const NONE := Vector2i(-1, 0)
const INNER := Rect2i(1, 1, Grid.W - 2, Grid.H - 2)

## What Rust is given for a kind that does not cool.
const NO_KIND := 255

## The decay chance by gas kind, a byte each, for Rust.
static var _decay := _column("decay")
## The kind each gas cools to by gas kind, a byte each, NO_KIND for those that do not.
static var _cool := _cools()


## The value of `column` for gas kind `kind`.
static func of(kind: int, column: String) -> Variant:
	return ROWS.get(kind, {}).get(column, DEFAULT[column])


## Gas can lie on p.
static func holds(w: World, p: Vector2i) -> bool:
	return INNER.has_point(p) and Tiles.gas[w.tiles[Grid.index(p)]] == 1


## Vector2i(kind, amount) of the gas on p, or NONE.
static func at(w: World, p: Vector2i) -> Vector2i:
	return w.gas.get(p, NONE)


## Gas on p thick enough to block sight.
static func blocks(w: World, p: Vector2i) -> bool:
	return not w.gas.is_empty() and at(w, p).y >= OPAQUE and of(at(w, p).x, "blocks")


## Gas on p that hurts whoever stands in it.
static func harms(w: World, p: Vector2i) -> bool:
	return of(at(w, p).x, "harm") > 0


## Lays `amount` of `kind` of `heat` on p without a word: onto the same kind it
## adds (up to MAX) and keeps the hotter heat, onto another the greater one stays.
static func put(w: World, p: Vector2i, kind: int, amount: int, heat := MAX) -> void:
	if amount <= 0 or not holds(w, p):
		return
	var was := at(w, p)
	if was.x == kind:
		w.gas[p] = Vector2i(kind, mini(MAX, was.y + amount))
		if of(kind, "cools") >= 0:
			w.gas_heat[p] = maxi(w.gas_heat.get(p, MAX), mini(MAX, heat))
	elif amount >= was.y:
		w.gas[p] = Vector2i(kind, mini(MAX, amount))
		if of(kind, "cools") >= 0:
			w.gas_heat[p] = mini(MAX, heat)
		else:
			w.gas_heat.erase(p)
	w._changed()


## `put`, and the cloud is told of when p had none: for spells and fire.
static func add(w: World, p: Vector2i, kind: int, amount: int, heat := MAX) -> void:
	var fresh := not w.gas.has(p) and holds(w, p) and amount > 0
	put(w, p, kind, amount, heat)
	if fresh:
		w.emit({t = &"gas", at = p, kind = kind})


## Fire is on p: fog there turns to steam. A cloud of an exploding gas goes off, the
## tiles joined to p by that gas all at once. Each creature in it is hurt BLAST and
## set alight, each tile that burns catches, and the gas is gone.
static func light(w: World, p: Vector2i) -> void:
	var here := at(w, p)
	var kind := here.x
	if w.gas.is_empty():
		return
	if of(kind, "boils") >= 0:
		w.gas.erase(p)
		# The steam it makes is of full heat (`add`).
		add(w, p, of(kind, "boils"), here.y)
		return
	if not of(kind, "explodes"):
		return
	var cloud: Array[Vector2i] = [p]
	var i := 0
	while i < cloud.size():
		for d in Grid.DIRS:
			var q: Vector2i = cloud[i] + d
			if at(w, q).x == kind and not cloud.has(q):
				cloud.append(q)
		i += 1
	for q in cloud:
		w.gas.erase(q)
	w.emit({t = &"blast", at = p, kind = kind, tiles = cloud})
	Hearing.noise(w, p, BLAST_LOUD, "쾅", false, -1)
	for q in cloud:
		var a := w.actor_at(q)
		if a != null:
			Harm.hurt(w, a, BLAST)
			Status.ignite(w, a)
		Terrain.ignite(w, q)
	w._changed()


## The amount the vent on p keeps up.
static func level_of(w: World, p: Vector2i) -> int:
	return w.vent_levels.get(p, VENT_LEVEL)


## One round of gas.
static func tick(w: World) -> void:
	if w.outcome != &"":
		return
	for p: Vector2i in w.burning.keys():
		light(w, p)
		if at(w, p).x != STEAM:
			add(w, p, SMOKE, SMOKE_PUFF)
	for p: Vector2i in w.vents:
		put(w, p, w.vents[p], level_of(w, p) - (at(w, p).y if at(w, p).x == w.vents[p] else 0))
	if w.gas.is_empty():
		return
	spread(w)
	for a in w.actors:
		var kind := at(w, a.pos).x
		if a.alive() and of(kind, "harm") > 0:
			w.emit({t = &"scald", id = a.id, at = a.pos, kind = kind})
			Harm.hurt(w, a, of(kind, "harm"))
		if a.alive() and of(kind, "wets"):
			Status.soak(w, a)
	for p: Vector2i in w.gas:
		if of(w.gas[p].x, "wets") and w.tile(p) == World.DRUM and not w.wet.has(p):
			Drums.soak(w, p)
		if of(w.gas[p].x, "erases"):
			Scent.clear(w, p)
	w._changed()


## The gas after a round of spreading, and of thinning unless `thin` is false.
static func spread(w: World, thin := true) -> void:
	var amount := PackedByteArray()
	amount.resize(w.tiles.size())
	var kind := amount.duplicate()
	var heat := amount.duplicate()
	for p: Vector2i in w.gas:
		amount[Grid.index(p)] = w.gas[p].y
		kind[Grid.index(p)] = w.gas[p].x
		heat[Grid.index(p)] = w.gas_heat.get(p, MAX)
	var hold := Native.mask(w.tiles, Tiles.gas)
	var decay := _decay if thin else PackedByteArray()
	var left := Native.gas(amount, kind, heat, hold, decay, _cool, w.rng.randi(), Grid.W)
	w.gas = {}
	w.gas_heat = {}
	for j in range(0, left.size(), 4):
		var p := Grid.at(left[j])
		w.gas[p] = Vector2i(left[j + 2], left[j + 1])
		if left[j + 3] > 0:
			w.gas_heat[p] = left[j + 3]


static func _column(column: String) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(256)
	for kind: int in ROWS:
		out[kind] = of(kind, column)
	return out


static func _cools() -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(256)
	out.fill(NO_KIND)
	for kind: int in ROWS:
		if of(kind, "cools") >= 0:
			out[kind] = of(kind, "cools")
	return out
