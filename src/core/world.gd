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
## Miho's wisps, and hunt her once they see her. Claws strike three times as
## hard at a creature that is not hunting (Brogue CE Combat.c sneak attack).
##
## Lanterns and doors break. Miho knocks a lantern out by walking into it,
## with a clang; an orb smashes the lantern or closed door it strikes. Water
## douses lanterns next to where it ends, silently, and fire relights them; a
## searching creature relights a lantern it stands next to.
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
const SEARCH_ROUNDS := 6
const CLAW := 1
const SNEAK := 3
const CRY := 5
const THUD := 9
const FLASH := 2
const KNOCK := 4

const FLOOR := 0
const WALL := 1
const DOOR := 2
const LANTERN := 3
const LANTERN_OUT := 4

var depth := 1
var tiles := PackedByteArray()
var rooms: Array[Rect2i] = []
var start := Vector2i.ZERO
var stairs := Vector2i(-1, -1)
var elixir := Vector2i(-1, -1)
var peaches: Array[Vector2i] = []
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


## Creatures and projectiles can be here.
func open_floor(p: Vector2i) -> bool:
	var t := tile(p)
	return t == FLOOR or t == DOOR


## Walls and closed doors block sight and light; a door is open while something is in it.
func opaque(p: Vector2i) -> bool:
	var t := tile(p)
	return t == WALL or (t == DOOR and actor_at(p) == null and shot_at(p) == null)


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


## True when no wall stands strictly between a and b on one of the eight lines.
func clear_line(a: Vector2i, b: Vector2i) -> bool:
	var d := Grid.line_dir(a, b)
	if d == Vector2i.ZERO:
		return false
	var p := a + d
	while p != b:
		if not open_floor(p):
			return false
		p += d
	return true


func light_sources() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in tiles.size():
		if tiles[i] == LANTERN:
			out.append({at = Grid.at(i), radius = Light.LANTERN_RADIUS, color = Light.LANTERN})
	for s in shots:
		if not s.gone:
			var l := s.spell.light(s.faction)
			if not l.is_empty():
				out.append({at = s.pos, radius = l.radius, color = l.color})
	return out


func light() -> PackedVector3Array:
	if _light_dirty:
		_light = Light.field(light_sources(), opaque)
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
	return Grid.cheb(a.pos, p) <= NIGHT[a.faction] or lit(p)


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


## A step onto a free tile, claws at a creature next to Miho, or a knock at a lantern.
func _can_move(dir: Vector2i) -> bool:
	var me := player()
	var to := me.pos + dir
	if me.stunned > 0 or Grid.cheb(to, me.pos) != 1:
		return false
	var foe := actor_at(to)
	if foe != null:
		return foe.faction != me.faction
	return tile(to) == LANTERN or (me.rooted <= 0 and vacant(to))


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
		if not Grid.DIRS.has(d) or not open_floor(me.pos + d) or aims.has(d):
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
			elif tile(to) == LANTERN:
				_knock(me, to)
			else:
				_move(me, to)
				if me.pos == stairs:
					_ascend()
					return events
				if me.pos == elixir:
					outcome = &"won"
					_emit({t = &"won"})
					return events
				if peaches.has(me.pos):
					peaches.erase(me.pos)
					me.hp = mini(me.max_hp, me.hp + 1)
					_emit({t = &"heal", id = me.id, hp = me.hp})
		&"cast":
			for one: Dictionary in action.spells:
				var spell := Spell.make(one.cards)
				tails -= spell.cost()
				_cast(me, spell, one.dir)
	_shots_phase()
	_heaven_phase()
	_end_round()
	sense()
	return events


## Updates what Miho sees, makes out in the dark, and remembers.
func sense() -> void:
	_changed()
	var me := player()
	var from := fov(me.pos)
	seen = PackedByteArray()
	seen.resize(tiles.size())
	dim = seen.duplicate()
	if known.size() != tiles.size():
		known.resize(tiles.size())
	for i in tiles.size():
		if from[i] == 0:
			continue
		var p := Grid.at(i)
		if sees(me, p):
			seen[i] = 1
			known[i] = 1
		elif Grid.cheb(p, me.pos) <= DIM and me.blind <= 0:
			dim[i] = 1
			known[i] = 1


func _emit(e: Dictionary) -> void:
	events.append(e)


func _changed() -> void:
	_light_dirty = true
	_fov.clear()


