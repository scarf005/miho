class_name Compounds
extends RefCounted
## What each compound (Cards.COMPOUND) does where it reaches. A spray
## of it covers its own shape; carried on a wisp or an orb it acts
## on the 3x3 round where the projectile ends (Spray.carried; 균열 on the
## first wall ahead of it and that wall's neighbours across its line), the
## creature it struck there among them. Each copy past the first, and each lone
## element that feeds a 상생 pair (Spell.grown), reaches one tile farther: a
## spray's fan, line, square or cleave (Spray.cover), the square round where a
## projectile ends. Other slots in a spray add their own plain
## effect where it reaches (Spray). To add a compound: its row in Cards.COMPOUND, its
## name in Cards.NAME, its cases in `ground`, `tip` and `strike` here (`at` is its
## centre: where a burst lands, the caster for one round her), its test in
## tests/test_compound_chains.gd. One that only touches the creatures it reaches
## is `calm`.
##
## 상생, one grows the other:
## 들불 sets what burns alight, and the creatures it reaches (Status), and
## that fire always spreads (World.wild).
## 용암 leaves hot ground (HOT) for HOT_ROUNDS on walkable ground that is not
## water: whoever stands on it as a round ends takes its harm, unless it flies or is
## fireproof (`spared`), which also cross it. The rest of heaven walks round it, so a fused orb
## (Shot.fused) sears those it reaches as it bursts (`_flare`): one beside the burst would
## step off. A burst spares its caster, so it lays none under it.
## 유탄 hurts every creature it reaches for SHRAPNEL. On an orb (비격진) it
## bursts: MORTAR harm and a harm more for every lone 쇠, the creature the orb
## struck among them once, and every breakable wall in reach takes a hit.
## 서리 freezes each creature it reaches for FROST rounds (Status: it cannot
## move and takes double the next harm), and freezes ponds, and the veil of
## dokkaebi fire (Veil), to ice (World.ICE) that can be walked.
## 단비 roots each creature it reaches RAIN rounds, and douses fire and
## lanterns and wets drums (Terrain.wash), then lays RAIN_FOG of fog (Gas.FOG).
## 상극, the two react:
## 증기 lays STEAM of steam (Gas.STEAM): it blocks sight, scalds whoever stands
## in it each round and wets drums.
## 가시 grows thorns (World.THORNS) on open ground and pricks each creature it
## reaches for THORN. Whoever steps onto thorns takes THORN; they let sight
## through and burn.
## 균열 brings every breakable wall it reaches down to rubble, silently.
## 진흙 douses, then turns open ground to mud (World.MUD): a step onto it takes
## MUD rounds (the creature is rooted till then) and makes no sound.
## 3단, of three elements:
## 용광로 leaves hot iron, which harms more than 용암's hot ground, and fells the wall
## at the end of its line.
## 늪 fells every breakable wall it reaches, turns the ground to mud and roots
## each creature SWAMP rounds.
## 최면 puts the first creature it reaches to sleep (Mind.sleep), hurting none.
## 쇠발톱 is cast on Miho, not sprayed: her claws harm more (Guise).
## 목책 grows a wooden wall (Elements.grow).
## 4단, of four elements:
## 봉화 sets what burns alight like 들불, and is heard BOOM tiles at its centre,
## where it relights every dark lantern the caster sees.
## 오작교 makes the sky and the ponds it reaches a skybridge.
## 안개비 lays fog and washes the scent away.
## 땅꺼짐 turns open ground to sky, but not what would cut Miho from the stairs
## (or the elixir) nor her own tile, and what stands on it falls (Fall).
## 그믐 puts out the fires and lanterns it reaches.
## 이간질 sets the creatures it reaches against each other in pairs, the
## nearest first (Mind.feud), when Miho casts it.
## 낙뢰 is 전기: it hurts a creature THUNDER and stuns it THUNDER_STUN as Elements.charge
## says, and flashes. It arcs on (`arc`), as DCSS `_chain_lightning_to` does.
## 고요 sends the creatures hunting within its reach to search where they stand
## (Mind.lose) and washes the scent away.
## 5단, of all five, heard BOOM tiles but 윤회:
## 윤회 heals the caster 1 and stuns each creature SAMSARA_STUN.
## 상극 hurts each creature CONQUEST_HARM: of all five elements, what a creature is weak
## to and what it is immune to cancel out (Elements.dealt).
## 황룡 fells every breakable wall it reaches, pushes each creature DRAGON_PUSH
## tiles away from its centre and stuns it DRAGON_STUN.
## Open ground is walkable, not a door, a skybridge or water, not the stairs,
## the elixir or a peach, and not burning.

