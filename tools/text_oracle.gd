extends SceneTree
## Holds the text of the game to one result across a change of how it is built. It prints one
## line per group, `<language>.<group> <sha256>`, and a last line `all <sha256>`, in Korean and
## in English: SpellInfo.spell of every spell the talismans queue (1 to 3 cards in every order,
## 4 and 5 as a set), SpellInfo.compound, every tab and rank of the 도감, the glossary, and Info
## of every tile kind and every creature kind, the creature hover in every state that
## text_oracle_cases.gd sets (resting, searching, held, burning, in or out of sight), and the log
## lines of every kind of event. Lines are hashed with their colours. A group that
## differs shows by its name. docs/plan-ecs.md describes tools/oracle.gd, its sibling.
## godot --headless --path . -s tools/text_oracle.gd -- [--record]
## --record also writes tools/text_oracle.expected.

const Cases := preload("res://tools/text_oracle_cases.gd")
const EXPECTED := "res://tools/text_oracle.expected"
const SEED := 7
## The most cards of a spell the talismans queue in every order; longer ones are sets.
const ORDERED := 3

var _failed := false
var _digests: Array[String] = []


func _init() -> void:
	var args := Array(OS.get_cmdline_user_args())
	for code in [&"ko", &"en"]:
		_language(code)
	TranslationServer.set_locale("ko")
	Lang.use(&"ko")
	if _failed:
		quit(1)
		return
	var all := HashingContext.new()
	all.start(HashingContext.HASH_SHA256)
	for line in _digests:
		print(line)
		all.update((line + "\n").to_utf8_buffer())
	var last := "all %s" % all.finish().hex_encode()
	print(last)
	if args.has("--record"):
		var f := FileAccess.open(EXPECTED, FileAccess.WRITE)
		f.store_string("\n".join(_digests) + "\n" + last + "\n")
	quit(0)


## Hashes every group in the language `code`.
func _language(code: StringName) -> void:
	TranslationServer.set_locale(code)
	Lang.use(code)
	if Lang.active() != code:
		_fail("the language %s did not take" % code)
		return
	for n in range(1, Spell.MAX_SLOTS + 1):
		_group(code, "spell%d" % n, _picks(n, n > ORDERED).map(_spell_of))
	_group(
		code,
		"compound",
		Cards.compounds().map(func(c): return [c, SpellInfo.compound(c), SpellInfo.combo(c)])
	)
	for tab in Codex.TABS.size():
		for rank in range(1, Bestiary.RANKS + 1):
			_group(code, "codex%d.%d" % [tab, rank], Codex.entries(tab, rank).map(_entry))
	_group(code, "glossary", [Glossary.rows()])
	_group(code, "tiles", Tiles.ROWS.keys().map(_tile))
	var kinds := Bestiary.KINDS.keys().filter(func(k): return Bestiary.HEALTH.has(k))
	_group(code, "creatures", [&"miho"] + kinds, _creature)
	_group(code, "situations", [&"miho"] + kinds, _situations)
	_group(code, "log", _log(kinds))


## Every queue of `n` talismans; for a set, one canonical order of each multiset.
func _picks(n: int, as_set: bool, from := 0) -> Array:
	if n == 0:
		return [[]]
	var out := []
	for i in range(from if as_set else 0, Cards.ALL.size()):
		for rest in _picks(n - 1, as_set, i):
			out.append([Cards.ALL[i]] + rest)
	return out


## The spell `pick` queues with its lines, or the pick alone when it queues none.
func _spell_of(pick: Array) -> Array:
	var s := Spell.make(pick)
	return [pick, null if s == null else [s.key(), s.shown(), SpellInfo.spell(s)]]


## A 도감 entry as data: the look, the name, the lines and the rest of its plain fields.
func _entry(e: Dictionary) -> Array:
	return [e.glyph, e.color, e.name, Codex.detail(e)]


## The hover over each way a tile of kind `t` lies, and its notes.
func _tile(t: int) -> Array:
	var w := Codex.stage()
	w.set_tile(Codex.AT, t)
	w.sense()
	var notes := []
	for flags in 8:
		notes.append(Info._notes(t, flags & 1 != 0, flags & 2 != 0, flags & 4 != 0))
	return [t, Info.terrain_facts(w, Codex.AT), Info.terrain(w, Codex.AT), notes]


## The hover over a creature of `kind`, beside Miho on the storey of a fixed seed.
func _creature(kind: StringName) -> Array:
	var w := Cases.world(SEED)
	if kind == &"miho":
		return [kind, Info.creature(w, w.player())]
	var at := w.player().pos + Vector2i(1, 0)
	w.set_tile(at, World.FLOOR)
	var a := FloorGen.spawn(w, kind, at)
	w.sense()
	return [kind, Info.creature(w, a), Info.creature_facts(a, [])]


## The hover over a creature of `kind` in each state of Cases.states, with how it is doing.
func _situations(kind: StringName) -> Array:
	var stood := Cases.stand(SEED, kind)
	var out := [kind]
	var states := Cases.states()
	for name in states:
		var w: World = stood[0].clone()
		var a := w.actor(stood[1])
		states[name].call(w, a)
		w.sense()
		out.append([name, Info.creature(w, a), Info.state(a), Info.doing(w, a)])
	return out


## The log lines of every fact of Cases.events, of the fire at each kind of tile, of what Miho
## spots and of a tail grown, each rendered by itself.
func _log(kinds: Array) -> Array:
	var before := World.create(SEED)
	var at := before.player().pos + Vector2i.RIGHT
	before.set_tile(at, World.FLOOR)
	var ids := {}
	for kind in kinds:
		ids[kind] = FloorGen.spawn(before, kind, at).id
	before.sense()
	var after := before.clone()
	after.sense()
	var told := func(w: World, facts: Array, spotted := []):
		return Messages._render(before, w, {facts = facts, spotted = spotted})
	var out := []
	for facts in Cases.events(ids, after.player().id):
		out.append(told.call(after, facts))
	var kept := before.clone()
	for tile in Tiles.ROWS:
		kept.set_tile(at, tile)
		for facts in Cases.fires(at):
			out.append(Messages._render(kept, after, {facts = facts, spotted = []}))
		out.append(Messages._spotted(kept, at))
	for c in Cards.ALL:
		kept.sites.append({kind = &"scroll", at = at, card = c})
		out.append(Messages._spotted(kept, at))
		kept.sites.clear()
	for spot in [func(w): w.stairs = at, func(w): w.elixir = at, func(w): w.peaches.append(at)]:
		spot.call(kept)
		out.append(Messages._spotted(kept, at))
		kept = before.clone()
	kept.sites.append({kind = Jars.KIMCHI, at = at})
	out.append(Messages._spotted(kept, at))
	after.tail_bonus += 1
	out.append(told.call(after, []))
	return out


func _group(code: StringName, name: String, data: Array, each := Callable()) -> void:
	var rows := data if each.is_null() else data.map(each)
	_digests.append("%s.%s %s" % [code, name, _sha(rows)])


func _sha(v: Variant) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(var_to_bytes(_plain(v)))
	return ctx.finish().hex_encode()


## `v` as plain data: a table is its pairs in iteration order; an object or a callable fails.
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
	if v is Object or v is Callable:
		_fail("%s is not plain data" % str(v))
		return null
	return v


func _fail(why: String) -> void:
	_failed = true
	printerr("error: " + why)
