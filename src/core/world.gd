class_name World
extends RefCounted
## The whole game state and the turn rules. `act` runs one round and returns
## the events the view animates; `preview` runs an action on a copy so the
## view can show its exact outcome before the player commits. One round is one
## second of game time.
##
## Round order: Miho acts, then every projectile flies (interleaved, one tile per
## sub-step), then every other creature acts. A creature spends one round
## charging (telegraphed) before it casts, and its new projectiles first fly
## after Miho's next action.
##
## Information comes from light and sound. A creature sees a tile in its line
## of sight when the tile is lit or close by (Miho's fox eyes reach 2 tiles in
## the dark, heaven's 1). Noise spreads around walls; Miho hears everything in
## range, heaven creatures go to search where they heard an alarm or saw one of
## Miho's projectiles, and hunt her once they see her (Mind; how they read a
## projectile depends on their wits), shouting to those in earshot. A resting
## creature standing at its home is asleep (Actor.asleep): it sees nothing, even
## next to it, until noise or a wound wakes it; a patrol, which walks while it
## rests, and a 장승, never sleep. Claws strike three times as hard at a creature that is
## not hunting and does not see Miho (Brogue CE Combat.c sneak attack;
## caught_unawares), so Miho can creep up on a sleeper. A creature
## that was hurt stays wary for WARY_ROUNDS: it does not go back to rest and
## sees Miho one tile farther in the dark.
##
## Terrain feeds both senses. Bamboo hides whoever stands in it from all but
## the tiles next to it and rustles underfoot; floorboards creak. Treading
## on either is heard; Miho's treads alarm heaven. Ponds cannot be walked
## but spells fly over them.
##
## Gas (fog, steam, smoke) lies on tiles, spreads and thins every round, and
## thick enough it blocks sight: see Gas.
##
## Compound spells leave hot ground, ice, thorns and mud: see Compounds.
## Water wets creatures, fire sets them alight and frost freezes them: see Status.
##
## Heaven falls into groups, and a creature struck by another group fights it
## for a while (Mind).
##
## A war drum calls heaven: see Drums. A plate in the floor goes off under whoever
## steps on it, and shows only on a lit tile or right next to Miho: see Traps.
## Some walls between rooms are hidden doors, found the same way.
##
## Lanterns, doors, walls and windows break; Terrain holds those rules. A door
## slides: walking into a closed one opens it with a sound and costs the move, and
## the close action shuts an open one. Creatures of heaven open doors on their way
## and leave them open. A closed door blocks sight, but its paper lets light through.
## A heaven creature that is not hunting and sees a lantern that went out or
## broke, a door or wall that broke, a burnt tile or a fallen creature goes to
## search there, once per change (Notice). A fallen creature leaves a body mark.
##
## Fire sets doors, bamboo and floorboards alight where a fire spell flies or
## ends, and around a fire orb's burst. A burning tile lights its surroundings,
## crackles (an alarm), hides nothing, burns whoever stands in it each round
## for FIRE_DAMAGE and may spread to each flammable neighbour; after BURN_ROUNDS
## it is ash. Fire on a fierce tile (straw, leaves, reeds, shelves) is worse: it
## burns for FIERCE_DAMAGE, and a fierce tile it catches spreads once more in the
## same round. Fire hurts those who stay in it: a tile set alight during a round
## burns nobody until the next round, so a creature it caught can step off. A
## fire orb's burst hurts every creature around it for FIRE_DAMAGE at once
## too (twice that to one weak to fire). Heaven walks around fire; water douses it.
##
## A storey is a few pavilions standing in open sky, joined by skybridges. Sky
## cannot be walked, but sight, light, sound and spells cross it. A bridge is
## walkable, creaks, never burns and is always lit by the moon, so whoever
## crosses one is seen from afar; so is a courtyard, ground with no roof.
## Screens, jars and censers stand in rooms and react when hit (Structures).
##
## A creature pushed into the sky falls (Fall): heaven's is gone, Miho lands on
## the storey below. 도약 leaps her across it (Leap). Every storey she has left
## is kept as she left it (Storeys).
##
## A spell cast with no direction goes on Miho: 그림자 or 둔갑 (Guise). A
## hovering wisp of 여 alone yelps, an alarm (Lure). Each storey climbed gives back
## one health. A storey may hold one event room, built by hand, whose reward is
## used on the spot: see EventRooms. The debug commands take no round: see Cheat.
##
## Miho grows one more tail on every storey (일미호 to 구미호). Her action
## is a move, a wait, or any number of spells whose cards together cost no more
## than her unspent tails. A spent tail regrows every TAIL_REGROW rounds, and a
## kill gives one back.

