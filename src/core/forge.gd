class_name Forge
extends RefCounted
## What lets out orbs of lava (Spell.lobbed). 봉화 (목, 화, 토, 금) sends a homing one along
## every open direction round its caster. 용광로 (구, 화, 토, 금) sets a FURNACE on a free tile
## within REACH: an ally that stands where it is put and every FIRE_ROUNDS rounds hurls an orb
## along the line nearest the closest foe it sees, unless that would catch its own side
## (Aim.catches).

const FURNACE := &"furnace"
## Tiles an orb of lava flies before it bursts.
const RANGE := 5
const REACH := 3
const FIRE_ROUNDS := 2
const ORB := [Cards.ORB, Cards.FIRE, Cards.EARTH]
const HOMING := [Cards.FOX, Cards.ORB, Cards.FIRE, Cards.EARTH]


## An orb of lava, which bursts after RANGE tiles.
static func lobbed(s: Spell) -> bool:
	return s.orb and s.has(&"lava")


## Whether `s` holds a compound that goes only with an orb and has none (Cards.LOBBED).
static func needs_orb(s: Spell) -> bool:
	return not s.orb and s.slots.any(func(c): return Cards.LOBBED.has(c))


## `caster` casts `spell` along `dir`: true when it is one of these, and World.cast has
## nothing more to do. A leap goes first and casts it where it lands.
static func cast(w: World, caster: Actor, spell: Spell, _dir: Vector2i) -> bool:
	if spell.shape == Spell.LEAP:
		return false
	if spell.has(&"beacon"):
		_beacon(w, caster)
		return true
	if spell.orb and spell.has(FURNACE):
		_furnace(w, caster)
		return true
	return false


static func _beacon(w: World, caster: Actor) -> void:
	var spell := Spell.make(HOMING)
	w.noise(
		caster.pos, spell.cast_noise(), spell.cast_word(), caster.faction == Actor.FOX, caster.id
	)
	for d in Grid.DIRS:
		var a := w.actor_at(caster.pos + d)
		if w.open_air(caster.pos + d) and (a == null or a.faction != caster.faction):
			w._step(w._spawn(caster, spell, d, Homing.targets(w, caster, spell, d)[0]))


static func _furnace(w: World, caster: Actor) -> void:
	var free := Spray.square(w, caster.pos, REACH).filter(
		func(p): return Compounds.open(w, p) and w.vacant(p)
	)
	if free.is_empty():
		return
	FloorGen.spawn(w, FURNACE, free[w.rng.randi() % free.size()])
	w._changed()


## A furnace's round: true for a furnace, which does nothing else.
static func turn(w: World, a: Actor) -> bool:
	if a.kind != FURNACE:
		return false
	var foe := w.actor(a.rival) if a.fighting() else null
	if foe != null and foe.alive() and Hat.sees(w, a, foe) and a.acted % FIRE_ROUNDS == 0:
		var plan := {cards = ORB, dir = Grid.nearest_dir(foe.pos - a.pos)}
		if not Aim.catches(w, a, plan, foe):
			w.cast(a, Spell.make(plan.cards), plan.dir)
	return true
