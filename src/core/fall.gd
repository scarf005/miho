class_name Fall
extends RefCounted
## Pushing a creature. It slides up to n tiles and stops at anything it cannot
## walk onto: a wall, a pond, a lantern, a creature. Sky is not stopped by: a
## creature of heaven that slides into it falls out of the game, drops no
## talisman and counts as a kill; Miho falls one storey down and lands on a
## fresh storey with her health and tails (her tails kept up to what that
## storey allows). On the first storey she has nowhere to fall to, and stops
## at the edge like at a wall. Pushed onto the stairs, the elixir or a peach,
## Miho takes them as if she had stepped there (World.arrive). A creature that
## slides at all gives one `push` event first, at the tile it slides from.
## A collapsing floor (Traps) drops a creature the same way, from where it stands.


static func push(w: World, a: Actor, dir: Vector2i, n: int) -> void:
	if not Grid.DIRS.has(dir):
		return
	var depth := w.depth
	for i in n:
		var to := a.pos + dir
		if w.tile(to) == World.SKY:
			drop(w, a, to)
			return
		if not w.vacant(to):
			return
		if i == 0:
			w.emit({t = &"push", id = a.id, at = a.pos})
		w.move(a, to)
		if a.faction == Actor.FOX and w.arrive(a):
			return
		if not a.alive() or w.depth != depth:
			return


## `a` falls from its tile into the sky at `into`: a creature of heaven is gone,
## Miho drops a storey (nothing happens to her on the first).
static func drop(w: World, a: Actor, into: Vector2i) -> void:
	if a.faction == Actor.HEAVEN:
		_lose(w, a, into)
	elif w.depth > 1:
		_drop(w, a, into)


## A creature of heaven falls from the edge at `into`.
static func _lose(w: World, a: Actor, into: Vector2i) -> void:
	a.hp = 0
	a.intent.clear()
	Mind.forget(w, a)
	w.emit({t = &"fall", id = a.id, from = a.pos, at = into})
	w.emit({t = &"die", id = a.id, at = a.pos})
	w.tails = mini(w.max_tails(), w.tails + 1)
	w.emit({t = &"soul", id = a.id, at = a.pos})
	w._changed()


## Miho falls to a new storey one below. Whatever flies or stands on the old
## one is left behind.
static func _drop(w: World, me: Actor, into: Vector2i) -> void:
	w.emit({t = &"fall", id = me.id, from = me.pos, at = into, depth = w.depth - 1})
	w.depth -= 1
	w.tails = mini(w.tails, w.max_tails())
	w.scent.clear()
	for s in w.shots:
		s.gone = true
	FloorGen.build(w)
	w._changed()
	w.sense()
