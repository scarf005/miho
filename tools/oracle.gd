extends SceneTree
## Holds the rules to one result across a change of how the world is stored. It plays the saved
## runs of tools/oracle/ through SaveGame.step and prints one line per run, `<name> <sha256>`,
## and a last line `all <sha256>`. Per action the hash takes the events, their sounds, the log
## lines the action added, the whole world with every table in its iteration order and, at
## intervals, a forecast, the observation text and the hover text on sample tiles. An action also
## runs on a clone at intervals, which must end as the world does. A failed step or a clone that
## differs exits 1. docs/plan-ecs.md describes it.
## godot --headless --path . -s tools/oracle.gd -- [--record | --save=<path>]
## --record plays a bot, writes the saves and tools/oracle.expected, and prints what the runs cover.
## --save=<path> prints the line of one save that is not in the set.

const DIR := "res://tools/oracle"
const EXPECTED := "res://tools/oracle.expected"
const FORECAST_EVERY := 5
const CLONE_EVERY := 7
const KEPT_EVERY := 64
## The World vars the hash takes, but its events and caches; `rng`, `light` and `events` follow.
const WORLD_VARS: Array[String] = [
	"depth",
	"tiles",
	"rooms",
	"start",
	"stairs",
	"elixir",
	"peaches",
	"jars",
	"pungent",
	"curses",
	"strong",
	"burning",
	"wild",
	"gas",
	"vents",
	"flares",
	"wet",
	"hot",
	"traps",
	"secrets",
	"seals",
	"sites",
	"tail_bonus",
	"storeys",
	"actors",
	"shots",
	"next_id",
	"tails",
	"regrow",
	"cheats",
	"cards",
	"round_no",
	"rounds",
	"gas_heat",
	"outcome",
	"changes",
	"bodies",
	"seen",
	"dim",
	"known",
	"heard",
	"scent",
]
const WORLD_SKIPPED: Array[String] = [
	"events", "rng", "_light", "_light_dirty", "_lit", "_fov", "_opaque", "_shade"
]

## The actions of each kind of run: the saves are written by a bot with these dice.
const PLAIN_SEEDS := [76, 82, 36]
const PLAIN_ACTIONS := 330
const RICH_SEEDS := [21, 22, 23, 24, 25, 26, 27, 28, 29]
const RICH_ACTIONS := 190
## The seed of the run of one forced scene (_forge).
const FORGE_SEED := 30

var _failed := false
var _dice := RandomNumberGenerator.new()
## Event name -> how many times the hash pass saw it, and the storeys it saw Miho on.
var _seen := {}
var _depths := {}
var _kind_at := 0
var _kept_bytes := {}
## Whether a run may step onto the elixir, which ends it.
var _winnable := false


func _init() -> void:
	TranslationServer.set_locale("ko")
	_check_vars()
	var args := Array(OS.get_cmdline_user_args())
	var one := args.filter(func(a): return a.begins_with("--save="))
	var paths: Array[String] = []
	if not one.is_empty():
		paths.append(one[0].trim_prefix("--save="))
	else:
		if args.has("--record"):
			_record()
		for f in DirAccess.get_files_at(DIR):
			if f.ends_with(".cfg"):
				paths.append(DIR.path_join(f))
		paths.sort()
	var lines := _hash_all(paths, one.is_empty())
	if _failed:
		quit(1)
		return
	if args.has("--record"):
		_write_expected(lines)
		_cover()
	quit(0)


# --- the hash ----------------------------------------------------------------


## Prints the line of each save in `paths` and, for the whole set, the last line; the lines printed.
func _hash_all(paths: Array[String], whole: bool) -> Array[String]:
	var lines: Array[String] = []
	var all := HashingContext.new()
	all.start(HashingContext.HASH_SHA256)
	for path in paths:
		var save := SaveGame.load_from(path)
		if save == null:
			_fail("%s %s" % [path, _unreadable(path)])
			return lines
		var digest := _hash_run(save)
		if _failed:
			return lines
		var line := "%s %s" % [path.get_file().get_basename(), digest]
		print(line)
		lines.append(line)
		all.update((line + "\n").to_utf8_buffer())
	if whole:
		var line := "all %s" % all.finish().hex_encode()
		print(line)
		lines.append(line)
	return lines


