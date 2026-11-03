class_name Spray
extends RefCounted
## A spell of elements alone sprays: it covers its tiles in the round it is
## cast, with no projectile, and emits a `spray` event with them (낙뢰 one more for each
## arc, `along`). Its first
## slot sets the shape. A lone element has its own gimmick, one level up for
## every copy (Spell.level, up to Spell.MAX_LEVEL), its numbers in LONE:
## 불 a 90° fan over the tiles the caster sees (radius `reach`): levels 1 and 2 set
## what burns alight, level 3 on also the creatures in it (Status), and the
## fire always spreads. Any spray of fire relights the dark lanterns it reaches.
## 물 a jet along the line (`reach` tiles) up to the first creature, which it
## pushes `push` tiles (World.push); level 3 on goes through and pushes every
## creature on it. It douses fire and lanterns, wets drums, washes scent away.
## 쇠 a gun, heard GUN_LOUD tiles, that lights the caster's tile for the round:
## a pistol shot and at two copies a rifle shot, farther and harder, hit the first
## creature on the line; from SHOTGUN_LEVEL copies a shotgun fans out, a tile farther
## and a wider spread for every copy, and hits each creature. The
## piercing rounds are wisps (Spell.pierces), not sprays.
## 흙 a quake in a ring of radius `reach` whatever the direction, thudding
## World.THUD tiles: it stuns for `stun` rounds; level 2 on cracks walls,
## level 3 on also fells cracked ones.
## 나무 roots underground: silent, not stopped by creatures, but by sky, pond,
## walls and bridges. They reach the nearest creatures the caster sees within
## `reach` steps (`count` of them, 0 for all) and root them `rounds`.
## A compound in the first slot has its own shape (Cards.COMPOUND), one tile bigger for
## every copy past the first and every lone element that feeds a 상생 pair
## (Spell.grown), and its own effect (Compounds). Those that act
## round the caster or on all she sees go every way (`radial`).
## Every other compound in the spell adds its effect there, and every lone
## element its plain effect on each tile and creature it covers: 불 sets what
## burns alight, 물 washes and pushes 1, 흙 stuns and cracks walls, 나무 roots,
## 쇠 hurts 1 for each 쇠 (Elements.strike does the creature part).

## A lone element's spray, each column by level: what it is called, its reach
## (tiles, steps for roots), the harm a gun does, the degrees a shotgun spreads
## (0 for the rest), the tiles a jet pushes, the rounds a quake stuns, the creatures roots
## take and the rounds they hold.
const LONE := {
	Cards.FIRE: {name = ["불길", "불길", "불길", "불길", "불길"], reach = [1, 2, 4, 5, 6]},
	Cards.WATER:
	{
		name = ["물줄기", "물줄기", "물줄기", "물줄기", "물줄기"],
		reach = [4, 6, 8, 10, 12],
		push = [1, 2, 3, 4, 5],
	},
	Cards.METAL:
	{
		name = ["권총", "소총", "산탄", "산탄", "산탄"],
		reach = [7, 10, 4, 5, 6],
		harm = [1, 2, 2, 3, 4],
		angle = [0, 0, 30, 45, 90],
	},
	Cards.EARTH:
	{
		name = ["지진", "지진", "지진", "지진", "지진"],
		reach = [1, 2, 3, 4, 5],
		stun = [1, 1, 2, 2, 3],
	},
	Cards.WOOD:
	{
		name = ["덩굴", "덩굴", "덩굴", "덩굴", "덩굴"],
		reach = [4, 6, 8, 10, 12],
		count = [1, 2, 0, 0, 0],
		rounds = [2, 3, 4, 5, 6],
	},
}
const GUN_LOUD := 9
## Degrees a fan covers, across its line.
const FAN_ANGLE := 90
## Tiles a lone 물 pushes on a spray led by a compound, a tile more a copy.
const PLAIN_PUSH := 1
## The copies of a lone element from which its spray changes: a shotgun in place
## of the rifle, a jet that goes through, a quake that cracks walls and one that
## fells cracked ones.
const SHOTGUN_LEVEL := 3
const THROUGH_LEVEL := 3
const CRACK_LEVEL := 2
const FELL_LEVEL := 3
## How far a fan of fire, or 들불, is heard.
const HUSH := 2

