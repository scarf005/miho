class_name Mind
extends RefCounted
## What the creatures of heaven do each round: look, then rest, search the spot
## they heard or saw something at, or hunt Miho. All functions act on a World.


static func heaven_phase(w: World) -> void:
	for a in w.actors.duplicate():
		if w.outcome != &"":
			return
		if not a.alive() or a.faction == Actor.FOX:
			continue
		a.acted += 1
		if a.stunned > 0:
			a.stunned -= 1
			continue
		perceive(w, a)
		if not a.intent.is_empty():
			var spell := Spell.make(a.intent)
			a.intent.clear()
			a.cooldown = a.info().cd
			w.cast(a, spell, a.aim)
			continue
		if a.blind > 0:
			continue
		match a.alert:
			Actor.HUNT:
				hunt(w, a)
			Actor.SEARCH:
				search(w, a)
			_:
				rest(w, a)


## Sight first: seeing Miho starts a hunt; seeing one of her wisps starts a search.
static func perceive(w: World, a: Actor) -> void:
	var me := w.player()
	a.sees_me = w.sees(a, me.pos)
	if a.sees_me or a.info().get("hunts", false):
		w.hunt_from(a, me.pos)
		return
	if a.alert == Actor.HUNT or a.blind > 0:
		return
	for s in w.shots:
		if not s.gone and s.faction != a.faction and w.sees(a, s.pos):
			a.alert = Actor.SEARCH
			a.target = s.pos
			a.lost = 0
			return


static func hunt(w: World, a: Actor) -> void:
	var me := w.player()
	if a.sees_me:
		var club: int = a.info().get("club", 0)
		if club > 0 and Grid.cheb(a.pos, me.pos) == 1:
			_club(w, a, me, club)
			return
		if a.cooldown <= 0 and _charge(w, a, Aim.at_miho(w, a)):
			return
		if a.rooted <= 0:
			_chase(w, a)
		return
	if a.info().get("hunts", false):
		if a.rooted <= 0:
			_step_to(w, a, me.pos, 1)
		return
	if a.pos != a.target and a.lost < World.SEARCH_ROUNDS:
		a.lost += 1
		if a.rooted > 0 or _step_to(w, a, a.target):
			return
	var to := Scent.next(w, a)
	if a.rooted <= 0 and _step_to(w, a, to):
		a.target = to
		return
	a.alert = Actor.SEARCH
	a.lost = 0
	search(w, a)


## Goes to the spot, throwing a wisp at it first when it lies in the dark.
## Next to a lantern that went out, it lights it again first.
static func search(w: World, a: Actor) -> void:
	if Terrain.relight_beside(w, a):
		return
	if a.cooldown <= 0 and _charge(w, a, Aim.searchlight(w, a)):
		return
	if a.rooted > 0:
		return
	if a.pos != a.target and _step_to(w, a, a.target):
		return
	a.lost += 1
	if a.lost > World.SEARCH_ROUNDS:
		a.alert = Actor.REST
		a.lost = 0
		w.emit({t = &"calm", id = a.id})
		return
	_drift(w, a)


static func rest(w: World, a: Actor) -> void:
	if a.rooted > 0:
		return
	if not a.info().get("patrol", false):
		if a.pos != a.home:
			_step_to(w, a, a.home)
		return
	if a.pos == a.post or not _step_to(w, a, a.post):
		a.post = FloorGen.patrol_point(w)


static func _club(w: World, a: Actor, me: Actor, n: int) -> void:
	w.emit({t = &"club", id = a.id, target = me.id, at = me.pos, n = n})
	w.noise(me.pos, 3, "퍽", true, a.id)
	w.hurt(me, n)


static func _charge(w: World, a: Actor, plan: Dictionary) -> bool:
	if plan.is_empty():
		return false
	a.intent.assign(plan.cards)
	a.aim = plan.dir
	w.emit({t = &"charge", id = a.id, cards = a.intent.duplicate(), dir = a.aim})
	return true


static func _chase(w: World, a: Actor) -> void:
	var me := w.player()
	match a.info().get("move", &"static"):
		&"approach":
			_step_to(w, a, me.pos, 1)
		&"slow":
			if a.acted % 2 == 0:
				_step_to(w, a, me.pos, 1)
		&"align":
			_align(w, a)


## Free tiles, never into fire.
static func _walkable(w: World, a: Actor) -> Callable:
	return func(p): return p == a.pos or (w.vacant(p) and not w.burning.has(p))


## One step along a shortest path towards `goal`, stopping `keep` tiles short;
## among equal paths it takes the straightest.
static func _step_to(w: World, a: Actor, goal: Vector2i, keep := 0) -> bool:
	if a.info().get("move", &"static") == &"static":
		return false
	var walk := _walkable(w, a)
	var dist: PackedInt32Array = Grid.search(goal, func(p): return walk.call(p)).dist
	var here := dist[Grid.index(a.pos)]
	if here < 0 or here <= keep:
		return false
	var best := a.pos
	var best_cost := INF
	for d in Grid.DIRS:
		var p := a.pos + d
		if not Grid.inside(p) or dist[Grid.index(p)] < 0 or not walk.call(p):
			continue
		var cost := dist[Grid.index(p)] + Vector2(goal - p).length() * 0.01
		if dist[Grid.index(p)] < here and cost < best_cost:
			best = p
			best_cost = cost
	if best == a.pos:
		return false
	w.move(a, best)
	return true


static func _drift(w: World, a: Actor) -> void:
	if a.info().get("move", &"static") == &"static":
		return
	var walk := _walkable(w, a)
	var free: Array[Vector2i] = []
	for d in Grid.DIRS:
		if walk.call(a.pos + d):
			free.append(a.pos + d)
	if not free.is_empty():
		w.move(a, free[w.rng.randi_range(0, free.size() - 1)])


static func _align(w: World, a: Actor) -> void:
	var to := Aim.lineup(w, a, _walkable(w, a))
	if to == Vector2i(-1, -1):
		_step_to(w, a, w.player().pos, 2)
	elif to != a.pos:
		w.move(a, to)
