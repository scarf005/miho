class_name Mind
extends RefCounted
## What the creatures of heaven do each round: look, then rest, search the spot
## they heard or saw something at, or hunt Miho. All functions act on a World.
##
## Infighting (DCSS behaviour_event ME_WHACK): a creature struck by a spell or
## blow of a creature of another group (Bestiary.GROUPS) fights it for
## GRUDGE_ROUNDS, renewed by each new blow, in place of whatever else it does:
## it strikes, charges at or walks to its rival while it sees it, and walks to
## where it saw it last when it does not; there, still not seeing it, it stops
## and searches. The fight also ends when the rival falls or Miho harms it.
## One of its own group only hurts it.
##
## Fleeing (DCSS mon-behv): a sharp or cunning creature that is not brave and
## hunts Miho at 1 health runs from her, towards its own group (`flee`).
##
## Bands (DCSS mon-place band): creatures of a group come in bands that follow
## their leader while they rest on patrol (`rest`); when it falls they scatter.

const GRUDGE_ROUNDS := 10


static func heaven_phase(w: World) -> void:
	for a in w.actors.duplicate():
		if w.outcome != &"":
			return
		if not a.alive() or a.faction == Actor.FOX or not w.actors.has(a):
			continue
		a.acted += 1
		if a.stunned > 0:
			a.stunned -= 1
			continue
		perceive(w, a)
		if not a.intent.is_empty():
			var spell := Bestiary.spell(a.kind, a.intent)
			a.intent.clear()
			a.cooldown = a.info().cd
			w.cast(a, spell, a.aim)
			continue
		if a.blind > 0 or _stoke(w, a) or _fight(w, a):
			continue
		match a.alert:
			Actor.HUNT:
				hunt(w, a)
			Actor.SEARCH:
				search(w, a)
			_:
				rest(w, a)


## Sight first: seeing Miho starts a hunt; seeing one of her projectiles starts
## a search or, for a cunning creature, a hunt (see `Bestiary` wits).
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
			a.noted = s.id
			_heed(w, a, s, s.pos)
			return
	Notice.react(w, a)


## A projectile of Miho's seen at `at`: a dull creature searches that spot, a
## sharp one where the projectile came from, a cunning one hunts from there.
static func _heed(w: World, a: Actor, s: Shot, at: Vector2i) -> void:
	match Bestiary.wits(a.kind):
		Bestiary.DULL:
			_look(a, at)
		Bestiary.SHARP:
			_look(a, s.origin)
		_:
			w.hunt_from(a, s.origin)


## It was hurt: wary for WARY_ROUNDS, and a resting creature looks around.
static func hurt(a: Actor) -> void:
	a.wary = World.WARY_ROUNDS
	if a.alert == Actor.REST:
		_look(a, a.pos)


## `a` has just started to hunt Miho: it shouts its word (Bestiary shout, DCSS
## handle_monster_shouts), a noise that sends every creature of heaven that
## hears it, is not hunting and is not deaf to search where `a` saw her. A
## creature without a shout is silent.
static func shout(w: World, a: Actor) -> void:
	var cry: Dictionary = a.info().get("shout", {})
	if cry.is_empty():
		return
	w.emit({t = &"shout", id = a.id, at = a.pos, word = cry.word})
	w.noise(a.pos, cry.loud, cry.word, true, a.id, a.target)


## `a` was struck by `by`: by Miho, it stops fighting; by a living creature
## of heaven of another group, it fights that one for GRUDGE_ROUNDS.
static func provoke(w: World, a: Actor, by: Actor) -> void:
	if a.faction != Actor.HEAVEN or not a.alive() or by == null:
		return
	if by.faction == Actor.FOX:
		a.rival = 0
		a.grudge = 0
		return
	if by == a or not by.alive() or Bestiary.allied(a.kind, by.kind):
		return
	if a.rival != by.id:
		w.emit({t = &"feud", id = a.id, rival = by.id, at = a.pos})
	a.rival = by.id
	a.grudge = GRUDGE_ROUNDS
	a.rival_at = by.pos


## `gone` has fallen: whoever fought it stops, and the band it led scatters:
## each follower goes back to its own ways.
static func forget(w: World, gone: Actor) -> void:
	var led := false
	for a in w.actors:
		if a.rival == gone.id:
			a.rival = 0
			a.grudge = 0
		if a.leader == gone.id:
			a.leader = 0
			led = true
	if led:
		w.emit({t = &"scatter", id = gone.id, at = gone.pos})


