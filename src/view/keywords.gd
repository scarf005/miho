class_name Keywords
extends RefCounted
## One rule that colours a word by what it means, for every screen that writes
## text: the hover, the 도감, the sidebar and the log all pass their runs
## through it. A run is [text, Color] and may carry a background Color and, in a
## panel row, the column it starts at. 인화성 is red on yellow, 가연성 orange, a
## status that harms its holder BAD and one that helps it GOOD. A word is
## coloured only whole, never as part of a longer one. A run with a colour of
## its own is left as it is, unless it is nothing but such a word.

## Conditions besides Status.NAME that harm their holder, and those that help it.
const HARM := ["묶임", "기절", "눈멂"]
const BOON := ["둔갑"]

## language -> {words: word -> colours, find: the RegEx for them}, made when first needed.
static var _tables := {}


## The Korean word -> [text colour] or [text colour, background colour].
static func _table() -> Dictionary:
	var out := {"인화성": [Palette.FIERCE_TEXT, Palette.FIERCE_BACK], "가연성": [Palette.FLAMMABLE]}
	for word: String in Status.NAME.values() + HARM:
		out[word] = [Palette.BAD]
	for word: String in BOON:
		out[word] = [Palette.GOOD]
	return out


## The words and the pattern that finds them in the language shown. English
## words match in any case.
static func _for() -> Dictionary:
	var code := Lang.active()
	if not _tables.has(code):
		var words := {}
		var table := _table()
		for word: String in table:
			words[_key(Lang.t(word))] = table[word]
		var keys := Array(words.keys())
		keys.sort_custom(func(a: String, b: String): return a.length() > b.length())
		var edge := "[가-힣A-Za-z0-9]"  # i18n: keep
		var find := "(?<!%s)(%s)(?!%s)" % [edge, "|".join(PackedStringArray(keys)), edge]
		_tables[code] = {
			words = words, find = RegEx.create_from_string(("" if code == &"ko" else "(?i)") + find)
		}
	return _tables[code]


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
static func panel(shown: Dictionary) -> Dictionary:
	var out := shown.duplicate()
	for key: String in ["rows", "detail", "aside"]:
		if out.has(key):
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
