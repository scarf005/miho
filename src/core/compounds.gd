class_name Compounds
extends RefCounted
## What each of the ten compounds (Cards.PAIRS) does where it reaches. A spray
## of it covers its own shape (Spray.SHAPE); carried on a wisp or an orb it acts
## on the 3x3 round where the projectile ends (벽 가르기 on the first wall ahead
## of it and that wall's neighbours across its line), the creature it struck
## there among them. Each copy past the first reaches one tile farther: a
## spray's fan, line, square or cleave (Spray.cover), the square round where a
## projectile ends. Other slots in a spray add their own plain effect where it
## reaches (Spray).
##
## 상생, one grows the other:
## 들불 sets what burns alight, and the creatures it reaches (Status), and
## that fire always spreads (World.wild).
## 용암 leaves hot ground (HOT) for HOT_ROUNDS on walkable ground that is not
## water: whoever stands on it as a round ends takes its harm, unless it eats
## fire. Heaven walks round it.
## 유탄 hurts every creature it reaches for SHRAPNEL.
## 서리 freezes each creature it reaches for FROST rounds (Status: it cannot
## move and takes double the next harm), and freezes ponds, and the veil of
## dokkaebi fire (Veil), to ice (World.ICE) that can be walked.
## 단비 roots each creature it reaches RAIN rounds, and douses fire and
## lanterns and wets drums (Terrain.wash).
## 상극, the two react:
## 증기 lays STEAM of steam (Gas.STEAM): it blocks sight, scalds whoever stands
## in it each round and wets drums.
## 쇳물 leaves hot iron: hot ground like 용암's, but harsher.
## 가시 grows thorns (World.THORNS) on open ground and pricks each creature it
## reaches for THORN. Whoever steps onto thorns takes THORN; they let sight
## through and burn.
## 벽 가르기 brings every breakable wall it reaches down to rubble, silently.
## 진흙 douses, then turns open ground to mud (World.MUD): a step onto it takes
## MUD rounds (the creature is rooted till then) and makes no sound.
## Open ground is walkable, not a door, a skybridge or water, not the stairs,
## the elixir or a peach, and not burning.

const LAVA := 0
const MOLTEN := 1
## Hot ground by kind: what it is called and its harm each round.
const HOT := [{name = "뜨거운 땅", harm = 1}, {name = "뜨거운 쇠", harm = 2}]
const HOT_ROUNDS := 3
const SHRAPNEL := 1
const FROST := 2
const RAIN := 3
const STEAM := Gas.MAX
const THORN := 1
const MUD := 2


## `s` carries its compounds to `at`, where it ends.
static func land(w: World, s: Shot, at: Vector2i) -> void:
	var struck := w.actor_at(at)
	for c in s.spell.compounds():
		var r := 1 + s.spell.extra(c)
		var tiles := Spray.cleave(w, at, s.dir, r) if c == &"split" else Spray.square(w, at, r)
		ground(w, c, tiles)
		for a in Spray.on(w, s, tiles):
			if a == struck or Spray.reaches(w, s, a):
				strike(w, s, c, a)
				if a != struck and a.alive():
					Mind.struck(w, a, s)


## What compound `c` does to the ground on `tiles`.
static func ground(w: World, c: StringName, tiles: Array[Vector2i]) -> void:
	match c:
		&"wildfire":
			for p in tiles:
				w.ignite(p, false, true)
		&"lava":
			heat(w, tiles, LAVA)
		&"molten":
			heat(w, tiles, MOLTEN)
		&"frost":
			_become(
				w, tiles.filter(func(p): return w.tile(p) in [World.POND, World.VEIL]), World.ICE
			)
		&"rain":
			for p in tiles:
				Terrain.wash(w, p)
		&"steam":
			for p in tiles:
				Gas.add(w, p, Gas.STEAM, STEAM)
		&"thorn":
			_become(w, tiles.filter(func(p): return _open(w, p)), World.THORNS)
		&"split":
			_split(w, tiles)
		&"mud":
			for p in tiles:
				Terrain.wash(w, p)
			_become(w, tiles.filter(func(p): return _open(w, p)), World.MUD)