## Why `path` is no save this build reads.
func _unreadable(path: String) -> String:
	var c := ConfigFile.new()
	if c.load(path) != OK:
		return "cannot be read"
	var version: Variant = c.get_value("run", "version", 0)
	if version != SaveGame.VERSION:
		return "is a save of version %s, not %d" % [version, SaveGame.VERSION]
	return "does not hold a run"


## The SHA-256 of a run played again from its seed; empty after a failure.
func _hash_run(save: SaveGame) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	save.begin()
	for i in save.actions.size():
		var action := save.actions[i]
		var w := save.world
		if i % KEPT_EVERY == 0:
			_kept_bytes.clear()
		if i % FORECAST_EVERY == 0:
			_feed(ctx, _probe(w, action))
		var cloned := []
		if i % CLONE_EVERY == 0:
			var c := w.clone()
			c.act(action)
			cloned = _compared(c)
		var round_was := w.round_no
		if not save.step():
			_fail("%s: action %d does not fit the rules" % [save.path, i])
			return ""
		w = save.world
		if (
			i % CLONE_EVERY == 0
			and not _same(cloned, _compared(w), "%s action %d" % [save.path, i])
		):
			return ""
		_feed(ctx, _after(save, round_was))
		for e in w.events:
			_seen[e.t] = _seen.get(e.t, 0) + 1
		_depths[w.depth] = true
		if _failed:
			return ""
	return ctx.finish().hex_encode()


func _feed(ctx: HashingContext, v: Variant) -> void:
	ctx.update(var_to_bytes(_plain(v)))


## What a forecast, the observation and the hover text say before the action.
func _probe(w: World, action: Dictionary) -> Array:
	var k := w.known_clone()
	var spots: Array[Vector2i] = [k.player().pos]
	for a in k.actors:
		if not a.is_miho():
			spots.append(a.pos)
	for j in 8:
		spots.append(
			Vector2i((w.round_no * 7 + j * 13) % Grid.W, (w.round_no * 5 + j * 11) % Grid.H)
		)
	var f := Forecast.of(w, action)
	return [
		[
			_world(f.after),
			f.events,
			f.paths,
			f.sprays,
			f.leaps,
			f.swaps,
			f.harm,
			f.deaths,
			f.noticed,
			f.falls,
			f.allies,
			f.sprouts,
			f.grounds,
			f.heated
		],
		Observation.text(w),
		spots.map(func(p): return Info.at(k, p))
	]


## What the action left: events, their sounds, the log lines it added and the whole world.
func _after(save: SaveGame, round_was: int) -> Array:
	var w := save.world
	var lines := []
	for i in range(save.messages.lines.size() - 1, -1, -1):
		var line := save.messages.lines[i]
		if line.round < round_was:
			break
		lines.append([line.text, line.n, line.round])
	return [w.events, w.events.map(Sfx.sound_of), lines, _world(w)]


## Every var of the world but the skipped ones, in the order of WORLD_VARS.
func _world(w: World) -> Array:
	var out := []
	for n in WORLD_VARS:
		out.append(_kept(w.storeys) if n == "storeys" else _plain(w.get(n)))
	out.append([w.rng.seed, w.rng.state])
	out.append(w.light())
	return out


## The kept storeys as bytes, one per depth in the order of `storeys`. A kept storey is never
## changed, so the bytes of the one already seen are reused, but for a full pass every
## KEPT_EVERY actions.
func _kept(storeys: Dictionary) -> Array:
	var out := []
	for depth in storeys:
		var seen: Array = _kept_bytes.get(depth, [])
		if seen.is_empty() or not is_same(seen[0], storeys[depth]):
			seen = [storeys[depth], var_to_bytes(_plain(storeys[depth]))]
			_kept_bytes[depth] = seen
		out.append([depth, seen[1]])
	return out


