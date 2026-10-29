class_name World
extends RefCounted
## The whole game state and the turn rules. `act` runs one round and returns
## the events the view animates; `preview` runs an action on a copy so the
## view can show its exact outcome before the player commits.
##
## Round order: Miho acts, then every projectile flies (interleaved, one tile per
## sub-step), then every other creature acts. A creature spends one round
## charging (telegraphed) before it casts, and its new projectiles first fly
## after Miho's next action.
##
## Miho has one tail per storey she has reached (일미호 to 구미호). Her action
## is a move, a wait, or any number of spells whose cards together cost no more
## than her unspent tails. Spent tails regrow one a round, and a kill gives one
## back.

const FLOORS := 9
const REAPER_OMEN := 40
const REAPER_ARRIVES := 45
const FOX_REACH := 7

const FLOOR := 0
const PILLAR := 1

var depth := 1
var tiles := PackedByteArray()
var start := Vector2i(4, 8)
var stairs := Vector2i(-1, -1)
var elixir := Vector2i(-1, -1)
var peaches: Array[Vector2i] = []
var actors: Array[Actor] = []
var shots: Array[Shot] = []
var next_id := 1
var tails := 1
var cards: Array[StringName] = [Cards.FOX, Cards.ORB]
var round_no := 0
var outcome := &""
var rng := RandomNumberGenerator.new()
var events: Array[Dictionary] = []


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
	return w


func clone() -> World:
	var w := World.new()
	w.depth = depth
	w.tiles = tiles.duplicate()
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
	w.cards = cards.duplicate()
	w.round_no = round_no
	w.outcome = outcome
	w.rng.seed = rng.seed
	w.rng.state = rng.state
	return w


func new_id() -> int:
	next_id += 1
	return next_id - 1


# --- queries -----------------------------------------------------------------


func player() -> Actor:
	return actors[0]


func max_tails() -> int:
	return depth


func open_floor(p: Vector2i) -> bool:
	return Grid.inside(p) and tiles[Grid.index(p)] == FLOOR


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


func occupied() -> Dictionary:
	var taken := {}
	for a in actors:
		if a.alive():
			taken[Grid.index(a.pos)] = true
	for s in shots:
		if not s.gone:
			taken[Grid.index(s.pos)] = true
	return taken


func vacant(p: Vector2i) -> bool:
	return open_floor(p) and actor_at(p) == null and shot_at(p) == null


## True when no pillar stands strictly between a and b on one of the eight lines.
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


func _can_move(dir: Vector2i) -> bool:
	var me := player()
	var to := me.pos + dir
	return me.stunned <= 0 and me.rooted <= 0 and Grid.cheb(to, me.pos) == 1 and vacant(to)


## Every spell is valid and known, line spells take distinct open directions,
## and the cards together cost no more than the unspent tails.
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
		if spell.line:
			var d: Vector2i = one.get("dir", Vector2i.ZERO)
			if not Grid.DIRS.has(d) or not open_floor(me.pos + d) or aims.has(d):
				return false
			aims[d] = true
		elif seek_tiles(me, 1).is_empty():
			return false
	return cost <= tails


## Free tiles next to the caster where foxfire appears, nearest foe first.
func seek_tiles(caster: Actor, n: int) -> Array[Vector2i]:
	var foes := actors.filter(func(a): return a.alive() and a.faction != caster.faction)
	var spots: Array[Vector2i] = []
	for d in Grid.DIRS:
		if vacant(caster.pos + d):
			spots.append(caster.pos + d)
	var near := func(p: Vector2i) -> int:
		var best := 99
		for f in foes:
			best = mini(best, Grid.cheb(p, f.pos))
		return best
	spots.sort_custom(func(a, b): return near.call(a) < near.call(b))
	return spots.slice(0, n)


## Runs `action` on a copy; the world itself does not change.
func preview(action: Dictionary) -> World:
	var w := clone()
	w.act(action)
	return w


# --- the round ---------------------------------------------------------------


func act(action: Dictionary) -> Array[Dictionary]:
	events = []
	if not can(action):
		return events
	var me := player()
	if me.stunned > 0:
		me.stunned -= 1
	match action.t:
		&"move":
			_move(me, me.pos + action.dir)
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
				_cast(me, spell, one.get("dir", Vector2i.ZERO))
	_shots_phase()
	_heaven_phase()
	_end_round()
	return events


