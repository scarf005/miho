extends SceneTree
## Miho's power against the creatures of each storey, measured on the real
## rules: tails, hp and talismans by depth, the enemies FloorGen places, the
## strongest spell Miho can cast with what she has (every spell of up to
## MAX_COST cards, cast in an open hall through World.act at a lone creature
## and at three), and the rounds she needs to kill each kind. Prints Markdown.
## godot --headless --path . -s tools/power.gd
## Measuring is slow (one core, over an hour); `just power` splits it over the
## cores: `-- --shard=I/N --memo=DIR` measures the I-th of N parts of the spells
## into DIR, and `-- --memo=DIR` prints the tables from the parts in DIR.

## Storeys built per depth to count the creatures FloorGen places.
const SEEDS := 12
## Most cards in a spell the search tries: those Spell.price puts within
## max_tails at the last storey, 9, and one more for an altar.
const MAX_COST := 6
## Tiles between Miho and the creature the casts are tried at.
const DISTANCES := [1, 4]
## The health a target gets, so a cast is never capped by its death.
const BIG := 99
const MIHO_AT := Vector2i(4, 13)
const EAST := Vector2i(1, 0)
## Rounds waited after a cast that leaves fire, hot ground or gas behind.
const AFTER := 3
const ALL_KINDS: Array[StringName] = [
	&"dokkaebi",
	&"oedari",
	&"bujigaengi",
	&"bitjaru",
	&"gamtu",
	&"jangseung",
	&"imugi",
	&"bulgae",
	&"haetae",
	&"cheonha",
	&"jiha",
	&"bulgasari",
	&"cheonnyeon",
	&"saja",
]

## Every spell worth trying: slots key -> a card queue that makes it.
var _spells := {}
## spell key + kind -> {one, two, three}: the harm to one creature in the cast
## round and over the rounds after, and to three in the cast round.
var _memo := {}
var _arena: World
## The part of the spells this run measures: {index, count}, or empty for all.
var _shard := {}
var _dir := ""


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--memo="):
			_dir = arg.trim_prefix("--memo=")
		elif arg.begins_with("--shard="):
			var part := arg.trim_prefix("--shard=").split("/")
			_shard = {index = int(part[0]), count = int(part[1])}
	_arena = _hall()
	_enumerate()
	_load()
	if not _shard.is_empty():
		_measure_all()
		quit()
		return
	_say("# Miho's power against the pavilion\n")
	_say("%d spells of up to %d cards, %d storeys per depth.\n" % [_spells.size(), MAX_COST, SEEDS])
	_creature_table()
	_depth_table()
	_kill_tables()
	quit()


# --- the hall ----------------------------------------------------------------


func _hall() -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	for y in range(1, Grid.H - 1):
		for x in range(1, Grid.W - 1):
			w.tiles[Grid.index(Vector2i(x, y))] = World.FLOOR
	w.rooms.assign([Rect2i(1, 1, Grid.W - 2, Grid.H - 2)])
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.hp = BIG
	me.max_hp = BIG
	me.pos = MIHO_AT
	w.actors.append(me)
	w.depth = 1
	w.cards.assign(Cards.ALL)
	w.sense()
	return w


func _foe(w: World, kind: StringName, at: Vector2i) -> Actor:
	var a := FloorGen.spawn(w, kind, at)
	a.hp = BIG
	a.max_hp = BIG
	a.cooldown = BIG
	return a


# --- the spells --------------------------------------------------------------


## Breadth first over the slots the cards queue (Spell.fill): one queue for each
## set of slots, the order of the slots after the first left out (it changes
## nothing a cast does) and 도약, which moves Miho and strikes no harder, too.
func _enumerate() -> void:
	var seen := {}
	var front: Array = [[]]
	for n in MAX_COST:
		var next: Array = []
		for cards: Array in front:
			for c in Cards.ALL:
				var picked := cards + [c]
				var slots := Spell.fill(picked)
				var exact := ",".join(slots)
				if slots.size() > Spell.MAX_SLOTS or seen.has(exact):
					continue
				seen[exact] = true
				next.append(picked)
				var key := _key(slots)
				if (
					not _spells.has(key)
					and not slots.has(Cards.VAULT)
					and Spell.make(picked) != null
				):
					_spells[key] = picked
		front = next


