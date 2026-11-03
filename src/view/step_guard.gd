class_name StepGuard
extends RefCounted
## What keeps Miho from losing a run or walking into harm by accident. A step
## onto a plate she has found, onto fire or off an edge asks first: the prompt
## waits in `asking` (the direction) until the same direction again, or Y, makes
## the step; anything else cancels it. A held key never steps there. A held
## direction key also stops once a creature is in sight that was not when the key
## went down (`sighted`). A 둔갑 cast before a creature it would not fool asks too:
## the prompt waits in `casting` (the spells) until the self key again, or Y, casts
## them. This is view state: a prompt takes no turn and is not in the save.

## What is asked before a 둔갑 a creature would see through.
const WATCHED := "{0} 눈앞에서 {1}할까?"

## The direction a step waits to be confirmed in, or zero.
var asking := Vector2i.ZERO
## The spells a cast waits to be confirmed with, or none.
var casting := []
## Ids of the creatures in sight at the last fresh key press.
var sighted := {}
## The key that last answered the prompt: its repeats do nothing.
var answered := KEY_NONE


## Whether stepping `d`, forecast as `f`, is onto a found plate, fire she sees or a
## drop. A plate asks whatever the forecast says: the round of the step shows no
## harm from a fire or vine plate, and an alarm plate harms nobody.
static func danger(w: World, d: Vector2i, f: Forecast) -> bool:
	if f == null:
		return false
	var to := w.player().pos + d
	var foe := w.actor_at(to)
	if foe != null and foe.faction != w.player().faction and Hat.shown(w, foe):
		return false
	var burns := w.seen[Grid.index(to)] == 1 and w.burning.has(to)
	return f.drops_me() or burns or Tiles.of(w.tile(to), "trap")


## How a key press `action` answers the prompt: &"yes", &"no", &"ignore" for one
## that does nothing, or &"" when it is no answer and goes on as usual. Y and N
## answer whatever their move keys mean; the prompt's own direction goes on and
## steps; a bare modifier leaves the prompt up.
func reply(event: InputEventKey, action: StringName) -> StringName:
	if event.is_echo():
		return &"ignore" if asked() or event.keycode == answered else &""
	answered = KEY_NONE
	if not asked():
		return &""
	if event.keycode in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
		return &"ignore"
	if event.keycode != KEY_Y and event.keycode != KEY_N and answers(action):
		return &""
	answered = event.keycode
	return &"yes" if event.keycode == KEY_Y else &"no"


## Whether a prompt is up.
func asked() -> bool:
	return asking != Vector2i.ZERO or not casting.is_empty()


## Takes the prompt down.
func drop() -> void:
	asking = Vector2i.ZERO
	casting = []


## Whether `action` is the prompt's own key, which goes on with what it asks about.
func answers(action: StringName) -> bool:
	return Keys.MOVES.get(action) == asking or action == &"self" and not casting.is_empty()


## Goes on with what the prompt of the game `m` asks about.
func go(m: Node) -> void:
	if casting.is_empty():
		m.move(asking)
	else:
		m.act({t = &"cast", spells = casting})


## Asks `line` (runs) over the log of the game `m`.
static func ask(m: Node, line: Array) -> void:
	m.show_log()
	m.term.log_lines.append([line, 1.0])
	m.sfx.play(&"warn")


## Whether the action waits on a prompt, now up: a 둔갑 cast that a creature she
## knows of would see through (Guise.watcher).
func holds_back(m: Node, action: Dictionary) -> bool:
	if action.t != &"cast" or action.spells == casting:
		return false
	var foe := Guise.watcher(m.known, action.spells)
	if foe == null:
		return false
	casting = action.spells
	var args := [[foe.info().name, Palette.KIND[foe.kind]], [Guise.NAME[Guise.GUISE], Palette.TEXT]]
	var line := Lang.runs(WATCHED, args, Palette.TEXT)
	ask(m, line if m.touch.enabled else line + [[" Y/N", Palette.TEXT]])
	return true


## What is asked before stepping `d`; the keys answer it unless `touch`.
static func question(w: World, d: Vector2i, touch: bool) -> String:
	var to := w.player().pos + d
	var name := Lang.t("불타는 칸" if w.burning.has(to) else Tiles.of(w.tile(to), "name"))
	var text := Lang.t("%s 갈까?") % toward(name)
	return text if touch else text + " Y/N"


## `word` with 로 after a vowel or ㄹ, else 으로; the word alone in another language.
static func toward(word: String) -> String:
	if Lang.active() != &"ko":
		return word
	var c := word.unicode_at(word.length() - 1) - 0xAC00
	return word + ("로" if c % 28 in [0, 8] else "으로")  # i18n: keep


## Whether a creature is in sight that was not at the last fresh key press.
func startled(w: World) -> bool:
	return Travel.in_sight(w).keys().any(func(id): return not sighted.has(id))