const FAN_SHAPE := &"fan"
const LINE := &"line"
const BURST := &"burst"
const CLEAVE := &"cleave"
## A burst that takes in the walls within its radius.
const BREACH := &"breach"
## Tiles across the line, where a wooden wall can grow.
const ACROSS := &"across"
## A band ahead of the caster, each of its lanes up to a wall.
const BAND := &"band"
## Every tile within a radius of the caster, walls and all.
const AROUND := &"around"
## The tiles of the creatures the caster sees, and her own tile if the third
## entry is there.
const SIGHT := &"sight"
## The roots of a lone 나무 at its third level.
const ROOTS := &"roots"

## Tiles roots grow under: ground, not bridges.
static var _roots := Grid.table(func(t): return Tiles.of(t, "walk") and t != World.BRIDGE)
## Tiles a burst spreads over: no walls.
static var _air := Grid.table(func(t): return not Tiles.of(t, "wall"))


## What the spray is called; a compound goes by its own name alone.
static func called(spell: Spell) -> String:
	var level := spell.level()
	return LONE[spell.slots[0]].name[level - 1] if level > 0 else ""


## How far the cast is heard: anything with 물, roots, 균열 and 봉화 (which
## is heard where it lands) are silent, those of `boom` loud, guns, quakes and
## anything else with 쇠 or 흙 loud, fire hushed.
static func noise(spell: Spell) -> int:
	if Cards.marked(spell.slots[0], "boom"):
		return Compounds.BOOM
	if spell.holds(Cards.WATER) or spell.slots[0] in [Cards.WOOD, &"rift"]:
		return 0
	if spell.holds(Cards.METAL) or spell.holds(Cards.EARTH):
		return GUN_LOUD
	return HUSH


static func _word(spell: Spell) -> String:
	match spell.slots[0]:
		Cards.METAL:
			return "쾅" if spell.level() >= SHOTGUN_LEVEL else "탕"
		Cards.EARTH:
			return "쿵"
		Cards.FIRE:
			return "화르륵"
	return "쾅" if noise(spell) > HUSH else "휙"


## `caster` sprays `spell` along `dir`.
static func cast(w: World, caster: Actor, spell: Spell, dir: Vector2i) -> void:
	var s := Shot.of(w, caster, spell)
	var level := spell.level()
	var lead := spell.slots[0]
	# A quake and roots go every way: struck creatures cannot tell a line.
	var every_way := lead in [Cards.EARTH, Cards.WOOD] if level > 0 else radial(lead)
	s.dir = Vector2i.ZERO if every_way else dir
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
	Hearing.noise(w, caster.pos, noise(spell), _word(spell), caster.faction == Actor.FOX, caster.id)
	Terrain.react(w, spell, tiles)
	if Terrain.lights(spell):
		_relight(w, caster, tiles)
	if level == 0:
		_compound(w, s, tiles)
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
				if reaches(w, s, a):
					Elements.root(w, a, LONE[Cards.WOOD].rounds[level - 1])
					Mind.struck(w, a, s)


## A spray of `s` running from `from` to `to`, `to` included, for what goes on from where
## it struck (Compounds.arc).
static func along(w: World, s: Shot, from: Vector2i, to: Vector2i) -> void:
	var n := Grid.cheb(from, to)
	var tiles: Array[Vector2i] = []
	for i in range(1, n + 1):
		tiles.append(Vector2i(Vector2(from).lerp(Vector2(to), float(i) / n).round()))
	w.emit(
		{
			t = &"spray",
			shot = s.id,
			id = s.caster,
			faction = s.faction,
			cards = s.spell.cards,
			at = from,
			tiles = tiles
		}
	)


## Relights the dark lanterns the caster sees on or next to the tiles covered:
## a lantern stops a spray, so it is never among them when a line ends at it.
static func _relight(w: World, caster: Actor, tiles: Array[Vector2i]) -> void:
	var view := w.fov(caster.pos)
	for p in tiles:
		for d: Vector2i in [Vector2i.ZERO] + Grid.DIRS:
			if Grid.inside(p + d) and view[Grid.index(p + d)] == 1:
				Terrain.relight(w, p + d)


