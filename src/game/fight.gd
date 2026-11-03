class_name Fight
extends RefCounted
## Auto-fight, as DCSS's Tab (autofight.lua): strike the nearest hostile in
## sight when it is next to Miho, else take one step towards it. Of several
## next to her it picks one caught unawares (Harm.caught_unawares, the sneak
## attack). Like DCSS it refuses when she is at or under half her health
## (autofight_stop 50).

## Health, in percent of the most, at and under which Tab refuses.
const STOP := 50


## Whether Miho is too hurt to fight recklessly.
static func too_hurt(w: World) -> bool:
	var me := w.player()
	return 100 * me.hp <= STOP * me.max_hp


## The creatures of heaven Miho sees, nearest first; among those next to her,
## those caught unawares first. Ties go to the older creature.
static func targets(w: World) -> Array[Actor]:
	var list: Array[Actor] = []
	for a in w.actors:
		if a.alive() and a.faction != Actor.FOX and Hat.shown(w, a):
			list.append(a)
	list.sort_custom(func(a, b): return [_rank(w, a), a.id] < [_rank(w, b), b.id])
	return list


static func _rank(w: World, a: Actor) -> int:
	var d := Grid.cheb(a.pos, w.player().pos)
	return d * 2 + (1 if d > 1 or not Harm.caught_unawares(w, a) else 0)


## The move that claws the first target next to Miho, or steps along the
## shortest walk over what she knows towards the nearest one that can be
## reached; empty when there is none.
static func step(w: World) -> Dictionary:
	var me := w.player().pos
	for a in targets(w):
		if Grid.cheb(a.pos, me) == 1:
			return {t = &"move", dir = a.pos - me}
		var open := Travel.open(w)
		open[Grid.index(a.pos)] = 1
		var found := Grid.search(me, open)
		found.from = me
		var path := Travel.route(found, a.pos)
		if not path.is_empty():
			return {t = &"move", dir = path[0] - me}
	return {}


## A creature her claws would catch unawares (Harm.claw): next to Miho, or
## asleep in sight.
static func sneakable(w: World, a: Actor) -> bool:
	var near := Grid.cheb(a.pos, w.player().pos) == 1
	return (
		a.alive()
		and a.faction != Actor.FOX
		and (near or a.asleep() and w.seen[Grid.index(a.pos)] == 1)
		and Hat.shown(w, a)
		and Harm.caught_unawares(w, a)
	)