## What compound `c` does to creature `a` it reaches.
static func strike(w: World, s: Shot, c: StringName, a: Actor) -> void:
	match c:
		&"wildfire":
			Status.ignite(w, a, true)
		&"shrapnel":
			Elements.harm(w, s, a, SHRAPNEL)
		&"frost":
			Status.freeze(w, a, FROST)
		&"rain":
			Elements.root(w, a, RAIN)
		&"thorn":
			Elements.harm(w, s, a, THORN)


## `a` has stepped onto `to`: thorns prick it, mud holds it.
static func step(w: World, a: Actor, to: Vector2i) -> void:
	match w.tile(to):
		World.THORNS:
			w.emit({t = &"prick", id = a.id, at = to})
			w.hurt(a, THORN)
		World.MUD:
			a.rooted = maxi(a.rooted, MUD)


## A round of hot ground: it sears whoever stands on it and cools by a round.
static func tick(w: World) -> void:
	if w.outcome != &"" or w.hot.is_empty():
		return
	var flame := Spell.make([Cards.FOX, Cards.FIRE])
	var cooled := {}
	for p: Vector2i in w.hot.keys():
		var h: Vector2i = w.hot[p]
		var a := w.actor_at(p)
		if a != null:
			w.emit({t = &"sear", id = a.id, at = p, kind = h.x})
			if Bestiary.absorbs(a.kind, flame):
				w.emit({t = &"absorb", id = a.id, at = p})
			else:
				w.hurt(a, HOT[h.x].harm)
		if h.y <= 1:
			w.hot.erase(p)
			cooled.get_or_add(h.x, []).append(p)
		else:
			w.hot[p] = Vector2i(h.x, h.y - 1)
	for kind: int in cooled:
		w.emit({t = &"cool", at = cooled[kind][0], tiles = cooled[kind], kind = kind})


## Open ground a compound may turn into another kind.
static func _open(w: World, p: Vector2i) -> bool:
	var t := w.tile(p)
	return (
		w.open_floor(p)
		and t not in [World.DOOR, World.DOOR_OPEN, World.BRIDGE]
		and not Tiles.of(t, "douses")
		and not (p == w.stairs or p == w.elixir or w.peaches.has(p))
		and not w.burning.has(p)
	)


## Lays hot ground of `kind` on the walkable dry tiles; the harsher kind and the
## longer time stay where it lies already.
static func heat(w: World, tiles: Array[Vector2i], kind: int) -> void:
	var laid: Array[Vector2i] = []
	for p in tiles:
		if w.open_floor(p) and not Tiles.of(w.tile(p), "douses"):
			var was: Vector2i = w.hot.get(p, Vector2i(kind, 0))
			w.hot[p] = Vector2i(maxi(was.x, kind), maxi(was.y, HOT_ROUNDS))
			laid.append(p)
	if not laid.is_empty():
		w.emit({t = &"heat", at = laid[0], tiles = laid, kind = kind})


static func _become(w: World, tiles: Array, to: int) -> void:
	var changed: Array[Vector2i] = []
	for p: Vector2i in tiles:
		if w.tile(p) != to:
			w.set_tile(p, to)
			changed.append(p)
	if not changed.is_empty():
		w.emit({t = &"become", at = changed[0], tiles = changed, tile = to})


## Each breakable wall on `tiles` takes one hit, then those still standing
## another, till all are rubble.
static func _split(w: World, tiles: Array[Vector2i]) -> void:
	var walls := tiles.filter(func(p): return Terrain.wall(w.tile(p)))
	while not walls.is_empty():
		walls = walls.filter(func(p): return Terrain.breakable(w, p))
		for p: Vector2i in walls:
			Terrain.hit(w, p)
		walls = walls.filter(func(p): return Terrain.wall(w.tile(p)))
