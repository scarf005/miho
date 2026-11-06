class_name Fall
extends RefCounted
## Pushing a creature. It slides up to n tiles and stops at anything it cannot
## walk onto: a wall, a pond, a lantern, a creature. At a wall it and the wall take
## one harm for each tile left of the push. Sky is not stopped by: a
## creature of heaven that slides into it falls out of the game and counts as
## a kill, its scroll (Scrolls) lying where it stood or the nearest tile that
## can hold it; Miho falls to the storey below, as she left
## it (Storeys), and on down while that storey is sky there too. She lands on
## the tile she fell at, or the free tile nearest it across floor and sky (walled in,
## the nearest one she can walk to from the start), and
## loses DAMAGE health for each storey fallen; her tails are kept up to what
## that storey allows. Under the 도약 buff (Guise.VAULT) the fall harms nothing, however
## many storeys it drops her, and spends the buff (Guise.land). On the first storey she has
## nowhere to fall to, and stops at the edge like at a wall. Pushed onto the stairs, the
## elixir or a peach, Miho takes them as if she had stepped there (Walk.arrive). A creature
## that slides at all gives one `push` event first, at the tile it slides from.
## A collapsing floor (Traps) drops a creature the same way, from where it stands.

const DAMAGE := 1
## What a push slams into. The rest only stops it.
const WALLS := [World.WALL, World.WALL_CRACKED, World.WOOD_WALL]


static func push(w: World, a: Actor, dir: Vector2i, n: int) -> void:
	if not Grid.DIRS.has(dir):
		return
	var depth := w.depth
	var flies := Bestiary.flies(a.kind)
	var ground := Masks.flown if flies else Tiles.walk
	for i in n:
		var to := a.pos + dir
		if w.tile(to) == World.SKY and not flies:
			drop(w, a, to)
			return
		if WALLS.has(w.tile(to)):
			_crash(w, a, to, n - i)
			return
		if not w.vacant(to, ground):
			return
		if i == 0:
			w.emit({t = &"push", id = a.id, at = a.pos})
		Walk.move(w, a, to)
		if a.is_miho() and (Walk.arrive(w, a) or w.elixir_asked):
			return
		if not a.alive() or w.depth != depth:
			return


## `a` slams into the wall at `at` with `left` tiles of the push to go, as DCSS
## `actor::collide`.
static func _crash(w: World, a: Actor, at: Vector2i, left: int) -> void:
	slam(w, at, left, a.id)
	w.emit({t = &"crash", id = a.id, at = a.pos})
	Harm.hurt(w, a, left)


## The wall at `at` takes `left` hits from what ran into it, `by` a creature's id, and is
## heard, by its foes too when `alarm`.
static func slam(w: World, at: Vector2i, left: int, by: int, alarm := true) -> void:
	var sound: Array = (
		[World.THUD, "쿵"] if Terrain.wall(w.tile(at)) else Tiles.of(w.tile(at), "hit")
	)
	for i in left:
		if WALLS.has(w.tile(at)) and Terrain.breakable(w, at):
			Terrain.hit(w, at)
	Hearing.noise(w, at, sound[0], sound[1], alarm, by)


## `a` falls from its tile into the sky at `into`: Miho drops a storey (nothing
## happens to her on the first), and any other creature is gone. An ally does not
## come along.
static func drop(w: World, a: Actor, into: Vector2i) -> void:
	if Bestiary.flies(a.kind):
		return
	if not a.is_miho():
		_lose(w, a, into)
	elif w.depth > 1:
		_drop(w, a, into)


## `a` and `b` have just traded places: a rotten board one of them left gave way under the
## other, who falls, unless a plate has taken Miho off `depth`, the storey of the trade, already.
static func traded(w: World, a: Actor, b: Actor, depth: int) -> void:
	for c: Actor in [a, b]:
		if c.alive() and w.depth == depth and w.tile(c.pos) == World.SKY:
			drop(w, c, c.pos)