## The tiles the spray covers.
static func cover(w: World, caster: Actor, spell: Spell, dir: Vector2i) -> Array[Vector2i]:
	var from := caster.pos
	var level := spell.level()
	match spell.slots[0] if level > 0 else &"":
		Cards.FIRE:
			return fan(w, from, dir, LONE[Cards.FIRE].reach[level - 1])
		Cards.WATER:
			return _jet(w, from, dir, level)
		Cards.METAL:
			var reached: int = LONE[Cards.METAL].reach[level - 1]
			if level >= SHOTGUN_LEVEL:
				return fan(w, from, dir, reached, LONE[Cards.METAL].angle[level - 1])
			return line(w, from, dir, reached, false)
		Cards.EARTH:
			return ring(from, LONE[Cards.EARTH].reach[level - 1])
		Cards.WOOD:
			return _paths(w, caster, rooted(w, caster, level), LONE[Cards.WOOD].reach[level - 1])
	var lead := spell.slots[0]
	var shape: Array = Cards.COMPOUND[lead].shape
	var grown := spell.grown(lead)
	var n: int = shape[1] + grown
	match shape[0]:
		FAN_SHAPE:
			return fan(w, from, dir, n)
		LINE:
			return line(w, from, dir, n, false)
		BURST:
			return square(w, landing(w, from, dir, shape[1]), shape[2] + grown)
		BREACH:
			return square(w, landing(w, from, dir, shape[1]), shape[2] + grown, true)
		AROUND:
			return square(w, from, n, true)
		BAND:
			return band(w, from, dir, n, shape[2])
		SIGHT:
			return sighted(w, caster, shape.size() > 2)
		ACROSS:
			var mid := landing(w, from, dir, shape[1])
			return Elements.growable(w, Elements.across(mid, dir, shape[2] + grown))
	return cleave(w, from, dir, n)


## The tiles compound `c` reaches carried to `at` along `dir`, `r` round it.
static func carried(
	w: World, c: StringName, at: Vector2i, dir: Vector2i, r: int
) -> Array[Vector2i]:
	match Cards.COMPOUND[c].shape[0]:
		CLEAVE:
			return cleave(w, at, dir, r)
		BREACH, AROUND:
			return square(w, at, r, true)
		ACROSS:
			return Elements.growable(w, square(w, at, r))
	return square(w, at, r)


## The shape of what `cover` gives `spell`.
static func form(spell: Spell) -> StringName:
	var level := spell.level()
	match spell.slots[0] if level > 0 else &"":
		Cards.FIRE:
			return FAN_SHAPE
		Cards.WATER:
			return LINE
		Cards.METAL:
			return FAN_SHAPE if level >= SHOTGUN_LEVEL else LINE
		Cards.EARTH:
			return AROUND
		Cards.WOOD:
			return ROOTS
	return Cards.COMPOUND[spell.slots[0]].shape[0]


## How far ahead of the caster `cover` reaches for `spell`: tiles, steps for
## roots; 0 for a spray that covers all the caster sees.
static func reach(spell: Spell) -> int:
	var level := spell.level()
	if level > 0:
		return LONE[spell.slots[0]].reach[level - 1]
	var shape: Array = Cards.COMPOUND[spell.slots[0]].shape
	match shape[0]:
		SIGHT:
			return 0
		BURST, BREACH, ACROSS:
			return shape[1]
	return shape[1] + spell.grown(spell.slots[0])


## Whether `cover` can hold a tile of kind `t` for `spell`.
static func holds(spell: Spell, t: int) -> bool:
	var walk: bool = Tiles.walk[t] == 1
	var open := walk or t == World.POND
	if (
		spell.level() == 0
		and Cards.COMPOUND[spell.slots[0]].shape[1] + spell.grown(spell.slots[0]) == 0
	):
		return walk
	match form(spell):
		AROUND, BREACH, CLEAVE, BAND:
			return true
		FAN_SHAPE, BURST:
			return not Terrain.wall(t)
		LINE:
			return open
	return walk