## The radius of the square round where a projectile carrying a compound ends,
## before the copies and feeders that grow it (`reach`).
const REACH := Grid.NEAR
const LAVA := 0
const MOLTEN := 1
## Hot ground by kind: what it is called and its harm each round.
const HOT := [{name = "뜨거운 땅", harm = 1}, {name = "뜨거운 쇠", harm = 2}]
const HOT_ROUNDS := 3
const SHRAPNEL := 1
const MORTAR := 2
## How far round where it ends a 비격진 bursts, wider than a plain orb's blast (Spell.blast).
const MORTAR_REACH := 2
const FROST := 2
const RAIN := 3
## The fog 단비 lays (Gas.FOG) on each tile it reaches.
const RAIN_FOG := 4
const STEAM := Gas.MAX
const THORN := 1
const MUD := 2
const SWAMP := 3
const BOOM := 12
const THUNDER := 3
const THUNDER_STUN := 2
## How far 낙뢰 arcs from the creature it struck, and how many arcs one cast makes.
const ARC_REACH := 3
const ARCS := 10
const SAMSARA_STUN := 2
const CONQUEST_HARM := 3
const DRAGON_PUSH := 3
const DRAGON_STUN := 2


## The radius compound `c` of `spell` reaches round where a projectile ends.
static func reach(spell: Spell, c: StringName) -> int:
	var base := MORTAR_REACH if spell.mortar() and c == &"shrapnel" else REACH
	return base + spell.grown(c)


## `s` carries its compounds to `at`, where it ends.
static func land(w: World, s: Shot, at: Vector2i) -> void:
	var struck := w.actor_at(at)
	for c in s.spell.compounds():
		var tiles := Spray.carried(w, c, at, s.dir, reach(s.spell, c))
		ground(w, s, c, tiles)
		tip(w, s, c, at)
		var line := Vector2i.ZERO if Spray.radial(c) else s.dir
		for a in Spray.farthest_first(Spray.on(w, s, tiles), line, at):
			if a.alive() and (a == struck or Spray.reaches(w, s, a)):
				strike(w, s, c, a, at)
				if a != struck and a.alive() and not Cards.marked(c, "calm"):
					Mind.struck(w, a, s)


## Whether `spell` has only compounds that are `calm` (Cards.COMPOUND).
static func calm(spell: Spell) -> bool:
	return spell.slots.all(func(c): return Cards.marked(c, "calm"))


