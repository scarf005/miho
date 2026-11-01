class_name Banner
extends RefCounted
## The lines over the map when a run ends.

## The line holding the seed, which a click copies.
const SEED := 3
## Puts text on the clipboard; a test swaps it, since a headless run has none.
static var clipboard := DisplayServer.clipboard_set


## The lines of a run that ended in `w` with `kills` creatures put down.
static func over(w: World, kills: int, seed_value: int) -> Array[String]:
	var again: String = (Keys.keys_of(&"restart").map(Keys.label) + ["R"])[0]
	return [
		"사람이 되었다" if w.outcome == &"won" else "쓰러졌다",
		"%d층 · %d초" % [w.depth, w.round_no],
		"처치 %d" % kills,
		seed_line(seed_value, false),
		"%s키를 눌러 재시작" % again,
	]


static func seed_line(seed_value: int, copied: bool) -> String:
	return "시드 %d 복사했다" % seed_value if copied else "시드 %d" % seed_value


## Copies the seed; a banner showing it says so.
static func copy(seed_value: int, t: Term) -> void:
	clipboard.call(str(seed_value))
	if t.banner_lines.size() > SEED:
		t.banner_lines[SEED] = seed_line(seed_value, true)
