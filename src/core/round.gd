class_name Round
extends RefCounted
## One round is one second of game time. Round order: Miho acts, then every
## projectile flies (interleaved, one tile per sub-step), then every other
## creature acts. A creature spends one round charging (telegraphed) before it
## casts, and its new projectiles first fly after Miho's next action.
##
## Miho's action is a move, a wait, or any number of spells whose cards together
## cost no more than her unspent tails. A spent tail regrows every TAIL_REGROW
## rounds, and a kill gives one back. Each storey climbed gives back one health.


## Runs one round of `action` and returns the events the view animates.
static func run(w: World, action: Dictionary) -> Array[Dictionary]:
	w.events = []
	w.heard = []
	w._changed()
	if not w.can(action) or Cheat.handled(w, action):
		return w.events
	var me := w.player()
	_regrow(w)
	var alight := w.burning.keys()
	Status.lapse(w, me, &"stunned")
	match action.t:
		&"move":
			var to: Vector2i = me.pos + action.dir
			var foe := w.actor_at(to)
			if foe != null and foe.faction != me.faction:
				Harm.claw(w, me, foe)
			elif Terrain.knockable(w.tile(to)):
				Terrain.knock(w, me, to)
			elif w.tile(to) == World.DOOR:
				Terrain.open_door(w, me, to)
			else:
				var storey := w.depth
				if foe != null:
					Walk.move(w, foe, me.pos)
				Walk.move(w, me, to)
				if foe != null:
					Fall.traded(w, foe, me, storey)
				if w.depth == storey:
					Scent.lay(w, to)
					if Walk.arrive(w, me):
						return w.events
		&"close":
			Terrain.close_door(w, me, me.pos + action.dir)
		&"dispel":
			Guise.dispel(w, me, action.kind)
		&"cast":
			for one: Dictionary in action.spells:
				var spell := Spell.make(one.cards)
				w.tails -= Cheat.cost(w, spell)
				Cast.cast(w, me, spell, one.dir)
	Flight.phase(w)
	Mind.heaven_phase(w)
	Terrain.burn(w, alight)
	Compounds.tick(w)
	Gas.tick(w)
	Status.tick(w)
	Vault.tick(w)
	EventRooms.tick(w)
	Statues.tick(w)
	Guise.tick(w)
	Lure.tick(w)
	end(w)
	w.sense()
	Raise.tick(w)
	return w.events


## One round of a spent tail growing back, counted before the action: the round
## a tail is spent in does not count, and nothing counts while none is missing.
static func _regrow(w: World) -> void:
	if w.tails >= w.max_tails():
		w.regrow = 0
		return
	w.regrow += 1
	if w.regrow >= World.TAIL_REGROW:
		w.regrow = 0
		w.tails += World.TAIL_REGROWN


static func end(w: World) -> void:
	Drums.dry(w)
	w.flares.clear()
	for a in w.actors:
		if a.alive():
			a.cooldown = maxi(0, a.cooldown - 1)
			Status.lapse(w, a, &"rooted")
			Status.lapse(w, a, &"blind")
			a.wary = maxi(0, a.wary - 1)
			a.grudge = maxi(0, a.grudge - 1)
	w.pungent = maxi(0, w.pungent - 1)
	Jars.arrive(w, w.player())
	for s in w.shots:
		if not s.gone and s.life > 0:
			s.life -= 1
			if s.life == 0:
				s.gone = true
				w.emit({t = &"fade", shot = s.id, at = s.pos})
				Elements.fade(w, s)
	prune(w)
	w.round_no += 1
	Curse.tick(w)


static func prune(w: World) -> void:
	var before := w.shots.size() + w.actors.size()
	w.shots.assign(w.shots.filter(func(s): return not s.gone))
	w.actors.assign(w.actors.filter(func(a): return a.alive() or a.is_miho()))
	if w.shots.size() + w.actors.size() != before:
		w._changed()


static func ascend(w: World) -> void:
	var party := Storeys.followers(w)
	Storeys.leave(w)
	Storeys.enter(w, w.depth + 1)
	Storeys.bring(w, party)
	w.regrow = 0
	w.tails = w.max_tails()
	w._changed()
	w.emit({t = &"ascend", depth = w.depth})
	var me := w.player()
	if me.hp < me.max_hp:
		me.hp += World.HEAL
		w.emit({t = &"heal", id = me.id, hp = me.hp})
	w.sense()
