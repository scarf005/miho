class_name Status
extends RefCounted
## What water leaves on a creature, for a number of rounds (Actor).
##
## 젖음 (Actor.wet, WET rounds): water wets whoever stands where it reaches
## (Terrain.wash: every spell of 수 where it ends, 물줄기, 단비, 진흙), and
## steam whoever stands in it as a round ends (Gas). A wet creature's steps
## splash, heard SPLASH tiles at least (`tread`; Miho's alarm heaven, mud
## stays silent). Fire that would set it alight dries it instead (`ignite`),
## and so does a burning tile it stands in (Terrain.burn).

const WET := 4
const SPLASH := 2
const SPLASH_WORD := "철벅"
## What each status is called, by its key (`of`).
const NAME := {&"wet": "젖음"}


## The status `a` holds, by key, or empty.
static func of(a: Actor) -> StringName:
	return &"wet" if a.wet > 0 else &""


## The rounds left of the status `a` holds.
static func rounds(a: Actor) -> int:
	return a.wet


## Water reaches `a`: it is wet for WET rounds.
static func soak(w: World, a: Actor) -> void:
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


## Fire strikes `a`: it dries when wet, else its tile catches fire, even
## where nothing burns (`wild`: the fire always spreads).
static func ignite(w: World, a: Actor, wild := false) -> void:
	if not (a.alive() and dry(w, a)):
		w.ignite(a.pos, true, wild)


## How far `a`'s step onto a tile of `tread` ([loud, word], Tiles) is heard,
## and the word for it: a wet one splashes.
static func tread(a: Actor, tread_of: Array) -> Array:
	return [maxi(tread_of[0], SPLASH), SPLASH_WORD] if a.wet > 0 else tread_of


## The end of a round: each status runs down a round.
static func tick(w: World) -> void:
	for a in w.actors:
		if a.alive() and a.wet > 0:
			a.wet -= 1
			if a.wet == 0:
				w.emit({t = &"dry", id = a.id, at = a.pos})
