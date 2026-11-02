class_name Keywords
extends RefCounted
## One rule that colours a word by what it means, for every screen that writes
## text: the hover, the 도감, the sidebar and the log all pass their runs
## through it. A run is [text, Color] and may carry a background Color and, in a
## panel row, the column it starts at. 인화성 is red on yellow, 가연성 orange, a
## status that harms its holder BAD and one that helps it GOOD. A word is
## coloured only whole, never as part of a longer one. A run with a colour of
## its own is left as it is, unless it is nothing but such a word. It is also the
## list of the names that have an entry in the 도감 (`terms`), of every tab,
## which WordHover shows and links where the pointer is over one. Such a name is
## found whole, or with a particle after it; inside a longer word it is not.

## Conditions besides Status.NAME that harm their holder, and those that help it.
const HARM := [
	"묶임", "기절", "눈멂", Curse.NAME[Curse.REAPER], Curse.NAME[Curse.SIGHT], Curse.NAME[Curse.BODY]
]
const BOON := [
	Guise.NAME[Guise.GUISE],
	Guise.NAME[Guise.TALON],
	Guise.NAME[Guise.CLOAK],
	Guise.NAME[Guise.FLAME],
	Guise.NAME[Guise.RAISE]
]
## Particles that may follow a name, which stays a link: 진흙이, 풀을.
const PARTICLES := "이|가|을|를|은|는|의|에서|에게|에|으로|로|과|와|도|만|까지|부터|처럼|이다"  # i18n: keep
## The tabs in the order their names win: a name that is a rule or a state means
## that, before a feature of the floor or a spell of the same name.
const TAB_ORDER := [6, 5, 4, 3, 2, 1, 0]

## language -> {words: shown word -> colours, find: the RegEx for them}, made
## when first needed.
static var _tables := {}
## language -> what the 도감 lists (_entries), and the last entry looked up as
## [language, (tab, index), lines], which a pointer over one word asks for again.
static var _listed := {}
static var _last := []


## The Korean word -> [text colour] or [text colour, background colour].
static func _table() -> Dictionary:
	var out := {"인화성": [Palette.FIERCE_TEXT, Palette.FIERCE_BACK], "가연성": [Palette.FLAMMABLE]}
	for word: String in Status.NAME.values() + HARM:
		out[word] = [Palette.BAD]
	for word: String in BOON:
		out[word] = [Palette.GOOD]
	return out


## The words and the pattern that finds them in the language shown.
static func _for() -> Dictionary:
	var code := Lang.active()
	if not _tables.has(code):
		var words := {}
		var table := _table()
		for word: String in table:
			words[_key(Lang.t(word))] = table[word]
		_tables[code] = {words = words, find = _regex(words.keys())}
	return _tables[code]


## The RegEx that finds the whole words `words`, longest first. English words
## match in any case.
static func _regex(words: Array, particles := "") -> RegEx:
	var keys := words.duplicate()
	keys.sort_custom(func(a: String, b: String): return a.length() > b.length())
	var edge := "[가-힣A-Za-z0-9]"  # i18n: keep
	var after := "" if particles == "" else "(?:%s)?" % particles
	var find := "(?<!%s)(%s)%s(?!%s)" % [edge, "|".join(PackedStringArray(keys)), after, edge]
	return RegEx.create_from_string(("" if Lang.active() == &"ko" else "(?i)") + find)


static func _key(word: String) -> String:
	return word if Lang.active() == &"ko" else word.to_lower()


## `text` as runs of `base` colour with each known word in its own.
static func runs(text: String, base: Color) -> Array:
	var out := []
	var at := 0
	var shown := _for()
	for m in shown.find.search_all(text):
		if m.get_start() > at:
			out.append([text.substr(at, m.get_start() - at), base])
		out.append([m.get_string()] + shown.words[_key(m.get_string())])
		at = m.get_end()
	if at < text.length() or out.is_empty():
		out.append([text.substr(at), base])
	return out


## One line's runs with the known words coloured.
static func paint(line: Array) -> Array:
	var out := []
	for run: Array in line:
		var plain: bool = run[1] == Palette.TEXT or run[1] == Palette.DIM
		var parts := []
		if plain:
			parts = runs(run[0], run[1])
		elif _for().words.has(_key(run[0])):
			parts = [[run[0]] + _for().words[_key(run[0])]]
		if parts.is_empty():
			out.append(run)
			continue
		parts[0] = parts[0] + run.slice(2).filter(func(v): return v is float or v is int)
		out.append_array(parts)
	return out


## Lines of runs with the known words coloured.
static func lines(rows: Array) -> Array:
	return rows.map(paint)


