class_name Cast
extends RefCounted
## A creature casts a spell: a buff, a leap, a spray, or projectiles that fly (Flight).


static func cast(w: World, caster: Actor, spell: Spell, dir: Vector2i) -> void:
	w.emit(
		{t = &"cast", id = caster.id, cards = spell.cards, dir = dir, bolt = Elements.bolt(spell)}
	)
	caster.magic.casts += 1
	Bunsin.learn(caster, spell, dir)
	if Guise.cast(w, caster, spell, dir) or Bunsin.cast(w, caster, spell, dir):
		return
	if Forge.cast(w, caster, spell, dir):
		return
	if spell.shape in [Spell.LEAP, Spell.SPRAY]:
		(Leap if spell.shape == Spell.LEAP else Spray).cast(w, caster, spell, dir)
		return
	if spell.gun():
		w.flares.append(caster.pos)
		w._light_dirty = true
	Hearing.noise(
		w, caster.pos, spell.cast_noise(), spell.cast_word(), caster.faction == Actor.FOX, caster.id
	)
	var targets := Homing.targets(w, caster, spell, dir)
	var heads := Homing.headings(w, caster, spell, dir, targets)
	for i in heads.size():
		var s := Flight.spawn(w, caster, spell, heads[i], targets[i])
		if spell.orb:
			# An orb that leaves on the line of one before it trails it from the caster.
			if not heads.slice(0, i).has(heads[i]):
				Flight.step(w, s)
		elif heads[i] == dir:
			Elements.loose(w, s)
		else:
			Flight.fly(w, s, s.pos + s.dir)
			s.dir = Homing.facing(w, s)