const FLOORS := 9
const REAPER_OMEN := 300
const REAPER_ARRIVES := 320
const TAIL_REGROW := 3
const VIEW := 40
const NIGHT := [2, 1]
const DIM := 7
const SEARCH_ROUNDS := 15
const WARY_ROUNDS := 30
const CLAW := 1
const SNEAK := 3
const CRY := 5
const THUD := 9
const KNOCK := 4
const BURN_ROUNDS := 3
const FIRE_DAMAGE := 2
## What fire on a fierce tile (Tiles.fierce) burns for each round.
const FIERCE_DAMAGE := 3
const HEAL := 1
const CRACKLE := 3

const FLOOR := 0
const WALL := 1
const DOOR := 2
const LANTERN := 3
const LANTERN_OUT := 4
const BAMBOO := 5
const BOARD := 6
const POND := 7
const ASH := 8
const LANTERN_BROKEN := 9
const WALL_CRACKED := 10
const RUBBLE := 11
const SKY := 12
const WINDOW := 13
const BRIDGE := 14
const DOOR_OPEN := 15
const DRUM := 16
const DRUM_TORN := 17
const GRASS := 18
const STRAW := 19
const REEDS := 20
const REEDS_FLAT := 21
const LEAVES := 22
const SHALLOW := 23
const PILLAR := 24
const WOOD_WALL := 25
const ICE := 26
const THORNS := 27
const MUD := 28
const TRAP_ALARM := 29
const TRAP_COLLAPSE := 30
const TRAP_FIRE := 31
const TRAP_VINE := 32
const ALTAR := 33
const ALTAR_LIT := 34
const VEIL := 35
const LAMP := 36
const TALISMAN := 37
const SHELF := 38
const SHELF_READ := 39
const SCREEN := 40
const JAR := 41
const WATER_JAR := 42
const CENSER := 43
const COURTYARD := 44
const STATUE := 45
const BOARD_ROTTEN := 46

var depth := 1
var tiles := PackedByteArray()
var rooms: Array[Rect2i] = []
var start := Vector2i.ZERO
var stairs := Vector2i(-1, -1)
var elixir := Vector2i(-1, -1)
var peaches: Array[Vector2i] = []
## Burning tiles: position -> rounds left; the wild ones always spread.
var burning := {}
var wild := {}
## Gas: position -> Vector2i(kind, amount) (Gas).
var gas := {}
## Tiles that breathe gas: position -> gas kind (Gas).
var vents := {}
## Tiles a gun lights this round (Spray).
var flares: Array[Vector2i] = []
## Wet drums: position -> rounds left (Drums).
var wet := {}
## Hot ground: position -> Vector2i(kind, rounds left) (Compounds).
var hot := {}
## Every plate in the floor: position -> its tile kind (Traps). The tile itself
## is the plate only once Miho has found it, and floor until then.
var traps := {}
## Hidden doors Miho has not found: position -> true. Each is a wall until she
## finds it, and then a door (Traps).
var secrets := {}
## The sealing wall of a treasure room, a plain wall: position -> the dark
## lanterns that bring it down once all are lit (Vault).
var seals := {}
## The event rooms' state on this storey (EventRooms): {kind, at, ...} each.
var sites: Array[Dictionary] = []
## Tails this storey allows beyond max_tails' count by depth (Altar).
var tail_bonus := 0
## The storeys Miho has left: depth -> what Storeys kept of each.
var storeys := {}
var actors: Array[Actor] = []
var shots: Array[Shot] = []
var next_id := 1
var tails := 1
var regrow := 0
var cheats := {}
var cards: Array[StringName] = [Cards.FOX, Cards.ORB]
var round_no := 0
var outcome := &""
var rng := RandomNumberGenerator.new()
var events: Array[Dictionary] = []
## What creatures can notice this storey, and the bodies of the fallen by tile
## (see Notice).
var changes: Array[Dictionary] = []
var bodies := {}
## Tiles Miho sees now; dark tiles whose shape she makes out but where she
## cannot see who stands; and every tile she has seen on this storey.
var seen := PackedByteArray()
var dim := PackedByteArray()
var known := PackedByteArray()
## Noises Miho heard this round: {at, word}.
var heard: Array[Dictionary] = []
var scent := PackedInt32Array()
var _light := PackedVector3Array()
var _light_dirty := true
var _fov := {}
var _opaque := PackedByteArray()
var _shade := PackedByteArray()


