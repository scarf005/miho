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
	return not s.has(Cards.ORB) and s.slots.any(func(c): return Cards.LOBBED.has(c))


## Whether `spell` works round its caster, whatever the direction it is cast along.
static func around(s: Spell) -> bool:
	return s.shape != Spell.LEAP and (s.has(&"beacon") or s.orb and s.has(FURNACE))


## `caster` casts `spell` along `dir`: true when it is one of these, and World.cast has
## nothing more to do. A leap goes first and casts it where it lands.
static func cast(w: World, caster: Actor, spell: Spell, _dir: Vector2i) -> bool:
	if not around(spell):
		return false
	if spell.has(&"beacon"):
		_beacon(w, caster)
	else:
		_furnace(w, caster)
	return true


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
	var standing := w.actors.filter(func(a): return a.alive() and a.kind == FURNACE)
	var fixed := standing.map(func(a): return a.pos)
	var guard := Compounds.linked(w, fixed)
	var free := Spray.square(w, caster.pos, REACH).filter(
		func(p):
			return (
				Compounds.open(w, p)
				and w.vacant(p)
				and (not guard or Compounds.linked(w, fixed + [p]))
			)
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
		var dir := Grid.nearest_dir(foe.pos - a.pos)
		if not _catches_own(w, a, dir):
			w.cast(a, Spell.make(ORB), dir)
	return true


## Whether an orb `a` throws along `dir` would burst on one of its own side, where it
## stops on the first creature or at the end of its range.
static func _catches_own(w: World, a: Actor, dir: Vector2i) -> bool:
	var end := a.pos
	for p: Vector2i in Forecast.ray(w, a.pos, dir).slice(0, RANGE):
		end = p
		if w.actor_at(p) != null:
			break
	var burst := Spray.square(w, end, 1, true)
	return w.actors.any(
		func(b): return b != a and b.alive() and b.faction == a.faction and burst.has(b.pos)
	)