func _move(a: Actor, to: Vector2i) -> void:
	_emit({t = &"move", id = a.id, from = a.pos, to = to})
	a.pos = to
	_changed()
	if a.faction == Actor.HEAVEN:
		_noise(to, a.info().get("step", 0), "탁", false, a.id)


## Spreads a noise around walls. Miho hears every noise in range but her own;
## heaven creatures that hear an alarm go to search its spot.
func _noise(at: Vector2i, loud: int, word: String, alarm: bool, by: int) -> void:
	if loud <= 0:
		return
	var dist: PackedInt32Array = Grid.search(at, func(p): return tile(p) != WALL).dist
	var me := player()
	var d := dist[Grid.index(me.pos)]
	var heard_it := by != me.id and d >= 0 and d <= loud
	if heard_it:
		heard.append({at = at, word = word})
	_emit({t = &"noise", at = at, word = word, loud = loud, heard = heard_it})
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


func _knock(me: Actor, at: Vector2i) -> void:
	_set_tile(at, LANTERN_OUT)
	_emit({t = &"smash", at = at})
	_noise(at, KNOCK, "쨍", true, me.id)


func _set_tile(p: Vector2i, t: int) -> void:
	tiles[Grid.index(p)] = t
	_changed()


func _claw(me: Actor, foe: Actor) -> void:
	var sneak := foe.alert != Actor.HUNT or foe.blind > 0
	var n := CLAW * (SNEAK if sneak else 1)
	_emit({t = &"claw", id = me.id, target = foe.id, at = foe.pos, n = n, sneak = sneak})
	_noise(foe.pos, 1 if sneak else 3, "퍽", true, me.id)
	_hurt(foe, n)
	if foe.alive():
		_hunt_from(foe, me.pos)


func _club(a: Actor, me: Actor, n: int) -> void:
	_emit({t = &"club", id = a.id, target = me.id, at = me.pos, n = n})
	_noise(me.pos, 3, "퍽", true, a.id)
	_hurt(me, n)


func _hunt_from(a: Actor, at: Vector2i) -> void:
	if a.alert != Actor.HUNT:
		_emit({t = &"notice", id = a.id, at = a.pos})
	a.alert = Actor.HUNT
	a.target = at
	a.lost = 0


func _cast(caster: Actor, spell: Spell, dir: Vector2i) -> void:
	_emit({t = &"cast", id = caster.id, cards = spell.cards, dir = dir})
	caster.casts += 1
	var word := "웅" if spell.orb else "휙"
	_noise(caster.pos, spell.cast_noise(), word, caster.faction == Actor.FOX, caster.id)
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
	_emit({t = &"spawn", shot = s.id, at = at, faction = s.faction, cards = spell.cards})
	return s


func _shots_phase() -> void:
	for sub in Spell.WISP_SPEED:
		for s in shots.duplicate():
			if not s.gone and sub < s.spell.speed() and s.dir != Vector2i.ZERO:
				_step(s)
	_prune()


func _fly(s: Shot, to: Vector2i) -> void:
	_emit({t = &"fly", shot = s.id, from = s.pos, to = to})
	s.pos = to
	_changed()


## One tile of flight. Orbs burst on walls and closed doors and strike
## creatures; a wisp stops and hovers at a wall, before a creature, or at the
## end of its range.
func _step(s: Shot) -> void:
	if s.spell.homing():
		s.dir = _steer(s)
	var to := s.pos + s.dir
	if not open_floor(to) or (s.spell.orb and tile(to) == DOOR and opaque(to)):
		if s.spell.orb:
			var struck := tile(to)
			_burst(s)
			_smash(s, to, struck)
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
			_emit({t = &"clash", shot = s.id, other = o.id, at = to})
			s.gone = true
			o.gone = true
			_changed()
			return
		if s.spell.orb:
			o.gone = true
			_emit({t = &"snuff", shot = o.id, at = to})
		elif o.spell.orb:
			_land(s)
			return
	_fly(s, to)
	if not s.spell.orb and Grid.cheb(s.origin, s.pos) >= Spell.RANGE:
		_land(s)


func _land(s: Shot) -> void:
	s.dir = Vector2i.ZERO
	_emit({t = &"land", shot = s.id, at = s.pos})
	_effects(s, s.pos)