static func create(seed_value: int) -> World:
	var w := World.new()
	w.rng.seed = seed_value
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.hp = Bestiary.info(&"miho").hp
	me.max_hp = me.hp
	w.actors.append(me)
	FloorGen.build(w)
	w.sense()
	return w


func clone() -> World:
	var w := World.new()
	w.depth = depth
	w.tiles = tiles.duplicate()
	w.rooms = rooms.duplicate()
	w.start = start
	w.stairs = stairs
	w.elixir = elixir
	w.peaches = peaches.duplicate()
	w.burning = burning.duplicate()
	w.wild = wild.duplicate()
	w.gas = gas.duplicate()
	w.vents = vents.duplicate()
	w.changes = changes.duplicate(true)
	w.bodies = bodies.duplicate(true)
	w.wet = wet.duplicate()
	w.hot = hot.duplicate()
	w.traps = traps.duplicate()
	w.secrets = secrets.duplicate()
	w.seals = seals.duplicate(true)
	w.sites.assign(sites.duplicate(true))
	w.tail_bonus = tail_bonus
	w.storeys = storeys.duplicate()
	for a in actors:
		w.actors.append(a.clone())
	for s in shots:
		w.shots.append(s.clone())
	w.next_id = next_id
	w.tails = tails
	w.regrow = regrow
	w.cheats = cheats.duplicate()
	w.cards = cards.duplicate()
	w.round_no = round_no
	w.outcome = outcome
	w.rng.seed = rng.seed
	w.rng.state = rng.state
	w.seen = seen.duplicate()
	w.dim = dim.duplicate()
	w.known = known.duplicate()
	w.heard = heard.duplicate()
	w.scent = scent.duplicate()
	return w


## A copy holding only what Miho knows: creatures and projectiles out of her
## sight and plates and doors she has not found are left out, so a preview
## never gives hidden things away.
func known_clone() -> World:
	var w := clone()
	w.traps = Traps.found(self)
	w.secrets = {}
	w.actors.assign(w.actors.filter(func(a): return a.faction == Actor.FOX or Hat.shown(self, a)))
	w.shots.assign(w.shots.filter(func(s): return seen[Grid.index(s.pos)] == 1))
	return w


func new_id() -> int:
	next_id += 1
	return next_id - 1


# --- queries -----------------------------------------------------------------


func player() -> Actor:
	return actors[0]


func max_tails() -> int:
	return depth + tail_bonus


func tile(p: Vector2i) -> int:
	return tiles[Grid.index(p)] if Grid.inside(p) else WALL


## Creatures can walk here.
func open_floor(p: Vector2i) -> bool:
	return Tiles.walk[tile(p)] == 1


## Projectiles can fly here: anywhere walkable, and over ponds and sky.
func open_air(p: Vector2i) -> bool:
	return open_floor(p) or tile(p) == POND or tile(p) == SKY


## Walls (cracked too), closed doors, bamboo, reeds and pillars block sight, as does
## gas of Gas.OPAQUE or more; nothing burning hides what is behind it.
func opaque(p: Vector2i) -> bool:
	return (Tiles.sight[tile(p)] == 1 and not burning.has(p)) or Gas.blocks(self, p)


## Walls (cracked too), bamboo and pillars cast shadows; a closed door's paper lets light through.
func blocks_light(p: Vector2i) -> bool:
	return Tiles.light[tile(p)] == 0 and not burning.has(p)


