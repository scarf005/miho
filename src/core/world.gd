class_name World
extends RefCounted
## The whole game state, and the way into the turn rules. `act` runs one round
## (Round) and returns the events the view animates; `preview` runs an action on a
## copy so the view can show its exact outcome before the player commits. One
## round is one second of game time. This file holds the state, the tile queries
## and the constants the rules share; each rule lives in the module named here.
##
## Round holds the order of a round, Miho's action, her tails and what a storey
## climbed gives back. She has depth plus the altar's bonus tails (max_tails).
##
## Information comes from light and sound: Sight, Light, Hearing and Scent. In
## the dark a creature sees NIGHT tiles (Miho 2, heaven 1). What heaven does with
## it is Mind and Notice; a resting creature is asleep (Actor.asleep) and a claw
## at one that is not hunting is a sneak attack (Harm.caught_unawares, SNEAK times
## CLAW). A creature that was hurt stays wary for WARY_ROUNDS (Mind).
##
## Terrain, with the doors, lanterns, walls and windows that break, is Terrain;
## the furniture of a room is Structures, the gas on the tiles Gas, hot ground,
## ice, thorns and mud Compounds, and what water, fire and frost leave on a
## creature Status. Fire on the tiles burns each round for FIRE_DAMAGE, or
## FIERCE_DAMAGE on a fierce tile, and is ash after BURN_ROUNDS.
##
## Plates in the floor and hidden doors are Traps, war drums Drums, creaking
## floorboards Creak. Heaven falls into groups that fight each other (Mind).
##
## A storey is built by FloorGen: pavilions in open sky joined by skybridges. Sky
## cannot be walked, but sight, light, sound and spells cross it (open_air). A
## creature pushed into it falls, and Miho lands on the storey below (Fall). 도약
## leaps her across it (Leap). Every storey she has left is kept as she left it
## (Storeys). A storey may hold one event room (EventRooms).
##
## A spell cast with no direction goes on Miho: a buff (Guise). A hovering wisp
## of 여 alone yelps, an alarm (Lure). The debug commands take no round (Cheat).

const FLOORS := 9
const REAPER_OMEN := 300
const REAPER_ARRIVES := 320
const TAIL_REGROW := 3
## Tails (or mana) one TAIL_REGROW gives back.
const TAIL_REGROWN := 1
const VIEW := 40
const NIGHT := [2, 1]
const DIM := 7
const SEARCH_ROUNDS := 15
const WARY_ROUNDS := 30
## Tiles farther a wary creature sees Miho in the dark.
const WARY_SIGHT := 1
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
const CENSER := 42
const COURTYARD := 43
const STATUE := 44
const BOARD_ROTTEN := 45

## The World fields that belong to the storey Miho is on, but its creatures.
const STOREY: Array[String] = [
	"tiles",
	"rooms",
	"start",
	"stairs",
	"elixir",
	"peaches",
	"jars",
	"burning",
	"wild",
	"gas",
	"vents",
	"wet",
	"hot",
	"traps",
	"secrets",
	"seals",
	"sites",
	"tail_bonus",
	"changes",
	"bodies",
	"known",
	"round_no",
	"curses",
]

var depth := 1
var tiles := PackedByteArray()
var rooms: Array[Rect2i] = []
var start := Vector2i.ZERO
var stairs := Vector2i(-1, -1)
var elixir := Vector2i(-1, -1)
var peaches: Array[Vector2i] = []
## What each jar on this storey holds, fixed when it was built: tile -> effect (Jars).
var jars := {}
## Rounds Miho's scent stays strong (Jars.eat), and the tiles it was laid strong on (Scent).
var pungent := 0
## What a torn 제웅 laid on this storey: curse -> its value (Curse).
var curses := {}
var strong := {}
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
## 1 for every tile `lit`, read off `_light` with it.
var _lit := PackedByteArray()
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
	for f in STOREY:
		w.set(f, copied(get(f)))
	w.pungent = pungent
	w.strong = strong.duplicate()
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
	w.outcome = outcome
	w.rng.seed = rng.seed
	w.rng.state = rng.state
	w.seen = seen.duplicate()
	w.dim = dim.duplicate()
	w.heard = heard.duplicate()
	w.scent = scent.duplicate()
	return w


