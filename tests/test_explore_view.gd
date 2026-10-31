extends GutTest
## Auto-explore on the game scene.


func _main() -> Node:
	var m: Node = load("res://src/view/main.tscn").instantiate()
	m.save_path = ""
	add_child_autofree(m)
	Keys.reset()
	m._new_run(3)
	m.state = &"play"
	return m


func test_explore_rests_until_the_tails_regrow_first() -> void:
	var m := _main()
	m.world.depth = 4
	m.world.tails = 1
	m._forecast()
	assert_eq(m._exploring(), {t = &"wait"})
	m.world.tails = m.world.max_tails()
	assert_eq(m._exploring().t, &"move")
