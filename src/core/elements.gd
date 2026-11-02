class_name Elements
extends RefCounted
## What the elements a projectile carries do, by its form, one step stronger
## for every copy past the first (Spell.extra):
## 불: a wisp sets the creature it strikes alight (Status: Miho's tile, so she
## can step off it); an orb bursts, hurting the
## eight tiles round it for World.FIRE_DAMAGE and setting what burns there
## alight (`splash`), and a wood creature it strikes catches alight. 1 more harm
## a copy. Both set alight what burns where they fly and end.
## 물: silent. Where it ends it douses lanterns and fire in the 3x3 round it,
## the struck creature's tile among them (Terrain.touch). A wisp of it carries
## darkness. An orb of it pushes the creature it strikes Spray.PLAIN_PUSH tiles
## (World.push), a tile more a copy.
## 쇠: a gun. A wisp is a bullet: BULLET harm, Spell.BULLET_SPEED, no light,
## heard Spray.GUN_LOUD. An orb is a cannonball: CANNON more harm, it pushes
## the creature it strikes CANNON_PUSH tiles (World.push), but for a 비격진,
## which bursts on it, and fells the wall it strikes, heard CANNON_LOUD. Either
## lights the caster's tile for the
## round (World.flares). 1 more harm a copy. A wisp of two 쇠 pierces: it goes
## through every creature, hurting each once, and one wall (`bore`,
## `pass_through`).
## 흙: thuds World.THUD where it ends. A wisp stuns STUN rounds, a round more a
## copy; an orb fells the wall it strikes in one blow.
## 나무: a wisp roots ROOT rounds, a round more a copy; an orb grows a wooden
## wall of WALL tiles across its line where it ends, a tile more a copy.
## A spray carries each element's wisp effect on the creatures it covers
## (Spray._compound), but fire there sets only wood creatures alight.

const ROOT := 2
const STUN := 1
const BULLET := 2
const CANNON := 2
const CANNON_PUSH := 2
const CANNON_LOUD := 13
const WALL := 3
## The harm a creature takes from a spell it is weak to (Bestiary.weak), times.
const WEAK := 2


## `s` strikes `a` for `n` before weakness: unless `a` eats the spell, it is
## hurt (twice over when weak), catches fire, and the elements afflict it.
## False when it ate the spell.
static func strike(w: World, s: Shot, a: Actor, n: int) -> bool:
	var spell := s.spell
	if absorbed(w, s, a):
		Mind.struck(w, a, s)
		return false
	harm(w, s, a, n)
	if spell.has(Cards.FIRE) and (spell.shape == Spell.WISP or Bestiary.burns(a.kind)):
		Status.ignite(w, a)
	if a.alive():
		if spell.orb and spell.has(Cards.METAL) and not spell.mortar():
			w.push(a, s.dir, CANNON_PUSH)
		if spell.orb and spell.has(Cards.WATER) and a.alive():
			w.push(a, s.dir, Spray.PLAIN_PUSH + spell.extra(Cards.WATER))
		if not spell.orb and spell.has(Cards.WOOD):
			root(w, a, ROOT + spell.extra(Cards.WOOD))
		if not spell.orb and spell.has(Cards.EARTH):
			stun(w, a, STUN + spell.extra(Cards.EARTH))
		Mind.struck(w, a, s)
	return true


## Whether `a` takes no harm or effect from `s`; one that eats it grows.
static func absorbed(w: World, s: Shot, a: Actor) -> bool:
	if not Bestiary.absorbs(a.kind, s.spell):
		return false
	w.emit({t = &"absorb", id = a.id, at = a.pos})
	if Bestiary.eats(a.kind, s.spell):
		a.max_hp += Bestiary.GROWTH
		a.hp += Bestiary.GROWTH
		w.emit({t = &"grow", id = a.id, hp = a.hp, max_hp = a.max_hp})
	return true


## `s` hurts `a` for n, twice over when `a` is weak to it.
static func harm(w: World, s: Shot, a: Actor, n: int, conducts := false) -> void:
	var weak := conducts or Bestiary.weak(a.kind, s.spell)
	if n > 0:
		w.hurt(a, n * (WEAK if weak else 1), weak)


static func root(w: World, a: Actor, rounds: int) -> void:
	a.rooted = maxi(a.rooted, rounds)
	w.emit({t = &"root", id = a.id, rounds = rounds})


static func stun(w: World, a: Actor, rounds: int) -> void:
	a.stunned = maxi(a.stunned, rounds)
	a.intent.clear()
	w.emit({t = &"stun", id = a.id, rounds = rounds})


## An orb that blasts (Spell.blasts) ends at `at`: each creature in the eight
## tiles round it but `center` that does not eat it is hurt for Spell.blast
## (twice over when weak). A fire orb also sets those tiles alight, burns the
## wooden creatures there and puts out each wisp.
static func splash(w: World, s: Shot, at: Vector2i, center: Actor) -> void:
	var spell := s.spell
	var fire := spell.has(Cards.FIRE)
	var n := spell.blast(spell.damage(Grid.cheb(s.origin, at)))
	w.emit(
		{
			t = &"splash",
			at = at,
			faction = s.faction,
			by = s.caster,
			title = s.spell.title(),
			cards = s.spell.cards,
			spell = s.spell.tag()
		}
	)
	for d in Grid.DIRS:
		var p := at + d
		if fire:
			w.ignite(p)
		var b := w.actor_at(p)
		if b != null and b != center:
			if Bestiary.absorbs(b.kind, spell):
				w.emit({t = &"absorb", id = b.id, at = p})
			else:
				var weak := Bestiary.weak(b.kind, spell)
				w.hurt(b, n * (WEAK if weak else 1), weak)
				if fire and Bestiary.burns(b.kind):
					Status.ignite(w, b)
			Mind.struck(w, b, s)
		var o := w.shot_at(p, s)
		if fire and o != null and not o.spell.orb:
			o.gone = true
			w._changed()
			w.emit({t = &"snuff", shot = o.id, at = p})


