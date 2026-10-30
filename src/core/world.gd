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
## projectile depends on their wits). Claws strike three times as hard at a
## creature that is not hunting (Brogue CE Combat.c sneak attack). A creature
## that was hurt stays wary for WARY_ROUNDS: it does not go back to rest and
## sees Miho one tile farther in the dark.
##
## Terrain feeds both senses. Bamboo hides whoever stands in it from all but
## the tiles next to it and rustles underfoot; floorboards creak. Treading
## on either is heard; Miho's treads alarm heaven. Ponds cannot be walked
## but spells fly over them.
##
## Lanterns, doors, walls and windows break; Terrain holds those rules.
##
## Fire sets doors, bamboo and floorboards alight where a fire spell flies or
## ends, and around a fire orb's burst. A burning tile lights its surroundings,
## crackles (an alarm), hides nothing, burns whoever stands in it each round
## and may spread to each flammable neighbour; after BURN_ROUNDS it is ash.
## Heaven walks around fire; water douses it.
##
## A storey is a few pavilions standing in open sky, joined by skybridges. Sky
## cannot be walked, but sight, light, sound and spells cross it. A bridge is
## walkable, creaks, never burns and is always lit by the moon, so whoever
## crosses one is seen from afar.
##
## Each storey climbed gives back one health.
##
## Miho has one tail per storey she has reached (일미호 to 구미호). Her action
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
const FLASH := 2
const KNOCK := 4
const BURN_ROUNDS := 3
const CRACKLE := 3
const SPREAD := 0.5

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
const WALKABLE := [FLOOR, DOOR, BAMBOO, BOARD, ASH, LANTERN_BROKEN, RUBBLE, BRIDGE]
const FLAMMABLE := [DOOR, BAMBOO, BOARD]
## How far a step onto the tile is heard, and the word for it.
const TREAD := {BAMBOO: [2, "사각"], BOARD: [3, "삐걱"], BRIDGE: [3, "삐걱"]}

var depth := 1
var tiles := PackedByteArray()
var rooms: Array[Rect2i] = []
var start := Vector2i.ZERO
var stairs := Vector2i(-1, -1)
var elixir := Vector2i(-1, -1)
var peaches: Array[Vector2i] = []
## Burning tiles: position -> rounds left.
var burning := {}
var actors: Array[Actor] = []
var shots: Array[Shot] = []
var next_id := 1
var tails := 1
var regrow := 0
var cards: Array[StringName] = [Cards.FOX, Cards.ORB]
var round_no := 0
var outcome := &""
var rng := RandomNumberGenerator.new()
var events: Array[Dictionary] = []
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
	for a in actors:
		w.actors.append(a.clone())
	for s in shots:
		w.shots.append(s.clone())
	w.next_id = next_id
	w.tails = tails
	w.regrow = regrow
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
## sight are left out, so a preview never gives hidden things away.
func known_clone() -> World:
	var w := clone()
	w.actors.assign(
		w.actors.filter(func(a): return a.faction == Actor.FOX or seen[Grid.index(a.pos)] == 1)
	)
	w.shots.assign(w.shots.filter(func(s): return seen[Grid.index(s.pos)] == 1))
	return w


func new_id() -> int:
	next_id += 1
	return next_id - 1


# --- queries -----------------------------------------------------------------


func player() -> Actor:
	return actors[0]


func max_tails() -> int:
	return depth


func tile(p: Vector2i) -> int:
	return tiles[Grid.index(p)] if Grid.inside(p) else WALL


## Creatures can walk here.
func open_floor(p: Vector2i) -> bool:
	return WALKABLE.has(tile(p))


## Projectiles can fly here: anywhere walkable, and over ponds and sky.
func open_air(p: Vector2i) -> bool:
	return open_floor(p) or tile(p) == POND or tile(p) == SKY


## Walls (cracked too), closed doors and bamboo block sight and light; a door is
## open while something is in it, and nothing burning blocks anything.
func opaque(p: Vector2i) -> bool:
	if Terrain.wall(tile(p)) or hides(p):
		return true
	return tile(p) == DOOR and not burning.has(p) and actor_at(p) == null and shot_at(p) == null


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


## Creatures may share a tile with a wisp that strikes nothing; it is only light.
func vacant(p: Vector2i) -> bool:
	if not open_floor(p) or actor_at(p) != null:
		return false
	var s := shot_at(p)
	return s == null or not s.spell.strikes()


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


