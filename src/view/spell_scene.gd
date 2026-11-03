class_name SpellScene
extends RefCounted
## The example of one spell, made from the spell alone as a CodexScene: Miho casts it
## in the hall at a creature that stands where the spell reaches. `plan` casts the
## spell in the empty hall and reads the tiles it would reach as the aim preview does
## (`reach`), stands the creature on the farthest of them along Miho's row, and takes
## the first creature of the Bestiary that the spell does anything to. When it does
## nothing to any, the first is tried behind a wall; then the reached tiles (NEAR in front
## of her when it reaches none) are laid
## with the first ground the hall draws (CodexScene.MARKS) that it does something to. A
## spell that goes on Miho herself (Guise.ANYWHERE) is cast on her, and she walks up to the
## creature. A new spell, or a change to a table, changes the example with no edit. A spell
## whose slot has its own row in CodexScene.TABLE plays that, and so does 용광로 with its 구.

## Rounds the example waits for the shots of a cast to land and an ally it raised to
## fight, at most.
const WAITS := 8
## Rounds an example lasts at the least, so that what a cast did stays in view.
const LINGER := 4
## Tiles east of Miho the creature stands when the spell reaches none on her row.
const NEAR := 3
## Tiles up and down a wall runs when the spell does something only to a creature that
## cannot see Miho (고요), and tiles it stands before the creature.
const BEHIND := 2
## The most 목 behind a 도약 its example shows.
const LEAP_WOODS := 3

static var _plans := {}


## The example of the spell of `cards`: data only, so that a list of entries costs nothing; it
## is planned when it is played (`ready`).
static func of(cards: Array) -> Dictionary:
	return {key = &"", spell = cards.duplicate()}


## The example of a talisman `c` held 1 to Spell.MAX_SLOTS times over, a part for each.
static func counts(c: StringName) -> Dictionary:
	var each := []
	for n in range(1, Spell.MAX_SLOTS + 1):
		var cards := []
		cards.resize(n)
		cards.fill(c)
		if Spell.make(cards) != null:
			each.append(of(cards).merged({label = Lang.t("%d단계") % n}))
	return {key = &"", each = each}


## The example of 도약 alone and with 1 to LEAP_WOODS 목 behind it, a part for each.
static func leaps() -> Dictionary:
	var each := []
	for n in LEAP_WOODS + 1:
		var cards := Cards.recipe(Cards.VAULT).duplicate()
		for i in n:
			cards.append(Cards.WOOD)
		var label := Lang.t("%s %d장") % [Lang.t(Cards.NAME[Cards.WOOD]), n]
		each.append(
			of(cards).merged({label = Lang.t(Cards.NAME[Cards.VAULT]) if n == 0 else label})
		)
	return {key = &"", each = each}


