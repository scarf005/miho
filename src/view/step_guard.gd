class_name StepGuard
extends RefCounted
## What keeps Miho from losing a run or walking into harm by accident. A step
## onto a plate she has found, onto fire or off an edge asks first: the prompt
## waits in `asking` (the direction) until the same direction again, or Y, makes
## the step; anything else cancels it. A held key never steps there. A held
## direction key also stops once a creature is in sight that was not when the key
## went down (`sighted`). This is view state: a prompt takes no turn and is not
## in the save.

## The direction a step waits to be confirmed in, or zero.
var asking := Vector2i.ZERO
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
	if foe != null and Hat.shown(w, foe):
		return false
	var burns := w.seen[Grid.index(to)] == 1 and w.burning.has(to)
	return f.drops_me() or burns or Tiles.of(w.tile(to), "trap")


## How a key press `action` answers the prompt: &"yes", &"no", &"ignore" for one
## that does nothing, or &"" when it is no answer and goes on as usual. Y and N
## answer whatever their move keys mean; the prompt's own direction goes on and
## steps; a bare modifier leaves the prompt up.
func reply(event: InputEventKey, action: StringName) -> StringName:
	if event.is_echo():
		return &"ignore" if asking != Vector2i.ZERO or event.keycode == answered else &""
	answered = KEY_NONE
	if asking == Vector2i.ZERO:
		return &""
	if event.keycode in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
		return &"ignore"
	if event.keycode != KEY_Y and event.keycode != KEY_N and Keys.MOVES.get(action) == asking:
		return &""
	answered = event.keycode
	return &"yes" if event.keycode == KEY_Y else &"no"


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