## Bamboo hides who stands in it from everyone not right next to it, until it burns.
func hides(p: Vector2i) -> bool:
	return tile(p) == BAMBOO and not burning.has(p)


func actor_at(p: Vector2i) -> Actor:
	for a in actors:
		if a.alive() and a.pos == p:
			return a
	return null


func actor(id: int) -> Actor:
	for a in actors:
		if a.id == id:
			return a
	return null


func shot_at(p: Vector2i, except: Shot = null) -> Shot:
	for s in shots:
		if not s.gone and s != except and s.pos == p:
			return s
	return null


## Creatures may share a tile with a hovering wisp; it strikes only when it chases.
func vacant(p: Vector2i) -> bool:
	if not open_floor(p) or actor_at(p) != null:
		return false
	var s := shot_at(p)
	return s == null or not s.spell.orb and s.dir == Vector2i.ZERO


## True when nothing a projectile cannot cross stands strictly between a and b
## on one of the eight lines.
func clear_line(a: Vector2i, b: Vector2i) -> bool:
	var d := Grid.line_dir(a, b)
	if d == Vector2i.ZERO:
		return false
	var p := a + d
	while p != b:
		if not open_air(p):
			return false
		p += d
	return true


## `opaque` for every tile at once, for Sight (cached until something moves).
func opaque_mask() -> PackedByteArray:
	if _opaque.is_empty():
		_opaque = Masks.opaque(self)
	return _opaque


## `blocks_light` for every tile at once, for Light (cached until something moves).
func light_mask() -> PackedByteArray:
	if _shade.is_empty():
		_shade = Masks.shade(self)
	return _shade


func light() -> PackedVector3Array:
	if _light_dirty:
		_light = Light.field(Light.sources(self), light_mask())
		for t in Light.MOONLIT:
			var i := tiles.find(t)
			while i >= 0:
				_light[i] += Light.MOON
				i = tiles.find(t, i + 1)
		_light_dirty = false
	return _light


func lit(p: Vector2i) -> bool:
	return Grid.inside(p) and Light.level(light()[Grid.index(p)]) >= Light.LIT


## Tiles in line of sight from p, lit or not (cached until something moves).
func fov(p: Vector2i) -> PackedByteArray:
	if not _fov.has(p):
		_fov[p] = Sight.field(p, VIEW, opaque_mask())
	return _fov[p]


## Whether `a` sees tile p now. Sight is symmetric, so this is read from p's side.
## A blinded fox still feels what is next to her; blinded heaven sees nothing.
func sees(a: Actor, p: Vector2i) -> bool:
	return _reaches(a, p) and (a.blind > 0 or fov(p)[Grid.index(a.pos)] == 1)


## Every tile `a` sees now; one field from its own side, as sight is symmetric.
func view_of(a: Actor) -> PackedByteArray:
	var view := fov(a.pos)
	var out := PackedByteArray()
	out.resize(tiles.size())
	for i in out.size():
		out[i] = 1 if _reaches(a, Grid.at(i)) and (a.blind > 0 or view[i] == 1) else 0
	return out


func _reaches(a: Actor, p: Vector2i) -> bool:
	if a.asleep():
		return false
	if a.blind > 0:
		return a.faction == Actor.FOX and Grid.cheb(a.pos, p) <= 1
	if hides(p) and Grid.cheb(a.pos, p) > 1:
		return false
	return Grid.cheb(a.pos, p) <= NIGHT[a.faction] + (1 if a.wary > 0 else 0) or lit(p)


func can(action: Dictionary) -> bool:
	if outcome != &"":
		return false
	match action.get("t"):
		&"wait":
			return true
		&"move":
			return Legal.move(self, action.get("dir", Vector2i.ZERO))
		&"cast":
			return Legal.cast(self, action.get("spells", []))
		&"close":
			return Legal.close(self, action.get("dir", Vector2i.ZERO))
	return action.get("t") == &"cheat" and Cheat.can(self, action)


## Runs `action` on a copy; the world itself does not change.
func preview(action: Dictionary) -> World:
	var w := clone()
	w.act(action)
	return w


# --- the round ---------------------------------------------------------------


