class_name CodexSim
extends Term
## The example beside a 도감 entry: a small Term of its own over the panel, with its
## own World (CodexScene) that plays round after round through Term.play. It has no
## link to the run, the log or the sound. The panel names the entry (Codex.panel).

## Cell scales to try, largest first, in the cells of the panel.
const SCALES: Array[float] = [1.0, 0.5]
## Cells of text the detail keeps beside the example; with less, no example.
const LEAST_TEXT := 16.0
## Rows above the example and rows under it that stay clear.
const TOP := 3.0
const FOOT := 1.0
## Seconds before the first round, after each round, and before starting again.
const START := 0.5
const ROUND := 0.45
const REST := 1.0

var _entry: Variant = null
var _scene := {}
var _rank := 0
var _actions: Array[Dictionary] = []
var _next := 0
var _left := 0.0


## The scale that fits the example on a screen of `room` cells, 0.0 when none does.
static func scale_for(room: Vector2i, side := Codex.SIDE_X) -> float:
	for k in SCALES:
		var high := CodexScene.VIEW.y * k
		if room.x - beside(k) - side - 1.0 >= LEAST_TEXT and TOP + high + FOOT <= room.y:
			return k
	return 0.0


## Cells across that the example at scale `k` takes from the detail, with a gap.
static func beside(k: float) -> float:
	return ceilf(CodexScene.VIEW.x * k) + 1.0


func _ready() -> void:
	cols = CodexScene.VIEW.x
	rows = CodexScene.VIEW.y
	side = Vector2i.ZERO
	foot = 0
	replay = true
	cam = CodexScene.CORNER
	clip_contents = true
	super()
	_stop()
	get_parent().panel_set.connect(_on_panel)


## The camera stays on the hall.
func follow(_p: Vector2i) -> void:
	pass


func _process(delta: float) -> void:
	super(delta)
	visible = not _covered()
	if _animating:
		return
	_left -= delta * speed
	if _left <= 0.0:
		_play_next()


func _on_panel(shown: Dictionary) -> void:
	var example: Dictionary = shown.get("example", {})
	if example.is_empty():
		_stop()
		return
	var k: float = example.scale
	scale = Vector2(k, k)
	position = Vector2(get_parent().cols - beside(k) + 1.0, TOP) * CELL
	if example.entry != _entry:
		_entry = example.entry
		_scene = example.scene
		_rank = example.rank
		_actions = CodexScene.actions(_scene)
		speed = get_parent().speed
		set_process(true)
		visible = true
		_begin()


func _stop() -> void:
	_entry = null
	rush()
	set_process(false)
	visible = false


func _begin() -> void:
	rush()
	_popups.clear()
	_flashes.clear()
	_trails.clear()
	show_world(CodexScene.build(_scene, _rank))
	_next = 0
	_left = START


## The next round of the scene, or the scene again from its start.
func _play_next() -> void:
	if _next >= _actions.size() or not world.can(_actions[_next]):
		_begin()
		return
	var action := _actions[_next]
	_next += 1
	_left = REST if _next == _actions.size() else ROUND
	var before := world.clone()
	play(world.act(action), before, world)


## Whether the box of the word under the pointer lies over the example.
func _covered() -> bool:
	var t: Term = get_parent()
	if t.hint.is_empty():
		return false
	var fit: Dictionary = t._info_fit(Vector2i(t.hint_at) - t.side + t.cam, t.hint)
	var box := Rect2(fit.at, fit.cells * fit.scale)
	return box.intersects(Rect2(position / CELL, Vector2(CodexScene.VIEW) * scale.x))