## `by` drags `a` off dry ground to its side: to the free walkable water tile next to both
## that is nearest `by`. With none, or on water already, `a` stays where it is. Miho takes
## what lies there, as on a push.
static func pull(w: World, a: Actor, by: Actor) -> void:
	if Tiles.water[w.tile(a.pos)] == 1:
		return
	var to := a.pos
	var near := INF
	for d in Grid.DIRS:
		var p := a.pos + d
		var gap := Vector2(p - by.pos).length()
		if (
			Tiles.water[w.tile(p)] == 1
			and w.vacant(p)
			and not w.traps.has(p)
			and Grid.cheb(p, by.pos) == 1
			and gap < near
		):
			to = p
			near = gap
	if to == a.pos:
		return
	w.emit({t = &"pull", id = a.id, at = a.pos})
	Walk.move(w, a, to)
	if a.is_miho():
		Walk.arrive(w, a)


## A creature that moves on water stands on a tile that is water no more: it is gone with
## no body, and one of heaven gives what a fall does.
static func stranded(w: World, a: Actor) -> void:
	_gone(w, a, [{t = &"die", id = a.id, at = a.pos, foe = not a.ally(), gone = true}])


## A creature falls from the edge at `into`; one of heaven gives what a fall does.
static func _lose(w: World, a: Actor, into: Vector2i) -> void:
	var fell := {t = &"fall", id = a.id, from = a.pos, at = into}
	_gone(w, a, [fell, {t = &"die", id = a.id, at = a.pos, foe = not a.ally()}])


## `a` leaves the board with no body, the events `told` telling how.
static func _gone(w: World, a: Actor, told: Array) -> void:
	a.hp = 0
	a.magic.intent.clear()
	Mind.forget(w, a)
	for e: Dictionary in told:
		w.emit(e)
	if not a.ally():
		w.player().buffs.prey = a.kind
		Harm.reward(w, a)
	w._changed()


## Where Miho lands from a fall at `into` that no floor or sky leads out of, as inside a
## court walled off (Outside): the free tile nearest it that can be walked to from the
## start, the lowest index of those as near; none when there is no such tile.
static func _walled_in(w: World, into: Vector2i) -> Vector2i:
	var walked: PackedInt32Array = Grid.search(w.start, Masks.floor_of(w)).dist
	var best := -1
	for i in walked.size():
		var p := Grid.at(i)
		if walked[i] < 0 or not w.vacant(p) or w.traps.has(p):
			continue
		if best < 0 or Grid.cheb(p, into) < Grid.cheb(Grid.at(best), into):
			best = i
	return Grid.at(best) if best >= 0 else Vector2i(-1, -1)


## Miho falls through the sky at `into` to the storeys below. Whatever flies
## or stands on the ones above is left there, and so is the elixir's question.
static func _drop(w: World, me: Actor, into: Vector2i) -> void:
	var from := me.pos
	var top := w.depth
	var soft := me.buffs.vault
	w.elixir_asked = false
	Storeys.leave(w)
	Storeys.enter(w, w.depth - 1)
	while w.depth > 1 and w.tile(into) == World.SKY:
		Storeys.leave(w)
		Storeys.enter(w, w.depth - 1)
	w.emit({t = &"fall", id = me.id, from = from, at = into, depth = w.depth, soft = soft})
	me.pos = Vector2i(-1, -1)  # in the air, off the tile she may land on
	var spot := FloorGen.nearest_free(w, into, Masks.air(w))
	if spot.x < 0:
		spot = _walled_in(w, into)
	me.pos = spot if spot.x >= 0 else w.start
	Storeys.carry(w)
	if soft:
		Guise.land(w, me)
	else:
		Harm.hurt(w, me, (top - w.depth) * DAMAGE)
	w.tails = mini(w.tails, w.max_tails())
	w._changed()
	w.sense()
