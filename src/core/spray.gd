class_name Spray
extends RefCounted
## A spell of elements alone sprays: it covers its tiles in the round it is
## cast, with no projectile, and emits one `spray` event with them. Its first
## slot sets the shape. A lone element has its own gimmick, one level up for
## every copy (Spell.level, up to 3):
## 불 a 90° fan over the tiles the caster sees (radius FAN): level 1 sets what
## burns alight, level 2 also the tiles the creatures in it stand on, and at
## level 3 the fire always spreads.
## 물 a jet along the line (JET tiles) up to the first creature, which it
## pushes PUSH tiles (World.push); level 3 goes on through and pushes every
## creature on it. It douses fire and lanterns, wets drums, washes scent away.
## 쇠 a gun, heard GUN_LOUD tiles, that lights the caster's tile for the round:
## a pistol shot along PISTOL tiles hits the first creature for 1; a shotgun
## fan of radius SHOTGUN hits each creature for 1, 2 next to the caster; an
## armour-piercing round along PIERCE tiles goes through every creature (2
## each) and one wall.
## 흙 a quake in a ring of radius QUAKE whatever the direction, thudding
## World.THUD tiles: it stuns for QUAKE_STUN rounds; level 2 cracks walls,
## level 3 also fells cracked ones.
## 나무 roots underground: silent, not stopped by creatures, but by sky, pond,
## walls and bridges. They reach the nearest creatures the caster sees within
## ROOT_REACH steps (ROOT_COUNT of them, 0 for all) and root them ROOT_ROUNDS.
## A compound in the first slot has its own shape (SHAPE) and, until compounds
## get their own effects, every element in the spell does its plain effect on
## each tile and creature it covers: 불 sets what burns alight, 물 washes and
## pushes 1, 흙 stuns and cracks walls, 나무 roots, 쇠 hurts 1 for each 쇠
## (Elements.strike does the creature part).

const FAN := [2, 3, 4]
const JET := [4, 6, 8]
const PUSH := [1, 2, 3]
const GUN_LOUD := 9
const PISTOL := 7
const SHOTGUN := 3
const PIERCE := 8
const PIERCE_HARM := 2
const QUAKE := [1, 2, 3]
const QUAKE_STUN := [1, 1, 2]
const ROOT_REACH := [4, 6, 8]
const ROOT_COUNT := [1, 2, 0]
const ROOT_ROUNDS := [2, 3, 4]
## How far a fan of fire, or a compound spray without water, is heard.
const HUSH := 2

const FAN_SHAPE := &"fan"
const LINE := &"line"
const BURST := &"burst"
const CLEAVE := &"cleave"
## compound -> [shape, size]: a fan's radius, a line's length, how far ahead a
## 3x3 burst lands, or how far ahead a cleave looks for a wall.
const SHAPE := {
	&"wildfire": [FAN_SHAPE, 3],
	&"lava": [LINE, 4],
	&"frost": [LINE, 4],
	&"molten": [LINE, 4],
	&"shrapnel": [BURST, 3],
	&"rain": [BURST, 3],
	&"steam": [BURST, 2],
	&"mud": [BURST, 2],
	&"thorn": [FAN_SHAPE, 2],
	&"split": [CLEAVE, 3],
}
## What a lone element's spray is called, by level.
const NAME := {
	Cards.FIRE: ["불길", "불길", "불길"],
	Cards.WATER: ["물줄기", "물줄기", "물줄기"],
	Cards.METAL: ["권총", "산탄", "철갑탄"],
	Cards.EARTH: ["땅울림", "땅울림", "땅울림"],
	Cards.WOOD: ["뿌리", "뿌리", "뿌리"],
}

## Tiles roots grow under: ground, not bridges.
static var _roots := Grid.table(func(t): return Tiles.walk[t] == 1 and t != World.BRIDGE)


