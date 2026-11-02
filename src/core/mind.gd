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
## Bands (DCSS mon-place band): creatures of a group come in bands that follow
## their leader while they rest on patrol (`rest`); when it falls they scatter.
##
## Allies: a creature of Miho's side other than her (`enlist`, Actor.ally). It takes
## its turn here with the rest and fights by the same rule of a rival (`_take_on`,
## `_fight`): it sees foes as a creature does, charges, casts and strikes, and between
## fights it follows her as a band follows its leader. It hunts nobody and never
## sleeps. A foe takes on an ally it sees that stands nearer than Miho, so an ally
## draws fire; a fallen one gives no tail, no form for 둔갑 and no body (World.hurt,
## Fall). What Miho's spells do to it is what they do to any creature but her
## (Spray.on), and it holds back a spell that would catch its own side (Aim.spared).
## Walking into one trades places (Legal.makes_way), and one by her comes along up
## the stairs (Storeys.followers), as in DCSS (swap_check, _tag_follower_at).

const GRUDGE_ROUNDS := 10


## `a` is of Miho's side from now on, in her train, however it came to be.
static func enlist(w: World, a: Actor) -> void:
	a.faction = Actor.FOX
	a.leader = w.player().id
	a.rival = 0
	a.grudge = 0
	a.alert = Actor.REST
	a.intent.clear()
	w.emit({t = &"ally", id = a.id, at = a.pos, kind = a.kind})


## One round of spent mana growing back, as World._regrow does for tails; it
## runs before the creature casts.
static func _regrow(a: Actor) -> void:
	if a.mana >= Bestiary.mana(a.kind):
		a.regrow = 0
		return
	a.regrow += 1
	if a.regrow >= World.TAIL_REGROW:
		a.regrow = 0
		a.mana += World.TAIL_REGROWN


static func heaven_phase(w: World) -> void:
	if Cheat.on(w, &"halt"):
		return
	for a in w.actors.duplicate():
		if w.outcome != &"":
			return
		if not a.alive() or a.is_miho() or not w.actors.has(a):
			continue
		if Bestiary.swims(a.kind) and Tiles.water[w.tile(a.pos)] != 1:
			Fall.stranded(w, a)
			continue
		a.acted += 1
		_regrow(a)
		if a.stunned > 0:
			Status.lapse(w, a, &"stunned")
			continue
		perceive(w, a)
		if not a.intent.is_empty():
			var plans: Array[Dictionary] = a.intent.duplicate()
			a.intent.clear()
			a.cooldown = a.info().get("cd", 0)
			for plan in plans:
				if a.alive() and w.actors.has(a) and w.outcome == &"":
					w.cast(a, Bestiary.spell(a.kind, plan.cards), plan.dir)
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


## Sight first: seeing Miho, and knowing her through any guise (Guise), starts
## a hunt; seeing one of her projectiles starts a search or, for a cunning
## creature, a hunt (see `Bestiary` wits). An ally looks only for foes (`_take_on`).
static func perceive(w: World, a: Actor) -> void:
	_take_on(w, a)
	if a.ally():
		return
	var me := w.player()
	a.sees_me = Guise.knows(w, a)
	if a.sees_me or a.info().get("hunts", false):
		w.hunt_from(a, me.pos)
		return
	if a.alert == Actor.HUNT or a.blind > 0:
		return
	for s in w.shots:
		if not s.gone and s.faction != a.faction and w.sees(a, s.pos):
			_heed(w, a, s)
			return
	Notice.react(w, a)


## `a` takes on the nearest of the other side it sees, by (distance, id), unless
## that is Miho, whom it hunts as ever. A fight among its own side goes on, and with
## nobody in sight it goes on walking to where it last saw its rival.
static func _take_on(w: World, a: Actor) -> void:
	var rival := w.actor(a.rival) if a.fighting() else null
	if rival != null and rival.faction == a.faction:
		return
	var near: Actor = null
	for b in w.actors:
		if b.alive() and b.faction != a.faction and Hat.sees(w, a, b):
			if near == null or Homing.closer(a.pos, b, near):
				near = b
	if near == null:
		return
	if not near.is_miho():
		feud(w, a, near)
	elif rival != null:
		a.rival = 0
		a.grudge = 0


