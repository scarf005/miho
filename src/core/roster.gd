class_name Roster
extends RefCounted
## Who lives on a storey, read from FloorGen.PLAN: the creatures of its row that come in no band
## stand as listed, and those that band are drawn from the world's rng (`drawn`).


## The creatures of PLAN's row for the storey that come in no band, or every other one of the
## row beside a maze, which leaves half the rooms to live in, its boss kept.
static func fixed(w: World) -> Array:
	var all: Array = FloorGen.PLAN[w.depth]
	var maze := not Labyrinth.site(w).is_empty()
	var out := []
	for i in all.size():
		var kept: bool = not maze or i % 2 == 0 or Bestiary.info(all[i]).get("boss", false)
		if kept and not Bestiary.bands(all[i]):
			out.append(all[i])
	return out


## The creatures that come in bands, drawn from the world's rng. The kinds PLAN holds on a
## storey below or at this one and on one above or at it may come, each weighed by how many
## times PLAN holds it (`_lean` by the storey's `element`). Two or three of their groups are
## drawn by their weight, then kinds of those groups one by one until their health reaches
## that of the banding kinds in PLAN's row, half of it beside a maze.
static func drawn(w: World, element: StringName) -> Array:
	var r := Bestiary.rank(w.depth)
	var weights := {}
	var first := {}
	var last := {}
	for d: int in FloorGen.PLAN:
		for kind: StringName in FloorGen.PLAN[d].filter(Bestiary.bands):
			weights[kind] = weights.get(kind, 0) + 1
			first[kind] = mini(first.get(kind, d), d)
			last[kind] = d
	var groups := {}
	for kind: StringName in weights.keys():
		if first[kind] > w.depth or last[kind] < w.depth:
			weights.erase(kind)
		else:
			weights[kind] *= _lean(kind, element)
			var group: StringName = Bestiary.info(kind).group
			groups[group] = groups.get(group, 0) + weights[kind]
	var chosen := {}
	for n in mini(w.rng.randi_range(2, 3), groups.size()):
		var group: StringName = _pick(w.rng, groups)
		groups.erase(group)
		chosen[group] = true
	for kind: StringName in weights.keys():
		if not chosen.has(Bestiary.info(kind).group):
			weights.erase(kind)
	var budget := 0
	for kind: StringName in FloorGen.PLAN[w.depth].filter(Bestiary.bands):
		budget += Bestiary.hp(kind, r)
	if not Labyrinth.site(w).is_empty():
		budget /= 2
	var out := []
	var total := 0
	while total < budget and not weights.is_empty():
		var kind: StringName = _pick(w.rng, weights)
		out.append(kind)
		total += Bestiary.hp(kind, r)
	return out


## How a kind's weight grows on a storey of `element`, in quarters: twice where one of its
## elements is the storey's or the one the storey's grows into (Cards.GROWS), half where one
## is the one the storey's beats (Cards.BEATS), and as it is otherwise.
static func _lean(kind: StringName, element: StringName) -> int:
	var own := Bestiary.elements(kind)
	if own.has(element) or own.has(Cards.GROWS.get(element, &"")):
		return 4
	if own.has(Cards.BEATS.get(element, &"")):
		return 1
	return 2


## A key of `weights` drawn by its weight.
static func _pick(rng: RandomNumberGenerator, weights: Dictionary) -> Variant:
	var n := rng.randi_range(1, weights.values().reduce(func(a, b): return a + b, 0))
	for key in weights:
		n -= weights[key]
		if n <= 0:
			return key
	return weights.keys().back()