## What the spray is called; a compound goes by its own name alone.
static func called(spell: Spell) -> String:
	var level := spell.level()
	return NAME[spell.slots[0]][level - 1] if level > 0 else ""


## How far the cast is heard: water and roots are silent, guns, quakes and
## anything with 쇠 or 흙 loud, fire hushed.
static func noise(spell: Spell) -> int:
	if spell.has(Cards.WATER) or spell.slots[0] == Cards.WOOD:
		return 0
	if spell.has(Cards.METAL) or spell.has(Cards.EARTH):
		return GUN_LOUD
	return HUSH


static func _word(spell: Spell) -> String:
	match spell.slots[0]:
		Cards.METAL:
			return "쾅" if spell.level() == 2 else "탕"
		Cards.EARTH:
			return "쿵"
		Cards.FIRE:
			return "화르륵"
	return "쾅" if noise(spell) > HUSH else "휙"


## `caster` sprays `spell` along `dir`.
static func cast(w: World, caster: Actor, spell: Spell, dir: Vector2i) -> void:
	var s := Shot.new()
	s.id = w.new_id()
	s.faction = caster.faction
	s.caster = caster.id
	s.spell = spell
	s.pos = caster.pos
	s.origin = caster.pos
	var level := spell.level()
	var lead := spell.slots[0]
	# A quake and roots go every way: struck creatures cannot tell a line.
	s.dir = Vector2i.ZERO if level > 0 and lead in [Cards.EARTH, Cards.WOOD] else dir
	var tiles := cover(w, caster, spell, dir)
	w.emit(
		{
			t = &"spray",
			shot = s.id,
			id = caster.id,
			faction = s.faction,
			cards = spell.cards,
			at = caster.pos,
			tiles = tiles
		}
	)
	w.noise(caster.pos, noise(spell), _word(spell), caster.faction == Actor.FOX, caster.id)
	if level == 0:
		_plain(w, s, tiles)
		return
	match lead:
		Cards.FIRE:
			_fire(w, s, tiles, level)
		Cards.WATER:
			_water(w, s, tiles, level)
		Cards.METAL:
			_gun(w, s, tiles, level)
		Cards.EARTH:
			_quake(w, s, tiles, level)
		Cards.WOOD:
			for a in rooted(w, caster, level):
				if _hit(w, s, a):
					Elements.root(w, a, ROOT_ROUNDS[level - 1])
					Mind.struck(w, a, s)


## The tiles the spray covers.
static func cover(w: World, caster: Actor, spell: Spell, dir: Vector2i) -> Array[Vector2i]:
	var from := caster.pos
	var level := spell.level()
	match spell.slots[0] if level > 0 else &"":
		Cards.FIRE:
			return fan(w, from, dir, FAN[level - 1])
		Cards.WATER:
			return _jet(w, from, dir, level)
		Cards.METAL:
			if level == 2:
				return fan(w, from, dir, SHOTGUN)
			var ap := level >= 3
			return line(w, from, dir, PIERCE if ap else PISTOL, ap, 1 if ap else 0)
		Cards.EARTH:
			return ring(from, QUAKE[level - 1])
		Cards.WOOD:
			return _paths(w, caster, rooted(w, caster, level), ROOT_REACH[level - 1])
	var shape: Array = SHAPE[spell.slots[0]]
	match shape[0]:
		FAN_SHAPE:
			return fan(w, from, dir, shape[1])
		LINE:
			return line(w, from, dir, shape[1], false, 0)
		BURST:
			return square(w, landing(w, from, dir, shape[1]))
	return cleave(w, from, dir, shape[1])


