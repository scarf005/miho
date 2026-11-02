extends SceneTree
## Prints SHA-256 digests of what a seed makes, to hold a speed change to the same result:
## every storey `seeds` seeds build on each of the nine storeys, `seeds` / 3 more on each
## skeleton, RNG state after each build included; then `rounds` rounds played on each of
## `seeds` seeds by a bot with its own dice (moves, waits, doors, spells of every card, and
## a forecast of each action), with everything the round leaves in the world.
## godot --headless --path . -s tools/storey_digest.gd -- 33 40


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := int(args[0]) if args.size() > 0 else 33
	var rounds := int(args[1]) if args.size() > 1 else 40
	_storeys(seeds)
	_play(seeds, rounds)
	quit()


func _storeys(seeds: int) -> void:
	var sum := HashingContext.new()
	sum.start(HashingContext.HASH_SHA256)
	var built := 0
	var from := Time.get_ticks_msec()
	for depth in range(1, World.FLOORS + 1):
		for seed_value in seeds:
			var w := World.create(seed_value * World.FLOORS + depth)
			w.depth = depth
			sum.update(_built(w, FloorGen.build(w)))
			built += 1
	for skeleton in Skeletons.ALL:
		for seed_value in seeds / 3:
			var w := World.create(seed_value + 7000)
			w.depth = seed_value % World.FLOORS + 1
			sum.update(_built(w, FloorGen.build(w, skeleton)))
			built += 1
	var ms := Time.get_ticks_msec() - from
	print("%d storeys %s %d ms" % [built, sum.finish().hex_encode(), ms])


func _play(seeds: int, rounds: int) -> void:
	var sum := HashingContext.new()
	sum.start(HashingContext.HASH_SHA256)
	var played := 0
	var from := Time.get_ticks_msec()
	for seed_value in seeds:
		var w := World.create(seed_value * 31 + 5)
		w.depth = seed_value % World.FLOORS + 1
		FloorGen.build(w)
		w.sense()
		w.cards.assign(Cards.ALL)
		var dice := RandomNumberGenerator.new()
		dice.seed = seed_value + 1
		for i in rounds:
			if w.outcome != &"":
				break
			w.tails = w.max_tails()
			var action := _action(w, dice)
			var f := Forecast.of(w, action)
			sum.update(_after(f.after, f.events))
			w.act(action)
			sum.update(_after(w, w.events))
			played += 1
	var ms := Time.get_ticks_msec() - from
	print("%d rounds %s %d ms" % [played, sum.finish().hex_encode(), ms])


## One legal action: mostly steps, a spell one time in five, a wait when nothing else may be.
static func _action(w: World, dice: RandomNumberGenerator) -> Dictionary:
	if dice.randi() % 5 == 0:
		var cards: Array[StringName] = [Cards.FORMS[dice.randi() % 2]]
		for k in dice.randi() % 3:
			cards.append(Cards.ELEMENTS[dice.randi() % 5])
		var dir := Grid.DIRS[dice.randi() % 8]
		var spell := {t = &"cast", spells = [{cards = cards, dir = dir}]}
		if w.can(spell):
			return spell
	var dir := Grid.DIRS[dice.randi() % 8]
	if dice.randi() % 12 == 0 and w.can({t = &"close", dir = dir}):
		return {t = &"close", dir = dir}
	var step := {t = &"move", dir = dir}
	return step if w.can(step) else {t = &"wait"}


## Everything a build leaves on `w`, in a fixed order.
static func _built(w: World, made: Dictionary) -> PackedByteArray:
	var row := [
		w.depth,
		w.tiles,
		w.rooms,
		w.start,
		w.stairs,
		w.elixir,
		w.peaches,
		w.jars,
		w.traps,
		w.secrets,
		w.seals,
		w.sites,
		w.vents,
		w.gas,
		w.tail_bonus,
		w.next_id,
		_actors(w),
		made,
		w.rng.state,
	]
	return var_to_bytes(row)


## What a round leaves on `w`, in a fixed order; a spell in an event goes by its cards.
static func _after(w: World, events: Array[Dictionary]) -> PackedByteArray:
	var told := []
	for e in events:
		var row := []
		for k in e:
			row.append([k, str(e[k]) if e[k] is Object else e[k]])
		told.append(row)
	var shots := []
	for s in w.shots:
		shots.append([s.id, s.pos, s.dir, s.life, s.target, s.gone, s.age, s.flown, s.spell.cards])
	var row := [
		w.tiles,
		w.seen,
		w.dim,
		w.known,
		w.scent,
		w.light(),
		w.burning,
		w.gas,
		w.hot,
		w.traps,
		w.secrets,
		w.changes,
		w.heard,
		_actors(w),
		shots,
		w.tails,
		w.round_no,
		w.outcome,
		w.rng.state,
		told,
	]
	return var_to_bytes(row)


static func _actors(w: World) -> Array:
	var out := []
	for a in w.actors:
		(
			out
			. append(
				[
					a.id,
					a.kind,
					a.pos,
					a.hp,
					a.max_hp,
					a.cooldown,
					a.rank,
					a.mana,
					a.leader,
					a.home,
					a.alert,
					a.target,
					a.sees_me,
					a.marked,
					a.wet,
					a.alight,
					a.frozen,
					a.rooted,
					a.blind,
					a.stunned,
				]
			)
		)
	return out