func light_sources() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in tiles.size():
		if tiles[i] == LANTERN:
			out.append({at = Grid.at(i), radius = Light.LANTERN_RADIUS, color = Light.LANTERN})
	for p in burning:
		out.append({at = p, radius = Light.FIRE_RADIUS, color = Light.FIRE})
	for s in shots:
		if not s.gone:
			var l := s.spell.light(s.faction)
			if not l.is_empty():
				out.append({at = s.pos, radius = l.radius, color = l.color})
	return out


func light() -> PackedVector3Array:
	if _light_dirty:
		_light = Light.field(light_sources(), opaque)
		for i in tiles.size():
			if tiles[i] == BRIDGE:
				_light[i] += Light.MOON
		_light_dirty = false
	return _light


func lit(p: Vector2i) -> bool:
	return Grid.inside(p) and Light.level(light()[Grid.index(p)]) >= Light.LIT


## Tiles in line of sight from p, lit or not (cached until something moves).
func fov(p: Vector2i) -> PackedByteArray:
	if not _fov.has(p):
		_fov[p] = Sight.field(p, VIEW, opaque)
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
			return _can_move(action.get("dir", Vector2i.ZERO))
		&"cast":
			return _can_cast(action.get("spells", []))
	return false


## A step onto a free tile, claws at a creature next to Miho, or a knock at a
## lantern or window.
func _can_move(dir: Vector2i) -> bool:
	var me := player()
	var to := me.pos + dir
	if me.stunned > 0 or Grid.cheb(to, me.pos) != 1:
		return false
	var foe := actor_at(to)
	if foe != null:
		return foe.faction != me.faction
	return Terrain.knockable(tile(to)) or (me.rooted <= 0 and vacant(to))


## Every spell is valid and known, takes its own open direction, and the cards
## together cost no more than the unspent tails.
func _can_cast(spells: Array) -> bool:
	var me := player()
	if me.stunned > 0 or spells.is_empty():
		return false
	var cost := 0
	var aims := {}
	for one: Dictionary in spells:
		var spell := Spell.make(one.get("cards", []))
		if spell == null or spell.cards.any(func(c): return not cards.has(c)):
			return false
		cost += spell.cost()
		var d: Vector2i = one.get("dir", Vector2i.ZERO)
		if not Grid.DIRS.has(d) or not Terrain.throwable(self, spell, me.pos + d) or aims.has(d):
			return false
		aims[d] = true
	return cost <= tails


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
	if not can(action):
		return events
	var me := player()
	if me.stunned > 0:
		me.stunned -= 1
	match action.t:
		&"move":
			var to: Vector2i = me.pos + action.dir
			var foe := actor_at(to)
			if foe != null:
				_claw(me, foe)
			elif Terrain.knockable(tile(to)):
				Terrain.knock(self, me, to)
			else:
				move(me, to)
				Scent.lay(self, to)
				if me.pos == stairs:
					_ascend()
					return events
				if me.pos == elixir:
					outcome = &"won"
					emit({t = &"won"})
					return events
				if peaches.has(me.pos):
					peaches.erase(me.pos)
					var grew := me.hp >= me.max_hp
					me.max_hp += 1 if grew else 0
					me.hp += 1
					emit({t = &"heal", id = me.id, hp = me.hp, grew = grew})
		&"cast":
			for one: Dictionary in action.spells:
				var spell := Spell.make(one.cards)
				tails -= spell.cost()
				cast(me, spell, one.dir)
	_shots_phase()
	Mind.heaven_phase(self)
	_burn()
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


func emit(e: Dictionary) -> void:
	events.append(e)


func _changed() -> void:
	_light_dirty = true
	_fov.clear()


func move(a: Actor, to: Vector2i) -> void:
	emit({t = &"move", id = a.id, from = a.pos, to = to})
	a.pos = to
	_changed()
	var tread: Array = TREAD.get(tile(to), [0, "탁"])
	noise(to, maxi(a.info().get("step", 0), tread[0]), tread[1], a.faction == Actor.FOX, a.id)


## Spreads a noise around walls. Miho hears every noise in range but her own;
## heaven creatures that hear an alarm go to search its spot.
func noise(at: Vector2i, loud: int, word: String, alarm: bool, by: int) -> void:
	if loud <= 0:
		return
	var open := func(p): return not Terrain.wall(tile(p))
	var dist: PackedInt32Array = Grid.search(at, open, func(_p): return false, loud).dist
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
				a.target = at
				a.lost = 0


func set_tile(p: Vector2i, t: int) -> void:
	tiles[Grid.index(p)] = t
	_changed()


