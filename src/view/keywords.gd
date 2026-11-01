class_name Keywords
extends RefCounted
## One rule that colours a word by what it means, for every screen that writes
## text: the hover, the 도감, the sidebar and the log all pass their runs
## through it. A run is [text, Color] and may carry a background Color and, in a
## panel row, the column it starts at. 인화성 is red on yellow, 가연성 orange, a
## status that harms its holder BAD and one that helps it GOOD. A word is
## coloured only whole, never as part of a longer one. A run with a colour of
## its own is left as it is, unless it is nothing but such a word. It is also the
## list of the words that have an entry in the 도감 (`terms`), which WordHover
## shows where the pointer is over one.

## Conditions besides Status.NAME that harm their holder, and those that help it.
const HARM := ["묶임", "기절", "눈멂"]
const BOON := ["둔갑"]

static var _words := _table()
## Finds the words of `terms`, made on first use.
static var _found: RegEx
static var _find := RegEx.create_from_string(
	"(?<![가-힣A-Za-z0-9])(%s)(?![가-힣A-Za-z0-9])" % "|".join(PackedStringArray(_words.keys()))
)


## word -> [text colour] or [text colour, background colour].
static func _table() -> Dictionary:
	var out := {"인화성": [Palette.FIERCE_TEXT, Palette.FIERCE_BACK], "가연성": [Palette.FLAMMABLE]}
	for word: String in Status.NAME.values() + HARM:
		out[word] = [Palette.BAD]
	for word: String in BOON:
		out[word] = [Palette.GOOD]
	return out


## `text` as runs of `base` colour with each known word in its own.
static func runs(text: String, base: Color) -> Array:
	var out := []
	var at := 0
	for m in _find.search_all(text):
		if m.get_start() > at:
			out.append([text.substr(at, m.get_start() - at), base])
		out.append([m.get_string()] + _words[m.get_string()])
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
		elif _words.has(run[0]):
			parts = [[run[0]] + _words[run[0]]]
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


## The words that have an entry of their own in the 도감: its glossary's terms,
## the conditions and the statuses; a new glossary term is a word with no other
## change here.
static func terms() -> Array:
	var out: Array = Info.glossary().keys() + Info.CONDITIONS.keys() + Status.NAME.values()
	out.sort_custom(func(a: String, b: String): return a.length() > b.length())
	return out


## The 도감 entry of `word` as hover lines, or none for a word without one.
static func entry(word: String) -> Array:
	if Info.glossary().has(word):
		return Info.term_facts(word)
	if Info.CONDITIONS.has(word):
		return Info.condition_facts(word)
	var key: Variant = Status.NAME.find_key(word)
	return [] if key == null else Info.status_facts(key)


## The entry of the word under column `col` (in cells) of a row of `runs` that
## starts at column `x`, or none.
static func entry_at(row: Array, x: float, col: float) -> Array:
	var text := ""
	var starts := PackedFloat32Array()
	for run: Array in row:
		x = column(run, x)
		for c in run[0]:
			starts.append(x)
			x += Term._cells(c)
			text += c
	starts.append(x)
	if _found == null:
		_found = RegEx.create_from_string(
			"(?<![가-힣A-Za-z0-9])(%s)(?![가-힣A-Za-z0-9])" % "|".join(PackedStringArray(terms()))
		)
	for m in _found.search_all(text):
		if col >= starts[m.get_start()] and col < starts[m.get_end()]:
			return entry(m.get_string())
	return []
