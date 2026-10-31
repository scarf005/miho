class_name Drums
extends RefCounted
## War drums (북). From storey 4 (tier 2) one stands in a lit room, at a chance.
## A drum blocks walking. A creature of heaven that is at least sharp (wits 1)
## and can move, starting to hunt Miho while a drum stands within REACH steps
## of walking, runs to the drum instead of attacking and strikes it from a tile
## next to it. The blow booms "둥" for the whole storey: Miho hears it, and
## every other creature of heaven that is not hunting and can hear goes to
## search the tile where the drummer last saw Miho.
##
## Water (a water spell ending beside it, or dousing it) wets a drum for
## WET_ROUNDS: struck, it makes no sound. An orb that hits a drum, or Miho
## walking into it, tears it (찌익), and a torn drum is flat and walkable and
## makes no sound for good. A drum burns like other wooden tiles. The creature
## does not know a drum is wet.

const FIRST_TIER := 2
const CHANCE := 0.5
const REACH := 8
const WET_ROUNDS := 20
## How far the boom is heard: everywhere.
const LOUD := Grid.W + Grid.H
const NONE := Vector2i(-1, -1)


## A drum that can be struck: whole and not burning.
static func usable(w: World, p: Vector2i) -> bool:
	return w.tile(p) == World.DRUM and not w.burning.has(p)


## `a` has just started hunting: it plans to drum if it is sharp enough, can
## move, and a drum is within REACH steps; the nearest one.
static func plan(w: World, a: Actor) -> void:
	a.drum = NONE
	if Bestiary.wits(a.kind) < Bestiary.SHARP or a.info().get("move", &"static") == &"static":
		return
	var dist := _dist(w, a)
	var best := REACH + 1
	var i := w.tiles.find(World.DRUM)
	while i >= 0:
		var stand := _stand(dist, Grid.at(i))
		if usable(w, Grid.at(i)) and not stand.is_empty() and stand.steps < best:
			a.drum = Grid.at(i)
			best = stand.steps
		i = w.tiles.find(World.DRUM, i + 1)


## The creature's turn when it is bound for a drum: a step towards it, or the
## blow when it stands beside it. False when it has no drum to go to (or cannot
## go now), and it hunts as usual.
static func go(w: World, a: Actor) -> bool:
	if a.drum == NONE or a.rooted > 0:
		return false
	var stand := _stand(_dist(w, a), a.drum)
	if not usable(w, a.drum) or stand.is_empty():
		a.drum = NONE
		return false
	if stand.steps == 0:
		strike(w, a)
		a.drum = NONE
		return true
	if Mind._step_to(w, a, stand.at):
		return true
	a.drum = NONE
	return false


## `a` beats the drum it stands beside.
static func strike(w: World, a: Actor) -> void:
	var wet := w.wet.has(a.drum)
	w.emit({t = &"drum", id = a.id, at = a.drum, wet = wet})
	if wet:
		return
	w.noise(a.drum, LOUD, "둥", false, a.id)
	for b in w.actors:
		if (
			b.alive()
			and b != a
			and b.faction == Actor.HEAVEN
			and b.alert != Actor.HUNT
			and not b.info().get("deaf", false)
		):
			b.alert = Actor.SEARCH
			b.target = a.target
			b.lost = 0


## A drum wet for WET_ROUNDS from now.
static func soak(w: World, p: Vector2i) -> void:
	w.wet[p] = WET_ROUNDS
	w.emit({t = &"soak", at = p})


## One round passes: wet drums dry a little.
static func dry(w: World) -> void:
	for p: Vector2i in w.wet.keys():
		w.wet[p] -= 1
		if w.wet[p] <= 0:
			w.wet.erase(p)


## Steps of walking from `a` to every tile within REACH (-1 beyond).
static func _dist(w: World, a: Actor) -> PackedInt32Array:
	return Grid.search(a.pos, Masks.walk(w, a, Mind._walkable(w, a)), REACH).dist


## The nearest tile beside `drum` that `dist` reaches: {at, steps}, or empty.
static func _stand(dist: PackedInt32Array, drum: Vector2i) -> Dictionary:
	var out := {}
	for d in Grid.DIRS:
		var p := drum + d
		var steps := dist[Grid.index(p)] if Grid.inside(p) else -1
		if steps >= 0 and (out.is_empty() or steps < out.steps):
			out = {at = p, steps = steps}
	return out