## Tiles within `r` (Chebyshev) of `from` and within half of `angle` degrees to each side
## of `dir`, that `from` sees, walls left out.
static func fan(
	w: World, from: Vector2i, dir: Vector2i, r: int, angle := FAN_ANGLE
) -> Array[Vector2i]:
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
				and Vector2(v).normalized().dot(d) >= cos(deg_to_rad(angle / 2.0)) - 0.001
			):
				out.append(p)
	return out


## Up to n tiles along `dir` from `from`, stopping before anything a projectile
## cannot fly into (a veil of fire is the last tile it reaches) and, unless
## `through`, at the first creature.
static func line(w: World, from: Vector2i, dir: Vector2i, n: int, through: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var p := from
	while out.size() < n:
		p += dir
		if not Grid.inside(p):
			break
		if not _open(w, p):
			if w.tile(p) == World.VEIL:
				out.append(p)
			break
		out.append(p)
		if not through and w.actor_at(p) != null:
			break
	return out


## A water jet's line, and the lantern it runs into, which it douses.
static func _jet(w: World, from: Vector2i, dir: Vector2i, level: int) -> Array[Vector2i]:
	var reached: int = LONE[Cards.WATER].reach[level - 1]
	var out := line(w, from, dir, reached, level >= THROUGH_LEVEL)
	var last: Vector2i = from if out.is_empty() else out.back()
	var stopped: bool = (
		out.size() < reached and (level >= THROUGH_LEVEL or w.actor_at(last) == null)
	)
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


## The tiles within `r` (Chebyshev) of `at`, 3x3 for 1, that the air reaches
## from `at`: walls and what lies behind them left out, unless `walls`.
static func square(w: World, at: Vector2i, r := 1, walls := false) -> Array[Vector2i]:
	var dist: PackedInt32Array = Grid.search(at, Grid.mask(w.tiles, _air), r).dist
	var out: Array[Vector2i] = []
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var p := at + Vector2i(x, y)
			if Grid.inside(p) and (walls or dist[Grid.index(p)] >= 0):
				out.append(p)
	return out


## The `wide` tiles across the line at each of the `n` tiles along `dir` from `from`; a lane
## ends at its first wall.
static func band(w: World, from: Vector2i, dir: Vector2i, n: int, wide: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var shut := {}
	for k in range(1, n + 1):
		var row := Elements.across(from + dir * k, dir, wide)
		for lane in row.size():
			if not Grid.inside(row[lane]) or Terrain.wall(w.tile(row[lane])):
				shut[lane] = true
			if not shut.has(lane):
				out.append(row[lane])
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


## The foes `caster` sees.
static func seen_foes(w: World, caster: Actor) -> Array[Actor]:
	var out: Array[Actor] = []
	for a in w.actors:
		if a.alive() and a.faction != caster.faction and Hat.sees(w, caster, a):
			out.append(a)
	return out


## The tiles the foes `caster` sees stand on, and its own first if `own`.
static func sighted(w: World, caster: Actor, own: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if own:
		out.append(caster.pos)
	for a in seen_foes(w, caster):
		out.append(a.pos)
	return out


## The creatures roots of `level` reach from `caster`: its foes it sees within
## reach underground, nearest first by (steps, id).
static func rooted(w: World, caster: Actor, level: int) -> Array[Actor]:
	var dist: PackedInt32Array = _search(w, caster, LONE[Cards.WOOD].reach[level - 1]).dist
	var foes: Array[Actor] = []
	for a in seen_foes(w, caster):
		if dist[Grid.index(a.pos)] > 0:
			foes.append(a)
	var steps := func(a: Actor) -> Array: return [dist[Grid.index(a.pos)], a.id]
	foes.sort_custom(func(a, b): return steps.call(a) < steps.call(b))
	var n: int = LONE[Cards.WOOD].count[level - 1]
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
static func on(w: World, s: Shot, tiles: Array[Vector2i]) -> Array[Actor]:
	var out: Array[Actor] = []
	for p in tiles:
		var a := w.actor_at(p)
		if a != null and a.id != s.caster:
			out.append(a)
	return out


## The creatures, the farthest along `dir` first, so those behind have room;
## with no line, the farthest from `from`.
static func farthest_first(foes: Array[Actor], dir: Vector2i, from: Vector2i) -> Array[Actor]:
	var along := func(a: Actor) -> int:
		return a.pos.x * dir.x + a.pos.y * dir.y if dir != Vector2i.ZERO else Grid.cheb(from, a.pos)
	foes.sort_custom(func(a, b): return [-along.call(a), a.id] < [-along.call(b), b.id])
	return foes


## The spray reaches `a`: false when `a` takes nothing from it.
static func reaches(w: World, s: Shot, a: Actor) -> bool:
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
			spell = s.spell.tag(),
			spray = true
		}
	)


static func _fire(w: World, s: Shot, tiles: Array[Vector2i], level: int) -> void:
	for p in tiles:
		Terrain.ignite(w, p, false, level >= 3)
	if level < 3:
		return
	for a in on(w, s, tiles):
		if reaches(w, s, a):
			if not Guise.through(w, s, a):
				Status.ignite(w, a, true)
			Mind.struck(w, a, s)


## The farthest creature is pushed first, so the ones behind it have room.
static func _water(w: World, s: Shot, tiles: Array[Vector2i], level: int) -> void:
	for p in tiles:
		Terrain.wash(w, p)
	var foes := on(w, s, tiles)
	foes.reverse()
	for a in foes:
		if reaches(w, s, a):
			w.push(a, s.dir, LONE[Cards.WATER].push[level - 1])
			if a.alive():
				Mind.struck(w, a, s)


static func _gun(w: World, s: Shot, tiles: Array[Vector2i], level: int) -> void:
	w.flares.append(s.origin)
	w._changed()
	for a in on(w, s, tiles):
		if reaches(w, s, a):
			Elements.harm(w, s, a, LONE[Cards.METAL].harm[level - 1])
			if a.alive():
				Mind.struck(w, a, s)


static func _quake(w: World, s: Shot, tiles: Array[Vector2i], level: int) -> void:
	for a in on(w, s, tiles):
		if reaches(w, s, a):
			Elements.stun(w, a, LONE[Cards.EARTH].stun[level - 1])
			Mind.struck(w, a, s)
	for p in tiles:
		var t := w.tile(p)
		var falls := t == World.WALL_CRACKED and level >= FELL_LEVEL
		if level >= CRACK_LEVEL and Terrain.breakable(w, p) and (t == World.WALL or falls):
			Terrain.hit(w, p)


## Whether compound `c` goes every way, with no line to tell a creature by.
static func radial(c: StringName) -> bool:
	return Cards.COMPOUND[c].shape[0] in [AROUND, SIGHT]


## Where a compound spray is centred: where a burst lands, the caster for one
## round her or over all she sees, else where its line ends.
static func centre(w: World, s: Shot, tiles: Array[Vector2i]) -> Vector2i:
	var shape: Array = Cards.COMPOUND[s.spell.slots[0]].shape
	match shape[0]:
		BURST, BREACH:
			return landing(w, s.origin, s.dir, shape[1])
		AROUND, SIGHT:
			return s.origin
	return tiles.back()


## A compound's spray: each compound's effect (Compounds), then each lone
## element's plain effect, on every tile and creature.
static func _compound(w: World, s: Shot, tiles: Array[Vector2i]) -> void:
	if tiles.is_empty():
		return
	var spell := s.spell
	var at := centre(w, s, tiles)
	if spell.gun():
		w.flares.append(s.origin)
		w._changed()
	for c in spell.compounds():
		Compounds.ground(w, s, c, tiles)
		Compounds.tip(w, s, c, at)
	for p in tiles:
		if spell.has(Cards.FIRE):
			Terrain.ignite(w, p)
		if spell.has(Cards.WATER):
			Terrain.wash(w, p)
		if spell.has(Cards.EARTH) and Terrain.wall(w.tile(p)) and Terrain.breakable(w, p):
			Terrain.hit(w, p)
	for a in farthest_first(on(w, s, tiles), s.dir, at):
		if not a.alive() or not reaches(w, s, a):
			continue
		for c in spell.compounds():
			Compounds.strike(w, s, c, a, at)
		if Compounds.calm(spell):
			continue
		if a.alive() and Elements.strike(w, s, a, spell.count(Cards.METAL)):
			if spell.has(Cards.WATER) and a.alive():
				w.push(a, s.dir, PLAIN_PUSH + spell.extra(Cards.WATER))