func _key(slots: Array) -> String:
	var rest := slots.slice(1).map(func(s): return String(s))
	rest.sort()
	return "%s|%s" % [slots[0], ",".join(rest)]


func _owned(cards: Array, held: Array) -> bool:
	return cards.all(func(c): return held.has(c))


# --- casting -----------------------------------------------------------------


## The harm one cast of `cards` does to the creatures at `spots` of `kind`.
func _cast_at(cards: Array, kind: StringName, spots: Array[Vector2i], after := false) -> Dictionary:
	var w := _arena.clone()
	var ids := []
	for p in spots:
		ids.append(_foe(w, kind, p).id)
	w.tails = Spell.price(cards.size())
	w.act({t = &"cast", spells = [{cards = cards, dir = EAST}]})
	var first := _harm(w.events, ids)
	var total := first
	var lingers := w.actors.any(func(a): return a.alight > 0) or not w.hot.is_empty()
	if after and (lingers or not w.gas.is_empty()):
		for i in AFTER:
			w.act({t = &"wait"})
			total += _harm(w.events, ids)
	return {first = first, total = total}


func _harm(events: Array, ids: Array) -> int:
	var n := 0
	for e in events:
		if e.t == &"hurt" and ids.has(e.id):
			n += e.n
	return n


## The most `cards` do to one creature of `kind` in the cast round and with the
## rounds after it, and to three in the cast round.
func _measure(cards: Array, kind: StringName) -> Dictionary:
	var out := {one = 0, one_after = 0, three = 0}
	for d: int in DISTANCES:
		var one := _cast_at(cards, kind, [MIHO_AT + EAST * d] as Array[Vector2i], true)
		out.one = maxi(out.one, one.first)
		out.one_after = maxi(out.one_after, one.total)
		var wide: Array[Vector2i] = []
		var deep: Array[Vector2i] = []
		for k in 3:
			wide.append(MIHO_AT + EAST * d + Vector2i(0, k - 1))
			deep.append(MIHO_AT + EAST * (d + k))
		for spots in [wide, deep]:
			out.three = maxi(out.three, _cast_at(cards, kind, spots).first)
	return out


## What decides how a cast strikes a creature: kinds that share it share their
## numbers (the health is the same for all in the hall).
func _profile(kind: StringName) -> String:
	var info := Bestiary.info(kind)
	var weak := ",".join(Bestiary.weak_to(kind).map(func(c): return String(c)))
	var tag := "%s|%s|%s|%s|%s"
	var facts := [info.get("absorb", ""), info.get("eats", ""), weak, Bestiary.burns(kind)]
	return tag % (facts + [info.get("hat", false)])


## Measures every spell of `keys` not yet measured against creatures like `kind`.
func _fill(keys: Array, kind: StringName) -> void:
	var profile := _profile(kind)
	var todo := keys.filter(
		func(k):
			return (
				not _memo.has(k + "@" + profile)
				and (_shard.is_empty() or k.hash() % _shard.count == _shard.index)
			)
	)
	printerr("%s: %d spells to measure" % [kind, todo.size()])
	for k: String in todo:
		_memo[k + "@" + profile] = _measure(_spells[k], kind)


## Measures what the tables will ask for: the spells of every depth against
## every kind of its storey. Saves them to the memo directory.
func _measure_all() -> void:
	for depth in range(1, World.FLOORS + 1):
		for kind in _kinds(depth):
			_ladder(_held(depth), kind, _max_tails(depth))
	var file := FileAccess.open("%s/%d.json" % [_dir, _shard.index], FileAccess.WRITE)
	file.store_string(JSON.stringify(_memo))


## Takes in the measures saved by the shards in the memo directory.
func _load() -> void:
	if _dir == "" or not DirAccess.dir_exists_absolute(_dir):
		return
	for name in DirAccess.get_files_at(_dir):
		var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_dir + "/" + name))
		for k in saved:
			var m: Dictionary = saved[k]
			_memo[k] = {one = int(m.one), one_after = int(m.one_after), three = int(m.three)}