## Its turn spent on its rival, while it fights one; false when it does not
## (a fight that ran out or lost its rival ends here, and it searches).
static func _fight(w: World, a: Actor) -> bool:
	if a.rival == 0:
		return false
	if a.grudge <= 0:
		_truce(w, a)
		return false
	var rival := w.actor(a.rival)
	if rival != null and w.sees(a, rival.pos):
		a.rival_at = rival.pos
		var melee: Dictionary = a.info().get("melee", {})
		if not melee.is_empty() and Grid.cheb(a.pos, rival.pos) == 1:
			_melee(w, a, rival, melee)
			return true
		if a.cooldown <= 0 and _charge(w, a, Aim.at(w, a, rival)):
			return true
		if a.rooted <= 0:
			_step_to(w, a, rival.pos, 1)
		return true
	if a.rooted > 0 or (a.pos != a.rival_at and _step_to(w, a, a.rival_at)):
		return true
	_truce(w, a)
	return false


## The fight is over: it searches where it last saw its rival.
static func _truce(w: World, a: Actor) -> void:
	a.rival = 0
	a.grudge = 0
	w.emit({t = &"truce", id = a.id, at = a.pos})
	if a.alert != Actor.HUNT:
		_look(a, a.rival_at)


## A projectile of Miho's struck `a`. One it saw coming gets the reaction of
## `perceive` again. From one it did not see, a dull creature only looks around,
## a sharp one searches the farthest tile it sees back along the flight line, and
## a cunning one searches where the projectile came from (and hunts as soon as
## `perceive` sees Miho). A projectile of heaven makes it wary, and one of
## another group makes it fight the caster (`provoke`).
static func struck(w: World, a: Actor, s: Shot) -> void:
	provoke(w, a, w.actor(s.caster))
	if a.faction != Actor.HEAVEN or a.alert == Actor.HUNT or s.faction == a.faction:
		return
	if a.noted == s.id:
		_heed(w, a, s, a.pos)
		return
	match Bestiary.wits(a.kind):
		Bestiary.DULL:
			_look(a, a.pos)
		Bestiary.SHARP:
			_look(a, _back(w, a, s))
		_:
			_look(a, s.origin)


## The farthest tile `a` sees back along the line `s` flew in on, up to its origin.
static func _back(w: World, a: Actor, s: Shot) -> Vector2i:
	var spot := a.pos
	var p := a.pos - s.dir
	var reach := Grid.cheb(a.pos, s.origin)
	while (
		s.dir != Vector2i.ZERO and Grid.cheb(a.pos, p) <= reach and w.open_air(p) and w.sees(a, p)
	):
		spot = p
		p -= s.dir
	return spot


static func _look(a: Actor, at: Vector2i) -> void:
	a.alert = Actor.SEARCH
	a.target = at
	a.lost = 0


static func hunt(w: World, a: Actor) -> void:
	if flee(w, a) or Drums.go(w, a):
		return
	var me := w.player()
	if a.sees_me:
		var melee: Dictionary = a.info().get("melee", {})
		if not melee.is_empty() and Grid.cheb(a.pos, me.pos) == 1:
			_melee(w, a, me, melee)
			return
		if a.cooldown <= 0 and _charge(w, a, Aim.at(w, a, me)):
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


## A fleeing creature (Actor.fleeing) that sees Miho steps to the neighbouring
## tile that is farther from her by foot, the one nearest its own group among
## them (DCSS mon-behv: a weak, not brave monster runs). With no such tile, or
## rooted, or with no way to her, it fights as before. Once she is out of sight
## it stops and searches where it stands. True when it spent its turn.
static func flee(w: World, a: Actor) -> bool:
	if not a.fleeing() or a.rooted > 0:
		return false
	if not a.sees_me:
		_look(a, a.pos)
		return true
	var walk := _walkable(w, a)
	var dist: PackedInt32Array = Grid.search(w.player().pos, Masks.walk(w, a, walk)).dist
	var here := dist[Grid.index(a.pos)]
	var kin := w.actors.filter(
		func(k): return k != a and k.alive() and Bestiary.allied(k.kind, a.kind)
	)
	var best := a.pos
	var best_cost := [INF, 0]
	for d in Grid.DIRS:
		var p := a.pos + d
		if not Grid.inside(p) or here < 0 or dist[Grid.index(p)] <= here or not walk.call(p):
			continue
		var near: int = (
			kin.map(func(k): return Grid.cheb(p, k.pos)).min() if not kin.is_empty() else 0
		)
		var cost := [near, -dist[Grid.index(p)]]
		if cost < best_cost:
			best = p
			best_cost = cost
	if best == a.pos:
		return false
	w.move(a, best)
	return true


