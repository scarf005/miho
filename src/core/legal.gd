class_name Legal
extends RefCounted
## Whether Miho can take an action now (World.can).


## A step onto a free tile, even one a shot flies through (a closed door slides
## open instead), claws at a creature next to Miho, or a knock at a lantern or window.
static func move(w: World, dir: Vector2i) -> bool:
	var me := w.player()
	var to := me.pos + dir
	if me.stunned > 0 or Grid.cheb(to, me.pos) != 1:
		return false
	var foe := w.actor_at(to)
	if foe != null:
		return foe.faction != me.faction
	return Terrain.knockable(w.tile(to)) or (me.rooted <= 0 and w.open_floor(to))


## An open door next to Miho with nothing in it.
static func close(w: World, dir: Vector2i) -> bool:
	var to := w.player().pos + dir
	return (
		w.player().stunned <= 0
		and Grid.DIRS.has(dir)
		and w.tile(to) == World.DOOR_OPEN
		and not w.burning.has(to)
		and w.actor_at(to) == null
		and w.shot_at(to) == null
	)


## Every spell is valid and known, takes its own open direction (a leap one
## it lands along) or none, on Miho herself (Guise), and the cards together
## cost no more than the unspent tails.
static func cast(w: World, spells: Array) -> bool:
	var me := w.player()
	if me.stunned > 0 or spells.is_empty():
		return false
	var cost := 0
	var aims := {}
	for one: Dictionary in spells:
		var spell := Spell.make(one.get("cards", []))
		if spell == null or spell.cards.any(func(c): return not w.cards.has(c)):
			return false
		cost += spell.cost()
		var d: Vector2i = one.get("dir", Vector2i.ZERO)
		if not Leap.open(w, me, spell, d) or aims.has(d):
			return false
		aims[d] = true
	return cost <= w.tails
