class_name Harm
extends RefCounted
## Claws strike three times as hard at a creature that is not hunting and does
## not see Miho (Brogue CE Combat.c sneak attack; caught_unawares), so Miho can
## creep up on a sleeper. A creature that was hurt stays wary for WARY_ROUNDS: it
## does not go back to rest and sees Miho one tile farther in the dark.


## Whether a claw at `a` is a sneak attack: it is off guard (not hunting) and
## does not see Miho, or does not know her in guise (Guise); a sleeping or
## blind creature sees nothing, but a blind hunter is on guard.
static func caught_unawares(w: World, a: Actor) -> bool:
	return a.alert != Actor.HUNT and not Guise.knows(w, a)


## The harm a claw of `me` at `foe` does: CLAW, SNEAK times that on a sneak attack,
## and what 쇠발톱 adds (Guise.talon_harm).
static func claw_harm(me: Actor, sneak: bool, foe: Actor = null) -> int:
	return World.CLAW * (World.SNEAK if sneak else 1) + Guise.talon_harm(me, foe)


static func claw(w: World, me: Actor, foe: Actor) -> void:
	var sneak := caught_unawares(w, foe)
	var n := claw_harm(me, sneak, foe)
	w.emit({t = &"claw", id = me.id, target = foe.id, at = foe.pos, n = n, sneak = sneak})
	Hearing.noise(w, foe.pos, 1 if sneak else 3, "퍽", true, me.id)
	hurt(w, foe, n)
	if foe.alive():
		Mind.provoke(w, foe, me)
		Mind.hunt_from(w, foe, me.pos)


static func hurt(w: World, a: Actor, n: int, weak := false) -> void:
	if not a.alive() or Cheat.immune(w, a):
		return
	var shatter := Status.shatter(a)
	n *= Status.SHATTER if shatter else 1
	a.hp -= n
	w.emit({t = &"hurt", id = a.id, n = n, hp = a.hp, at = a.pos, weak = weak, shatter = shatter})
	Guise.hurt(w, a)
	if a.alive():
		if shatter:
			w.emit({t = &"thaw", id = a.id, at = a.pos})
		if a.faction == Actor.HEAVEN:
			Hearing.noise(w, a.pos, World.CRY, "끽", true, a.id)
			Mind.hurt(a)
		return
	w.emit({t = &"die", id = a.id, at = a.pos, foe = a.faction == Actor.HEAVEN})
	a.intent.clear()
	w._changed()
	if a.is_miho():
		w.outcome = &"lost"
		w.emit({t = &"lost"})
		return
	Mind.forget(w, a)
	if a.ally():
		return
	Notice.fallen(w, a)
	reward(w, a)


## What Miho gets for a creature of heaven that is gone: a tail, its soul and the scroll
## it leaves (Scrolls.drop).
static func reward(w: World, a: Actor) -> void:
	w.tails = mini(w.max_tails(), w.tails + 1)
	w.emit({t = &"soul", id = a.id, at = a.pos})
	Scrolls.drop(w, a)