## What the clone check compares: the world and the events of the action.
func _compared(w: World) -> Array:
	return _world(w) + [_plain(w.events)]


## Whether the clone ended as the world did; prints the first field that differs.
func _same(clone: Array, world: Array, where: String) -> bool:
	var names := WORLD_VARS + ["rng", "light", "events"]
	for i in names.size():
		if var_to_bytes(clone[i]) == var_to_bytes(world[i]):
			continue
		_fail("%s: the clone differs in %s at %s" % [where, names[i], _differ(clone[i], world[i])])
		return false
	return true


## Where two plain values first differ, with both.
func _differ(a: Variant, b: Variant) -> String:
	if a is Array and b is Array and a.size() == b.size():
		for i in a.size():
			if var_to_bytes(a[i]) != var_to_bytes(b[i]):
				return "[%d] %s" % [i, _differ(a[i], b[i])]
	return "%s != %s" % [str(a).left(160), str(b).left(160)]


# --- plain data --------------------------------------------------------------


## `v` as plain data: a table is its pairs in iteration order, a spell its cards, a creature or a
## projectile its row. Any other object fails.
func _plain(v: Variant) -> Variant:
	if v is Dictionary:
		var out := []
		for k in v:
			out.append([_plain(k), _plain(v[k])])
		return out
	if v is Array:
		var out := []
		out.resize(v.size())
		for i in v.size():
			out[i] = _plain(v[i])
		return out
	return _object(v) if v is Object else v


## The plain data of a spell, creature or projectile; any other object fails.
func _object(o: Object) -> Variant:
	var out: Variant = null
	if o is Spell:
		out = _plain(o.cards)
	elif o is Actor:
		out = _actor_row(o)
	elif o is Shot:
		out = _shot_row(o)
	else:
		_fail("%s is not plain data" % o.get_class())
	return out


## Every field of an Actor: the one place a field move changes.
func _actor_row(a: Actor) -> Array:
	return [
		a.id,
		a.kind,
		a.faction,
		a.pos,
		a.hp,
		a.max_hp,
		a.magic.cooldown,
		_plain(a.magic.intent),
		a.rank,
		a.ailments.rooted,
		a.ailments.stunned,
		a.ailments.blind,
		a.ailments.wet,
		a.ailments.alight,
		a.ailments.frozen,
		a.magic.casts,
		a.magic.mana,
		a.magic.regrow,
		a.brain.acted,
		a.brain.alert,
		a.brain.target,
		a.brain.lost,
		a.brain.wary,
		_plain(a.brain.marked),
		a.brain.sees_me,
		a.brain.guard,
		a.brain.drum,
		a.brain.home,
		a.brain.post,
		a.ties.rival,
		a.ties.grudge,
		a.ties.rival_at,
		a.ties.leader,
		a.buffs.prey,
		a.buffs.form,
		a.buffs.guise,
		a.buffs.beside,
		a.buffs.talon,
		a.buffs.cloak,
		a.buffs.flame,
		a.buffs.raise,
		_plain(a.magic.imprint)
	]


## Every field of a Shot: the one place a field move changes.
func _shot_row(s: Shot) -> Array:
	return [
		s.id,
		s.faction,
		s.caster,
		_plain(s.spell),
		s.pos,
		s.origin,
		s.dir,
		s.life,
		s.gone,
		s.target,
		s.turn,
		s.bank,
		s.flown,
		s.host,
		s.pierced,
		s.fused,
		s.age,
		s.arcs
	]


func _fail(why: String) -> void:
	_failed = true
	printerr("error: " + why)


## Fails when World has a var that the hash neither takes nor skips.
func _check_vars() -> void:
	var known := WORLD_VARS + WORLD_SKIPPED
	for p in World.new().get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and not known.has(p.name):
			_fail("World.%s is neither hashed nor skipped" % p.name)


# --- recording ---------------------------------------------------------------