func _emit(e: Dictionary) -> void:
	events.append(e)


func _move(a: Actor, to: Vector2i) -> void:
	_emit({t = &"move", id = a.id, from = a.pos, to = to})
	a.pos = to


func _cast(caster: Actor, spell: Spell, dir: Vector2i) -> void:
	_emit({t = &"cast", id = caster.id, cards = spell.cards, dir = dir})
	caster.casts += 1
	if spell.line:
		var s := _spawn(caster, spell, caster.pos, dir)
		_step_line(s)
		return
	for p in seek_tiles(caster, spell.count()):
		_spawn(caster, spell, p, Vector2i.ZERO)


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
	_emit({t = &"spawn", shot = s.id, at = at, faction = s.faction, cards = spell.cards})
	return s


func _shots_phase() -> void:
	for sub in Spell.SEEK_SPEED:
		for s in shots.duplicate():
			if s.gone or sub >= s.spell.speed():
				continue
			if s.spell.line:
				_step_line(s)
			else:
				_step_seek(s)
	_prune()


func _step_seek(s: Shot) -> void:
	var foes := {}
	for a in actors:
		if a.alive() and a.faction != s.faction and not s.struck.has(a.id):
			foes[Grid.index(a.pos)] = a
	for o in shots:
		if not o.gone and o.faction != s.faction and not o.spell.line:
			foes[Grid.index(o.pos)] = o
	if foes.is_empty():
		return
	var taken := occupied()
	var found := Grid.search(
		s.pos,
		func(p): return open_floor(p) and (foes.has(Grid.index(p)) or not taken.has(Grid.index(p))),
		func(p): return foes.has(Grid.index(p))
	)
	var dist: PackedInt32Array = found.dist
	var best := -1
	for i in foes:
		if (
			dist[i] > 0
			and (
				best < 0
				or dist[i] < dist[best]
				or (dist[i] == dist[best] and foes[i].id < foes[best].id)
			)
		):
			best = i
	if best < 0:
		return
	var target_pos := Grid.at(best)
	var step := Grid.first_step(found, s.pos, target_pos)
	if step != target_pos:
		_emit({t = &"fly", shot = s.id, from = s.pos, to = step})
		s.pos = step
		return
	var target = foes[best]
	if target is Shot:
		_emit({t = &"clash", shot = s.id, other = target.id, at = target_pos})
		s.gone = true
		target.gone = true
		return
	_strike(s, target, step - s.pos)
	if s.spell.has(Cards.METAL):
		s.struck.append(target.id)
	else:
		s.gone = true


func _step_line(s: Shot) -> void:
	if s.spell.homing():
		s.dir = _steer(s)
	var to := s.pos + s.dir
	if not open_floor(to):
		_emit({t = &"burst", shot = s.id, at = s.pos})
		s.gone = true
		if s.spell.has(Cards.FIRE):
			_splash(s, s.pos, null)
		return
	var a := actor_at(to)
	if a != null and not s.struck.has(a.id):
		_emit({t = &"fly", shot = s.id, from = s.pos, to = to})
		s.pos = to
		_strike(s, a, s.dir)
		if s.spell.has(Cards.METAL):
			s.struck.append(a.id)
		else:
			s.gone = true
		return
	var o := shot_at(to, s)
	if o != null:
		if o.spell.line:
			_emit({t = &"clash", shot = s.id, other = o.id, at = to})
			s.gone = true
			o.gone = true
			return
		o.gone = true
		_emit({t = &"snuff", shot = o.id, at = to})
	_emit({t = &"fly", shot = s.id, from = s.pos, to = to})
	s.pos = to


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


func _strike(s: Shot, a: Actor, dir: Vector2i) -> void:
	var spell := s.spell
	_emit({t = &"hit", shot = s.id, id = a.id, at = a.pos})
	if Bestiary.absorbs(a.kind, spell):
		_emit({t = &"absorb", id = a.id, at = a.pos})
		return
	var at := a.pos
	_hurt(a, spell.damage(Grid.cheb(s.origin, at)))
	if a.alive():
		if spell.has(Cards.WATER):
			_push(a, dir)
		if spell.has(Cards.WOOD):
			a.rooted = maxi(a.rooted, 2)
			_emit({t = &"root", id = a.id})
		if spell.has(Cards.EARTH):
			a.stunned = 1
			a.intent.clear()
			_emit({t = &"stun", id = a.id})
	if spell.has(Cards.FIRE):
		_splash(s, at, a)