func act(action: Dictionary) -> Array[Dictionary]:
	events = []
	heard = []
	_changed()
	if not can(action) or Cheat.handled(self, action):
		return events
	var me := player()
	_regrow()
	var alight := burning.keys()
	Status.lapse(self, me, &"stunned")
	match action.t:
		&"move":
			var to: Vector2i = me.pos + action.dir
			var foe := actor_at(to)
			if foe != null:
				_claw(me, foe)
			elif Terrain.knockable(tile(to)):
				Terrain.knock(self, me, to)
			elif tile(to) == DOOR:
				Terrain.open_door(self, me, to)
			else:
				var storey := depth
				move(me, to)
				if depth == storey:
					Scent.lay(self, to)
					if arrive(me):
						return events
		&"close":
			Terrain.close_door(self, me, me.pos + action.dir)
		&"cast":
			for one: Dictionary in action.spells:
				var spell := Spell.make(one.cards)
				tails -= Cheat.cost(self, spell)
				cast(me, spell, one.dir)
	_shots_phase()
	Mind.heaven_phase(self)
	Terrain.burn(self, alight)
	Compounds.tick(self)
	Gas.tick(self)
	Status.tick(self)
	Vault.tick(self)
	EventRooms.tick(self)
	Statues.tick(self)
	Guise.tick(self)
	Lure.tick(self)
	_end_round()
	sense()
	return events


## Updates what Miho sees, makes out in the dark or in bamboo, and remembers.
func sense() -> void:
	_changed()
	var me := player()
	var from := fov(me.pos)
	seen = PackedByteArray()
	seen.resize(tiles.size())
	dim = seen.duplicate()
	if known.size() != tiles.size():
		known.resize(tiles.size())
	var clear := not opaque(me.pos)
	for i in tiles.size():
		if from[i] == 0:
			continue
		var p := Grid.at(i)
		# Sight is symmetric between clear tiles, so her own field answers for them.
		if _reaches(me, p) and ((clear and not opaque(p)) or sees(me, p)):
			seen[i] = 1
			known[i] = 1
		elif me.blind <= 0 and (Grid.cheb(p, me.pos) <= DIM or (hides(p) and lit(p))):
			dim[i] = 1
			known[i] = 1
	Traps.find(self)
	Notice.remember(self)
	Cheat.reveal(self)


func emit(e: Dictionary) -> void:
	events.append(e)


func _changed() -> void:
	_light_dirty = true
	_fov.clear()
	_opaque = PackedByteArray()
	_shade = PackedByteArray()


## A step; into a closed door it slides the door open instead and stays put.
## The step event carries the tread: the word of the tile stepped onto and how
## far it is heard, which sound the step.
func move(a: Actor, to: Vector2i) -> void:
	if tile(to) == DOOR:
		Terrain.open_door(self, a, to)
		return
	var from := a.pos
	var tread: Array = Status.tread(a, Tiles.of(tile(to), "tread"))
	var loud := 0 if tile(to) == MUD else maxi(a.info().get("step", 0), tread[0])
	emit({t = &"move", id = a.id, from = from, to = to, word = tread[1], loud = loud})
	a.pos = to
	for s in shots:
		if s.host == a.id and not s.gone:
			s.pos = to
			emit({t = &"ride", shot = s.id, to = to})
	_changed()
	noise(to, loud, tread[1], a.faction == Actor.FOX, a.id)
	Terrain.crumble(self, a, from)
	Terrain.trample(self, to)
	Compounds.step(self, a, to)
	Traps.step(self, a, Grid.line_dir(from, to))


## Miho has come onto her tile, by a step or a push: the stairs take her up,
## the elixir wins, a peach heals, a scroll gives its talisman. True when the
## storey or the run ends.
func arrive(me: Actor) -> bool:
	if me.pos == stairs:
		_ascend()
		return true
	if me.pos == elixir:
		outcome = &"won"
		emit({t = &"won"})
		return true
	if peaches.has(me.pos):
		peaches.erase(me.pos)
		var grew := me.hp >= me.max_hp
		me.max_hp += HEAL if grew else 0
		me.hp += HEAL
		emit({t = &"heal", id = me.id, hp = me.hp, grew = grew, peach = true})
	Scrolls.arrive(self, me)
	EventRooms.arrive(self, me)
	return false