## Plays the bot, writes the saves, and leaves the hash pass to `_init`.
func _record() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var at := 0
	for seed_value in PLAIN_SEEDS:
		at += 1
		_save_run(at, seed_value, false)
	for k in RICH_SEEDS.size():
		at += 1
		_save_run(at, RICH_SEEDS[k], true, k)
	_save_run(at + 1, FORGE_SEED, true, -1)


func _save_run(number: int, seed_value: int, rich: bool, k := 0) -> void:
	_dice.seed = seed_value * 7 + 1
	var save := SaveGame.new(DIR.path_join("%02d.cfg" % number), seed_value)
	var w := World.create(seed_value)
	if k < 0:
		_forge(save, w)
	elif rich:
		_rich(save, w, k)
	else:
		_walk(save, w)
	save.write()
	print(
		(
			"%02d: %s %d actions, %d kills, storey %d, %s"
			% [
				number,
				"forge" if k < 0 else ("rich" if rich else "plain"),
				save.actions.size(),
				save.kills,
				w.depth,
				w.outcome if w.outcome != &"" else &"alive"
			]
		)
	)


## Plays `action` when it fits the rules.
func _play(save: SaveGame, w: World, action: Dictionary) -> bool:
	if action.is_empty() or not w.can(action):
		return false
	var events := w.act(action)
	save.kills += events.filter(func(e): return e.t == &"die" and e.get("foe", false)).size()
	save.actions.append(action)
	return true


## A plain run: no cheats; goes up by the shortest path, claws what stands next to it and casts
## what it holds at what stands in line.
func _walk(save: SaveGame, w: World) -> void:
	for i in PLAIN_ACTIONS:
		if w.outcome != &"":
			return
		var action := _fight(w)
		if action.is_empty():
			action = _step_to(w, w.stairs if w.stairs.x >= 0 else w.elixir)
		if not _play(save, w, action) and not _play(save, w, _any_step(w)):
			_play(save, w, {t = &"wait"})


## A spell along the line to the nearest creature of heaven that is awake and in sight, else a
## claw when it stands next to Miho, else a wait for her tails to grow back.
func _fight(w: World) -> Dictionary:
	var me := w.player().pos
	var foes := w.actors.filter(
		func(a):
			return a.faction == Actor.HEAVEN and not a.asleep() and w.seen[Grid.index(a.pos)] == 1
	)
	foes.sort_custom(func(a, b): return Grid.cheb(a.pos, me) < Grid.cheb(b.pos, me))
	for a in foes:
		var line := Grid.line_dir(me, a.pos)
		if Grid.cheb(a.pos, me) <= Spell.RANGE and line != Vector2i.ZERO and w.tails >= 1:
			for tries in 4:
				var cards := []
				for n in 1 + _dice.randi() % mini(3, w.tails):
					cards.append(w.cards[_dice.randi() % w.cards.size()])
				var cast := {t = &"cast", spells = [{cards = cards, dir = line}]}
				if w.can(cast):
					return cast
		if Grid.cheb(a.pos, me) == 1:
			return {t = &"move", dir = a.pos - me}
	return {t = &"wait"} if not foes.is_empty() and w.tails < w.max_tails() else {}


## A step along the shortest path to `goal`, or none.
func _step_to(w: World, goal: Vector2i) -> Dictionary:
	var me := Grid.index(w.player().pos)
	var found := Grid.search(w.player().pos, Masks.floor_of(w))
	var i := Grid.index(goal) if Grid.inside(goal) else me
	if found.dist[i] <= 0:
		return {}
	while found.parent[i] != me:
		i = found.parent[i]
	return {t = &"move", dir = Grid.at(i) - w.player().pos}


## The first step that fits the rules, from a random direction.
func _any_step(w: World) -> Dictionary:
	var from := _dice.randi() % 8
	for k in 8:
		var step := {t = &"move", dir = Grid.DIRS[(from + k) % 8]}
		if w.can(step):
			return step
	return {}