## The scenes one entry can play, of which the player picks one (Codex.part).
static func parts(scene: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not scene.is_empty():
		out.assign(scene.get("each", [scene]))
	return out


## `scene` in CodexScene's own form: one that `of` made is planned (the first time only).
static func ready(scene: Dictionary) -> Dictionary:
	if not scene.has("spell"):
		return scene
	var k := str(scene.spell)
	if not _plans.has(k):
		_plans[k] = _plan(scene.spell)
	return _plans[k]


## Every scene `scene` stands for, each in CodexScene's own form.
static func resolve(scene: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign(parts(scene).map(ready))
	return out


## The tiles the aim preview paints for `action` in `w`, as {tints, marks, lines}: the
## same Forecast and AimView that draw them over the map.
static func reach(w: World, action: Dictionary) -> Dictionary:
	var out := {tints = {}, marks = {}}
	var term := Term.new()
	AimView.paint(Forecast.of(w, action), w, w.known_clone(), term, out.tints, out.marks)
	out.lines = term.lines
	term.free()
	return out


static func _plan(cards: Array) -> Dictionary:
	var slots := Spell.make(cards).slots
	if slots == [Cards.ORB, Forge.FURNACE]:
		return CodexScene.of(Forge.FURNACE, cards)
	if slots.size() == 1 and CodexScene.TABLE.has(slots[0]):
		return CodexScene.of(slots[0], cards)
	var inward := Guise.ANYWHERE.has(Guise.kind(Spell.make(cards)))
	var lay := {
		cards = cards,
		inward = inward,
		hit = [],
		dx = 0,
		kind = &"",
		ground = "",
		twin = false,
		wall = 0
	}
	var bare := _scene(lay)
	var w := CodexScene.build(bare)
	var me := w.player().pos
	lay.dx = NEAR
	if not inward:
		var far := 0
		for p: Vector2i in reach(w, CodexScene.actions(bare)[0]).tints:
			if CodexScene.HALL.has_point(p) and p.x > me.x:
				lay.hit.append(p - me)
				far = maxi(far, p.x - me.x) if p.y == me.y else far
		lay.dx = far if far > 0 else NEAR
		if Spell.make(cards).shape == Spell.LEAP:
			lay.dx = maxi(1, lay.dx / 2)
	var kinds := Codex.foes()
	var tries := kinds.map(func(k): return {kind = k})
	tries.append({kind = kinds[0], twin = true})
	tries.append({kind = kinds[0], wall = BEHIND})
	var patch: Array = lay.hit
	if patch.is_empty():
		patch = range(1, NEAR + 1).map(func(x: int) -> Vector2i: return Vector2i(x, 0))
	tries.append_array(
		CodexScene.MARKS.keys().map(func(g): return {ground = g, dx = 0, hit = patch})
	)
	lay.kind = kinds[0]
	for pick: Dictionary in tries:
		var next := lay.merged(pick, true)
		if alters(_scene(next)):
			lay = next
			break
	return _scene(lay, _waits(_scene(lay)))


## The scene `lay` lays out: Miho, a creature of `kind` `dx` tiles east of her (none for
## 0) and a second beside it if `twin`, `ground` on the tiles she reaches, and what she
## does: cast at once, then, for a spell she casts on herself, walk to the creature, else
## wait `waits` rounds.
static func _scene(lay: Dictionary, waits := WAITS) -> Dictionary:
	var at := {Vector2i.ZERO: "@"}
	if lay.dx > 0:
		at[Vector2i(lay.dx, 0)] = "m"
		if lay.twin:
			at[Vector2i(lay.dx, 1)] = "m"
	if lay.wall > 0:
		for y in range(-lay.wall, lay.wall + 1):
			at[Vector2i(lay.dx - lay.wall, y)] = "#"
	if lay.ground != "":
		for o: Vector2i in lay.hit:
			at[o] = at.get(o, lay.ground)
	var wide: int = at.keys().reduce(func(n: int, o: Vector2i) -> int: return maxi(n, o.x), 0)
	var high: int = at.keys().reduce(func(n: int, o: Vector2i) -> int: return maxi(n, absi(o.y)), 0)
	var rows := []
	for y in range(-high, high + 1):
		var row := ""
		for x in range(-CodexScene.ME, wide + 1):
			row += at.get(Vector2i(x, y), " ")
		rows.append(row)
	return {
		key = lay.kind,
		map = "/".join(rows),
		cards = lay.cards,
		do = ("s" + ">".repeat(lay.dx)) if lay.inward else ("c" + ".".repeat(waits)),
	}


## Whether the cast of `scene` does anything, in some round, that waiting would not: to its
## creature or to the hall.
static func alters(scene: Dictionary) -> bool:
	var cast := CodexScene.build(scene)
	var idle := CodexScene.build(scene)
	for action in CodexScene.actions(scene):
		if action.t == &"wait" and cast.shots.is_empty():
			break
		cast.act(action)
		idle.act({t = &"wait"} if action.t == &"cast" else action)
		if _state(cast) != _state(idle):
			return true
	return false


## What a cast can do, as one value: Miho's health, the creatures, the projectiles, and the
## tiles, fires, hot ground and gas.
static func _state(w: World) -> int:
	var foe := [w.player().hp]
	for a in w.actors.slice(1):
		foe += [
			a.hp,
			a.ailments.rooted,
			a.ailments.stunned,
			a.ailments.blind,
			a.ailments.wet,
			a.ailments.alight,
			a.ailments.frozen,
			a.brain.alert
		]
		foe += [a.brain.marked, a.ties.rival, a.asleep()]
	var shots := w.shots.map(func(s: Shot) -> Array: return [s.pos, s.host])
	return [foe, shots, w.tiles, w.burning.keys(), w.hot.keys(), w.gas.keys()].hash()


## The rounds the shots of `scene`'s cast take to land, at least LINGER so its result stays.
static func _waits(scene: Dictionary) -> int:
	var w := CodexScene.build(scene)
	w.act(CodexScene.actions(scene)[0])
	var n := 1
	while (not w.shots.is_empty() or w.actors.any(func(a): return a.ally())) and n < WAITS:
		w.act({t = &"wait"})
		n += 1
	return maxi(n, LINGER)
