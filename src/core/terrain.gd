class_name Terrain
extends RefCounted
## Terrain that reacts to what Miho and heaven do to it.
##
## A lantern has three states: lit, out, and broken (rubble that can be walked
## over and never lit again). Each hit moves it one step on: Miho walking into
## it, with a clang, or an orb striking it. An orb also smashes the closed door
## it strikes. Water douses lit lanterns next to where it ends, silently, and
## fire relights dark ones; a searching creature with a fire spell relights a
## dark lantern it stands next to.
##
## Walls break only to orbs: two hits turn a wall into a cracked wall (which
## still blocks walking, sight and light) and then into rubble. Each hit thuds.
## An orb of 흙 or 쇠 brings a wall down at once. The outermost ring of tiles
## never breaks.
##
## A wooden wall, grown by an orb of 나무 (Elements.sprout), blocks walking,
## sight and light like a wall, but burns, and one hit breaks it to floor.
##
## A door slides. Walking into a closed one, by Miho or a creature of heaven,
## opens it instead of stepping, with a rustle of SLIDE tiles; Miho's alarms
## heaven. Open it stays until Miho shuts it with the close action (same sound).
## A closed door blocks sight, not light. An orb smashes a closed door to floor.
## An open door burns like a closed one.

## A drum tears to a flat torn drum when Miho walks into it or an orb strikes
## it (Drums); water wets it.
##
## A window in an outer wall blocks walking but not sight or light, and breaks
## to floor with a clang when Miho walks into it or an orb strikes it.
##
## Reeds block sight until a creature steps onto them: they lie flat. A pillar
## blocks walking, sight and light, and never breaks.
##
## A plank (`plank`) is 마루 with sky on two opposite sides, the way of a bridge: it
## burns away to the sky, and whoever stands on it then falls (Fall).

## How far a sliding door is heard.
const SLIDE := 3
## How far a rotten board that gives way is heard.
const CRACK := 4


## A lantern that is not broken: it blocks walking and a hit moves it one step on.
static func lantern(t: int) -> bool:
	return t == World.LANTERN or t == World.LANTERN_OUT


## A tile Miho knocks by walking into it: a lantern, a window or a drum.
static func knockable(t: int) -> bool:
	return Tiles.knock[t] == 1


## A wall, cracked or not: it blocks walking, sight and light.
static func wall(t: int) -> bool:
	return Tiles.wall[t] == 1


## A tile a hit changes. The outermost ring of the map, and beyond it, never breaks.
static func breakable(w: World, at: Vector2i) -> bool:
	var inner := at.x > 0 and at.y > 0 and at.x < Grid.W - 1 and at.y < Grid.H - 1
	return Tiles.of(w.tile(at), "breaks_to") >= 0 and (inner or not wall(w.tile(at)))


## An orb can be hurled at any open tile and at a breakable lantern or wall
## right next to the caster, which it strikes where it stands; a spray goes
## any way.
static func throwable(w: World, spell: Spell, at: Vector2i) -> bool:
	return spell.shape == Spell.SPRAY or w.open_air(at) or (spell.orb and breakable(w, at))


## Miho walks into a lantern, window, drum or piece of furniture: a hit, with the
## sound of its row.
static func knock(w: World, me: Actor, at: Vector2i) -> void:
	var sound: Array = Tiles.of(w.tile(at), "hit")
	hit(w, at)
	w.noise(at, sound[0], sound[1], true, me.id)


## Whether `p` is a plank: 마루 with sky on two opposite sides.
static func plank(w: World, p: Vector2i) -> bool:
	return (
		w.tile(p) == World.BOARD
		and (
			(w.tile(p + Vector2i.UP) == World.SKY and w.tile(p + Vector2i.DOWN) == World.SKY)
			or (w.tile(p + Vector2i.LEFT) == World.SKY and w.tile(p + Vector2i.RIGHT) == World.SKY)
		)
	)


## A creature steps off the tile at `at`: a rotten board gives way to the sky, with a
## crack heard CRACK tiles.
static func crumble(w: World, by: Actor, at: Vector2i) -> void:
	var was := w.tile(at)
	var gone: int = Tiles.of(was, "crumbles")
	if gone >= 0:
		w.set_tile(at, gone)
		w.emit({t = &"crumble", at = at, was = was})
		w.noise(at, CRACK, "우지끈", by.faction == Actor.FOX, by.id)