## A rich run: every card and tail at once, no harm; a mix of moves, spells, buffs, summons,
## storey changes, plates, edges of the sky and harm done to creatures. Some runs end mortal.
func _rich(save: SaveGame, w: World, k: int) -> void:
	for cmd in [&"cards", &"tails", &"god"] + ([&"reveal"] if k % 2 == 0 else []):
		_play(save, w, {t = &"cheat", cmd = cmd})
	var depths := [k % World.FLOORS + 1, (k + 3) % World.FLOORS + 1, k % World.FLOORS + 1]
	var mortal := k % 3 != 0
	var halt_until := -1
	var queue: Array = []
	for i in RICH_ACTIONS:
		if w.outcome != &"":
			return
		_winnable = i >= RICH_ACTIONS * 9 / 10
		var action := {}
		if not queue.is_empty():
			action = _next(w, queue)
		elif Cheat.on(w, &"halt"):
			action = {t = &"cheat", cmd = &"halt"} if i >= halt_until else _mix(w, queue)
		elif i == 20 and k == 1:
			_vigil(save, w)
		elif i == RICH_ACTIONS * 9 / 10 and k == 3:
			action = {t = &"cheat", cmd = &"floor", depth = World.FLOORS}
			queue.append(_finale.bind(queue))
		elif i == 12 or i % (RICH_ACTIONS / 4) == 0:
			action = {
				t = &"cheat",
				cmd = &"floor",
				depth = depths.pop_front() if not depths.is_empty() else 1
			}
		elif _dice.randi() % 50 == 0:
			action = {t = &"cheat", cmd = &"halt"}
			halt_until = i + 6 + _dice.randi() % 10
		elif mortal and i >= RICH_ACTIONS * 4 / 5:
			action = _peril(w)
		else:
			action = _mix(w, queue)
		if _play(save, w, action):
			if action.get("cmd") == &"floor":
				_tour(w, queue)
		else:
			_play(save, w, _any_step(w))


## A forced scene of 용광로 and 봉화: cast round her on her own tile and along a way, one furnace
## after another so that a later one must keep her a way, among creatures it hurls lava at. Each
## cast stands on an action that the hash takes a forecast of.
func _forge(save: SaveGame, w: World) -> void:
	for cmd in [&"cards", &"tails", &"god", &"reveal"]:
		_play(save, w, {t = &"cheat", cmd = cmd})
	_play(save, w, {t = &"cheat", cmd = &"floor", depth = 4})
	for n in 4:
		_play(save, w, _summon(w))
	var furnace: Array = Cards.spell_of(&"furnace").duplicate()
	var beacon: Array = Cards.spell_of(&"beacon").duplicate()
	for scene in [
		[furnace, Vector2i.ZERO],
		[furnace, Vector2i.RIGHT],
		[furnace, Vector2i.ZERO],
		[beacon, Vector2i.ZERO],
		[furnace, Vector2i.ZERO],
		[beacon, Vector2i.LEFT],
		[furnace, Vector2i.DOWN],
		[furnace, Vector2i.ZERO]
	]:
		while save.actions.size() % FORECAST_EVERY != FORECAST_EVERY - 1:
			_play(save, w, {t = &"wait"})
		_play(save, w, {t = &"cheat", cmd = &"tails"})
		_play(save, w, {t = &"cast", spells = [{cards = scene[0], dir = scene[1]}]})
		for n in 4:
			_play(save, w, {t = &"wait"})
	for n in 20:
		if not _play(save, w, _any_step(w)):
			_play(save, w, {t = &"wait"})
		_play(save, w, {t = &"wait"})


## On the last storey, a step onto the elixir.
func _finale(w: World, queue: Array) -> Dictionary:
	_visit(w, queue, w.elixir)
	return {}


## The next action of a scene: a Callable makes it from the world as it stands.
func _next(w: World, queue: Array) -> Dictionary:
	var next: Variant = queue.pop_front()
	return next.call(w) if next is Callable else next


