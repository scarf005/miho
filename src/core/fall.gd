class_name Fall
extends RefCounted
## Pushing a creature. It slides up to n tiles and stops at anything it cannot
## walk onto: a wall, a pond, a lantern, a creature. Sky is not stopped by: a
## creature of heaven that slides into it falls out of the game and counts as
## a kill, its scroll (Scrolls) lying where it stood or the nearest tile that
## can hold it; Miho falls to the storey below, as she left
## it (Storeys), and on down while that storey is sky there too. She lands on
## the tile she fell at, or the free tile nearest it across floor and sky, and
## loses DAMAGE health for each storey fallen; her tails are kept up to what
## that storey allows. On the first storey she has nowhere to fall to, and
## stops at the edge like at a wall. Pushed onto the stairs, the elixir or a peach,
## Miho takes them as if she had stepped there (World.arrive). A creature that
## slides at all gives one `push` event first, at the tile it slides from.
## A collapsing floor (Traps) drops a creature the same way, from where it stands.

const DAMAGE := 1


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
		if a.is_miho() and w.arrive(a):
			return
		if not a.alive() or w.depth != depth:
			return


## `a` falls from its tile into the sky at `into`: Miho drops a storey (nothing
## happens to her on the first), and any other creature is gone. An ally does not
## come along.
static func drop(w: World, a: Actor, into: Vector2i) -> void:
	if not a.is_miho():
		_lose(w, a, into)
	elif w.depth > 1:
		_drop(w, a, into)


## A creature falls from the edge at `into`; one of heaven gives what a fall does.
static func _lose(w: World, a: Actor, into: Vector2i) -> void:
	a.hp = 0
	a.intent.clear()
	Mind.forget(w, a)
	w.emit({t = &"fall", id = a.id, from = a.pos, at = into})
	w.emit({t = &"die", id = a.id, at = a.pos, foe = not a.ally()})
	if not a.ally():
		w.player().prey = a.kind
		w.tails = mini(w.max_tails(), w.tails + 1)
		w.emit({t = &"soul", id = a.id, at = a.pos})
		Scrolls.drop(w, a)
	w._changed()


## Miho falls through the sky at `into` to the storeys below. Whatever flies
## or stands on the ones above is left there.
static func _drop(w: World, me: Actor, into: Vector2i) -> void:
	var from := me.pos
	var top := w.depth
	Storeys.leave(w)
	Storeys.enter(w, w.depth - 1)
	while w.depth > 1 and w.tile(into) == World.SKY:
		Storeys.leave(w)
		Storeys.enter(w, w.depth - 1)
	w.emit({t = &"fall", id = me.id, from = from, at = into, depth = w.depth})
	me.pos = Vector2i(-1, -1)  # in the air, off the tile she may land on
	var spot := FloorGen.nearest_free(w, into, Masks.air(w))
	me.pos = spot if spot.x >= 0 else w.start
	Storeys.carry(w)
	w.hurt(me, (top - w.depth) * DAMAGE)
	w.tails = mini(w.tails, w.max_tails())
	w._changed()
	w.sense()