## A creature steps onto reeds at `at`: they lie flat, and sight clears.
static func trample(w: World, at: Vector2i) -> void:
	var was := w.tile(at)
	var flat: int = Tiles.of(was, "trample")
	if flat >= 0:
		w.set_tile(at, flat)
		w.emit({t = &"trample", at = at, was = was})


## `by` slides the closed door at `at` open; its move is spent.
static func open_door(w: World, by: Actor, at: Vector2i) -> void:
	_slide(w, by, at, World.DOOR_OPEN, &"open")


## Miho slides the open door at `at` shut.
static func close_door(w: World, by: Actor, at: Vector2i) -> void:
	_slide(w, by, at, World.DOOR, &"close")


static func _slide(w: World, by: Actor, at: Vector2i, to: int, event: StringName) -> void:
	w.set_tile(at, to)
	w.emit({t = event, at = at, id = by.id})
	w.noise(at, SLIDE, "드르륵", by.faction == Actor.FOX, by.id)


## An orb without water hits the lantern, closed door, window or wall it struck;
## one of 흙 or 쇠 hits a wall till it falls (Elements.fells). A wall thuds and
## a window clangs. A lantern breaks outright, so no one can light it again,
## but an orb of fire lights a dark one instead.
static func smash(w: World, s: Shot, at: Vector2i, struck: int) -> void:
	if lights(s.spell) and struck == World.LANTERN_OUT:
		relight(w, at)
	elif not s.spell.has(Cards.WATER) and w.tile(at) == struck and breakable(w, at):
		hit(w, at, World.LANTERN_BROKEN if lantern(struck) else -1)
		while Elements.fells(s.spell) and wall(w.tile(at)) and breakable(w, at):
			hit(w, at)
		if wall(struck):
			w.noise(at, World.THUD, "쿵", true, s.caster)
		elif struck == World.WINDOW:
			w.noise(at, World.KNOCK, "쨍", true, s.caster)


## Moves the tile one step along `breaks_to`, or straight `to` when given; `was`
## is the tile it was.
static func hit(w: World, at: Vector2i, to := -1) -> void:
	var was := w.tile(at)
	w.burning.erase(at)
	w.set_tile(at, Tiles.of(was, "breaks_to") if to < 0 else to)
	Notice.smashed(w, was, at)
	w.emit({t = &"smash", at = at, was = was, left = w.tile(at)})
	Structures.broke(w, was, at)


## Whether a spell lights what it reaches: any with fire, but steam.
static func lights(spell: Spell) -> bool:
	return spell.holds(Cards.FIRE) and not spell.holds(Cards.WATER)


## Lights the lantern at `p` if it is dark.
static func relight(w: World, p: Vector2i) -> void:
	if w.tile(p) == World.LANTERN_OUT:
		w.set_tile(p, World.LANTERN)
		w.emit({t = &"relight", at = p})


## Fire relights the dark lanterns next to where a spell ends, except `struck`,
## and water douses lit lanterns and flames and washes away Miho's scent there.
static func touch(w: World, s: Shot, at: Vector2i, struck: Vector2i) -> void:
	for d: Vector2i in [Vector2i.ZERO] + Grid.DIRS:
		var p := at + d
		if lights(s.spell) and p != struck:
			relight(w, p)
		if s.spell.has(Cards.WATER):
			wash(w, p)


## Water on p: Miho's scent washes away, the creature there and a drum get
## wet, a lit lantern, a fire, a veil of dokkaebi fire or a wisp goes out.
static func wash(w: World, p: Vector2i) -> void:
	Scent.clear(w, p)
	var a := w.actor_at(p)
	if a != null:
		Status.soak(w, a)
	if w.tile(p) == World.DRUM:
		Drums.soak(w, p)
	douse(w, p)
	var o := w.shot_at(p)
	if (
		o != null
		and o.spell.shape == Spell.WISP
		and not (o.spell.has(Cards.METAL) or o.spell.has(Cards.WATER))
	):
		o.gone = true
		w._changed()
		w.emit({t = &"snuff", shot = o.id, at = p})