## What compound `c` of `s` does to the ground on `tiles`.
static func ground(w: World, s: Shot, c: StringName, tiles: Array[Vector2i]) -> void:
	match c:
		&"wildfire":
			for p in tiles:
				Terrain.ignite(w, p, false, true)
		&"lava":
			if s.fused:
				_flare(w, s, tiles)
			var caster := w.actor(s.caster)
			heat(w, tiles.filter(func(p): return caster == null or p != caster.pos), MOLTEN)
		&"frost":
			_become(
				w, tiles.filter(func(p): return w.tile(p) in [World.POND, World.VEIL]), World.ICE
			)
		&"rain":
			for p in tiles:
				Terrain.wash(w, p)
				Gas.add(w, p, Gas.FOG, RAIN_FOG)
		&"steam":
			for p in tiles:
				Gas.add(w, p, Gas.STEAM, STEAM)
		&"thorn":
			_become(w, tiles.filter(func(p): return open(w, p)), World.THORNS)
		&"rift":
			_split(w, tiles)
		&"mud":
			for p in tiles:
				Terrain.wash(w, p)
			_become(w, tiles.filter(func(p): return open(w, p)), World.MUD)
		&"swamp":
			_split(w, tiles)
			ground(w, s, &"mud", tiles)
		&"palisade":
			Elements.grow(w, tiles)
		&"magpie":
			_become(w, tiles.filter(func(p): return w.tile(p) == World.SKY), World.BRIDGE)
		&"mist":
			for p in tiles:
				Gas.add(w, p, Gas.FOG, Gas.MAX)
			_forget(w, tiles)
		&"sinkhole":
			_sink(w, tiles)
		&"newmoon":
			for p in tiles:
				Terrain.douse(w, p)
		&"discord":
			_feud(w, s, tiles)
		&"stillness":
			_forget(w, tiles)
		Cards.DRAGON:
			_split(w, tiles)


## What compound `c` of `s` does at `at`, the centre of its spray: the last
## tile of a line, where a burst or the projectile carrying it lands, else the
## caster.
static func tip(w: World, s: Shot, c: StringName, at: Vector2i) -> void:
	match c:
		&"shrapnel":
			if s.spell.mortar():
				_explode(w, s, at, reach(s.spell, c))
		Cards.SAMSARA:
			_renew(w, s)


## What compound `c` of `s` does to creature `a` it reaches, round `at`.
static func strike(w: World, s: Shot, c: StringName, a: Actor, at: Vector2i) -> void:
	if not a.alive():
		return
	match c:
		&"wildfire":
			Status.ignite(w, a, true)
		&"shrapnel":
			Elements.harm(
				w, s, a, MORTAR + s.spell.count(Cards.METAL) if s.spell.mortar() else SHRAPNEL
			)
		&"frost":
			Status.freeze(w, a, FROST)
		&"rain":
			Elements.root(w, a, RAIN)
		&"thorn":
			Elements.harm(w, s, a, THORN)
		&"swamp":
			Elements.root(w, a, SWAMP)
		&"hypnosis":
			Mind.sleep(w, a)
		&"sinkhole":
			if w.tile(a.pos) == World.SKY:
				Fall.drop(w, a, a.pos)
		&"stillness":
			if a.faction == Actor.HEAVEN and a.brain.alert == Actor.HUNT:
				Mind.lose(a)
		&"thunder":
			if a.alive():
				Elements.shock(w, a, THUNDER, THUNDER_STUN)
				arc(w, s, a)
		Cards.SAMSARA:
			Elements.stun(w, a, SAMSARA_STUN)
		Cards.CONQUEST:
			Elements.harm(w, s, a, CONQUEST_HARM)
		Cards.DRAGON:
			w.push(a, Grid.nearest_dir(a.pos - at), DRAGON_PUSH)
			if a.alive():
				Elements.stun(w, a, DRAGON_STUN)


## `a` has stepped onto `to`: thorns prick it, mud holds it.
static func step(w: World, a: Actor, to: Vector2i) -> void:
	match w.tile(to):
		World.THORNS:
			w.emit({t = &"prick", id = a.id, at = to})
			Harm.hurt(w, a, THORN)
		World.MUD:
			Elements.root(w, a, MUD)


## A round of hot ground: it sears whoever stands on it and cools by a round.
static func tick(w: World) -> void:
	if w.outcome != &"" or w.hot.is_empty():
		return
	var cooled := {}
	for p: Vector2i in w.hot.keys():
		var h: Vector2i = w.hot[p]
		var a := w.actor_at(p)
		if a != null and not spared(a):
			_sear(w, a, h.x)
		if h.y <= 1:
			w.hot.erase(p)
			cooled.get_or_add(h.x, []).append(p)
		else:
			w.hot[p] = Vector2i(h.x, h.y - 1)
	for kind: int in cooled:
		w.emit({t = &"cool", at = cooled[kind][0], tiles = cooled[kind], kind = kind})