## A creature of `kind` of rank `r` casting what it charges (Aim.at) at Miho
## from every distance, its turn starting at each of its spells, and striking
## her in melee: the most harm one action does her, and the spells cast.
func _blow(kind: StringName, r: int) -> Dictionary:
	var info := Bestiary.info(kind)
	var out := {melee = info.get("melee", {}).get("damage", 0), cast = 0, cast_name = ""}
	for start in Bestiary.casts(kind, r).size():
		for d in range(1, Spell.RANGE + 1):
			var w := _arena.clone()
			var foe := _foe(w, kind, MIHO_AT + EAST * d)
			foe.rank = r
			foe.casts = start
			var plans := Aim.at(w, foe, w.player())
			w.events = []
			for plan in plans:
				w.cast(foe, Bestiary.spell(kind, plan.cards), plan.dir)
			for i in 12:
				w._shots_phase()
			var n := 0
			for e in w.events:
				if e.t == &"hurt" and e.id == w.player().id:
					n += e.n
			if not plans.is_empty() and (n > out.cast or out.cast_name == ""):
				out.cast = n
				var titles := plans.map(func(p): return Bestiary.spell(kind, p.cards).title())
				out.cast_name = " + ".join(titles)
	return out


# --- the world by depth ------------------------------------------------------


func _tier(depth: int) -> int:
	return (depth + World.TAIL_EVERY - 1) / World.TAIL_EVERY


func _max_tails(depth: int) -> int:
	return 1 + (depth - 1) / World.TAIL_EVERY


## The talismans Miho can hold on arriving at `depth`: the two she starts with
## and the drop of every creature the plan places on a storey before it (a tier's
## first storey counts for the other two).
func _held(depth: int) -> Array:
	var out := [Cards.FOX, Cards.ORB]
	var done := (depth + 1) / World.TAIL_EVERY
	for tier in range(1, done + 1):
		for kind in FloorGen.PLAN[tier]:
			var drop: StringName = Bestiary.info(kind).get("drop", &"")
			if drop != &"" and not out.has(drop):
				out.append(drop)
	return out