## Slides a creature up to n tiles along dir, off the edge into the sky if
## nothing stops it (see Fall).
func push(a: Actor, dir: Vector2i, n: int) -> void:
	Fall.push(self, a, dir, n)


## Spreads a noise around walls. Miho hears every noise in range but her own;
## heaven creatures that hear an alarm go to search its spot, or `spot` when given.
func noise(
	at: Vector2i, loud: int, word: String, alarm: bool, by: int, spot := Vector2i(-1, -1)
) -> void:
	if loud <= 0:
		return
	var dist: PackedInt32Array = Grid.search(at, Masks.heard(self), loud).dist
	var me := player()
	var d := dist[Grid.index(me.pos)]
	var heard_it := by != me.id and d >= 0 and d <= loud
	if heard_it:
		heard.append({at = at, word = word})
	emit({t = &"noise", at = at, word = word, loud = loud, heard = heard_it})
	if not alarm:
		return
	for a in actors:
		if (
			a.alive()
			and a.faction == Actor.HEAVEN
			and a.id != by
			and a.alert != Actor.HUNT
			and not a.info().get("deaf", false)
		):
			var da := dist[Grid.index(a.pos)]
			if da >= 0 and da <= loud:
				a.alert = Actor.SEARCH
				a.target = at if spot.x < 0 else spot
				a.lost = 0


func set_tile(p: Vector2i, t: int) -> void:
	if tiles[Grid.index(p)] != t:
		wet.erase(p)
	tiles[Grid.index(p)] = t
	_changed()


## Whether a claw at `a` is a sneak attack: it is off guard (not hunting) and
## does not see Miho, or does not know her in guise (Guise); a sleeping or
## blind creature sees nothing, but a blind hunter is on guard.
func caught_unawares(a: Actor) -> bool:
	return a.alert != Actor.HUNT and not Guise.knows(self, a)


func _claw(me: Actor, foe: Actor) -> void:
	var sneak := caught_unawares(foe)
	var n := CLAW * (SNEAK if sneak else 1)
	emit({t = &"claw", id = me.id, target = foe.id, at = foe.pos, n = n, sneak = sneak})
	noise(foe.pos, 1 if sneak else 3, "퍽", true, me.id)
	hurt(foe, n)
	if foe.alive():
		Mind.provoke(self, foe, me)
		hunt_from(foe, me.pos)


## `a` hunts Miho from `at`; starting to, it notices her and shouts (Mind.shout).
func hunt_from(a: Actor, at: Vector2i) -> void:
	var fresh := a.alert != Actor.HUNT
	if fresh:
		emit({t = &"notice", id = a.id, at = a.pos})
		Drums.plan(self, a)
	a.alert = Actor.HUNT
	a.target = at
	a.lost = 0
	if fresh:
		Mind.shout(self, a)


func cast(caster: Actor, spell: Spell, dir: Vector2i) -> void:
	emit({t = &"cast", id = caster.id, cards = spell.cards, dir = dir})
	caster.casts += 1
	if Guise.cast(self, caster, spell, dir):
		return
	if spell.shape in [Spell.LEAP, Spell.SPRAY]:
		(Leap if spell.shape == Spell.LEAP else Spray).cast(self, caster, spell, dir)
		return
	if spell.gun():
		flares.append(caster.pos)
	noise(caster.pos, spell.cast_noise(), spell.cast_word(), caster.faction == Actor.FOX, caster.id)
	var targets := Homing.targets(self, caster, spell)
	var heads := Homing.headings(self, caster, dir, targets)
	for i in heads.size():
		var s := _spawn(caster, spell, heads[i], targets[i])
		if heads[i] == dir:
			_step(s)
		else:
			_fly(s, s.pos + s.dir)
			s.dir = Homing.facing(self, s)


func _spawn(caster: Actor, spell: Spell, dir: Vector2i, target: int) -> Shot:
	var s := Shot.new()
	s.id = new_id()
	s.faction = caster.faction
	s.caster = caster.id
	s.spell = spell
	s.pos = caster.pos
	s.origin = caster.pos
	s.dir = dir
	s.life = spell.life()
	s.target = target
	s.turn = spell.turn()
	shots.append(s)
	_changed()
	emit(
		{
			t = &"spawn",
			shot = s.id,
			at = s.pos,
			faction = s.faction,
			cards = spell.cards,
			target = target
		}
	)
	return s


