class_name Traps
extends RefCounted
## Plates in the floor (Brogue CE hidden traps). Placement lays them by tier in
## World.traps, each as the tile kind it becomes once found, while the tile
## itself stays floor, so nothing that reads the board gives one away. Miho
## finds a plate when she sees its tile and the tile is lit or within REACH of
## her; a plate that goes off in her sight is found too. A found plate stays on
## her map. Whoever steps onto a plate, found or not, sets it off, and a plate
## goes off again for every creature that steps on it.
##
## Heaven made the plates and walks round every one of them, found or not. A
## creature a push or a fall drops onto one sets it off.
##
## A hidden door (World.secrets, DCSS secret doors) is a wall between two rooms
## until Miho finds it the same way, and then a closed door. It is sealed from
## both sides until then, so heaven does not use it either, and the storey is
## whole without it. A hit that cracks it leaves a cracked wall and no door.
##
## 징 함정 (alarm plate): a gong that the whole storey hears; every creature of
## heaven that can hear and is not hunting goes to search the plate.
## 허방다리 (collapsing floor): the creature drops through the floor (Fall):
## heaven's is gone, Miho goes down a storey.
## 불씨 함정 (fire plate): sets FLAME_REACH tiles alight in the direction the
## creature was stepping.
## 덩굴 함정 (vine plate): roots every creature within VINE_REACH of the plate,
## itself included, for ROOT_ROUNDS.

## How near to Miho a plate must be to be found in the dark.
const REACH := 1
const GONG := "댕"
const CLICK := "철컥"
const FLAME_REACH := 3
const VINE_REACH := 1
const ROOT_ROUNDS := 4


## The plates Miho has found: position -> tile kind.
static func found(w: World) -> Dictionary:
	var out := {}
	for p: Vector2i in w.traps:
		if w.tile(p) == w.traps[p]:
			out[p] = w.traps[p]
	return out


## Miho finds every plate and hidden door she sees that is lit or next to her,
## and every plate that went off this round; a plate that went off already
## told her so.
static func find(w: World) -> void:
	var sprung := {}
	for e in w.events:
		if e.t == &"trap" and e.depth == w.depth:
			sprung[e.at] = true
	for p: Vector2i in w.traps:
		var kind: int = w.traps[p]
		if w.tile(p) == kind or not w.open_floor(p) or not _spotted(w, p, sprung.has(p)):
			continue
		w.set_tile(p, kind)
		if not sprung.has(p):
			w.emit({t = &"find", at = p, kind = kind})
	for p: Vector2i in w.secrets.keys():
		if w.tile(p) != World.WALL:
			w.secrets.erase(p)
		elif _spotted(w, p, false):
			w.secrets.erase(p)
			w.set_tile(p, World.DOOR)
			w.emit({t = &"find", at = p, kind = World.DOOR})


## Miho sees p and it is lit, next to her, or `sprung`.
static func _spotted(w: World, p: Vector2i, sprung: bool) -> bool:
	return (
		w.seen[Grid.index(p)] == 1 and (sprung or w.lit(p) or Grid.cheb(p, w.player().pos) <= REACH)
	)


## `a` has stepped onto `a.pos` moving along `dir`: a plate there goes off.
static func step(w: World, a: Actor, dir: Vector2i) -> void:
	var kind: int = w.traps.get(a.pos, -1)
	if kind < 0:
		return
	w.emit({t = &"trap", id = a.id, at = a.pos, kind = kind, depth = w.depth})
	match kind:
		World.TRAP_ALARM:
			w.noise(a.pos, Drums.LOUD, GONG, true, a.id)
		World.TRAP_COLLAPSE:
			Fall.drop(w, a, a.pos)
		World.TRAP_FIRE:
			_flame(w, a.pos, dir)
		World.TRAP_VINE:
			_vines(w, a.pos)


## Sets the FLAME_REACH tiles from `at` along `dir` alight, as far as they are
## open floor; not a plate, which would burn to ash and hide.
static func _flame(w: World, at: Vector2i, dir: Vector2i) -> void:
	for i in range(1, FLAME_REACH + 1):
		var p := at + dir * i
		if not w.open_floor(p):
			return
		if not w.traps.has(p):
			w.ignite(p, true)


static func _vines(w: World, at: Vector2i) -> void:
	for y in range(-VINE_REACH, VINE_REACH + 1):
		for x in range(-VINE_REACH, VINE_REACH + 1):
			var a := w.actor_at(at + Vector2i(x, y))
			if a != null:
				a.rooted = maxi(a.rooted, ROOT_ROUNDS)
				w.emit({t = &"root", id = a.id, rounds = ROOT_ROUNDS})
