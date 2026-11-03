class_name Lang
extends RefCounted
## The language of every string the player reads. The Korean text is the
## message id: `t("피해: %d") % n` shows it as written in Korean and as the
## entry of assets/i18n/*.po in English (Godot's TranslationServer). Translate a
## format string, then format it. Rule code in src/core keeps Korean ids only;
## no comparison, save or rng reads a translated string.

## Language code -> its name, written in that language.
const NAMES := {&"ko": "한국어", &"en": "English"}  # i18n: keep
const FALLBACK := &"en"

## While true every string stays Korean and `use` changes nothing: the tests
## (GUT) read Korean. A test of the language sets it false and back.
static var locked := _testing()
## Renders in this language instead of the active one (Messages keeps a line in
## every language, so that a log follows a language change).
static var forced := &""

static var _slot := RegEx.create_from_string("\\{(\\d)\\}")
static var _particle := RegEx.create_from_string("[가-힣]+/[가-힣]+")  # i18n: keep
static var _one := RegEx.create_from_string("\\b1( more)? (tile|floor|step|time)s\\b")


static func _testing() -> bool:
	return Array(OS.get_cmdline_args()).any(
		func(a: String) -> bool: return a.ends_with("gut_cmdln.gd")
	)


## The language for a player with no choice saved: Korean on a Korean system,
## else English.
static func detect() -> StringName:
	return &"ko" if OS.get_locale_language() == "ko" else FALLBACK


## The language shown now.
static func active() -> StringName:
	if forced != &"":
		return forced
	if locked:
		return &"ko"
	var code := StringName(TranslationServer.get_locale().substr(0, 2))
	return code if NAMES.has(code) else FALLBACK


static func use(code: StringName) -> void:
	if not locked and NAMES.has(code):
		TranslationServer.set_locale(code)


## `msgid` in the language shown; itself when it has no entry. An entry with a
## `context` wins over the one without.
static func t(msgid: String, context := "") -> String:
	if msgid == "":
		return msgid
	if context != "":
		var special := t_in(msgid, context)
		if special != msgid:
			return special
	return t_in(msgid, "")


## The entry of `msgid` under `context` alone.
static func t_in(msgid: String, context: String) -> String:
	if forced == &"":
		return msgid if locked else TranslationServer.translate(msgid, context)
	var table := TranslationServer.get_translation_object(forced)
	var out := table.get_message(msgid, context) if table != null else &""
	return String(out) if out != &"" else msgid


## `closed` after a word ending in a final consonant, else `open`: Korean
## particles. Nothing in another language.
static func particle(word: String, closed: String, open: String) -> String:
	if active() != &"ko":
		return ""
	var c := word.unicode_at(word.length() - 1) if word != "" else 0
	return closed if c >= 0xAC00 and c <= 0xD7A3 and (c - 0xAC00) % 28 != 0 else open


## A sentence as runs: `template` (a message id) in `base` colour with `{0}`,
## `{1}` ... replaced by the runs `args`, whose text is translated. In Korean a
## particle pair right after a placeholder (`{0}이/가`) becomes the one that
## fits the word. In English the player's `{0}'s` is `your`.
static func runs(template: String, args: Array, base: Color) -> Array:
	var text := t(template)
	var out := []
	var at := 0
	for m in _slot.search_all(text):
		_literal(out, text.substr(at, m.get_start() - at), base)
		var arg: Array = args[int(m.get_string(1))].duplicate()
		arg[0] = t(arg[0])
		out.append(arg)
		at = m.get_end()
		if arg[0] == "you" and text.substr(at, 2) == "'s":
			arg[0] = "your"
			at += 2
		var pair := _particle.search(text, at)
		if pair != null and pair.get_start() == at:
			var forms := pair.get_string().split("/")
			_literal(out, particle(arg[0], forms[0], forms[1]), base)
			at = pair.get_end()
	_literal(out, text.substr(at), base)
	return out


static func _literal(out: Array, text: String, base: Color) -> void:
	if text != "":
		out.append([text, base])


## Puts the first letter of the runs in capitals, as an English sentence begins.
static func capitalize(runs: Array) -> void:
	if not runs.is_empty() and runs[0][0] != "":
		runs[0][0] = runs[0][0].left(1).to_upper() + runs[0][0].substr(1)


## `text` with a count of one in the singular: every count in English is written
## in the plural, and only here do a format's value and its unit meet.
static func singular(text: String) -> String:
	return _one.sub(text, "1$1 $2", true) if active() == &"en" else text
