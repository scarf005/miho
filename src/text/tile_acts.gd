class_name TileActs
extends RefCounted
## What is done to a tile, gas or fire in the 도감: read off by doing it to one on the
## stand-in floor (Codex.stage), so a change to a rule moves the text. The hover does not
## tell these; it is what stands there now.

## The tiles whose own notes tell what a hit does to them (Info._notes).
const HIT_TOLD := [World.SCREEN, World.JAR, World.CENSER, World.DRUM]
const AT := Codex.AT

## What has been read off, by language and by what was asked.
static var _read := {}


## What is done to tile kind `t`, each what it leaves on a line with all that leave it.
static func lines(t: int) -> Array:
	return _once(["tile", t], _tile.bind(t))


## What fire does on any tile, and what puts it out.
static func fire() -> Array:
	return _once(["fire"], _fire)


## The spells that lay gas `kind`, a line or none.
static func gas(kind: int) -> Array:
	return _once(["gas", kind], _gas.bind(kind))


## The lines a jar's entry adds: each thing it can hold with its chance (Jars.chances)
## and what it does.
static func jar() -> Array:
	var curses: Array = Curse.NAME.values().map(func(n): return Lang.t(n))
	var does := {
		&"empty": "",
		&"water":
		(
			Lang.t(", 주위 %d칸 %s, 불과 냄새 지움")
			% [Grid.DIRS.size(), Lang.t(Tiles.of(World.SHALLOW, "name"))]
		),
		Jars.KIMCHI: Lang.t(", 체력 +%d") % World.HEAL,
		&"effigy": Lang.t(", 무작위 저주: %s") % ", ".join(curses),
		&"scarecrow": Lang.t(", 보는 적이 이 칸 수색"),
		&"salt": Lang.t(", 냄새 지움"),
		&"beans": Lang.t(", 주위 %d칸 적 기절 %d초") % [Grid.DIRS.size(), Jars.BEANS_STUN],
		&"coals":
		(
			Lang.t(", 이 칸과 옆 %d칸 %s")
			% [Placement.SIDES.size(), Lang.t(Compounds.HOT[Compounds.LAVA].name)]
		),
	}
	var chances := Jars.chances()
	var out := []
	for k in Jars.ROWS.size():
		var row: Dictionary = Jars.ROWS[k]
		out.append(
			[[Lang.t("%s: %d%%%s") % [Lang.t(row.name), chances[k], does[row.id]], Palette.DIM]]
		)
	return out


## The rows of the tag every tile with what bare floor takes shows.
static func ground() -> Array:
	return _once(["ground"], func(): return _rows(_once(["bare"], _bare)))


static func _once(key: Array, read: Callable) -> Variant:
	var at := [Lang.active()] + key
	if not _read.has(at):
		_read[at] = read.call()
	return _read[at]


static func _bare() -> Dictionary:
	return _changes(World.FLOOR, _spells())


static func _tile(t: int) -> Array:
	var deeds := _elements() + _water() + ([] if t in HIT_TOLD else _hits()) + _spells()
	var rows := _changes(t, deeds)
	var bare: Dictionary = _once(["bare"], _bare)
	var out := []
	if bare.keys().all(func(to): return _holds(rows, to, bare[to])):
		out.append(Lang.t("땅."))
		for to: String in bare:
			rows[to] = rows[to].filter(func(label): return label not in bare[to])
	out.append_array(_rows(rows))
	var left := _burnt(t)
	if left != Tiles.DEFAULT.burns_to:
		out.append(Lang.t("불탄 뒤: %s") % Lang.t(Tiles.of(left, "name")))
	return out.map(func(line): return [[line, Palette.DIM]])


static func _fire() -> Array:
	var out := []
	var doused := []
	for deed: Array in _water() + _spells():
		var w := Codex.stage()
		w.burning[AT] = World.BURN_ROUNDS
		deed[1].call(w)
		if not w.burning.has(AT) and deed.size() < 3:
			doused.append(deed[0])
	out.append([[Lang.t("뿜는 기체: "), Palette.DIM], _gas_name(Gas.SMOKE)])
	out.append([["%s: %s" % [", ".join(doused), Lang.t("꺼짐")], Palette.DIM]])
	return out


static func _gas(kind: int) -> Array:
	var makers := []
	for deed: Array in _spells():
		var w := Codex.stage()
		deed[1].call(w)
		if Gas.at(w, AT).x == kind:
			makers.append(deed[0])
	if makers.is_empty():
		return []
	return [[[Lang.t("만드는 주문: %s") % ", ".join(makers), Palette.DIM]]]


