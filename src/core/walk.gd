class_name Walk
extends RefCounted
## Terrain feeds both senses: bamboo rustles underfoot and floorboards creak.
## Treading on either is heard; Miho's treads alarm heaven. A door slides:
## walking into a closed one opens it with a sound and costs the move.


## A step; into a closed door it slides the door open instead and stays put.
## The step event carries the tread: the word of the tile stepped onto and how
## far it is heard, which sound the step.
static func move(w: World, a: Actor, to: Vector2i) -> void:
	if w.tile(to) == World.DOOR:
		Terrain.open_door(w, a, to)
		return
	var from := a.pos
	var tread: Array = Status.tread(a, Tiles.of(w.tile(to), "tread"))
	var loud := 0 if w.tile(to) == World.MUD else maxi(a.info().get("step", 0), tread[0])
	w.emit(
		{
			t = &"move",
			id = a.id,
			from = from,
			to = to,
			word = tread[1],
			loud = loud,
			flies = Bestiary.flies(a.kind)
		}
	)
	a.pos = to
	var on := riders(w, a)
	for s in on:
		s.pos = to
		w.emit({t = &"ride", shot = s.id, to = to})
	if Light.borne(a) or on.any(Light.glows):
		w._light_dirty = true
	Hearing.noise(w, to, loud, tread[1], a.faction == Actor.FOX, a.id)
	Terrain.stepped(w, a, from, to)


## The wisps clinging to `a` (Elements.stick) and still alive, in the order of play.
static func riders(w: World, a: Actor) -> Array[Shot]:
	var out: Array[Shot] = []
	for s in w.shots:
		if s.host == a.id and not s.gone:
			out.append(s)
	return out


## Miho has come onto her tile, by a step or a push: the stairs take her up,
## the elixir wins, a peach heals, a scroll gives its talisman. True when the
## storey or the run ends.
static func arrive(w: World, me: Actor) -> bool:
	if me.pos == w.stairs:
		Round.ascend(w)
		return true
	if me.pos == w.elixir:
		w.outcome = &"won"
		w.emit({t = &"won"})
		return true
	if w.peaches.has(me.pos):
		w.peaches.erase(me.pos)
		var grew := me.hp >= me.max_hp
		me.max_hp += World.HEAL if grew else 0
		me.hp += World.HEAL
		w.emit({t = &"heal", id = me.id, hp = me.hp, grew = grew, peach = true})
	Scrolls.arrive(w, me)
	Jars.arrive(w, me)
	EventRooms.arrive(w, me)
	return false