## The creatures gone and then rounds of waiting, until the reaper has come (Curse).
func _vigil(save: SaveGame, w: World) -> void:
	_play(save, w, {t = &"cheat", cmd = &"kill_all"})
	for n in World.REAPER_ARRIVES + 5:
		_play(save, w, {t = &"wait"})


## One action of the mix; scenes of several actions are left in `queue`.
func _mix(w: World, queue: Array) -> Dictionary:
	var foes := w.actors.filter(func(a): return a.faction == Actor.HEAVEN)
	var pick := _dice.randi() % 100
	var out := {}
	if pick < 28:
		out = _any_step(w) if _dice.randi() % 2 == 0 else _toward_exit(w)
	elif pick < 31:
		out = _door(w)
	elif pick < 58:
		out = _cast(w, foes)
	elif pick < 68:
		out = _buff()
	elif pick < 74:
		out = _dispel(w)
	elif pick < 82:
		out = _summon(w)
	elif pick < 85:
		out = {t = &"cheat", cmd = &"floor", depth = 1 + _dice.randi() % World.FLOORS}
	elif pick < 91:
		_goto_scene(w, queue)
	elif pick < 93:
		_edge_scene(w, queue)
	elif pick < 95:
		_duel_scene(w, queue)
	elif not foes.is_empty():
		var foe: Actor = foes[_dice.randi() % foes.size()]
		out = {t = &"cheat", cmd = &"damage", id = foe.id, n = 1 + _dice.randi() % 3}
		if pick >= 97:
			out = {t = &"cheat", cmd = &"kill", id = foe.id}
	if out.is_empty() and not queue.is_empty():
		out = _next(w, queue)
	return out


## The first open door next to Miho, shut.
func _door(w: World) -> Dictionary:
	for d in Grid.DIRS:
		if w.can({t = &"close", dir = d}):
			return {t = &"close", dir = d}
	return {}


## A buff she wears, dropped.
func _dispel(w: World) -> Dictionary:
	var worn := Guise.worn(w, w.player())
	return {t = &"dispel", kind = worn[_dice.randi() % worn.size()]} if not worn.is_empty() else {}


func _toward_exit(w: World) -> Dictionary:
	return _step_to(w, _exit(w))


## The stairs, or the elixir that wins the run when it may; else off the board.
func _exit(w: World) -> Vector2i:
	return w.stairs if w.stairs.x >= 0 else (w.elixir if _winnable else Vector2i(-1, -1))


## The cards of a random spell: a compound, any cards, a form with elements, or copies of a form.
func _cards() -> Array:
	var cards := []
	match _dice.randi() % 5:
		0, 1:
			var all := Cards.compounds()
			cards = Cards.recipe(all[_dice.randi() % all.size()]).duplicate()
			if _dice.randi() % 2 == 0:
				cards.push_front(Cards.FORMS[_dice.randi() % 2])
		2:
			for n in 1 + _dice.randi() % 5:
				cards.append(Cards.ALL[_dice.randi() % Cards.ALL.size()])
		3:
			cards.append(Cards.FORMS[_dice.randi() % 2])
			for n in _dice.randi() % 4:
				cards.append(Cards.ELEMENTS[_dice.randi() % 5])
		_:
			cards.resize(1 + _dice.randi() % 5)
			cards.fill(Cards.FORMS[_dice.randi() % 2])
	return cards


## One to three spells along random directions, some aimed at a creature; empty when none fits.
func _cast(w: World, foes: Array) -> Dictionary:
	var me := w.player().pos
	for tries in 8:
		var spells := []
		var used := {}
		for n in 1 + (_dice.randi() % 3 if _dice.randi() % 4 == 0 else 0):
			var d: Vector2i = Grid.DIRS[_dice.randi() % 8]
			if not foes.is_empty() and _dice.randi() % 3 == 0:
				d = Grid.nearest_dir(foes[_dice.randi() % foes.size()].pos - me)
			if not used.has(d):
				used[d] = true
				spells.append({cards = _cards(), dir = d})
		for size in [spells.size(), 1]:
			var cast := {t = &"cast", spells = spells.slice(0, size)}
			if w.can(cast):
				return cast
	return {}