func _hurt(a: Actor, n: int) -> void:
	if not a.alive():
		return
	a.hp -= n
	_emit({t = &"hurt", id = a.id, n = n, hp = a.hp, at = a.pos})
	if a.alive():
		return
	_emit({t = &"die", id = a.id, at = a.pos})
	a.intent.clear()
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


func _push(a: Actor, dir: Vector2i) -> void:
	var to := a.pos + dir
	if vacant(to):
		_emit({t = &"push", id = a.id, from = a.pos, to = to})
		a.pos = to
		return
	_emit({t = &"slam", id = a.id, at = to})
	var b := actor_at(to)
	_hurt(a, 1)
	if b != null:
		_hurt(b, 1)


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
		if o != null and not o.spell.line:
			o.gone = true
			_emit({t = &"snuff", shot = o.id, at = p})


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
		if not a.intent.is_empty():
			var spell := Spell.make(a.intent)
			a.intent.clear()
			a.cooldown = a.info().cd
			_cast(a, spell, a.aim)
			continue
		if a.cooldown <= 0:
			var plan := _plan(a)
			if not plan.is_empty():
				a.intent.assign(plan.cards)
				a.aim = plan.dir
				_emit({t = &"charge", id = a.id, cards = a.intent.duplicate(), dir = a.aim})
				continue
		if a.rooted <= 0:
			_wander(a)


func _plan(a: Actor) -> Dictionary:
	var cast := a.next_cast()
	var spell := Spell.make(cast)
	var me := player()
	if spell.homing():
		return _plan_homing(a, cast)
	if spell.line:
		var d := Grid.line_dir(a.pos, me.pos)
		if d != Vector2i.ZERO and Grid.cheb(a.pos, me.pos) >= 2 and clear_line(a.pos, me.pos):
			return {cards = cast, dir = d}
		return {}
	var found := Grid.search(a.pos, open_floor)
	var reach: int = found.dist[Grid.index(me.pos)]
	if reach > 0 and reach <= FOX_REACH and not seek_tiles(a, 1).is_empty():
		return {cards = cast, dir = Vector2i.ZERO}
	return {}


## A homing orb leaves towards Miho, or beside her line when a pillar is in the way.
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


func _wander(a: Actor) -> void:
	var info := a.info()
	match info.get("move", &"static"):
		&"approach":
			_approach(a, info.get("keep", 1))
		&"slow":
			if a.acted % 2 == 0:
				_approach(a, 1)
		&"align":
			_align(a)


func _walkable(a: Actor) -> Callable:
	var taken := occupied()
	return func(p): return open_floor(p) and (p == a.pos or not taken.has(Grid.index(p)))


func _approach(a: Actor, keep: int) -> void:
	var me := player()
	var walk := _walkable(a)
	var found := Grid.search(me.pos, func(p): return walk.call(p))
	var dist: PackedInt32Array = found.dist
	var here := dist[Grid.index(a.pos)]
	if here < 0 or here <= keep:
		return
	for d in Grid.DIRS:
		var p := a.pos + d
		if (
			Grid.inside(p)
			and p != a.pos
			and dist[Grid.index(p)] >= 0
			and dist[Grid.index(p)] < here
			and vacant(p)
		):
			_move(a, p)
			return


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
		_approach(a, 2)
		return
	_move(a, Grid.first_step(found, a.pos, Grid.at(best)))


func _end_round() -> void:
	tails = mini(max_tails(), tails + 1)
	for a in actors:
		if a.alive():
			a.cooldown = maxi(0, a.cooldown - 1)
			a.rooted = maxi(0, a.rooted - 1)
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
			_emit({t = &"arrive", id = saja.id, at = spot})


func _prune() -> void:
	shots.assign(shots.filter(func(s): return not s.gone))
	actors.assign(actors.filter(func(a): return a.alive() or a.faction == Actor.FOX))


func _ascend() -> void:
	depth += 1
	tails = max_tails()
	FloorGen.build(self)
	_emit({t = &"ascend", depth = depth})