## A piercing wisp (Spell.pierces) flying at the wall `to` goes through it, once,
## if open air lies behind it. False when it cannot.
static func bore(w: World, s: Shot, to: Vector2i) -> bool:
	if s.pierced or not Terrain.wall(w.tile(to)) or not w.open_air(to + s.dir):
		return false
	s.pierced = true
	s.flown += 1
	return true


## A piercing wisp goes through `a`, hurting it once, and flies on. False when
## `a` ate it.
static func pass_through(w: World, s: Shot, a: Actor) -> bool:
	var title := s.spell.title()
	w.emit(
		{
			t = &"hit",
			shot = s.id,
			id = a.id,
			at = a.pos,
			by = s.caster,
			title = title,
			cards = s.spell.cards,
			spell = s.spell.tag(),
			through = true
		}
	)
	return strike(w, s, a, s.spell.damage(Grid.cheb(s.origin, a.pos)))


## An orb of 흙 or 쇠 brings the wall it strikes down in one blow.
static func fells(spell: Spell) -> bool:
	return spell.orb and (spell.has(Cards.EARTH) or spell.has(Cards.METAL))


## Tiles a wooden wall grows across: `spell` hurled along `dir` ending at
## `at`, WALL of them and one more for every 나무 past the first, centred on
## `at` and then alternately to either side. Across a diagonal cast it climbs
## like stairs, one row or column at a time, so no step slips between its tiles.
static func wall_tiles(spell: Spell, at: Vector2i, dir: Vector2i) -> Array[Vector2i]:
	return across(at, dir, WALL + spell.extra(Cards.WOOD))


## `n` tiles across the line `dir` at `at`, as `wall_tiles` lays them.
static func across(at: Vector2i, dir: Vector2i, n: int) -> Array[Vector2i]:
	var cross := Vector2i(-dir.y, dir.x)
	var steps := [[cross], [-cross]]
	if cross.x != 0 and cross.y != 0:
		steps = [
			[Vector2i(cross.x, 0), Vector2i(0, cross.y)],
			[Vector2i(0, -cross.y), Vector2i(-cross.x, 0)],
		]
	var ends: Array[Vector2i] = [at, at]
	var out: Array[Vector2i] = [at]
	for k in range(1, n):
		var side := (k - 1) % 2
		ends[side] += steps[side][((k - 1) / 2) % steps[side].size()]
		out.append(ends[side])
	return out


## An orb of 나무 ends at `at`: the wooden wall grows.
static func sprout(w: World, s: Shot, at: Vector2i) -> void:
	grow(w, wall_tiles(s.spell, at, s.dir))


## The tiles a wooden wall can grow on: open ground with nothing on it, not
## burning, not a door, the stairs, the elixir or a peach.
static func growable(w: World, tiles: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for p in tiles:
		var sites := w.sites.any(func(site): return site.at == p)
		var special := p == w.stairs or p == w.elixir or w.peaches.has(p) or sites
		if (
			w.open_floor(p)
			and w.tile(p) not in [World.DOOR, World.DOOR_OPEN]
			and not special
			and not w.burning.has(p)
			and w.actor_at(p) == null
			and w.shot_at(p) == null
		):
			out.append(p)
	return out


## A wooden wall grows on each of `tiles` it can.
static func grow(w: World, tiles: Array[Vector2i]) -> void:
	var grown := growable(w, tiles)
	for p in grown:
		w.set_tile(p, World.WOOD_WALL)
	if not grown.is_empty():
		w.emit({t = &"sprout", at = grown[0], tiles = grown})


## A shot that faded where it stopped: a mortar lands and a blast goes off there, as
## loud as one that struck.
static func fade(w: World, s: Shot) -> void:
	if s.spell.mortar() or s.spell.blasts():
		w.noise(s.pos, s.spell.burst_noise(), "쾅", true, s.caster)
	if s.spell.mortar():
		Compounds.land(w, s, s.pos)
	elif s.spell.blasts():
		splash(w, s, s.pos, null)


## A wisp that struck `a` and was not eaten rides it for WISP_LIFE rounds,
## lighting it as it moves (World.move). It stays a shot, so it hovers where
## `a` fell when `a` dies.
static func stick(w: World, s: Shot, a: Actor) -> void:
	s.gone = false
	s.dir = Vector2i.ZERO
	s.host = a.id
	# A swap may have moved `a` off the tile the wisp struck it on.
	s.pos = a.pos
	s.life = Spell.WISP_LIFE
	w._changed()
	w.emit(
		{
			t = &"stick",
			shot = s.id,
			id = a.id,
			at = a.pos,
			faction = s.faction,
			cards = s.spell.cards,
			title = s.spell.title(),
			spell = s.spell.tag()
		}
	)