## A stoker (Bestiary stokes) spends its turn lighting a dark lantern beside it.
static func _stoke(w: World, a: Actor) -> bool:
	return a.info().get("stokes", false) and Terrain.relight_beside(w, a)


## A tracker (Bestiary tracks) on Miho's trail sweeps along it, searching.
static func _track(w: World, a: Actor) -> bool:
	if not a.info().get("tracks", false) or a.rooted > 0:
		return false
	var to := Scent.next(w, a)
	if to == a.pos or not _step_to(w, a, to):
		return false
	_look(a, a.pos)
	return true


## Goes to the spot, throwing a wisp at it first when it lies in the dark.
## Next to a lantern that went out, it lights it again first.
static func search(w: World, a: Actor) -> void:
	if Terrain.relight_beside(w, a) or _track(w, a):
		return
	if a.cooldown <= 0 and _charge(w, a, Aim.searchlight(w, a)):
		return
	if a.rooted > 0:
		return
	if a.pos != a.target and _step_to(w, a, a.target):
		return
	a.lost += 1
	if a.lost > World.SEARCH_ROUNDS and a.wary <= 0:
		a.alert = Actor.REST
		a.lost = 0
		w.emit({t = &"calm", id = a.id})
		return
	_drift(w, a)


## A follower on patrol (Actor.following) keeps within FloorGen.BAND_SPREAD of its
## leader, who sets the way. True while it does, whether it stepped or stood.
static func _follow(w: World, a: Actor) -> bool:
	var lead := w.actor(a.leader)
	if not a.following() or lead == null:
		return false
	if Grid.cheb(a.pos, lead.pos) > FloorGen.BAND_SPREAD:
		_step_to(w, a, lead.pos, FloorGen.BAND_SPREAD)
	return true


static func rest(w: World, a: Actor) -> void:
	if a.rooted > 0 or _track(w, a) or _follow(w, a):
		return
	if not a.info().get("patrol", false):
		if a.pos != a.home:
			_step_to(w, a, a.home)
		return
	if a.pos == a.post or not _step_to(w, a, a.post):
		a.post = FloorGen.patrol_point(w)


## `a` strikes `target` beside it with its `melee` (Bestiary), throwing it
## back when the blow throws.
static func _melee(w: World, a: Actor, target: Actor, melee: Dictionary) -> void:
	w.emit({t = &"melee", id = a.id, target = target.id, at = target.pos, n = melee.damage})
	w.noise(target.pos, 3, "퍽", true, a.id)
	w.hurt(target, melee.damage)
	provoke(w, target, a)
	if melee.get("throw", 0) > 0 and target.alive():
		w.push(target, target.pos - a.pos, melee.throw)


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


## Free tiles, never into fire, onto hot ground or onto a plate.
static func _walkable(w: World, a: Actor) -> Callable:
	return func(p):
		return (
			p == a.pos
			or (w.vacant(p) and not w.burning.has(p) and not w.hot.has(p) and not w.traps.has(p))
		)


## One step along a shortest path towards `goal`, stopping `keep` tiles short;
## among equal paths it takes the straightest.
static func _step_to(w: World, a: Actor, goal: Vector2i, keep := 0) -> bool:
	if a.info().get("move", &"static") == &"static":
		return false
	var walk := _walkable(w, a)
	var dist: PackedInt32Array = Grid.search(goal, Masks.walk(w, a, walk)).dist
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
	var to := Aim.lineup(w, a, Masks.walk(w, a, _walkable(w, a)))
	if to == Vector2i(-1, -1):
		_step_to(w, a, w.player().pos, 2)
	elif to != a.pos:
		w.move(a, to)
