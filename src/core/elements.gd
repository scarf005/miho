class_name Elements
extends RefCounted
## What the elements a spell carries do to a creature it strikes and where it
## ends, one step stronger for every copy past the first (Spell.extra): 불
## hurts 1 more, 나무 roots and 쇠 blinds a round longer, 흙 stuns a round longer.

const ROOT := 2
const STUN := 1
const BLIND := 2


## `s` strikes `a` for `n` before weakness: unless `a` eats the spell, it is
## hurt (twice over when weak), a wood creature catches fire, and the elements
## afflict it. False when it ate the spell.
static func strike(w: World, s: Shot, a: Actor, n: int) -> bool:
	var spell := s.spell
	if absorbed(w, s, a):
		return false
	harm(w, s, a, n)
	if spell.has(Cards.FIRE) and Bestiary.burns(a.kind):
		w.ignite(a.pos, true)
	if a.alive():
		if spell.has(Cards.WOOD):
			root(w, a, ROOT + spell.extra(Cards.WOOD))
		if spell.has(Cards.EARTH):
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
static func harm(w: World, s: Shot, a: Actor, n: int) -> void:
	var weak := Bestiary.weak(a.kind, s.spell)
	if n > 0:
		w.hurt(a, n * (2 if weak else 1), weak)


static func root(w: World, a: Actor, rounds: int) -> void:
	a.rooted = maxi(a.rooted, rounds)
	w.emit({t = &"root", id = a.id, rounds = rounds})


static func stun(w: World, a: Actor, rounds: int) -> void:
	a.stunned = maxi(a.stunned, rounds)
	a.intent.clear()
	w.emit({t = &"stun", id = a.id, rounds = rounds})


static func blind(w: World, a: Actor, rounds: int, at: Vector2i) -> void:
	a.blind = maxi(a.blind, rounds)
	a.intent.clear()
	w.emit({t = &"blind", id = a.id, rounds = rounds})
	if a.faction == Actor.HEAVEN:
		a.alert = Actor.SEARCH
		a.target = at
		a.lost = 0


## 쇠 flashes where `s` ends: every foe within FLASH tiles that sees the spot is blinded.
static func flash(w: World, s: Shot, at: Vector2i) -> void:
	w.emit({t = &"flash", at = at, faction = s.faction})
	var view := w.fov(at)
	for a in w.actors:
		if (
			a.alive()
			and a.faction != s.faction
			and Grid.cheb(a.pos, at) <= World.FLASH
			and view[Grid.index(a.pos)] == 1
		):
			blind(w, a, BLIND + s.spell.extra(Cards.METAL), at)