## A projectile of Miho's seen flying: a dull creature searches the spot it
## flies at, a sharp one where it came from, a cunning one hunts from there.
static func _heed(w: World, a: Actor, s: Shot) -> void:
	match Bestiary.wits(a.kind):
		Bestiary.DULL:
			_look(a, s.pos)
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


## `a` was struck by `by`: by Miho, it stops fighting; by a living ally of hers or
## a creature of heaven of another group, it fights that one for GRUDGE_ROUNDS.
static func provoke(w: World, a: Actor, by: Actor) -> void:
	if a.faction != Actor.HEAVEN or not a.alive() or by == null:
		return
	if by.is_miho():
		a.rival = 0
		a.grudge = 0
		return
	if by == a or not by.alive() or (not by.ally() and Bestiary.allied(a.kind, by.kind)):
		return
	feud(w, a, by)


## `a` fights `rival` for GRUDGE_ROUNDS, of whatever group.
static func feud(w: World, a: Actor, rival: Actor) -> void:
	if a.rival != rival.id:
		w.emit({t = &"feud", id = a.id, rival = rival.id, at = a.pos})
	a.rival = rival.id
	a.grudge = GRUDGE_ROUNDS
	a.rival_at = rival.pos


## `a` loses Miho: it searches the tile it stands on.
static func lose(a: Actor) -> void:
	_look(a, a.pos)


## `a` falls asleep where it stands (Actor.asleep): it rests there from now on
## with its charged spells and fights dropped. One that does not sleep
## (Actor.sleeps) or sleeps already is left alone.
static func sleep(w: World, a: Actor) -> void:
	if not a.alive() or not a.sleeps() or a.asleep():
		return
	a.alert = Actor.REST
	a.home = a.pos
	a.lost = 0
	a.rival = 0
	a.grudge = 0
	a.sees_me = false
	a.intent.clear()
	w._changed()
	w.emit({t = &"sleep", id = a.id, at = a.pos})


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
	if rival != null and Hat.sees(w, a, rival):
		a.rival_at = rival.pos
		var melee: Dictionary = a.info().get("melee", {})
		var near: bool = not melee.is_empty() and Grid.cheb(a.pos, rival.pos) == 1
		if near and not a.ally():
			_melee(w, a, rival, melee)
			return true
		if a.cooldown <= 0 and _charge(w, a, Aim.spared(w, a, rival)):
			return true
		if near:
			_melee(w, a, rival, melee)
		elif a.rooted <= 0:
			_close(w, a, rival)
		return true
	if a.rooted > 0 or (a.pos != a.rival_at and _step_to(w, a, a.rival_at)):
		return true
	_truce(w, a)
	return false


## `a` goes after `foe`: one whose spell wants room lines up for it (Aim.keeps, DCSS
## _set_firing_pos), any other walks up to it.
static func _close(w: World, a: Actor, foe: Actor) -> void:
	if Aim.keeps(a):
		_align(w, a, foe)
	else:
		_step_to(w, a, foe.pos, 1)


## The fight is over: a creature of heaven searches where it last saw its rival, and
## an ally goes back to her.
static func _truce(w: World, a: Actor) -> void:
	a.rival = 0
	a.grudge = 0
	w.emit({t = &"truce", id = a.id, at = a.pos})
	if a.alert != Actor.HUNT and not a.ally():
		_look(a, a.rival_at)


## A projectile struck `a`. One of Miho's shows it where she stands, so it hunts
## her from her tile (the projectile's origin when she is gone), whatever its
## wits. One of heaven makes it wary, and one of another group, or of an ally of
## hers, makes it fight the caster (`provoke`), even one fallen since.
static func struck(w: World, a: Actor, s: Shot) -> void:
	var caster := w.actor(s.caster)
	provoke(w, a, caster)
	if a.faction != Actor.HEAVEN or not a.alive() or s.faction == a.faction:
		return
	if caster != null and caster.is_miho():
		w.hunt_from(a, caster.pos if caster.alive() else s.origin)


static func _look(a: Actor, at: Vector2i) -> void:
	a.alert = Actor.SEARCH
	a.target = at
	a.lost = 0