func _claw(me: Actor, foe: Actor) -> void:
	var sneak := foe.unaware()
	var n := CLAW * (SNEAK if sneak else 1)
	emit({t = &"claw", id = me.id, target = foe.id, at = foe.pos, n = n, sneak = sneak})
	noise(foe.pos, 1 if sneak else 3, "퍽", true, me.id)
	hurt(foe, n)
	if foe.alive():
		hunt_from(foe, me.pos)


func hunt_from(a: Actor, at: Vector2i) -> void:
	if a.alert != Actor.HUNT:
		emit({t = &"notice", id = a.id, at = a.pos})
	a.alert = Actor.HUNT
	a.target = at
	a.lost = 0


func cast(caster: Actor, spell: Spell, dir: Vector2i) -> void:
	emit({t = &"cast", id = caster.id, cards = spell.cards, dir = dir})
	caster.casts += 1
	var word := "웅" if spell.orb else "휙"
	noise(caster.pos, spell.cast_noise(), word, caster.faction == Actor.FOX, caster.id)
	_step(_spawn(caster, spell, caster.pos, dir))


func _spawn(caster: Actor, spell: Spell, at: Vector2i, dir: Vector2i) -> Shot:
	var s := Shot.new()
	s.id = new_id()
	s.faction = caster.faction
	s.caster = caster.id
	s.spell = spell
	s.pos = at
	s.origin = caster.pos
	s.dir = dir
	s.life = spell.life()
	shots.append(s)
	_changed()
	emit({t = &"spawn", shot = s.id, at = at, faction = s.faction, cards = spell.cards})
	return s


func _shots_phase() -> void:
	for sub in Spell.WISP_SPEED:
		for s in shots.duplicate():
			if not s.gone and sub < s.spell.speed() and s.dir != Vector2i.ZERO:
				_step(s)
	_prune()


func _fly(s: Shot, to: Vector2i) -> void:
	emit({t = &"fly", shot = s.id, from = s.pos, to = to})
	s.pos = to
	_changed()
	if s.spell.has(Cards.FIRE):
		_ignite(to)


## One tile of flight. Orbs burst on walls and closed doors and strike
## creatures; a wisp stops and hovers at a wall, before a creature, or at the
## end of its range.
func _step(s: Shot) -> void:
	if s.spell.homing():
		s.dir = Aim.steer(self, s)
	var to := s.pos + s.dir
	if not open_air(to) or (s.spell.orb and tile(to) == DOOR and opaque(to)):
		if s.spell.orb:
			var struck := tile(to)
			_burst(s)
			Terrain.smash(self, s, to, struck)
		else:
			_land(s)
		return
	var a := actor_at(to)
	if a != null:
		if s.spell.strikes():
			_fly(s, to)
			s.gone = true
			_strike(s, a)
		else:
			_land(s)
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
	if not s.spell.orb and Grid.cheb(s.origin, s.pos) >= Spell.RANGE:
		_land(s)


func _land(s: Shot) -> void:
	s.dir = Vector2i.ZERO
	emit({t = &"land", shot = s.id, at = s.pos})
	_effects(s, s.pos)


func _burst(s: Shot) -> void:
	emit({t = &"burst", shot = s.id, at = s.pos})
	s.gone = true
	_changed()
	noise(s.pos, s.spell.burst_noise(), "쾅", true, s.caster)
	if s.spell.has(Cards.FIRE):
		_splash(s, s.pos, null)
	_effects(s, s.pos, s.pos + s.dir)


## Flash and thud happen wherever the spell ends; fire sets that tile alight
## and relights the lanterns next to it, except the one an orb just struck, and
## water douses lanterns and flames.
func _effects(s: Shot, at: Vector2i, struck := Vector2i(-1, -1)) -> void:
	if s.spell.has(Cards.METAL):
		_flash(s, at)
	if s.spell.has(Cards.EARTH):
		noise(at, THUD, "쿵", true, s.caster)
	if s.spell.has(Cards.FIRE):
		_ignite(at)
	Terrain.touch(self, s, at, struck)


func _flash(s: Shot, at: Vector2i) -> void:
	emit({t = &"flash", at = at, faction = s.faction})
	var view := fov(at)
	for a in actors:
		if (
			a.alive()
			and a.faction != s.faction
			and Grid.cheb(a.pos, at) <= FLASH
			and view[Grid.index(a.pos)] == 1
		):
			a.blind = 2
			a.intent.clear()
			emit({t = &"blind", id = a.id})
			if a.faction == Actor.HEAVEN:
				a.alert = Actor.SEARCH
				a.target = at
				a.lost = 0


