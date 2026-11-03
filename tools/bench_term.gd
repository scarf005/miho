extends SceneTree
## Times what the term pays on a storey in full sight, lit by lanterns with fire about:
## lighting the storey (Term.show_world) and one draw of the whole map.
## godot --headless --path . -s tools/bench_term.gd

const FRAMES := 400
## Frames left out at the start, while the font caches its glyphs.
const WARM := 100


class Timed:
	extends Term
	var took: Array[int] = []

	func _draw() -> void:
		var from := Time.get_ticks_usec()
		super()
		took.append(Time.get_ticks_usec() - from)


var _term: Timed


func _initialize() -> void:
	var w := World.create(3)
	for y in range(4, Grid.H, 8):
		for x in range(4, Grid.W, 12):
			w.set_tile(Vector2i(x, y), World.LANTERN)
			w.burning[Vector2i(x + 2, y)] = World.BURN_ROUNDS
	w.seen.fill(1)
	w.known.fill(1)
	_term = Timed.new()
	root.add_child(_term)
	_term.fit(Vector2(1920, 1080), 0.0)
	var from := Time.get_ticks_usec()
	for i in 20:
		_term.show_world(w)
	print("show_world: mean %d us" % ((Time.get_ticks_usec() - from) / 20))


func _process(_delta: float) -> bool:
	_term.queue_redraw()
	if _term.took.size() < FRAMES:
		return false
	var took := _term.took.slice(WARM)
	took.sort()
	var sum: int = took.reduce(func(n, t): return n + t, 0)
	print(
		(
			"term draw %d: mean %d us, median %d us"
			% [took.size(), sum / took.size(), took[took.size() / 2]]
		)
	)
	return true