## Tiles within `r` (Chebyshev) of `from` and within 45° of `dir`, that `from`
## sees, walls left out.
static func fan(w: World, from: Vector2i, dir: Vector2i, r: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var view := w.fov(from)
	var d := Vector2(dir).normalized()
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var v := Vector2i(x, y)
			var p := from + v
			if v == Vector2i.ZERO or not Grid.inside(p) or view[Grid.index(p)] == 0:
				continue
			if (
				not Terrain.wall(w.tile(p))
				and Vector2(v).normalized().dot(d) >= cos(PI / 4) - 0.001
			):
				out.append(p)
	return out


## Up to n tiles along `dir` from `from`, stopping before anything a projectile
## cannot fly into and, unless `through`, at the first creature. It passes
## `walls` wall tiles first.
static func line(
	w: World, from: Vector2i, dir: Vector2i, n: int, through: bool, walls: int
) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var p := from
	var left := walls
	while out.size() < n:
		p += dir
		if not Grid.inside(p):
			break
		if Terrain.wall(w.tile(p)) and left > 0:
			left -= 1
		elif not _open(w, p):
			break
		out.append(p)
		if not through and w.actor_at(p) != null:
			break
	return out


## A water jet's line, and the lantern it runs into, which it douses.
static func _jet(w: World, from: Vector2i, dir: Vector2i, level: int) -> Array[Vector2i]:
	var out := line(w, from, dir, JET[level - 1], level >= 3, 0)
	var last: Vector2i = from if out.is_empty() else out.back()
	var stopped: bool = out.size() < JET[level - 1] and (level >= 3 or w.actor_at(last) == null)
	if stopped and Terrain.lantern(w.tile(last + dir)):
		out.append(last + dir)
	return out


static func _open(w: World, p: Vector2i) -> bool:
	return w.open_air(p) and not (w.tile(p) == World.DOOR and w.opaque(p))


## Where something thrown n tiles along `dir` lands: short of what it cannot
## fly into, or on the first creature.
static func landing(w: World, from: Vector2i, dir: Vector2i, n: int) -> Vector2i:
	var p := from
	for i in n:
		if not _open(w, p + dir):
			break
		p += dir
		if w.actor_at(p) != null:
			break
	return p


## The 3x3 tiles round `at`, walls left out.
static func square(w: World, at: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d: Vector2i in [Vector2i.ZERO] + Grid.DIRS:
		if Grid.inside(at + d) and not Terrain.wall(w.tile(at + d)):
			out.append(at + d)
	return out


## Every tile 1 to r tiles from `from`.
static func ring(from: Vector2i, r: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var p := from + Vector2i(x, y)
			if p != from and Grid.inside(p):
				out.append(p)
	return out


## The first wall within n tiles along `dir` and its two neighbours across the
## line; nothing when something else stops the line first.
static func cleave(w: World, from: Vector2i, dir: Vector2i, n: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for k in range(1, n + 1):
		var p := from + dir * k
		if Terrain.wall(w.tile(p)):
			for q: Vector2i in [p, p + Vector2i(-dir.y, dir.x), p + Vector2i(dir.y, -dir.x)]:
				if Grid.inside(q):
					out.append(q)
			return out
		if not _open(w, p):
			return out
	return out


## The creatures roots of `level` reach from `caster`: its foes it sees within
## reach underground, nearest first by (steps, id).
static func rooted(w: World, caster: Actor, level: int) -> Array[Actor]:
	var dist: PackedInt32Array = _search(w, caster, ROOT_REACH[level - 1]).dist
	var foes: Array[Actor] = []
	for a in w.actors:
		if a.alive() and a.faction != caster.faction and w.sees(caster, a.pos):
			if dist[Grid.index(a.pos)] > 0:
				foes.append(a)
	var steps := func(a: Actor) -> Array: return [dist[Grid.index(a.pos)], a.id]
	foes.sort_custom(func(a, b): return steps.call(a) < steps.call(b))
	var n: int = ROOT_COUNT[level - 1]
	return foes if n == 0 else foes.slice(0, n)


static func _search(w: World, caster: Actor, reach: int) -> Dictionary:
	return Grid.search(caster.pos, Grid.mask(w.tiles, _roots), reach)


## The tiles the roots grow along to each creature.
static func _paths(w: World, caster: Actor, foes: Array[Actor], reach: int) -> Array[Vector2i]:
	var parent: PackedInt32Array = _search(w, caster, reach).parent
	var out: Array[Vector2i] = []
	for a in foes:
		var i := Grid.index(a.pos)
		var path: Array[Vector2i] = []
		while i >= 0 and i != Grid.index(caster.pos):
			path.push_front(Grid.at(i))
			i = parent[i]
		for p in path:
			if not out.has(p):
				out.append(p)
	return out


## The creatures on `tiles` but the caster.
static func _on(w: World, s: Shot, tiles: Array[Vector2i]) -> Array[Actor]:
	var out: Array[Actor] = []
	for p in tiles:
		var a := w.actor_at(p)
		if a != null and a.id != s.caster:
			out.append(a)
	return out


## The spray reaches `a`: false when `a` takes nothing from it.
static func _hit(w: World, s: Shot, a: Actor) -> bool:
	_tell(w, s, a)
	return not Elements.absorbed(w, s, a)


## A `hit` event, for the log to tell whose spell it was.
static func _tell(w: World, s: Shot, a: Actor) -> void:
	w.emit(
		{
			t = &"hit",
			shot = s.id,
			id = a.id,
			at = a.pos,
			by = s.caster,
			title = s.spell.title(),
			spray = true
		}
	)


static func _fire(w: World, s: Shot, tiles: Array[Vector2i], level: int) -> void:
	for p in tiles:
		w.ignite(p, false, level >= 3)
	if level < 2:
		return
	for a in _on(w, s, tiles):
		if _hit(w, s, a):
			w.ignite(a.pos, true, level >= 3)
			Mind.struck(w, a, s)


## The farthest creature is pushed first, so the ones behind it have room.
static func _water(w: World, s: Shot, tiles: Array[Vector2i], level: int) -> void:
	for p in tiles:
		Terrain.wash(w, p)
	var foes := _on(w, s, tiles)
	foes.reverse()
	for a in foes:
		if _hit(w, s, a):
			w.push(a, s.dir, PUSH[level - 1])
			if a.alive():
				Mind.struck(w, a, s)


static func _gun(w: World, s: Shot, tiles: Array[Vector2i], level: int) -> void:
	w.flares.append(s.origin)
	w._changed()
	for a in _on(w, s, tiles):
		var n := 1
		if level == 2 and Grid.cheb(s.origin, a.pos) <= 1:
			n = 2
		elif level >= 3:
			n = PIERCE_HARM
		if _hit(w, s, a):
			Elements.harm(w, s, a, n)
			if a.alive():
				Mind.struck(w, a, s)


static func _quake(w: World, s: Shot, tiles: Array[Vector2i], level: int) -> void:
	for a in _on(w, s, tiles):
		if _hit(w, s, a):
			Elements.stun(w, a, QUAKE_STUN[level - 1])
			Mind.struck(w, a, s)
	for p in tiles:
		var t := w.tile(p)
		var falls := t == World.WALL_CRACKED and level >= 3
		if level >= 2 and Terrain.breakable(w, p) and (t == World.WALL or falls):
			Terrain.hit(w, p)


## A compound's spray: each element's plain effect on every tile and creature.
static func _plain(w: World, s: Shot, tiles: Array[Vector2i]) -> void:
	var spell := s.spell
	for p in tiles:
		if spell.has(Cards.FIRE):
			w.ignite(p)
		if spell.has(Cards.WATER):
			Terrain.wash(w, p)
		if spell.has(Cards.EARTH) and Terrain.wall(w.tile(p)) and Terrain.breakable(w, p):
			Terrain.hit(w, p)
	var foes := _on(w, s, tiles)
	foes.reverse()
	for a in foes:
		_tell(w, s, a)
		if Elements.strike(w, s, a, spell.count(Cards.METAL)) and spell.has(Cards.WATER):
			if a.alive():
				w.push(a, s.dir, 1 + spell.extra(Cards.WATER))