static func hunt(w: World, a: Actor) -> void:
	if Drums.go(w, a):
		return
	var me := w.player()
	if a.sees_me:
		var melee: Dictionary = a.info().get("melee", {})
		if not melee.is_empty() and Grid.cheb(a.pos, me.pos) == 1:
			if a.cooldown > 0 or not _charge(w, a, Aim.kindle(w, a, me)):
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
	if _suspect(w, a):
		return
	var by_nose: bool = me.cloak and a.info().get("tracks", false)
	if not by_nose and a.pos != a.target and a.lost < World.SEARCH_ROUNDS:
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


## A stoker (Bestiary stokes) spends its turn lighting a dark lantern beside it,
## unless it is asleep: only one awake (on patrol, searching, hunting, walking
## home) does.
static func _stoke(w: World, a: Actor) -> bool:
	return a.info().get("stokes", false) and not a.asleep() and Terrain.relight_beside(w, a)


## A tracker (Bestiary tracks) on Miho's trail sweeps along it, searching.
static func _track(w: World, a: Actor) -> bool:
	if not a.info().get("tracks", false) or a.rooted > 0:
		return false
	var to := Scent.next(w, a)
	if to == a.pos or not _step_to(w, a, to):
		return false
	_look(a, a.pos)
	return true


## A clever creature that cannot see Miho under her 은신 throws a wisp at where it
## suspects her (Aim.suspected).
static func _suspect(w: World, a: Actor) -> bool:
	return a.cooldown <= 0 and _charge(w, a, Aim.suspected(w, a))


## Goes to the spot, throwing a wisp at it first when it lies in the dark or it
## suspects Miho there. Next to a lantern that went out, it lights it again first.
static func search(w: World, a: Actor) -> void:
	if Terrain.relight_beside(w, a) or _suspect(w, a) or _track(w, a):
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
	var spread := 1 if a.ally() else FloorGen.BAND_SPREAD
	if Grid.cheb(a.pos, lead.pos) > spread:
		_step_to(w, a, lead.pos, spread)
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
## back when the blow throws and rooting it when the blow roots.
static func _melee(w: World, a: Actor, target: Actor, melee: Dictionary) -> void:
	w.emit({t = &"melee", id = a.id, target = target.id, at = target.pos, n = melee.damage})
	w.noise(target.pos, 3, "퍽", true, a.id)
	w.hurt(target, melee.damage)
	provoke(w, target, a)
	var seizes: bool = melee.get("pull", false)
	if melee.get("root", 0) > 0 and target.alive() and not (seizes and target.rooted > 0):
		Elements.root(w, target, melee.root)
		if seizes:
			Fall.pull(w, target, a)
	if melee.get("throw", 0) > 0 and target.alive():
		w.push(target, target.pos - a.pos, melee.throw)


## `a` charges the spells `plans` (Aim), one `charge` event each, paying their
## mana when it has some.
static func _charge(w: World, a: Actor, plans: Array[Dictionary]) -> bool:
	if plans.is_empty():
		return false
	a.intent.assign(plans)
	for plan in plans:
		if Bestiary.mana(a.kind) > 0:
			a.mana -= Spell.price(plan.cards.size())
		w.emit({t = &"charge", id = a.id, cards = plan.cards.duplicate(), dir = plan.dir})
	return true


static func _chase(w: World, a: Actor) -> void:
	var me := w.player()
	match a.info().get("move", &"static"):
		&"approach", &"water":
			_step_to(w, a, me.pos, 1)
		&"slow":
			if a.acted % 2 == 0:
				_step_to(w, a, me.pos, 1)
		&"align":
			_align(w, a, me)


## Free tiles of its ground (Bestiary.ground), never into fire, onto hot ground or onto a
## plate.
static func _walkable(w: World, a: Actor) -> Callable:
	var ground := Bestiary.ground(a.kind)
	return func(p):
		return (
			p == a.pos
			or (
				w.vacant(p, ground)
				and not w.burning.has(p)
				and not w.hot.has(p)
				and not w.traps.has(p)
			)
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


static func _align(w: World, a: Actor, foe: Actor) -> void:
	var to := Aim.lineup(w, a, Masks.walk(w, a, _walkable(w, a)), foe)
	if to == Vector2i(-1, -1):
		_step_to(w, a, foe.pos, 2)
	elif to != a.pos:
		w.move(a, to)
