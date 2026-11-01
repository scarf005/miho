class_name Status
extends RefCounted
## What water, fire and frost leave on a creature, for a number of rounds (Actor). A
## creature holds at most one status at a time.
##
## 젖음 (Actor.wet, WET rounds): water wets whoever stands where it reaches
## (Terrain.wash: every spell of 수 where it ends, 물줄기, 단비, 진흙), and
## steam whoever stands in it as a round ends (Gas). A wet creature's steps
## splash, heard SPLASH tiles at least (`tread`; Miho's alarm heaven, mud
## stays silent). Fire that would set it alight dries it instead (`ignite`),
## and so does a burning tile it stands in (Terrain.burn).
##
## 불붙음 (Actor.alight, ALIGHT rounds): fire that strikes a creature of heaven
## sets it alight (`ignite`: a fire wisp any creature, other fire a wood one).
## From the round after, it burns for World.FIRE_DAMAGE as each round ends (a
## burning tile under it adds nothing; Terrain.burn); it lights the tiles round
## it like a burning tile (Light). Water puts it out and wets it. Miho
## never catches alight: fire that would set her alight sets her tile alight,
## even where nothing burns, so she can step off it before it burns her.
##
## 얼어붙음 (Actor.frozen): 서리 (Compounds.FROST rounds, twice that on a wet
## creature, which is then no longer wet) freezes a creature and puts out its
## fire. It is rooted as long (Actor.rooted: it cannot move). The next harm it
## takes is doubled and breaks the ice, and fire that would set it alight thaws
## it instead; either frees it. Water does not wet it.

const WET := 4
const SPLASH := 2
const SPLASH_WORD := "철벅"
const ALIGHT := 3
## Times as long frost holds a wet creature, and times the harm it takes while
## frozen (`shatter`).
const FROZEN_WET := 2
const SHATTER := 2
## What each status is called, by its key (`of`).
const NAME := {&"wet": "젖음", &"alight": "불붙음", &"frozen": "얼어붙음"}
## The event that tells each condition besides a status ends, by Actor field.
const ENDS := {&"rooted": &"unroot", &"stunned": &"unstun", &"blind": &"unblind"}


## The status `a` holds, by key, or empty.
static func of(a: Actor) -> StringName:
	if a.frozen > 0:
		return &"frozen"
	if a.alight > 0:
		return &"alight"
	return &"wet" if a.wet > 0 else &""


## The rounds left of the status `a` holds.
static func rounds(a: Actor) -> int:
	return maxi(a.wet, maxi(a.alight, a.frozen))


## Water reaches `a`: its fire goes out, and, unless frozen, it is wet for
## WET rounds.
static func soak(w: World, a: Actor) -> void:
	if a.alight > 0:
		_quench(w, a)
	if a.frozen > 0:
		return
	if a.wet <= 0:
		w.emit({t = &"wet", id = a.id, at = a.pos, rounds = WET})
	a.wet = WET


## Fire reaches `a`: a wet creature dries, true; false when it was dry.
static func dry(w: World, a: Actor) -> bool:
	if a.wet <= 0:
		return false
	a.wet = 0
	w.emit({t = &"dry", id = a.id, at = a.pos})
	return true


## Fire strikes `a`: it thaws when frozen and dries when wet; else a creature
## of heaven is alight for ALIGHT rounds, and Miho's tile catches fire
## (`wild`: it always spreads).
static func ignite(w: World, a: Actor, wild := false) -> void:
	if a.alive() and a.frozen > 0:
		_thaw(w, a)
		return
	if a.alive() and dry(w, a):
		return
	if a.faction == Actor.FOX or not a.alive():
		w.ignite(a.pos, true, wild)
		return
	if a.alight <= 0:
		w.emit({t = &"alight", id = a.id, at = a.pos, rounds = ALIGHT})
	a.alight = ALIGHT
	w._changed()


## Frost reaches `a`: it is frozen and rooted for `n` rounds, twice that when
## wet; its fire goes out.
static func freeze(w: World, a: Actor, n: int) -> void:
	if a.wet > 0:
		a.wet = 0
		n *= FROZEN_WET
		w.emit({t = &"dry", id = a.id, at = a.pos})
	if a.alight > 0:
		_quench(w, a)
	a.frozen = maxi(a.frozen, n)
	a.rooted = maxi(a.rooted, n)
	w.emit({t = &"freeze", id = a.id, at = a.pos, rounds = n})


## `a` is about to be hurt: true when it is frozen, and the ice breaks, which
## frees it (World.hurt doubles the harm).
static func shatter(a: Actor) -> bool:
	if a.frozen <= 0:
		return false
	a.frozen = 0
	a.rooted = 0
	return true


## How far `a`'s step onto a tile of `tread` ([loud, word], Tiles) is heard,
## and the word for it: a wet one splashes.
static func tread(a: Actor, tread_of: Array) -> Array:
	return [maxi(tread_of[0], SPLASH), SPLASH_WORD] if a.wet > 0 else tread_of


## `a`'s condition `key` (an Actor field in ENDS) runs down a round; its end is
## told, unless the ice that held `a` melted in the same round (`thaw` tells it).
static func lapse(w: World, a: Actor, key: StringName) -> void:
	var left: int = a.get(key)
	if left <= 0:
		return
	a.set(key, left - 1)
	if (
		left > 1
		or (key == &"rooted" and w.events.any(func(e): return e.t == &"thaw" and e.id == a.id))
	):
		return
	w.emit({t = ENDS[key], id = a.id, at = a.pos})


## `a` is let go of every condition in ENDS at once, as on a new storey.
static func release(w: World, a: Actor) -> void:
	for key in ENDS:
		if a.get(key) > 0:
			a.set(key, 0)
			w.emit({t = ENDS[key], id = a.id, at = a.pos})


## The end of a round: whoever was alight before this round burns, and each
## status runs down a round.
static func tick(w: World) -> void:
	if w.outcome != &"":
		return
	var lit := w.events.filter(func(e): return e.t == &"alight").map(func(e): return e.id)
	for a in w.actors.duplicate():
		if w.outcome != &"":
			return
		if a.alive() and a.alight > 0:
			if not lit.has(a.id):
				w.emit({t = &"burn", at = a.pos, id = a.id})
				w.hurt(a, World.FIRE_DAMAGE)
			a.alight -= 1
			if a.alive() and a.alight == 0:
				_quench(w, a)
		if a.alive() and a.wet > 0:
			a.wet -= 1
			if a.wet == 0:
				w.emit({t = &"dry", id = a.id, at = a.pos})
		if a.alive() and a.frozen > 0:
			a.frozen -= 1
			if a.frozen == 0:
				w.emit({t = &"thaw", id = a.id, at = a.pos})


## The ice on `a` melts, and it is free to move.
static func _thaw(w: World, a: Actor) -> void:
	a.frozen = 0
	a.rooted = 0
	w.emit({t = &"thaw", id = a.id, at = a.pos})


static func _quench(w: World, a: Actor) -> void:
	a.alight = 0
	w._changed()
	w.emit({t = &"quench", id = a.id, at = a.pos})