## A table of a storey as its own copy: a list or a table with what it holds, a mask.
static func copied(v: Variant) -> Variant:
	if v is Array or v is Dictionary:
		return v.duplicate(true)
	return v.duplicate() if v is PackedByteArray else v


## A copy holding only what Miho knows: creatures and projectiles out of her
## sight, plates and doors she has not found and what jars hold are left out, so a preview
## never gives hidden things away.
func known_clone() -> World:
	var w := clone()
	w.traps = Traps.found(self)
	w.bodies = Notice.known(self)
	w.secrets = {}
	w.jars = {}
	w.actors.assign(w.actors.filter(func(a): return a.is_miho() or Hat.shown(self, a)))
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
	if p.x >= 0 and p.y >= 0 and p.x < Grid.W and p.y < Grid.H:
		return tiles[p.y * Grid.W + p.x]
	return WALL


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
		if a.pos == p and a.alive():
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
func vacant(p: Vector2i, ground := Tiles.walk) -> bool:
	if ground[tile(p)] != 1 or actor_at(p) != null:
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


## `opaque` for every tile at once, for Sight (cached until the board changes).
func opaque_mask() -> PackedByteArray:
	if _opaque.is_empty():
		_opaque = Masks.opaque(self)
	return _opaque


## `blocks_light` for every tile at once, for Light (cached until the board changes).
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
		_lit = Native.lit(_light, Light.LIT)
		_light_dirty = false
	return _light


func _lit_mask() -> PackedByteArray:
	if _light_dirty:
		light()
	return _lit


func lit(p: Vector2i) -> bool:
	return Grid.inside(p) and _lit_mask()[p.y * Grid.W + p.x] == 1


## Tiles in line of sight from p, lit or not (cached until the board changes).
func fov(p: Vector2i) -> PackedByteArray:
	if not _fov.has(p):
		_fov[p] = Sight.field(p, VIEW, opaque_mask())
	return _fov[p]


## Whether `a` sees tile p now. Sight is symmetric, so this is read from p's side.
## A blinded fox still feels what is next to her; blinded heaven sees nothing.
func sees(a: Actor, p: Vector2i) -> bool:
	return _reaches(a, p) and (a.ailments.blind > 0 or fov(p)[Grid.index(a.pos)] == 1)


## Every tile `a` sees now; one field from its own side, as sight is symmetric.
func view_of(a: Actor) -> PackedByteArray:
	var view := fov(a.pos)
	var out := PackedByteArray()
	out.resize(tiles.size())
	for i in out.size():
		out[i] = 1 if _reaches(a, Grid.at(i)) and (a.ailments.blind > 0 or view[i] == 1) else 0
	return out


func _reaches(a: Actor, p: Vector2i) -> bool:
	if a.asleep():
		return false
	if a.ailments.blind > 0:
		return a.faction == Actor.FOX and Grid.cheb(a.pos, p) <= 1
	if hides(p) and Grid.cheb(a.pos, p) > 1:
		return false
	return Grid.cheb(a.pos, p) <= Sight.reach(self, a) or lit(p)


func can(action: Dictionary) -> bool:
	return outcome == &"" and Legal.action(self, action)


## Runs `action` on a copy; the world itself does not change.
func preview(action: Dictionary) -> World:
	var w := clone()
	w.act(action)
	return w


# --- the round ---------------------------------------------------------------


func act(action: Dictionary) -> Array[Dictionary]:
	return Round.run(self, action)


## Updates what Miho sees, makes out in the dark or in bamboo, and remembers.
func sense() -> void:
	_changed()
	var me := player()
	if known.size() != tiles.size():
		known.resize(tiles.size())
	var sensed := Sight.sensed(self, me)
	var was := seen
	seen = sensed[0]
	dim = sensed[1]
	known = sensed[2]
	Traps.find(self, was)
	Notice.remember(self)
	Cheat.reveal(self)


func emit(e: Dictionary) -> void:
	events.append(e)


func _changed() -> void:
	_light_dirty = true
	_fov.clear()
	_opaque = PackedByteArray()
	_shade = PackedByteArray()


## Slides a creature up to n tiles along dir, off the edge into the sky if
## nothing stops it (see Fall).
func push(a: Actor, dir: Vector2i, n: int) -> void:
	Fall.push(self, a, dir, n)


func set_tile(p: Vector2i, t: int) -> void:
	if tiles[Grid.index(p)] != t:
		wet.erase(p)
	tiles[Grid.index(p)] = t
	_changed()