## A lit lantern, a fire or a veil of dokkaebi fire on p goes out.
static func douse(w: World, p: Vector2i) -> void:
	if w.tile(p) == World.VEIL:
		w.emit({t = &"douse", at = p})
		w.set_tile(p, World.ASH)
	if w.tile(p) == World.LANTERN or w.burning.has(p):
		w.burning.erase(p)
		if w.tile(p) == World.LANTERN:
			Notice.smashed(w, World.LANTERN, p)
		w.set_tile(p, World.LANTERN_OUT if w.tile(p) == World.LANTERN else w.tile(p))
		w.emit({t = &"douse", at = p})


## A searching creature with a spell that `lights` lights a lantern that went out
## next to it; true when it did.
static func relight_beside(w: World, a: Actor) -> bool:
	if not a.repertoire().any(func(cast): return lights(Spell.make(cast))):
		return false
	for d in Grid.DIRS:
		if w.tile(a.pos + d) == World.LANTERN_OUT:
			w.set_tile(a.pos + d, World.LANTERN)
			w.emit({t = &"relight", at = a.pos + d, id = a.id})
			return true
	return false


## Each burning tile crackles, burns and dries whoever stands in it (unless it
## eats fire, or burns already: Status) if it was already alight when the
## round began (`alight`): for World.FIERCE_DAMAGE on a fierce tile, else
## World.FIRE_DAMAGE. It may set each flammable neighbour alight (a wild one
## always does), and burns down to ash; a plank gives way to the sky with a crack
## heard CRACK tiles, last of all, since Miho may fall a storey with it. A fierce
## tile caught this round spreads once more in the same round, so fire runs two
## steps a round through them.
static func burn(w: World, alight: Array) -> void:
	if w.outcome != &"":
		return
	var flame := Spell.make([Cards.FOX, Cards.FIRE])
	var caught: Array[Vector2i] = []
	var gone := {}
	for p: Vector2i in w.burning.keys():
		w.noise(p, World.CRACKLE, "타닥", true, 0)
		var a := w.actor_at(p)
		if a != null and alight.has(p) and a.alight <= 0:
			var fierce := Tiles.fierce[w.tile(p)] == 1
			w.emit({t = &"burn", at = p, id = a.id, fierce = fierce})
			if Bestiary.absorbs(a.kind, flame):
				w.emit({t = &"absorb", id = a.id, at = p})
			else:
				w.hurt(a, World.FIERCE_DAMAGE if fierce else World.FIRE_DAMAGE)
				Status.dry(w, a)
		caught.append_array(_catch(w, p))
		w.burning[p] -= 1
		if w.burning[p] <= 0:
			w.burning.erase(p)
			w.wild.erase(p)
			if plank(w, p):
				gone[p] = true
				continue
			w.set_tile(p, Tiles.of(w.tile(p), "burns_to"))
			Notice.record(w, &"ash", p)
			w.emit({t = &"burnout", at = p})
	var again: Array[Vector2i] = []
	for q in caught:
		if Tiles.fierce[w.tile(q)] == 1 and not again.has(q):
			again.append(q)
	for q in again:
		caught.append_array(_catch(w, q))
	for p in caught:
		w.ignite(p)
	for p: Vector2i in gone:
		w.set_tile(p, World.SKY)
		w.emit({t = &"crumble", at = p, was = World.BOARD})
		w.noise(p, CRACK, "우지끈", true, 0)
	var falling := w.actors.filter(func(a): return a.alive() and gone.has(a.pos))
	falling.reverse()
	for a: Actor in falling:
		Fall.drop(w, a, a.pos)


## The flammable neighbours of the fire at `p` that it takes: a wild fire takes
## all, other fire each by that tile's `spread`.
static func _catch(w: World, p: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in Grid.DIRS:
		var q := p + d
		if Tiles.burns[w.tile(q)] == 1 and not w.burning.has(q):
			if w.wild.has(p) or w.rng.randf() < Tiles.of(w.tile(q), "spread"):
				out.append(q)
	return out
