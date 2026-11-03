class_name ExampleSim
extends Term
## A small Term of its own with a World of its own (CodexScene, SpellScene) that plays
## round after round through Term.play, over whatever shows an example: the 도감, the
## spellbook, the box of a hover. It has no link to the run, the log or the sound.
## Before each cast the tiles it would reach are tinted as the aim preview tints them
## (SpellScene.reach).

## Seconds before the first round, after each round, and before starting again.
const START := 0.5
const ROUND := 0.45
const REST := 1.0
## Seconds the tiles a cast reaches stay tinted before it is cast.
const AIM := 0.8

var _scene := {}
var _rank := 0
var _actions: Array[Dictionary] = []
var _next := 0
var _left := 0.0
var _aimed := false


func _ready() -> void:
	cols = CodexScene.VIEW.x
	rows = CodexScene.VIEW.y
	side = Vector2i.ZERO
	foot = 0
	replay = true
	cam = CodexScene.CORNER
	clip_contents = true
	super()
	stop()


## The camera stays on the hall.
func follow(_p: Vector2i) -> void:
	pass


func _process(delta: float) -> void:
	super(delta)
	if _animating:
		return
	_left -= delta * speed
	if _left <= 0.0:
		_play_next()


## Plays `scene`, on a storey of rank `rank`, from its start.
func show_scene(scene: Dictionary, rank := 0) -> void:
	_scene = scene
	_rank = rank
	speed = get_parent().speed
	still = get_parent().still
	set_process(true)
	visible = true
	_begin()


func stop() -> void:
	_scene = {}
	rush()
	set_process(false)
	visible = false


func _begin() -> void:
	rush()
	_popups.clear()
	_flashes.clear()
	_trails.clear()
	_clear()
	var scene := SpellScene.ready(_scene)
	_actions = CodexScene.actions(scene)
	show_world(CodexScene.build(scene, _rank))
	_next = 0
	_left = START


## The next round of the scene: a cast shows the tiles it reaches first. After the last,
## the scene again from its start.
func _play_next() -> void:
	if _next >= _actions.size() or not world.can(_actions[_next]):
		_begin()
		return
	var action := _actions[_next]
	if action.t == &"cast" and not _aimed:
		var shown := SpellScene.reach(world, action)
		tints = shown.tints
		marks = shown.marks
		lines = shown.lines
		_aimed = true
		_left = AIM
		return
	_clear()
	_next += 1
	_left = REST if _next == _actions.size() else ROUND
	var before := world.clone()
	play(world.act(action), before, world)


func _clear() -> void:
	tints = {}
	marks = {}
	lines = []
	_aimed = false


## The example `scene` plays in Term `t`, in `sim` or one made now; it stops and is freed with none.
static func swap(t: Term, sim: ExampleSim, scene: Dictionary) -> ExampleSim:
	if scene.is_empty():
		if sim != null:
			sim.queue_free()
		return null
	if sim == null:
		sim = ExampleSim.new()
		t.add_child(sim)
	sim.show_scene(scene)
	sim.visible = false
	return sim


## Puts `sim` in the box laid out as `fit` (InfoBox), where its cells are; it is hidden
## when the box has none.
static func place(sim: ExampleSim, fit: Dictionary) -> void:
	if sim == null:
		return
	sim.visible = fit.has("example")
	if sim.visible:
		sim.position = (fit.at + fit.example * fit.scale) * CELL
		sim.scale = Vector2(fit.scale, fit.scale)