## The kinds the plan gives a storey (a boss only on the last), and the 저승사자
## who arrives on every storey but the last after World.REAPER_ARRIVES rounds.
func _kinds(depth: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for kind: StringName in FloorGen.PLAN[_tier(depth)]:
		var boss: bool = Bestiary.info(kind).get("boss", false)
		if not out.has(kind) and (depth >= World.FLOORS or not boss):
			out.append(kind)
	if depth < World.FLOORS:
		out.append(&"saja")
	return out


## Creatures FloorGen placed on average, by kind, over SEEDS storeys.
func _counts(depth: int) -> Dictionary:
	var sum := {}
	for s in SEEDS:
		var w := World.create(s)
		w.depth = depth
		FloorGen.build(w)
		for a in w.actors.slice(1):
			sum[a.kind] = sum.get(a.kind, 0) + 1
	var out := {}
	for k in sum:
		out[k] = float(sum[k]) / SEEDS
	return out


func _glyphs(held: Array) -> String:
	return "".join(held.map(func(c): return Cards.GLYPH[c]))


# --- tables ------------------------------------------------------------------


func _creature_table() -> void:
	_say("## Creatures\n")
	_say("- rank: of the storeys the kind is placed on (Bestiary.rank: storeys 1-6, 7-12, ...).")
	_say("- melee: harm of a blow from the next tile. cast: the most harm one charged turn (the")
	_say("  spells it picks, Aim.at) does Miho over distances 1 to %d." % Spell.RANGE)
	_say("- hits: blows to kill Miho at 3 hp. spells: every spell it casts at that rank.")
	_say("- cd: rounds between casts. weak to: elements that hit it twice.")
	_say("")
	_say("| kind | rank | hp | melee | cast | hits | cd | weak to | spells | other |")
	_say("|---|---|---|---|---|---|---|---|---|---|")
	for row in _ranked_kinds():
		var kind: StringName = row[0]
		var r: int = row[1]
		var info := Bestiary.info(kind)
		var blow := _blow(kind, r)
		var spells := Bestiary.casts(kind, r).map(func(c): return Bestiary.spell(kind, c).title())
		var worst := maxi(blow.melee, blow.cast)
		var weak := ",".join(Bestiary.weak_to(kind).map(func(c): return Cards.NAME[c]))
		var other := []
		for flag in ["brave", "boss", "hunts", "patrol", "deaf", "hat"]:
			if info.get(flag, false):
				other.append(flag)
		if info.get("absorb", &"") != &"":
			other.append("absorbs %s" % info.absorb)
		if info.has("drop"):
			other.append("drops %s" % Cards.NAME[info.drop])
		if info.get("move", &"") != &"":
			other.append(String(info.move))
		if info.get("melee", {}).get("throw", 0) > 0:
			other.append("throws %d" % info.melee.throw)
		var cast := "%d (%s)" % [blow.cast, blow.cast_name] if blow.cast_name != "" else "-"
		_say(
			(
				"| %s | %d | %d | %d | %s | %s | %s | %s | %s | %s |"
				% [
					info.name,
					r,
					Bestiary.hp(kind, r),
					blow.melee,
					cast,
					str(ceili(3.0 / worst)) if worst > 0 else "never",
					str(info.get("cd", "-")),
					weak if weak != "" else "-",
					", ".join(spells) if not spells.is_empty() else "-",
					", ".join(other),
				]
			)
		)
	_say("")


## [kind, rank] for every kind and each rank of the storeys it is placed on.
func _ranked_kinds() -> Array:
	var placed := {}
	for depth in range(1, World.FLOORS + 1):
		for kind in _kinds(depth):
			placed["%s/%d" % [kind, Bestiary.rank(_tier(depth))]] = true
	var out := []
	for kind in ALL_KINDS:
		for r in range(1, Bestiary.RANKS + 1):
			if placed.has("%s/%d" % [kind, r]):
				out.append([kind, r])
	return out


func _depth_table() -> void:
	_say("## Miho by depth\n")
	_say("- tails: max_tails, and in brackets with a lit altar (that storey only).")
	_say("- hp bound: 3, and 1 more for each peach eaten at full hp (one grows on each odd storey")
	_say("  from the third), counting only the storeys before.")
	_say("- spells: distinct spells costing at most max_tails from the talismans held.")
	_say("- creatures: mean number FloorGen placed over %d storeys per depth." % SEEDS)
	_say("")
	_say("| depth | tier | tails | hp bound | talismans on arrival | spells | creatures |")
	_say("|---|---|---|---|---|---|---|")
	for depth in range(1, World.FLOORS + 1):
		var held := _held(depth)
		var t := _max_tails(depth)
		var peaches := maxi(0, (depth - 2) / 2)
		var count := (
			_spells
			. keys()
			. filter(func(k): return _owned(_spells[k], held) and _spells[k].size() <= t)
			. size()
		)
		var counts := _counts(depth)
		var names := []
		for k in counts:
			names.append("%s %.1f" % [Bestiary.info(k).name, counts[k]])
		_say(
			(
				"| %d | %d | %d (%d) | 3..%d | %s | %d | %s |"
				% [
					depth,
					_tier(depth),
					t,
					t + 1,
					3 + peaches,
					_glyphs(held),
					count,
					", ".join(names)
				]
			)
		)
	_say("")


## The best harm per cost a creature takes, for the spells `held` allows.
## cost -> {one, three, spell (title)}, the best of cost at most that.
func _ladder(held: Array, kind: StringName, top: int) -> Array:
	var best := []
	for n in range(0, top + 1):
		best.append({one = 0, three = 0, after = 0, one_spell = "", after_spell = ""})
	var keys := _spells.keys().filter(
		func(k): return Spell.price(_spells[k].size()) <= top and _owned(_spells[k], held)
	)
	_fill(keys, kind)
	if not _shard.is_empty():
		return best
	for k in keys:
		var cards: Array = _spells[k]
		var h: Dictionary = _memo[k + "@" + _profile(kind)]
		for n in range(Spell.price(cards.size()), top + 1):
			if h.one > best[n].one:
				best[n].one = h.one
				best[n].one_spell = Spell.make(cards).title()
			if h.one_after > best[n].after:
				best[n].after = h.one_after
				best[n].after_spell = Spell.make(cards).title()
			best[n].three = maxi(best[n].three, h.three)
	return best


## The cheapest cost whose best cast does at least `hp`, or 0 for none.
func _one_shot(ladder: Array, hp: int, field: String) -> int:
	for n in range(1, ladder.size()):
		if ladder[n][field] >= hp:
			return n
	return 0


## Rounds and tails to kill `hp`: each round the cheapest cast that finishes it,
## else the strongest, else a claw (World.CLAW); one tail grows back every
## TAIL_REGROW rounds.
func _rounds(ladder: Array, hp: int, tails: int) -> Array:
	var left := hp
	var rounds := 0
	var spent := 0
	var regrow := 0
	while left > 0 and rounds < 200:
		rounds += 1
		var pick := 0
		for n in range(1, mini(tails, ladder.size() - 1) + 1):
			if ladder[n].one >= left:
				pick = n
				break
		if pick == 0 and tails > 0:
			pick = mini(tails, ladder.size() - 1)
		var dealt: int = ladder[pick].one if pick > 0 else 0
		if dealt <= 0:
			dealt = World.CLAW
			pick = 0
		left -= dealt
		tails -= pick
		spent += pick
		regrow += 1
		if regrow >= World.TAIL_REGROW:
			regrow = 0
			tails = mini(tails + 1, ladder.size() - 1)
	return [rounds, spent]


func _kill_tables() -> void:
	_say("## Miho's strongest cast against each creature, by depth\n")
	_say("Casts cost at most max_tails, from the talismans held on arrival.")
	_say("- cast: hp off one creature in the cast round, and the best spell for it.")
	_say(
		(
			"- +burn: the best over the cast round and %d rounds after it (fire, hot ground, gas)."
			% AFTER
		)
	)
	_say("- x3: hp off three creatures standing together, the best of a row across the cast and")
	_say("  a row along it, at 1 and 4 tiles, in the cast round.")
	_say("- per tail: best cast harm / cost over every cost up to max_tails (cost in brackets).")
	_say("- one-shot: fewest tails of one cast that kills a creature at full hp.")
	_say("- rounds (tails): rounds to kill by casting the cheapest spell that finishes it, else")
	_say(
		(
			"  the strongest; %d tail back every %d rounds; a claw does %d. Cast-round harm only."
			% [1, World.TAIL_REGROW, World.CLAW]
		)
	)
	_say("")
	_say("| depth | tails | kind | hp | cast | +burn | x3 | per tail | one-shot | rounds (tails) |")
	_say("|---|---|---|---|---|---|---|---|---|---|")
	for depth in range(1, World.FLOORS + 1):
		var held := _held(depth)
		var t := _max_tails(depth)
		for kind in _kinds(depth):
			var hp := Bestiary.hp(kind, Bestiary.rank(_tier(depth)))
			var ladder := _ladder(held, kind, t)
			var top: Dictionary = ladder[t]
			var ratio := 0.0
			var ratio_at := 0
			for n in range(1, t + 1):
				if float(ladder[n].one) / n > ratio:
					ratio = float(ladder[n].one) / n
					ratio_at = n
			var shot := _one_shot(ladder, hp, "one")
			var rk := _rounds(ladder, hp, t)
			_say(
				(
					"| %d | %d | %s | %d | %d %s | %d %s | %d | %.2f (%d) | %s | %d (%d) |"
					% [
						depth,
						t,
						Bestiary.info(kind).name,
						hp,
						top.one,
						top.one_spell,
						top.after,
						top.after_spell,
						top.three,
						ratio,
						ratio_at,
						str(shot) if shot > 0 else "-",
						rk[0],
						rk[1],
					]
				)
			)
	_say("")


func _say(line: String) -> void:
	print(line)
