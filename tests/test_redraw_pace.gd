extends GutTest
## What the term draws follows what moves on it, and nothing waits long to be seen.

const FRAME := 1.0 / 60.0

var _m: Node
var _pace: RedrawPace
var _drawn := 0


func before_each() -> void:
	_m = load("res://src/view/main.tscn").instantiate()
	_m.save_path = ""
	add_child_autofree(_m)
	await get_tree().process_frame
	_m._new_run(3)
	_m.state = &"play"
	_pace = _m.term.get_node("RedrawPace")
	_pace.set_process(false)
	_m.term.draw.connect(func(): _drawn += 1)
	await get_tree().process_frame
	_drawn = 0


func _frames(n: int) -> int:
	var from := _drawn
	for i in n:
		_pace._process(FRAME)
		await get_tree().process_frame
	return _drawn - from


func test_a_quiet_screen_is_drawn_at_the_calm_pace() -> void:
	var drawn: int = await _frames(60)
	assert_between(drawn, 19, 21)


func test_a_popup_is_drawn_every_frame_until_it_is_gone() -> void:
	_m.term._popups.append(
		{at = Vector2i(1, 1), text = "쿵", color = Color.WHITE, born = 0.0, life = 9.0}
	)
	assert_eq(await _frames(10), 10)


func test_an_input_is_drawn_on_its_frame() -> void:
	await _frames(1)
	_pace._calm = 0.0
	_pace._input(InputEventMouseMotion.new())
	await get_tree().process_frame
	assert_eq(_drawn > 0, true)
	var before := _drawn
	_pace._input(InputEventMouseMotion.new())
	await get_tree().process_frame
	assert_eq(_drawn, before + 1)
