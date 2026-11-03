extends TouchBase
## The game keeps the run on disk once a second and whenever the player leaves it.

const SAVE := "user://test_autosave.cfg"


func after_each() -> void:
	SaveGame.new(SAVE).erase()


## The game in play with one round not yet on disk.
func _played() -> Node:
	var m := _main(false)
	m.save_path = SAVE
	m.new_run(3)
	m.run.record({t = &"wait"}, 0, false)
	assert_null(SaveGame.load_from(SAVE), "the round waits for the clock")
	return m


func _clock(m: Node) -> Autosave:
	return m.get_children().filter(func(c): return c is Autosave)[0]


func _saved_rounds() -> int:
	return SaveGame.load_from(SAVE).actions.size()


func test_the_clock_writes_the_run() -> void:
	var m := _played()
	_clock(m).timeout.emit()
	assert_eq(_saved_rounds(), 1)


func test_leaving_the_window_writes_the_run() -> void:
	var m := _played()
	_clock(m).notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	assert_eq(_saved_rounds(), 1)


func test_the_phone_pausing_the_game_writes_the_run() -> void:
	var m := _played()
	_clock(m).notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_eq(_saved_rounds(), 1)


func test_closing_the_game_writes_the_run() -> void:
	var m := _played()
	m.get_parent().remove_child(m)
	assert_eq(_saved_rounds(), 1)
	m.queue_free()


func test_going_back_to_the_title_offers_the_last_round() -> void:
	var m := _played()
	m.new_run()
	m.show_title()
	assert_not_null(m.pending)
	assert_eq(m.pending.actions.size(), 1)


func test_a_death_is_not_undone_by_the_clock() -> void:
	var m := _played()
	_clock(m).timeout.emit()
	m.run.record({t = &"wait"}, 0, false)
	m.run.record({t = &"wait"}, 0, true)
	_clock(m).timeout.emit()
	assert_null(SaveGame.load_from(SAVE))