func _strike(s: Shot, a: Actor) -> void:
	var spell := s.spell
	var at := a.pos
	emit({t = &"hit", shot = s.id, id = a.id, at = at})
	noise(at, spell.burst_noise(), "쾅", true, s.caster)
	if Bestiary.absorbs(a.kind, spell):
		emit({t = &"absorb", id = a.id, at = at})
		return
	var weak := Bestiary.weak(a.kind, spell)
	var n := spell.damage(Grid.cheb(s.origin, at)) * (2 if weak else 1)
	if n > 0:
		hurt(a, n, weak)
	if spell.has(Cards.FIRE) and Bestiary.burns(a.kind):
		_ignite(at, true)
	if a.alive():
		if spell.has(Cards.WOOD):
			a.rooted = maxi(a.rooted, 2)
			emit({t = &"root", id = a.id})
		if spell.has(Cards.EARTH):
			a.stunned = 1
			a.intent.clear()
			emit({t = &"stun", id = a.id})
		Mind.struck(self, a, s)
	if spell.orb and spell.has(Cards.FIRE):
		_splash(s, at, a)
	_effects(s, at)


func hurt(a: Actor, n: int, weak := false) -> void:
	if not a.alive():
		return
	a.hp -= n
	emit({t = &"hurt", id = a.id, n = n, hp = a.hp, at = a.pos, weak = weak})
	if a.alive():
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
	var drop: StringName = a.info().get("drop", &"")
	tails = mini(max_tails(), tails + 1)
	emit({t = &"soul", id = a.id, at = a.pos})
	if drop != &"" and not cards.has(drop):
		cards.append(drop)
		emit({t = &"card", card = drop, at = a.pos})


func _splash(s: Shot, at: Vector2i, center: Actor) -> void:
	emit({t = &"splash", at = at, faction = s.faction})
	for d in Grid.DIRS:
		var p := at + d
		_ignite(p)
		var b := actor_at(p)
		if b != null and b != center:
			if Bestiary.absorbs(b.kind, s.spell):
				emit({t = &"absorb", id = b.id, at = p})
			else:
				var weak := Bestiary.weak(b.kind, s.spell)
				hurt(b, 2 if weak else 1, weak)
				if Bestiary.burns(b.kind):
					_ignite(p, true)
		var o := shot_at(p, s)
		if o != null and not o.spell.orb:
			o.gone = true
			_changed()
			emit({t = &"snuff", shot = o.id, at = p})


## Sets p alight if it is flammable, or whatever it is when `force`d.
func _ignite(p: Vector2i, force := false) -> void:
	if (force or FLAMMABLE.has(tile(p))) and not burning.has(p):
		burning[p] = BURN_ROUNDS
		Scent.clear(self, p)
		_changed()
		emit({t = &"ignite", at = p})


## Each burning tile crackles, burns whoever stands in it (unless it eats
## fire), may set each flammable neighbour alight, and burns down to ash.
func _burn() -> void:
	if outcome != &"":
		return
	var flame := Spell.make([Cards.FOX, Cards.FIRE])
	var caught: Array[Vector2i] = []
	for p: Vector2i in burning.keys():
		noise(p, CRACKLE, "타닥", true, 0)
		var a := actor_at(p)
		if a != null:
			emit({t = &"burn", at = p, id = a.id})
			if Bestiary.absorbs(a.kind, flame):
				emit({t = &"absorb", id = a.id, at = p})
			else:
				hurt(a, 1)
		for d in Grid.DIRS:
			if FLAMMABLE.has(tile(p + d)) and not burning.has(p + d) and rng.randf() < SPREAD:
				caught.append(p + d)
		burning[p] -= 1
		if burning[p] <= 0:
			burning.erase(p)
			set_tile(p, ASH)
			emit({t = &"burnout", at = p})
	for p in caught:
		_ignite(p)


func _end_round() -> void:
	regrow += 1
	if regrow >= TAIL_REGROW:
		regrow = 0
		tails = mini(max_tails(), tails + 1)
	for a in actors:
		if a.alive():
			a.cooldown = maxi(0, a.cooldown - 1)
			a.rooted = maxi(0, a.rooted - 1)
			a.blind = maxi(0, a.blind - 1)
			a.wary = maxi(0, a.wary - 1)
	for s in shots:
		if not s.gone and s.life > 0:
			s.life -= 1
			if s.life == 0:
				s.gone = true
				emit({t = &"fade", shot = s.id, at = s.pos})
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
	depth += 1
	tails = max_tails()
	regrow = 0
	scent.clear()
	FloorGen.build(self)
	_changed()
	sense()
	emit({t = &"ascend", depth = depth})
	var me := player()
	if me.hp < me.max_hp:
		me.hp += 1
		emit({t = &"heal", id = me.id, hp = me.hp})