## Whether hot ground does nothing to `a`: it flies, or is fireproof.
static func spared(a: Actor) -> bool:
	return Bestiary.flies(a.kind) or Bestiary.fireproof(a.nature_kind())


## Hot ground of `kind` sears `a` on it.
static func _sear(w: World, a: Actor, kind: int) -> void:
	w.emit({t = &"sear", id = a.id, at = a.pos, kind = kind})
	Harm.fire(w, a, HOT[kind].harm, a.pos)


## A fused orb of lava bursts: it sears those on `tiles`, but one that hot ground spares or
## seared this round already, so that the orbs of one volley sear a creature once.
static func _flare(w: World, s: Shot, tiles: Array[Vector2i]) -> void:
	for a in Spray.on(w, s, tiles):
		if not spared(a) and not w.events.any(func(e): return e.t == &"sear" and e.id == a.id):
			_sear(w, a, MOLTEN)


## Open ground a compound may turn into another kind.
static func open(w: World, p: Vector2i) -> bool:
	var t := w.tile(p)
	return (
		w.open_floor(p)
		and t not in [World.DOOR, World.DOOR_OPEN, World.BRIDGE]
		and not Tiles.of(t, "douses")
		and not (p == w.stairs or p == w.elixir or w.peaches.has(p))
		and not w.burning.has(p)
	)


## Lays hot ground of `kind` on the walkable dry tiles; the harsher kind and the
## longer time stay where it lies already.
static func heat(w: World, tiles: Array[Vector2i], kind: int) -> void:
	var laid: Array[Vector2i] = []
	for p in tiles:
		if w.open_floor(p) and not Tiles.of(w.tile(p), "douses"):
			var was: Vector2i = w.hot.get(p, Vector2i(kind, 0))
			w.hot[p] = Vector2i(maxi(was.x, kind), maxi(was.y, HOT_ROUNDS))
			laid.append(p)
	if not laid.is_empty():
		w.emit({t = &"heat", at = laid[0], tiles = laid, kind = kind})


static func _become(w: World, tiles: Array, to: int) -> void:
	var changed: Array[Vector2i] = []
	for p: Vector2i in tiles:
		if w.tile(p) != to:
			w.set_tile(p, to)
			changed.append(p)
	if not changed.is_empty():
		w.emit({t = &"become", at = changed[0], tiles = changed, tile = to})


## Each breakable wall on `tiles` takes one hit, then those still standing
## another, till all are rubble.
static func _split(w: World, tiles: Array[Vector2i]) -> void:
	var walls := tiles.filter(func(p): return Terrain.wall(w.tile(p)))
	while not walls.is_empty():
		walls = walls.filter(func(p): return Terrain.breakable(w, p))
		for p: Vector2i in walls:
			Terrain.hit(w, p)
		walls = walls.filter(func(p): return Terrain.wall(w.tile(p)))


## The scent on `tiles` is washed away.
static func _forget(w: World, tiles: Array[Vector2i]) -> void:
	for p in tiles:
		Scent.clear(w, p)


## A 비격진 bursts at `at`: every breakable wall within `r` takes a hit, as a
## cannonball hits one. Its creatures are hurt by 유탄 (`strike`).
static func _explode(w: World, s: Shot, at: Vector2i, r: int) -> void:
	w.emit(
		{
			t = &"splash",
			at = at,
			faction = s.faction,
			by = s.caster,
			title = s.spell.title(),
			cards = s.spell.cards,
			spell = s.spell.tag(),
			r = r
		}
	)
	for p in Spray.square(w, at, r, true):
		if Terrain.wall(w.tile(p)) and Terrain.breakable(w, p):
			Terrain.hit(w, p)


## 윤회 heals the caster, up to its health. Only Miho's is told (`heal`).
static func _renew(w: World, s: Shot) -> void:
	var me := w.actor(s.caster)
	if me == null or not me.alive() or me.hp >= me.max_hp:
		return
	me.hp += World.HEAL
	if me.is_miho():
		w.emit({t = &"heal", id = me.id, hp = me.hp, spell = true})


