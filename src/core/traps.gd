class_name Traps
extends RefCounted
## Plates in the floor (Brogue CE hidden traps). Placement lays them by storey in
## World.traps, each as the tile kind it becomes once found, while the tile
## itself stays floor, so nothing that reads the board gives one away. Miho
## finds a plate when she sees its tile and the tile is lit or within REACH of
## her; a plate that goes off in her sight is found too. A found plate stays on
## her map. Whoever steps onto a plate, found or not, sets it off, and so does a
## projectile that flies over one with nobody on it; a plate goes off again every
## time.
##
## Heaven walks round the plates until it hunts, and then goes over them, as Brogue
## CE `monsterAvoids` keeps only wandering monsters off traps, so a gong does not
## ring again for each searcher it calls. An ally always walks round them.
##
## A hidden door (World.secrets, DCSS secret doors) is a wall between two rooms
## until Miho finds it the same way, and then a closed door. It is sealed from
## both sides until then, so heaven does not use it either, and the storey is
## whole without it. A hit that cracks it leaves a cracked wall and no door.
##
## 징 함정 (alarm plate): a gong that the whole storey hears; every creature of
## heaven that can hear and is not hunting goes to search the plate.
## 허방다리 (collapsing floor): the creature drops through the floor (Fall):
## heaven's is gone, Miho goes down a storey. A projectile drops too.
## 불씨 함정 (fire plate): sets FLAME_REACH tiles alight in the direction the
## creature was stepping or the projectile flying.
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
## and every plate she saw go off this round, as `was`, what she saw when it began,
## tells; a plate that went off already told her so. A hat keeps one it hides from
## telling.
static func find(w: World, was: PackedByteArray) -> void:
	var sprung := {}
	for e in w.events:
		if e.t == &"trap" and e.depth == w.depth and not Hat.veils(w, e.get("id", 0)):
			sprung[e.at] = true
	for p: Vector2i in w.traps:
		var kind: int = w.traps[p]
		if w.tile(p) == kind or not w.open_floor(p) or not _spotted(w, p, sprung.has(p), was):
			continue
		w.set_tile(p, kind)
		if not sprung.has(p):
			w.emit({t = &"find", at = p, kind = kind})
	for p: Vector2i in w.secrets.keys():
		if w.tile(p) != World.WALL:
			w.secrets.erase(p)
		elif _spotted(w, p, false, was):
			w.secrets.erase(p)
			w.set_tile(p, World.DOOR)
			w.emit({t = &"find", at = p, kind = World.DOOR})


## Miho sees p and it is lit or next to her, or it is `sprung` and she saw it then.
static func _spotted(w: World, p: Vector2i, sprung: bool, was: PackedByteArray) -> bool:
	var i := Grid.index(p)
	if sprung:
		return w.seen[i] == 1 or (i < was.size() and was[i] == 1)
	return w.seen[i] == 1 and (w.lit(p) or Grid.cheb(p, w.player().pos) <= REACH)


## Whether `a` keeps off the plate at `p`, if there is one there.
static func bars(w: World, a: Actor, p: Vector2i) -> bool:
	return w.traps.has(p) and (a.ally() or a.alert != Actor.HUNT)


## `a` has stepped onto `a.pos` moving along `dir`: a plate there goes off.
static func step(w: World, a: Actor, dir: Vector2i) -> void:
	var kind: int = w.traps.get(a.pos, -1)
	if kind < 0:
		return
	w.emit({t = &"trap", id = a.id, at = a.pos, kind = kind, depth = w.depth})
	if kind == World.TRAP_COLLAPSE:
		Fall.drop(w, a, a.pos)
	else:
		_go_off(w, kind, a.pos, dir, a.id)


## `s` has flown onto `s.pos`, with nobody on it: a plate there goes off. Its gong is
## heard by Miho whoever cast it, for she did not press it herself.
static func fly(w: World, s: Shot) -> void:
	var kind: int = w.traps.get(s.pos, -1)
	if kind < 0:
		return
	var spell := s.spell.tag()
	w.emit({t = &"trap", shot = s.id, spell = spell, at = s.pos, kind = kind, depth = w.depth})
	if kind == World.TRAP_COLLAPSE:
		s.gone = true
		w.emit({t = &"fade", shot = s.id, at = s.pos, dropped = true, spell = spell})
		w._changed()
	else:
		_go_off(w, kind, s.pos, s.dir, 0)


static func _go_off(w: World, kind: int, at: Vector2i, dir: Vector2i, by: int) -> void:
	match kind:
		World.TRAP_ALARM:
			Hearing.noise(w, at, Drums.LOUD, GONG, true, by)
		World.TRAP_FIRE:
			_flame(w, at, dir)
		World.TRAP_VINE:
			_vines(w, at)


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
