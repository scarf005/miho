class_name Jars
extends RefCounted
## What a jar (장독) holds. It is decided when the storey is built (`fill`): each
## jar gets one effect of ROWS by its weight, from a generator seeded from the
## world's, and the hover does not tell it. It happens when the jar breaks
## (Structures.broke), whoever broke it. World.jars holds tile -> effect id; a jar
## with none is empty.
##
## 빈 독 does nothing. 물 floods the bare floor round the jar to shallow water, and
## water's own rules (Terrain.wash) put out fire, lanterns and a veil and wash the
## scent away there. 김치 lies on the tile as a site {kind, at} (kept as a scroll
## is): Miho eats it on the tile once she is hurt, whether she came onto it hurt or
## was hurt standing there. It heals HEAL, never above her maximum, and her scent is
## strong for PUNGENT_ROUNDS (Scent). 제웅, a straw
## doll, tears and hurts the nearest creature of heaven Miho sees by EFFIGY_HARM.
## 허수아비, a scarecrow, falls where every creature that sees it goes to search
## (Notice), as it does for a lantern that broke. 소금, salt, clears the scent trail of the
## whole storey (Scent.clear). 팥, red beans, stun every creature of heaven in the eight
## tiles round the jar for BEANS_STUN rounds, Miho not. 숯, charcoal, spills coals the way a
## censer does (Structures.spill).

## The effects with their weights, in the order the dice go over them.
const ROWS := [
	{id = &"empty", name = "빈 독", weight = 30},
	{id = &"water", name = "물", weight = 15},
	{id = &"kimchi", name = "김치", weight = 20},
	{id = &"effigy", name = "제웅", weight = 10},
	{id = &"scarecrow", name = "허수아비", weight = 10},
	{id = &"salt", name = "소금", weight = 5},
	{id = &"beans", name = "팥", weight = 5},
	{id = &"coals", name = "숯", weight = 5},
]
const KIMCHI := &"kimchi"
## Rounds Miho's scent stays strong after she eats kimchi.
const PUNGENT_ROUNDS := 20
const EFFIGY_HARM := 1
## Rounds the creatures round a jar of red beans are stunned: a 흙 wisp's.
const BEANS_STUN := Elements.STUN


## The weight of every effect of `rows` together.
static func total(rows: Array = ROWS) -> int:
	return rows.reduce(func(sum: int, row: Dictionary): return sum + row.weight, 0)


## The chance of each effect of `rows` in percent: whole numbers that add up to 100, the
## rest of the division going to the largest remainders.
static func chances(rows: Array = ROWS) -> Array[int]:
	var sum := total(rows)
	var out: Array[int] = []
	for row: Dictionary in rows:
		out.append(row.weight * 100 / sum)
	var order := range(rows.size())
	order.sort_custom(
		func(a: int, b: int):
			var ra: int = rows[a].weight * 100 % sum
			var rb: int = rows[b].weight * 100 % sum
			return ra > rb or (ra == rb and a < b)
	)
	for k in 100 - out.reduce(func(s: int, n: int): return s + n, 0):
		out[order[k]] += 1
	return out


## Gives every jar of the storey its effect.
static func fill(w: World) -> void:
	w.jars.clear()
	var dice := RandomNumberGenerator.new()
	dice.seed = hash("jars%d" % w.rng.state)
	for i in w.tiles.size():
		if w.tiles[i] == World.JAR:
			w.jars[Grid.at(i)] = _roll(dice.randi_range(1, total()))


static func _roll(n: int) -> StringName:
	for row: Dictionary in ROWS:
		n -= row.weight
		if n <= 0:
			return row.id
	return ROWS.back().id


## The jar at `at` has just broken: its effect happens, once.
static func broke(w: World, at: Vector2i) -> void:
	var what: StringName = w.jars.get(at, &"empty")
	w.jars.erase(at)
	if what == &"empty":
		return
	w.emit({t = &"jar", what = what, at = at})
	match what:
		&"water":
			_flood(w, at)
		KIMCHI:
			w.sites.append({kind = KIMCHI, at = at})
		&"effigy":
			_tear(w)
		&"scarecrow":
			Notice.record(w, &"scarecrow", at)
		&"salt":
			_scatter(w)
		&"beans":
			_pour(w, at)
		&"coals":
			Structures.spill(w, at)


## The name of effect `id`.
static func name_of(id: StringName) -> String:
	return ROWS.filter(func(row: Dictionary): return row.id == id)[0].name


## The tiles where kimchi lies.
static func spots(w: World) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for site: Dictionary in w.sites:
		if site.kind == KIMCHI:
			out.append(site.at)
	return out


## She eats the kimchi on her tile, once, if she is alive and hurt; at full health
## it stays for later.
static func arrive(w: World, me: Actor) -> void:
	for site: Dictionary in w.sites.duplicate():
		if site.kind == KIMCHI and site.at == me.pos and me.alive() and me.hp < me.max_hp:
			w.sites.erase(site)
			var healed := mini(World.HEAL, me.max_hp - me.hp)
			me.hp += healed
			w.pungent = PUNGENT_ROUNDS
			Scent.lay(w, me.pos)
			w.emit({t = &"heal", id = me.id, hp = me.hp, n = healed, kimchi = true})


static func _flood(w: World, at: Vector2i) -> void:
	for d: Vector2i in [Vector2i.ZERO] + Grid.DIRS:
		if w.tile(at + d) == World.FLOOR and not w.traps.has(at + d):
			w.set_tile(at + d, World.SHALLOW)
		Terrain.wash(w, at + d)


static func _tear(w: World) -> void:
	var me := w.player()
	var near: Actor = null
	for a in w.actors:
		if (
			a.faction == Actor.HEAVEN
			and a.alive()
			and w.sees(me, a.pos)
			and not Hat.hidden(w, a, me.pos)
			and (near == null or Grid.cheb(a.pos, me.pos) < Grid.cheb(near.pos, me.pos))
		):
			near = a
	if near != null:
		w.hurt(near, EFFIGY_HARM)


static func _scatter(w: World) -> void:
	for i in w.tiles.size():
		Scent.clear(w, Grid.at(i))


static func _pour(w: World, at: Vector2i) -> void:
	for d in Grid.DIRS:
		var a := w.actor_at(at + d)
		if a != null and a.faction == Actor.HEAVEN and a.alive():
			Elements.stun(w, a, BEANS_STUN)