## A panel (Term.panel) with the words in its rows, detail and aside coloured.
## Rows already `painted` stay as they are: a log is thousands long.
static func panel(shown: Dictionary) -> Dictionary:
	var out := shown.duplicate()
	for key: String in ["rows", "detail", "aside"]:
		if out.has(key) and not (key == "rows" and out.get("painted", false)):
			out[key] = lines(out[key])
	return out


## The background of a run, or a clear colour for none.
static func back(run: Array) -> Color:
	var colors := run.slice(2).filter(func(v): return v is Color)
	return colors[0] if not colors.is_empty() else Color(0, 0, 0, 0)


## The column a run starts at in a panel row, else `x`, where the last one ended.
static func column(run: Array, x: float) -> float:
	var at := run.slice(2).filter(func(v): return v is float or v is int)
	return at[0] if not at.is_empty() else x


## The part `text` of `run`: its colours, not its column.
static func piece(run: Array, text: String, color: Variant = null) -> Array:
	return (
		[text, run[1] if color == null else color] + run.slice(2).filter(func(v): return v is Color)
	)


## The names that have an entry of their own in the 도감, in the language
## shown, longest first: every entry of every tab (Codex.entries), so a new
## entry is a word with no other change here.
static func terms() -> Array:
	return _entries().names.keys()


## What the 도감 lists, made on first use in each language: the entries of each
## tab, name -> where it is as (tab, index), and the RegEx that finds the names
## whole, or with a particle after them, in a text.
static func _entries() -> Dictionary:
	var code := Lang.active()
	if not _listed.has(code):
		var tabs := {}
		var at := {}
		for tab: int in TAB_ORDER:
			tabs[tab] = Codex.entries(tab)
			for k in tabs[tab].size():
				var key := _key(tabs[tab][k].name)
				if not at.has(key):
					at[key] = Vector2i(tab, k)
		for i in Info.WITS.size():
			at[_key(Lang.t(Info.WITS_WHO[i]))] = at[_key(Lang.t(Info.WITS[i]))]
		var names := at.keys()
		names.sort_custom(func(a: String, b: String): return a.length() > b.length())
		var sorted := {}
		for name: String in names:
			sorted[name] = at[name]
		var particles := PARTICLES if code == &"ko" else ""
		_listed[code] = {tabs = tabs, names = sorted, find = _regex(names.map(_escape), particles)}
	return _listed[code]


static func _escape(name: String) -> String:
	for c in "\\.^$*+?()[]{}|":
		name = name.replace(c, "\\" + c)
	return name


## Where the entry of `word` is, as (tab, index), or (-1, -1).
static func locate(word: String) -> Vector2i:
	return _entries().names.get(_key(word), Vector2i(-1, -1))


## The 도감 entry of `word` as hover lines, or none for a word without one.
static func entry(word: String) -> Array:
	var at := locate(word)
	if at.x < 0:
		return []
	var code := Lang.active()
	if _last.size() == 3 and _last[0] == code and _last[1] == at:
		return _last[2]
	_last = [code, at, Codex.detail(_entries().tabs[at.x][at.y])]
	return _last[2]


## The word under column `col` (in cells) of a row of `runs` that starts at
## column `x`, or empty.
static func word_at(row: Array, x: float, col: float) -> String:
	var text := ""
	var starts := PackedFloat32Array()
	for run: Array in row:
		x = column(run, x)
		for c in run[0]:
			starts.append(x)
			x += Term._cells(c)
			text += c
	starts.append(x)
	for m in _entries().find.search_all(text):
		if col >= starts[m.get_start(1)] and col < starts[m.get_end(1)]:
			return _key(m.get_string(1))
	return ""


## The entry of the word under column `col` of a row, or none.
static func entry_at(row: Array, x: float, col: float) -> Array:
	return entry(word_at(row, x, col))


## Coloured runs broken into rows no wider than `width` cells, at the spaces;
## a word wider than that takes a row of its own.
static func rows_of(runs: Array, width: float) -> Array:
	var out := [[]]
	var x := 0.0
	for run: Array in runs:
		if x + Term._cells(run[0]) <= width:
			out[-1].append(run)
			x += Term._cells(run[0])
			continue
		var words: PackedStringArray = run[0].split(" ")
		for i in words.size():
			var word: String = (" " if i > 0 else "") + words[i]
			if x > 0.0 and x + Term._cells(word) > width:
				out.append([])
				x = 0.0
				word = word.lstrip(" ")
			if word != "":
				out[-1].append(piece(run, word))
				x += Term._cells(word)
	return out