## The open ground on `tiles` becomes sky, but Miho's tile and any tile that
## would cut her from the stairs (or the elixir), taken in the order of `tiles`.
static func _sink(w: World, tiles: Array[Vector2i]) -> void:
	var me := w.player().pos
	var guard := linked(w, [])
	var gone: Array[Vector2i] = []
	for p in tiles:
		if p != me and open(w, p) and (not guard or linked(w, gone + [p])):
			gone.append(p)
	for p in gone:
		w.hot.erase(p)
		w.traps.erase(p)
	_become(w, gone, World.SKY)
	Scrolls.displace(w, gone)


## Whether Miho can walk to the stairs (the elixir where there are none) with
## the tiles in `blocked` gone; false when there is no goal.
static func linked(w: World, blocked: Array) -> bool:
	var goal := w.stairs if Grid.inside(w.stairs) else w.elixir
	if not Grid.inside(goal):
		return false
	var dist: PackedInt32Array = Grid.search(goal, Masks.opened(w, blocked)).dist
	return dist[Grid.index(w.player().pos)] >= 0


## The creatures of heaven on `tiles`, the nearest pairs first, are set on each
## other (Mind.feud) of whatever group, but those that eat the spell. Only
## Miho's spell does.
static func _feud(w: World, s: Shot, tiles: Array[Vector2i]) -> void:
	if s.faction != Actor.FOX:
		return
	var foes := Spray.on(w, s, tiles).filter(
		func(a): return a.faction == Actor.HEAVEN and not Bestiary.absorbs(a.kind, s.spell)
	)
	var pairs := []
	for i in foes.size():
		for j in range(i + 1, foes.size()):
			var far: int = (foes[i].pos - foes[j].pos).length_squared()
			pairs.append([far, foes[i].id, foes[j].id, i, j])
	pairs.sort_custom(func(a, b): return a < b)
	var paired := {}
	for pair: Array in pairs:
		if not (paired.has(pair[3]) or paired.has(pair[4])):
			paired[pair[3]] = true
			paired[pair[4]] = true
			Mind.feud(w, foes[pair[3]], foes[pair[4]])
			Mind.feud(w, foes[pair[4]], foes[pair[3]])


## 낙뢰 goes on from `from`, which it just struck, to a foe of the caster that the tile sees
## within ARC_REACH, until one cast has made ARCS arcs or none is left: never the one it
## just struck, else the one struck least, then the nearest. Each arc is a spray of its own
## along its path (Spray.along), so it shows on the aim and on the map.
static func arc(w: World, s: Shot, from: Actor) -> void:
	var struck := {from.id: 1}
	var last := from
	var at := from.pos
	while s.arcs < ARCS:
		var next := _next_arc(w, s, at, last, struck)
		if next == null:
			return
		s.arcs += 1
		struck[next.id] = struck.get(next.id, 0) + 1
		Spray.along(w, s, at, next.pos)
		at = next.pos
		last = next
		if Spray.reaches(w, s, next):
			Elements.shock(w, next, THUNDER, THUNDER_STUN)
			if next.alive():
				Mind.struck(w, next, s)


static func _next_arc(w: World, s: Shot, at: Vector2i, last: Actor, struck: Dictionary) -> Actor:
	var view := w.fov(at)
	var foes := w.actors.filter(
		func(a: Actor) -> bool:
			return (
				a.alive()
				and a != last
				and a.faction != s.faction
				and Grid.cheb(at, a.pos) <= ARC_REACH
				and view[Grid.index(a.pos)] == 1
			)
	)
	var rank := func(a: Actor) -> Array: return [struck.get(a.id, 0), Grid.cheb(at, a.pos), a.id]
	foes.sort_custom(func(a, b): return rank.call(a) < rank.call(b))
	return null if foes.is_empty() else foes[0]
