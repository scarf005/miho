class_name Flight
extends RefCounted
## How projectiles fly. After Miho acts, every projectile flies (interleaved, one tile
## per sub-step), and then every other creature acts. A creature spends one round
## charging (telegraphed) before it casts, and its new projectiles first fly after
## Miho's next action.


static func spawn(w: World, caster: Actor, spell: Spell, dir: Vector2i, target: int) -> Shot:
	var s := Shot.of(w, caster, spell)
	s.dir = dir
	s.life = spell.life()
	s.target = target
	s.turn = spell.turn()
	w.shots.append(s)
	w._changed()
	w.emit(
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


static func phase(w: World) -> void:
	var top := Spell.BULLET_SPEED
	for s: Shot in w.shots:
		top = maxi(top, s.pace())
	for sub in top:
		for s: Shot in w.shots.duplicate():
			if not s.gone and sub < s.pace() and s.dir != Vector2i.ZERO and not rides(w, s):
				step(w, s)
	for s: Shot in w.shots:
		if not s.gone and s.dir != Vector2i.ZERO and not rides(w, s):
			s.age += 1
	Round.prune(w)


static func fly(w: World, s: Shot, to: Vector2i) -> void:
	w.emit({t = &"fly", shot = s.id, from = s.pos, to = to})
	s.pos = to
	s.flown += 1
	w._changed()
	if s.spell.has(Cards.FIRE):
		Terrain.ignite(w, to)
	if w.actor_at(to) == null:
		Traps.enter(w, s, s.dir)


## One tile of flight. Orbs burst on walls and closed doors; every projectile
## strikes the creature it reaches; a wisp stops and hovers at a wall or after
## Spell.RANGE tiles, chasing or not, and flies no more; a piercing one goes on
## through creatures and a wall (Elements.bore, pass_through).
static func step(w: World, s: Shot) -> void:
	if s.turn > 0:
		s.dir = Homing.steer(w, s)
		var t := w.actor(s.target)
		if t != null and t.pos == s.pos and not s.spell.pierces():
			s.gone = true
			_strike(w, s, t)
			return
	var to := s.pos + s.dir
	if s.spell.pierces() and Elements.bore(w, s, to):
		to += s.dir
	elif not w.open_air(to) or (s.spell.orb and w.tile(to) == World.DOOR and w.opaque(to)):
		if s.spell.orb:
			var struck := w.tile(to)
			_burst(w, s)
			Terrain.smash(w, s, to, struck)
		else:
			_land(w, s)
		return
	var a := w.actor_at(to)
	if a != null:
		fly(w, s, to)
		if s.spell.pierces():
			s.gone = not Elements.pass_through(w, s, a)
			return
		s.gone = true
		_strike(w, s, a)
		return
	var o := w.shot_at(to, s)
	if o != null:
		if s.spell.orb and o.spell.orb:
			w.emit({t = &"clash", shot = s.id, other = o.id, at = to})
			s.gone = true
			o.gone = true
			w._changed()
			return
		if s.spell.orb:
			o.gone = true
			w.emit({t = &"snuff", shot = o.id, at = to})
		elif o.spell.orb:
			_land(w, s)
			return
	fly(w, s, to)
	if not s.gone and not s.spell.orb and s.flown >= Spell.RANGE:
		_land(w, s)


static func _land(w: World, s: Shot) -> void:
	s.life = Spell.WISP_LIFE
	w.emit({t = &"land", shot = s.id, at = s.pos})
	_effects(w, s, s.pos)


static func _burst(w: World, s: Shot) -> void:
	w.emit({t = &"burst", shot = s.id, at = s.pos, cards = s.spell.cards})
	s.gone = true
	w._changed()
	Hearing.noise(w, s.pos, s.spell.burst_noise(), "쾅", true, s.caster)
	if s.spell.blasts():
		Elements.splash(w, s, s.pos, null)
	_effects(w, s, s.pos, s.pos + s.dir)


## A thud happens wherever the spell ends; fire sets that tile alight and
## relights the lanterns next to it, except the one an orb just struck, water
## douses lanterns and flames, a wood orb grows a wall (Elements), and each
## compound acts round where it ends (Compounds); 도약 brings Miho (Leap.swap).
static func _effects(w: World, s: Shot, at: Vector2i, struck := Vector2i(-1, -1)) -> void:
	if s.spell.has(Cards.EARTH):
		Hearing.noise(w, at, World.THUD, "쿵", true, s.caster)
	if s.spell.has(Cards.FIRE):
		Terrain.ignite(w, at)
	Terrain.touch(w, s, at, struck)
	if s.spell.orb and s.spell.has(Cards.WOOD):
		Elements.sprout(w, s, at)
	Compounds.land(w, s, at)
	s.dir = Vector2i.ZERO
	Leap.swap(w, s, w.actor_at(at))


static func _strike(w: World, s: Shot, a: Actor) -> void:
	var spell := s.spell
	var at := a.pos
	w.emit(
		{
			t = &"hit",
			shot = s.id,
			id = a.id,
			at = at,
			by = s.caster,
			title = spell.title(),
			cards = spell.cards,
			spell = spell.tag()
		}
	)
	Hearing.noise(w, at, spell.burst_noise(), "쾅", true, s.caster)
	var storey := w.depth
	if not Elements.strike(w, s, a, spell.damage(Grid.cheb(s.origin, at))) or w.depth != storey:
		return
	if spell.blasts():
		Elements.splash(w, s, at, a)
	_effects(w, s, at)
	if not spell.orb and not spell.gun():
		Elements.stick(w, s, a)


## Whether `s` rides a living creature, and so neither flies nor strikes again.
static func rides(w: World, s: Shot) -> bool:
	var a := w.actor(s.host)
	return a != null and a.alive()