func _shots_phase() -> void:
	for sub in Spell.BULLET_SPEED:
		for s: Shot in shots.duplicate():
			if not s.gone and sub < s.spell.speed() and s.dir != Vector2i.ZERO and not rides(s):
				_step(s)
	_prune()


func _fly(s: Shot, to: Vector2i) -> void:
	emit({t = &"fly", shot = s.id, from = s.pos, to = to})
	s.pos = to
	s.flown += 1
	_changed()
	if s.spell.has(Cards.FIRE):
		ignite(to)


## One tile of flight. Orbs burst on walls and closed doors; every projectile
## strikes the creature it reaches; a wisp stops and hovers at a wall or after
## Spell.RANGE tiles, chasing or not, and flies no more; a piercing one goes on
## through creatures and a wall (Elements.bore, pass_through).
func _step(s: Shot) -> void:
	if s.turn > 0:
		s.dir = Homing.steer(self, s)
		var t := actor(s.target)
		if t != null and t.pos == s.pos and not s.spell.pierces():
			s.gone = true
			_strike(s, t)
			return
	var to := s.pos + s.dir
	if s.spell.pierces() and Elements.bore(self, s, to):
		to += s.dir
	elif not open_air(to) or (s.spell.orb and tile(to) == DOOR and opaque(to)):
		if s.spell.orb:
			var struck := tile(to)
			_burst(s)
			Terrain.smash(self, s, to, struck)
		else:
			_land(s)
		return
	var a := actor_at(to)
	if a != null:
		_fly(s, to)
		if s.spell.pierces():
			s.gone = not Elements.pass_through(self, s, a)
			return
		s.gone = true
		_strike(s, a)
		return
	var o := shot_at(to, s)
	if o != null:
		if s.spell.orb and o.spell.orb:
			emit({t = &"clash", shot = s.id, other = o.id, at = to})
			s.gone = true
			o.gone = true
			_changed()
			return
		if s.spell.orb:
			o.gone = true
			emit({t = &"snuff", shot = o.id, at = to})
		elif o.spell.orb:
			_land(s)
			return
	_fly(s, to)
	if not s.spell.orb and s.flown >= Spell.RANGE:
		_land(s)


func _land(s: Shot) -> void:
	s.life = Spell.WISP_LIFE
	emit({t = &"land", shot = s.id, at = s.pos})
	_effects(s, s.pos)


func _burst(s: Shot) -> void:
	emit({t = &"burst", shot = s.id, at = s.pos})
	s.gone = true
	_changed()
	noise(s.pos, s.spell.burst_noise(), "쾅", true, s.caster)
	if s.spell.has(Cards.FIRE):
		Elements.splash(self, s, s.pos, null)
	_effects(s, s.pos, s.pos + s.dir)


## A thud happens wherever the spell ends; fire sets that tile alight and
## relights the lanterns next to it, except the one an orb just struck, water
## douses lanterns and flames, a wood orb grows a wall (Elements), and each
## compound acts round where it ends (Compounds); 도약 brings Miho (Leap.swap).
func _effects(s: Shot, at: Vector2i, struck := Vector2i(-1, -1)) -> void:
	if s.spell.has(Cards.EARTH):
		noise(at, THUD, "쿵", true, s.caster)
	if s.spell.has(Cards.FIRE):
		ignite(at)
	Terrain.touch(self, s, at, struck)
	if s.spell.orb and s.spell.has(Cards.WOOD):
		Elements.sprout(self, s, at)
	Compounds.land(self, s, at)
	s.dir = Vector2i.ZERO
	Leap.swap(self, s, actor_at(at))


func _strike(s: Shot, a: Actor) -> void:
	var spell := s.spell
	var at := a.pos
	emit({t = &"hit", shot = s.id, id = a.id, at = at, by = s.caster, title = spell.title()})
	noise(at, spell.burst_noise(), "쾅", true, s.caster)
	if not Elements.strike(self, s, a, spell.damage(Grid.cheb(s.origin, at))):
		return
	if spell.orb and spell.has(Cards.FIRE):
		Elements.splash(self, s, at, a)
	_effects(s, at)
	if not spell.orb and not spell.gun():
		Elements.stick(self, s, a)


