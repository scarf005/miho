class_name CodexSim
extends ExampleSim
## The example beside a 도감 entry or a spell of the spellbook: an ExampleSim over the
## panel, which the panel names (Codex.panel, Menu.panel).

## Cell scales to try, largest first, in the cells of the panel.
const SCALES: Array[float] = [1.0, 0.5]
## Cells of text the detail keeps beside the example; with less, no example.
const LEAST_TEXT := 16.0
## Rows above the example and rows under it that stay clear.
const TOP := 3.0
const FOOT := 1.0

var _entry: Variant = null


## The scale that fits the example, and `under` rows beneath it, on a screen of `room` cells,
## 0.0 when none does.
static func scale_for(room: Vector2i, side := Codex.SIDE_X, under := 0) -> float:
	for k in SCALES:
		var high := CodexScene.VIEW.y * k
		if room.x - beside(k) - side - 1.0 >= LEAST_TEXT and TOP + high + under + FOOT <= room.y:
			return k
	return 0.0


## Cells across that the example at scale `k` takes from the detail, with a gap.
static func beside(k: float) -> float:
	return ceilf(CodexScene.VIEW.x * k) + 1.0


## Where the example fits in the top right corner of a screen of `room` cells at the largest
## scale, clear of every rectangle of text in `texts`: {scale, at}, or empty.
static func corner(room: Vector2i, texts: Array[Rect2]) -> Dictionary:
	for k in SCALES:
		var at := Vector2(room.x - beside(k) + 1.0, TOP)
		var box := Rect2(at, Vector2(CodexScene.VIEW) * k)
		if at.x >= 0.0 and box.end.y + FOOT <= room.y:
			if not texts.any(func(r: Rect2) -> bool: return r.intersects(box)):
				return {scale = k, at = at}
	return {}


func _ready() -> void:
	super()
	get_parent().panel_set.connect(_on_panel)


func _process(delta: float) -> void:
	super(delta)
	visible = not _covered() and _entry != null


func _on_panel(shown: Dictionary) -> void:
	var example: Dictionary = shown.get("example", {})
	if example.is_empty():
		_entry = null
		stop()
		return
	var k: float = example.scale
	scale = Vector2(k, k)
	var corner := Vector2(get_parent().cols - beside(k) + 1.0, TOP)
	position = example.get("at", corner) * CELL
	if example.entry != _entry:
		_entry = example.entry
		show_scene(example.scene, example.rank)


## Whether the box of the word under the pointer, or a box Shift keeps, lies over
## the example.
func _covered() -> bool:
	var t: Term = get_parent()
	var fits := [] if t.pin.is_empty() else [t.pin.fit]
	if not t.hint.is_empty():
		fits.append(t.hint_fit())
	var view := Rect2(position / CELL, Vector2(CodexScene.VIEW) * scale.x)
	return fits.any(
		func(fit: Dictionary) -> bool: return Rect2(fit.at, fit.cells * fit.scale).intersects(view)
	)
