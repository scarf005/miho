class_name Cheat
extends RefCounted
## Debug commands for testing, played through World.act like any other action so
## a save keeps them and Continue plays them again: {t = &"cheat", cmd, ...}.
## A command takes no round: nothing flies, no creature acts and the clock stays
## put. The four toggles are kept in World.cheats and copied with it: 무적 (Miho
## takes no harm), 꼬리 무제한 (casting spends no tails), 맵 밝히기 (every tile
## known and seen) and 적 멈춤 (creatures take no turns). Harming a creature goes
## by Harm.hurt, so a death drops its scroll and gives Miho a tail.

## What every spell is said to cost the tails Miho may spend while they are free.
const UNLIMITED := 1000000
const TOGGLES: Array[StringName] = [&"god", &"tails", &"reveal", &"halt"]
## The name of each command, as the debug list and the log say it.
const NAME := {
	&"teleport": "순간이동",
	&"god": "무적",
	&"kill": "적 제거",
	&"kill_all": "적 제거",
	&"damage": "적에게 피해",
	&"tails": "꼬리 무제한",
	&"move_foe": "적 이동",
	&"floor": "층 이동",
	&"card": "부적 얻기",
	&"cards": "부적 얻기",
	&"summon": "적 소환",
	&"reveal": "맵 밝히기",
	&"heal": "체력 회복",
	&"halt": "적 멈춤",
}
## The parts of each command and their types.
const ARGS := {
	&"teleport": {at = TYPE_VECTOR2I},
	&"god": {},
	&"kill": {id = TYPE_INT},
	&"kill_all": {},
	&"damage": {id = TYPE_INT, n = TYPE_INT},
	&"tails": {},
	&"move_foe": {id = TYPE_INT, at = TYPE_VECTOR2I},
	&"floor": {depth = TYPE_INT},
	&"card": {card = TYPE_STRING_NAME},
	&"cards": {},
	&"summon": {kind = TYPE_STRING_NAME, at = TYPE_VECTOR2I},
	&"reveal": {},
	&"heal": {},
	&"halt": {},
}


static func on(w: World, toggle: StringName) -> bool:
	return w.cheats.get(toggle, false)


## What casting `spell` costs in tails.
static func cost(w: World, spell: Spell) -> int:
	return 0 if on(w, &"tails") else spell.cost()


## The tails Miho may spend.
static func tails(w: World) -> int:
	return UNLIMITED if on(w, &"tails") else w.tails


## Whether `a` takes no harm.
static func immune(w: World, a: Actor) -> bool:
	return a.is_miho() and on(w, &"god")


## With 맵 밝히기 on, every tile is known and seen; called once Miho's sight is worked out.
static func reveal(w: World) -> void:
	if on(w, &"reveal"):
		w.seen.fill(1)
		w.dim.fill(0)
		w.known.fill(1)


## Whether the action has the parts of its command, of the right types.
static func shaped(action: Dictionary) -> bool:
	var parts: Dictionary = ARGS.get(action.get("cmd"), {})
	return (
		ARGS.has(action.get("cmd"))
		and parts.keys().all(func(k): return typeof(action.get(k)) == parts[k])
	)


static func can(w: World, action: Dictionary) -> bool:
	if not shaped(action):
		return false
	var me := w.player()
	var foe := w.actor(action.get("id", -1))
	var foe_ok := foe != null and foe.alive() and foe.faction != Actor.FOX
	match action.cmd:
		&"teleport":
			return action.at != me.pos and _free(w, action.at)
		&"kill":
			return foe_ok
		&"kill_all":
			return w.actors.any(func(a): return a.faction != Actor.FOX)
		&"damage":
			return foe_ok and action.n >= 1
		&"move_foe":
			return foe_ok and _free(w, action.at, Bestiary.ground(foe.kind))
		&"floor":
			return action.depth >= 1 and action.depth <= World.FLOORS and action.depth != w.depth
		&"card":
			return Cards.ALL.has(action.card) and not w.cards.has(action.card)
		&"cards":
			return Cards.ALL.any(func(c): return not w.cards.has(c))
		&"summon":
			return (
				Bestiary.KINDS.has(action.kind)
				and action.kind != &"miho"
				and _free(w, action.at, Bestiary.ground(action.kind))
			)
		&"heal":
			return me.hp < me.max_hp
	return true


## Runs a cheat action that `can` allows and says so; false for any other action.
static func handled(w: World, action: Dictionary) -> bool:
	if action.t != &"cheat":
		return false
	var me := w.player()
	var foe := w.actor(action.get("id", -1))
	var e := {t = &"cheat", cmd = action.cmd}
	match action.cmd:
		&"teleport":
			_carry(w, me, action.at)
			e.at = action.at
		&"kill":
			e.merge({kind = foe.kind, at = foe.pos})
			_remove(w, foe)
		&"kill_all":
			for a in w.actors.filter(func(a): return a.faction != Actor.FOX):
				_remove(w, a)
		&"damage":
			Harm.hurt(w, foe, action.n)
		&"move_foe":
			_carry(w, foe, action.at)
			e.merge({kind = foe.kind, at = action.at})
		&"floor":
			Storeys.leave(w)
			Storeys.enter(w, action.depth)
			w.regrow = 0
			w.tails = w.max_tails()
			e.depth = action.depth
		&"card", &"cards":
			for c in [action.card] if action.cmd == &"card" else Cards.ALL:
				if not w.cards.has(c):
					w.cards.append(c)
					w.emit({t = &"card", card = c, at = me.pos})
		&"summon":
			FloorGen.spawn(w, action.kind, action.at)
			e.merge({kind = action.kind, at = action.at})
		&"heal":
			me.hp = me.max_hp
		_:
			w.cheats[action.cmd] = not on(w, action.cmd)
			e.on = on(w, action.cmd)
	if action.cmd not in [&"damage", &"card", &"cards"]:
		w.emit(e)
	Round.prune(w)
	w._changed()
	w.sense()
	return true


## Puts `a` on `to`, and the wisps riding it with it, without a step.
static func _carry(w: World, a: Actor, to: Vector2i) -> void:
	a.pos = to
	for s in w.shots:
		if s.host == a.id and not s.gone:
			s.pos = to


## A free tile a creature may stand on: no creature, no closed door.
static func _free(w: World, p: Vector2i, ground := Tiles.walk) -> bool:
	return Grid.inside(p) and w.vacant(p, ground) and w.tile(p) != World.DOOR


## Takes `a` off the board without a fall: no body, no scroll, no tail.
static func _remove(w: World, a: Actor) -> void:
	Mind.forget(w, a)
	w.actors.erase(a)