## Whether `s` rides a living creature, and so neither flies nor strikes again.
func rides(s: Shot) -> bool:
	var a := actor(s.host)
	return a != null and a.alive()


func hurt(a: Actor, n: int, weak := false) -> void:
	if not a.alive() or Cheat.immune(self, a):
		return
	var shatter := Status.shatter(a)
	n *= 2 if shatter else 1
	a.hp -= n
	emit({t = &"hurt", id = a.id, n = n, hp = a.hp, at = a.pos, weak = weak, shatter = shatter})
	Guise.hurt(self, a)
	if a.alive():
		if shatter:
			emit({t = &"thaw", id = a.id, at = a.pos})
		if a.faction == Actor.HEAVEN:
			noise(a.pos, CRY, "끽", true, a.id)
			Mind.hurt(a)
		return
	emit({t = &"die", id = a.id, at = a.pos})
	a.intent.clear()
	_changed()
	if a.faction == Actor.FOX:
		outcome = &"lost"
		emit({t = &"lost"})
		return
	Notice.fallen(self, a)
	Mind.forget(self, a)
	tails = mini(max_tails(), tails + 1)
	emit({t = &"soul", id = a.id, at = a.pos})
	Scrolls.drop(self, a)


## Sets p alight if it is flammable, or whatever it is when `force`d; a
## `wildfire` always spreads. Water never burns.
func ignite(p: Vector2i, force := false, wildfire := false) -> void:
	Gas.light(self, p)
	if (
		(force or Tiles.burns[tile(p)] == 1)
		and not burning.has(p)
		and not Tiles.of(tile(p), "douses")
	):
		burning[p] = BURN_ROUNDS
		if wildfire:
			wild[p] = true
		else:
			wild.erase(p)
		Scent.clear(self, p)
		_changed()
		emit({t = &"ignite", at = p})


## One round of a spent tail growing back, counted before the action: the round
## a tail is spent in does not count, and nothing counts while none is missing.
func _regrow() -> void:
	if tails >= max_tails():
		regrow = 0
		return
	regrow += 1
	if regrow >= TAIL_REGROW:
		regrow = 0
		tails += 1


func _end_round() -> void:
	Drums.dry(self)
	flares.clear()
	for a in actors:
		if a.alive():
			a.cooldown = maxi(0, a.cooldown - 1)
			Status.lapse(self, a, &"rooted")
			Status.lapse(self, a, &"blind")
			a.wary = maxi(0, a.wary - 1)
			a.grudge = maxi(0, a.grudge - 1)
	for s in shots:
		if not s.gone and s.life > 0:
			s.life -= 1
			if s.life == 0:
				s.gone = true
				emit({t = &"fade", shot = s.id, at = s.pos})
				if s.spell.mortar():
					noise(s.pos, s.spell.burst_noise(), "쾅", true, s.caster)
					Compounds.land(self, s, s.pos)
	_prune()
	round_no += 1
	if outcome != &"" or depth >= FLOORS:
		return
	if round_no == REAPER_OMEN:
		emit({t = &"omen", at = start})
	elif round_no == REAPER_ARRIVES:
		var spot := FloorGen.nearest_free(self, start)
		if spot.x >= 0:
			var saja := FloorGen.spawn(self, &"saja", spot)
			_changed()
			emit({t = &"arrive", id = saja.id, at = spot})


func _prune() -> void:
	var before := shots.size() + actors.size()
	shots.assign(shots.filter(func(s): return not s.gone))
	actors.assign(actors.filter(func(a): return a.alive() or a.faction == Actor.FOX))
	if shots.size() + actors.size() != before:
		_changed()


func _ascend() -> void:
	Storeys.leave(self)
	Storeys.enter(self, depth + 1)
	regrow = 0
	tails = max_tails()
	_changed()
	emit({t = &"ascend", depth = depth})
	var me := player()
	if me.hp < me.max_hp:
		me.hp += HEAL
		emit({t = &"heal", id = me.id, hp = me.hp})
	sense()