func _burst(s: Shot) -> void:
	_emit({t = &"burst", shot = s.id, at = s.pos})
	s.gone = true
	_changed()
	_noise(s.pos, s.spell.burst_noise(), "쾅", true, s.caster)
	if s.spell.has(Cards.FIRE):
		_splash(s, s.pos, null)
	_effects(s, s.pos)


## Flash and thud happen wherever the spell ends; fire there relights the
## lanterns next to it, and water douses them.
func _effects(s: Shot, at: Vector2i) -> void:
	if s.spell.has(Cards.METAL):
		_flash(s, at)
	if s.spell.has(Cards.EARTH):
		_noise(at, THUD, "쿵", true, s.caster)
	for d in Grid.DIRS:
		var p := at + d
		if s.spell.has(Cards.FIRE) and tile(p) == LANTERN_OUT:
			_set_tile(p, LANTERN)
			_emit({t = &"relight", at = p})
		if s.spell.has(Cards.WATER) and tile(p) == LANTERN:
			_set_tile(p, LANTERN_OUT)
			_emit({t = &"douse", at = p})


## An orb without water breaks the lit lantern or the closed door it struck.
func _smash(s: Shot, at: Vector2i, struck: int) -> void:
	if s.spell.has(Cards.WATER) or tile(at) != struck or (struck != LANTERN and struck != DOOR):
		return
	_set_tile(at, LANTERN_OUT if struck == LANTERN else FLOOR)
	_emit({t = &"smash", at = at})


func _flash(s: Shot, at: Vector2i) -> void:
	_emit({t = &"flash", at = at, faction = s.faction})
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
			_emit({t = &"blind", id = a.id})
			if a.faction == Actor.HEAVEN:
				a.alert = Actor.SEARCH
				a.target = at
				a.lost = 0


func _steer(s: Shot) -> Vector2i:
	var target: Actor = null
	for a in actors:
		if a.alive() and a.faction != s.faction:
			if (
				target == null
				or Vector2(a.pos - s.pos).length() < Vector2(target.pos - s.pos).length()
			):
				target = a
	if target == null:
		return s.dir
	var i := Grid.DIRS.find(s.dir)
	var best := s.dir
	var best_len := Vector2(target.pos - (s.pos + s.dir)).length()
	for turn in [-1, 1]:
		var d := Grid.DIRS[(i + turn + 8) % 8]
		var length := Vector2(target.pos - (s.pos + d)).length()
		if length < best_len - 0.001:
			best = d
			best_len = length
	return best


func _strike(s: Shot, a: Actor) -> void:
	var spell := s.spell
	var at := a.pos
	_emit({t = &"hit", shot = s.id, id = a.id, at = at})
	_noise(at, spell.burst_noise(), "쾅", true, s.caster)
	if Bestiary.absorbs(a.kind, spell):
		_emit({t = &"absorb", id = a.id, at = at})
		return
	var n := spell.damage(Grid.cheb(s.origin, at))
	if n > 0:
		_hurt(a, n)
	if a.alive():
		if spell.has(Cards.WOOD):
			a.rooted = maxi(a.rooted, 2)
			_emit({t = &"root", id = a.id})
		if spell.has(Cards.EARTH):
			a.stunned = 1
			a.intent.clear()
			_emit({t = &"stun", id = a.id})
		if a.faction == Actor.HEAVEN and a.alert != Actor.HUNT:
			a.alert = Actor.SEARCH
			a.target = s.origin
			a.lost = 0
	if spell.orb and spell.has(Cards.FIRE):
		_splash(s, at, a)
	_effects(s, at)


func _hurt(a: Actor, n: int) -> void:
	if not a.alive():
		return
	a.hp -= n
	_emit({t = &"hurt", id = a.id, n = n, hp = a.hp, at = a.pos})
	if a.alive():
		if a.faction == Actor.HEAVEN:
			_noise(a.pos, CRY, "끽", true, a.id)
		return
	_emit({t = &"die", id = a.id, at = a.pos})
	a.intent.clear()
	_changed()
	if a.faction == Actor.FOX:
		outcome = &"lost"
		_emit({t = &"lost"})
		return
	var drop: StringName = a.info().get("drop", &"")
	tails = mini(max_tails(), tails + 1)
	_emit({t = &"soul", id = a.id, at = a.pos})
	if drop != &"" and not cards.has(drop):
		cards.append(drop)
		_emit({t = &"card", card = drop, at = a.pos})