static func _gas_name(kind: int) -> Array:
	return [Lang.t(Gas.of(kind, "name")), Palette.GAS[kind][1]]


## Whether `rows` holds under what is left `to` all of `labels`.
static func _holds(rows: Dictionary, to: String, labels: Array) -> bool:
	return rows.has(to) and labels.all(func(label): return label in rows[to])


static func _rows(rows: Dictionary) -> Array:
	var out := []
	for to: String in rows:
		if not rows[to].is_empty():
			out.append("%s: %s" % [", ".join(rows[to]), SpellInfo.turned(to)])
	return out


## What each deed leaves of tile kind `t`: a name -> the labels of the deeds that leave
## it. A deed with a third field is left out where the deed of that label leaves the same.
static func _changes(t: int, deeds: Array) -> Dictionary:
	var out := {}
	for deed: Array in deeds:
		var w := Codex.stage()
		w.set_tile(AT, t)
		deed[1].call(w)
		var left := _left(w, t)
		if left != "" and (deed.size() < 3 or deed[2] not in out.get(left, [])):
			out.get_or_add(left, []).append(deed[0])
	return out


## The name of what lies at AT, were it tile kind `t` before: "" for no change.
static func _left(w: World, t: int) -> String:
	if w.tile(AT) != t:
		return Tiles.of(w.tile(AT), "name")
	return Compounds.HOT[w.hot[AT].x].name if w.hot.has(AT) else ""


## What is left of tile kind `t` once its fire is out.
static func _burnt(t: int) -> int:
	if Tiles.burns[t] == 0:
		return Tiles.DEFAULT.burns_to
	var w := Codex.stage()
	w.set_tile(AT, t)
	w.burning[AT] = 1
	Terrain.burn(w, [])
	return w.tile(AT)


## The lone elements but water on the tile, by its `reacts` row.
static func _elements() -> Array:
	var out := []
	for e: StringName in Cards.ELEMENTS:
		if e != Cards.WATER:
			var at: Array[Vector2i] = [AT]
			var deed := func(w): Terrain.react(w, Spell.make([e]), at)
			out.append([Lang.t("%s 주문") % Lang.t(Cards.NAME[e]), deed])
	return out


## The deeds of water, as [label, what it does to a World]. A third field is the label
## of a deed that tells this one wherever both leave the same.
static func _water() -> Array:
	var spell := Lang.t("%s 주문") % Lang.t(Cards.NAME[Cards.WATER])
	var none := Vector2i(-1, -1)
	var orb := func(w): Terrain.touch(w, _shot(w, [Cards.ORB, Cards.WATER]), AT, none)
	var spray := func(w): Terrain.touch(w, _shot(w, [Cards.WATER]), AT, none)
	return [[spell, spray], [_orb(Cards.WATER), orb, spell]]


## The deeds of a blow: an orb and walking into it.
static func _hits() -> Array:
	var plain := Lang.t(Spell.SHAPE_NAME[Spell.ORB])
	var out := [[plain, _smash.bind([Cards.ORB])]]
	for c in [Cards.EARTH, Cards.METAL]:
		out.append([_orb(c), _smash.bind([Cards.ORB, c]), plain])
	out.append([Lang.t("부딪침"), _knock])
	return out


## The deeds of compounds on the ground.
static func _spells() -> Array:
	var out := []
	for c: StringName in Cards.compounds():
		out.append([Lang.t(Cards.NAME[c]), _lay.bind(c)])
	return out


static func _orb(c: StringName) -> String:
	return "%s %s" % [Lang.t(Cards.NAME[c]), Lang.t(Spell.SHAPE_NAME[Spell.ORB])]


static func _smash(w: World, cards: Array) -> void:
	Terrain.smash(w, _shot(w, cards), AT, w.tile(AT))


static func _knock(w: World) -> void:
	if Terrain.knockable(w.tile(AT)):
		Terrain.knock(w, w.player(), AT)


static func _lay(w: World, c: StringName) -> void:
	var at: Array[Vector2i] = [AT]
	Compounds.ground(w, _shot(w, Cards.COMPOUND[c].made), c, at)


static func _shot(w: World, cards: Array) -> Shot:
	var s := Shot.new()
	s.spell = Spell.make(cards)
	s.caster = w.player().id
	s.pos = AT
	s.dir = Vector2i.RIGHT
	return s