## A buff or 분신, cast on herself.
func _buff() -> Dictionary:
	var recipes := Guise.RECIPE.values() + [Cards.SETS[Cards.BUNSIN]]
	var cards: Array = recipes[_dice.randi() % recipes.size()].duplicate()
	return {t = &"cast", spells = [{cards = cards, dir = Vector2i.ZERO}]}


## The next kind in turn on a free tile near Miho.
func _summon(w: World) -> Dictionary:
	var kinds := Bestiary.KINDS.keys()
	for k in kinds.size():
		var kind: StringName = kinds[(_kind_at + k) % kinds.size()]
		for r in range(1, 6):
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if maxi(absi(dx), absi(dy)) == r:
						var summon := {
							t = &"cheat",
							cmd = &"summon",
							kind = kind,
							at = w.player().pos + Vector2i(dx, dy)
						}
						if w.can(summon):
							_kind_at = (_kind_at + k + 1) % kinds.size()
							return summon
	return {}


## A tile next to something to step onto (a plate, the exit, a peach, a jar, a site, a shelf) or
## to walk up to (a statue), and a step onto it.
func _goto_scene(w: World, queue: Array) -> void:
	var goals: Array = w.traps.keys() + w.peaches + w.jars.keys()
	goals.append_array(w.sites.map(func(s): return s.at))
	for t in [World.SHELF, World.STATUE]:
		var i := w.tiles.find(t)
		if i >= 0:
			goals.append(Grid.at(i))
	if goals.is_empty() or _dice.randi() % 4 == 0:
		goals = [_exit(w)]
	_visit(w, queue, goals[_dice.randi() % goals.size()])


## A teleport to a tile next to `goal`, and a step onto it.
func _visit(w: World, queue: Array, goal: Vector2i) -> void:
	for d in Grid.DIRS:
		var teleport := {t = &"cheat", cmd = &"teleport", at = goal - d}
		if w.can(teleport):
			queue.append(teleport)
			queue.append({t = &"move", dir = d})
			return


## What a storey just entered holds: a statue to walk up to, a shelf to read, a swamp gas to set
## alight, a drum to wet, a 해태 to put down, an altar to light with the fall of creatures called
## up near it.
func _tour(w: World, queue: Array) -> void:
	for t in [World.STATUE, World.SHELF]:
		var i := w.tiles.find(t)
		if i >= 0:
			_visit(w, queue, Grid.at(i))
	var marsh := w.gas.keys().filter(func(p): return w.gas[p].x == Gas.MARSH)
	if not marsh.is_empty():
		_shoot(w, queue, marsh[0], Cards.FIRE)
	if w.tiles.has(World.DRUM):
		_shoot(w, queue, Grid.at(w.tiles.find(World.DRUM)), Cards.WATER)
	for site in w.sites:
		if site.kind == &"creak":
			_put_down(queue, site.id)
		elif site.kind == &"altar":
			for n in Altar.NEED:
				queue.append(_call_up.bind(site.at))
				_put_down(queue, 0)


## A teleport to a tile next to `at` and a spell of `element` at it.
func _shoot(w: World, queue: Array, at: Vector2i, element: StringName) -> void:
	for d in Grid.DIRS:
		var teleport := {t = &"cheat", cmd = &"teleport", at = at - d}
		if w.can(teleport):
			queue.append(teleport)
			queue.append({t = &"cast", spells = [{cards = [Cards.FOX, element], dir = d}]})
			return


## A summon of a creature of heaven near `at`.
func _call_up(w: World, at: Vector2i) -> Dictionary:
	for r in range(1, 5):
		for d in Grid.DIRS:
			var summon := {t = &"cheat", cmd = &"summon", kind = &"dokkaebi", at = at + d * r}
			if w.can(summon):
				return summon
	return {}