func _splash(s: Shot, at: Vector2i, center: Actor) -> void:
	_emit({t = &"splash", at = at, faction = s.faction})
	for d in Grid.DIRS:
		var p := at + d
		var b := actor_at(p)
		if b != null and b != center:
			if Bestiary.absorbs(b.kind, s.spell):
				_emit({t = &"absorb", id = b.id, at = p})
			else:
				_hurt(b, 1)
		var o := shot_at(p, s)
		if o != null and not o.spell.orb:
			o.gone = true
			_changed()
			_emit({t = &"snuff", shot = o.id, at = p})


# --- heaven ------------------------------------------------------------------


func _heaven_phase() -> void:
	for a in actors.duplicate():
		if outcome != &"":
			return
		if not a.alive() or a.faction == Actor.FOX:
			continue
		a.acted += 1
		if a.stunned > 0:
			a.stunned -= 1
			continue
		_perceive(a)
		if not a.intent.is_empty():
			var spell := Spell.make(a.intent)
			a.intent.clear()
			a.cooldown = a.info().cd
			_cast(a, spell, a.aim)
			continue
		if a.blind > 0:
			continue
		match a.alert:
			Actor.HUNT:
				_hunt(a)
			Actor.SEARCH:
				_search(a)
			_:
				_rest(a)


## Sight first: seeing Miho starts a hunt; seeing one of her wisps starts a search.
func _perceive(a: Actor) -> void:
	var me := player()
	a.sees_me = sees(a, me.pos)
	if a.sees_me or a.info().get("hunts", false):
		_hunt_from(a, me.pos)
		return
	if a.alert == Actor.HUNT or a.blind > 0:
		return
	for s in shots:
		if not s.gone and s.faction != a.faction and sees(a, s.pos):
			a.alert = Actor.SEARCH
			a.target = s.pos
			a.lost = 0
			return


func _hunt(a: Actor) -> void:
	var me := player()
	if a.sees_me:
		var club: int = a.info().get("club", 0)
		if club > 0 and Grid.cheb(a.pos, me.pos) == 1:
			_club(a, me, club)
			return
		if a.cooldown <= 0 and _charge(a, _plan(a)):
			return
		if a.rooted <= 0:
			_chase(a)
		return
	if a.info().get("hunts", false):
		if a.rooted <= 0:
			_step_to(a, me.pos, 1)
		return
	if a.pos != a.target and a.lost < SEARCH_ROUNDS:
		a.lost += 1
		if a.rooted > 0 or _step_to(a, a.target):
			return
	a.alert = Actor.SEARCH
	a.lost = 0
	_search(a)


## Goes to the spot, throwing a wisp at it first when it lies in the dark.
## Next to a lantern that went out, it lights it again first.
func _search(a: Actor) -> void:
	for d in Grid.DIRS:
		if tile(a.pos + d) == LANTERN_OUT:
			_set_tile(a.pos + d, LANTERN)
			_emit({t = &"relight", at = a.pos + d, id = a.id})
			return
	if a.cooldown <= 0 and _charge(a, _searchlight(a)):
		return
	if a.rooted > 0:
		return
	if a.pos != a.target and _step_to(a, a.target):
		return
	a.lost += 1
	if a.lost > SEARCH_ROUNDS:
		a.alert = Actor.REST
		a.lost = 0
		_emit({t = &"calm", id = a.id})
		return
	_drift(a)


func _rest(a: Actor) -> void:
	if a.rooted > 0:
		return
	if not a.info().get("patrol", false):
		if a.pos != a.home:
			_step_to(a, a.home)
		return
	if a.pos == a.post or not _step_to(a, a.post):
		a.post = FloorGen.patrol_point(self)


func _charge(a: Actor, plan: Dictionary) -> bool:
	if plan.is_empty():
		return false
	a.intent.assign(plan.cards)
	a.aim = plan.dir
	_emit({t = &"charge", id = a.id, cards = a.intent.duplicate(), dir = a.aim})
	return true


## An attack along a line at Miho, when it sees her.
func _plan(a: Actor) -> Dictionary:
	var cast := a.next_cast()
	var spell := Spell.make(cast)
	var me := player()
	if spell.homing():
		return _plan_homing(a, cast)
	if not spell.strikes():
		return {}
	var d := Grid.line_dir(a.pos, me.pos)
	var r := Grid.cheb(a.pos, me.pos)
	if (
		d != Vector2i.ZERO
		and r >= 2
		and clear_line(a.pos, me.pos)
		and (spell.orb or r <= Spell.RANGE)
	):
		return {cards = cast, dir = d}
	return {}


## A homing orb leaves towards Miho, or beside her line when a wall is in the way.
func _plan_homing(a: Actor, cast: Array) -> Dictionary:
	var me := player()
	if Grid.cheb(a.pos, me.pos) > 6:
		return {}
	var i := Grid.DIRS.find(Grid.nearest_dir(me.pos - a.pos))
	for turn in [0, -1, 1]:
		var dir := Grid.DIRS[(i + turn + 8) % 8]
		if open_floor(a.pos + dir):
			return {cards = cast, dir = dir}
	return {}


## A wisp thrown at a dark spot it is searching.
func _searchlight(a: Actor) -> Dictionary:
	var cast := a.next_cast()
	var spell := Spell.make(cast)
	if spell == null or not spell.wisp or spell.orb or lit(a.target):
		return {}
	var r := Grid.cheb(a.pos, a.target)
	if r < 2 or r > Spell.RANGE:
		return {}
	var dir := Grid.nearest_dir(a.target - a.pos)
	if not open_floor(a.pos + dir):
		return {}
	return {cards = cast, dir = dir}


func _chase(a: Actor) -> void:
	var me := player()
	match a.info().get("move", &"static"):
		&"approach":
			_step_to(a, me.pos, 1)
		&"slow":
			if a.acted % 2 == 0:
				_step_to(a, me.pos, 1)
		&"align":
			_align(a)


func _walkable(a: Actor) -> Callable:
	return func(p): return p == a.pos or vacant(p)


## One step along a shortest path towards `goal`, stopping `keep` tiles short;
## among equal paths it takes the straightest.
func _step_to(a: Actor, goal: Vector2i, keep := 0) -> bool:
	if a.info().get("move", &"static") == &"static":
		return false
	var walk := _walkable(a)
	var dist: PackedInt32Array = Grid.search(goal, func(p): return walk.call(p)).dist
	var here := dist[Grid.index(a.pos)]
	if here < 0 or here <= keep:
		return false
	var best := a.pos
	var best_cost := INF
	for d in Grid.DIRS:
		var p := a.pos + d
		if not Grid.inside(p) or dist[Grid.index(p)] < 0 or not vacant(p):
			continue
		var cost := dist[Grid.index(p)] + Vector2(goal - p).length() * 0.01
		if dist[Grid.index(p)] < here and cost < best_cost:
			best = p
			best_cost = cost
	if best == a.pos:
		return false
	_move(a, best)
	return true


func _drift(a: Actor) -> void:
	if a.info().get("move", &"static") == &"static":
		return
	var free: Array[Vector2i] = []
	for d in Grid.DIRS:
		if vacant(a.pos + d):
			free.append(a.pos + d)
	if not free.is_empty():
		_move(a, free[rng.randi_range(0, free.size() - 1)])


func _align(a: Actor) -> void:
	var me := player()
	var good := func(q: Vector2i) -> bool:
		var r := Grid.cheb(q, me.pos)
		return r >= 3 and r <= 6 and clear_line(q, me.pos)
	if good.call(a.pos):
		return
	var walk := _walkable(a)
	var found := Grid.search(a.pos, func(p): return walk.call(p))
	var dist: PackedInt32Array = found.dist
	var best := -1
	for i in dist.size():
		if dist[i] > 0 and good.call(Grid.at(i)) and (best < 0 or dist[i] < dist[best]):
			best = i
	if best < 0:
		_step_to(a, me.pos, 2)
		return
	_move(a, Grid.first_step(found, a.pos, Grid.at(best)))


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
	for s in shots:
		if not s.gone and s.life > 0:
			s.life -= 1
			if s.life == 0:
				s.gone = true
				_emit({t = &"fade", shot = s.id, at = s.pos})
	_prune()
	round_no += 1
	if outcome != &"" or depth >= FLOORS:
		return
	if round_no == REAPER_OMEN:
		_emit({t = &"omen", at = start})
	elif round_no == REAPER_ARRIVES:
		var spot := FloorGen.nearest_free(self, start)
		if spot.x >= 0:
			var saja := FloorGen.spawn(self, &"saja", spot)
			_changed()
			_emit({t = &"arrive", id = saja.id, at = spot})


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
	FloorGen.build(self)
	_changed()
	sense()
	_emit({t = &"ascend", depth = depth})