## The creature `id`, or the last of heaven when 0, left with 1 health, Miho beside it, and a claw
## that puts it down in a round, which the harm of a cheat does not.
func _put_down(queue: Array, id: int) -> void:
	for step in [&"damage", &"teleport", &"claw"]:
		queue.append(_put_down_step.bind(id, step))


func _put_down_step(w: World, id: int, step: StringName) -> Dictionary:
	var foes := w.actors.filter(func(a): return a.faction == Actor.HEAVEN)
	var foe: Actor = w.actor(id) if id > 0 else (foes.back() if not foes.is_empty() else null)
	if foe == null or not foe.alive():
		return {}
	var me := w.player().pos
	if step == &"damage" and foe.hp > 1:
		return {t = &"cheat", cmd = &"damage", id = foe.id, n = foe.hp - 1}
	if step == &"claw" and Grid.cheb(foe.pos, me) == 1:
		return {t = &"move", dir = foe.pos - me}
	for d in Grid.DIRS:
		var teleport := {t = &"cheat", cmd = &"teleport", at = foe.pos - d}
		if step == &"teleport" and w.can(teleport):
			return teleport
	return {}


## A creature next to Miho, and spells of compounds at it, hypnosis the first.
func _duel_scene(w: World, queue: Array) -> void:
	for d in Grid.DIRS:
		var summon := {t = &"cheat", cmd = &"summon", kind = &"gaekgwi", at = w.player().pos + d}
		if w.can(summon):
			queue.append(summon)
			var all := Cards.compounds()
			var recipes := [Cards.recipe(&"hypnosis")]
			for n in 2:
				recipes.append(Cards.recipe(all[_dice.randi() % all.size()]))
			for cards in recipes:
				queue.append({t = &"cast", spells = [{cards = cards.duplicate(), dir = d}]})
			return


## Miho behind a creature that stands at the edge of the sky, and spells of water along the line.
func _edge_scene(w: World, queue: Array) -> void:
	var spots := []
	for i in w.tiles.size():
		var c := Grid.at(i)
		for d in Grid.DIRS:
			if w.tile(c + d) == World.SKY and w.open_floor(c) and w.open_floor(c - d):
				spots.append([c, d])
	if spots.is_empty():
		return
	var spot: Array = spots[_dice.randi() % spots.size()]
	var kind: StringName = Bestiary.KINDS.keys()[_kind_at % Bestiary.KINDS.size()]
	_kind_at += 1
	queue.append({t = &"cheat", cmd = &"teleport", at = spot[0] - spot[1]})
	queue.append({t = &"cheat", cmd = &"summon", kind = kind, at = spot[0]})
	for n in 3:
		var cards := [Cards.FORMS[_dice.randi() % 2], Cards.WATER]
		if n == 2:
			cards = Cards.recipe(&"rain").duplicate()
		queue.append({t = &"cast", spells = [{cards = cards, dir = spot[1]}]})


## The end of a mortal run: no god mode, and creatures called up next to Miho.
func _peril(w: World) -> Dictionary:
	if Cheat.on(w, &"god"):
		return {t = &"cheat", cmd = &"god"}
	return _summon(w) if _dice.randi() % 3 == 0 else {t = &"wait"}


## What the runs cover: the events seen, and the events src/core emits that no run showed.
func _cover() -> void:
	print("storeys reached: ", _depths.keys())
	print("events seen: ", _seen)
	var emitted := {}
	var named := RegEx.create_from_string('\\bt = &"([a-z_]+)"')
	for f in DirAccess.get_files_at("res://src/core"):
		if f.ends_with(".gd"):
			var text := FileAccess.get_file_as_string("res://src/core".path_join(f))
			for m in named.search_all(text):
				emitted[m.get_string(1)] = true
	var missing := emitted.keys().filter(func(t): return not _seen.has(StringName(t)))
	missing.sort()
	print("events never seen: ", missing)


func _write_expected(lines: Array[String]) -> void:
	var file := FileAccess.open(EXPECTED, FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
