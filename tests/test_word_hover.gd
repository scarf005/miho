extends GutTest
## A word with a 도감 entry shows it where the map hover cannot be pointed at:
## in a 도감 detail, a panel row and the log over the map.

const NONE := Vector2i(-1, -1)


func _term() -> Term:
	var t: Term = autofree(Term.new())
	t.cols = 60
	t.rows = 24
	return t


## The pixel centre of the character `at` of the row drawn from cell `x`, `y`.
func _over(x: float, y: int) -> Vector2:
	return Vector2(x + 0.5, y + 0.5) * Term.CELL


func _head(lines: Array) -> String:
	return Info.plain(lines).split("\n")[0]


func test_every_glossary_term_is_a_word_with_an_entry() -> void:
	for term: String in Info.glossary():
		assert_eq(_head(Keywords.entry(term)), term + ".", term)
	assert_eq(Keywords.entry("모르는 말"), [])


func test_a_status_and_a_condition_have_the_entry_the_dogam_tells() -> void:
	assert_eq(Keywords.entry("젖음"), Info.status_facts(&"wet"))
	assert_eq(Keywords.entry("묶임"), Info.condition_facts("묶임"))


func test_the_entry_is_of_the_word_under_the_pointer_and_of_no_other_cell() -> void:
	var row := [["둔함", Palette.DIM], [" · ", Palette.DIM], ["고정", Palette.DIM]]
	assert_eq(_head(Keywords.entry_at(row, 13.0, 13.5)), "둔함.")
	assert_eq(_head(Keywords.entry_at(row, 13.0, 13.0 + Term._cells("둔함") + 0.2)), "", "between")
	assert_eq(_head(Keywords.entry_at(row, 13.0, 13.0 + Term._cells("둔함 · ") + 0.2)), "고정.")
	assert_eq(Keywords.entry_at(row, 13.0, 12.5), [], "left of the row")


func test_a_word_inside_a_longer_one_has_no_entry() -> void:
	assert_eq(Keywords.entry_at([["소음기", Palette.TEXT]], 0.0, 0.5), [])


func test_a_tag_of_several_words_has_its_entry_over_each_of_them() -> void:
	var row := [["위치 감지", Palette.DIM]]
	for col in [0.5, 2.0, 4.0]:
		assert_eq(_head(Keywords.entry_at(row, 0.0, col)), "위치 감지.", str(col))


func test_the_dogam_detail_gives_the_entry_of_a_tag_it_shows() -> void:
	var codex := Codex.new()
	codex.tab = 0
	codex.select(Codex.foes().find(&"jangseung"))
	var t := _term()
	t.panel = codex.panel()
	var k := 0
	while not Info.plain([t.panel.aside[k]]).contains("고정"):
		k += 1
	assert_eq(_head(WordHover.at(t, _over(Codex.SIDE_X, 3 + k))), "둔함.")
	assert_eq(WordHover.at(t, _over(Codex.SIDE_X, 2)), [], "no row of text there")


func test_the_log_over_the_map_gives_the_entry_of_a_word_in_it() -> void:
	var t := _term()
	t.log_lines = [[[["도깨비가 ", Palette.TEXT], ["묶임", Palette.BAD]], 1.0]]
	assert_eq(_head(WordHover.at(t, _over(Term.MAP.x + 0.5 + 5.0, 0))), "묶임")
	assert_eq(WordHover.word_at(t, _over(Term.MAP.x + 0.5, 0)), "도깨비", "a creature's name")
	t.banner_lines = ["미호"]
	assert_eq(WordHover.at(t, _over(Term.MAP.x + 5.5, 0)), [], "a banner hides the log")


func test_every_tag_of_a_creature_has_an_entry_in_the_glossary() -> void:
	for kind in Codex.foes():
		for tag: String in Info._traits(Codex.foe(kind), Bestiary.elements(kind)):
			if not tag.contains(": "):
				assert_true(Info.glossary().has(tag), "%s: %s" % [kind, tag])


func test_the_entry_is_gone_when_the_panel_under_the_pointer_changes() -> void:
	var t := _term()
	t.hint = Keywords.entry("소음")
	assert_false(t.hint.is_empty())
	t.panel = {}
	assert_true(t.hint.is_empty())


func test_the_log_is_pointed_at_where_it_is_drawn_in_a_portrait_screen() -> void:
	var t := _term()
	t.cols = 10
	t.side = Vector2i.ZERO
	t.log_lines = [[[["가나다라마바사 ", Palette.TEXT], ["묶임", Palette.BAD]], 1.0]]
	assert_eq(_head(WordHover.at(t, _over(1.0, 1))), "묶임", "the word wrapped to the next row")
	assert_eq(WordHover.at(t, _over(Term.MAP.x + 1.0, 1)), [], "not shifted by the sidebar")


func test_the_map_hover_comes_back_when_the_word_under_the_pointer_has_faded() -> void:
	var m: Node = load("res://src/view/main.tscn").instantiate()
	m.save_path = ""
	add_child_autofree(m)
	m._new_run(3)
	m.state = &"play"
	m.glass.visible = false
	m.term.banner_lines.clear()
	m.world.act({t = &"cheat", cmd = &"reveal"})
	m.term.show_world(m.world)
	m._forecast()
	var row: int = -m.term.cam.y + 1
	m.term.log_lines = []
	for i in row:
		m.term.log_lines.append([[["·", Palette.TEXT]], 1.0])
	m.term.log_lines.append([[["당신이 불붙음 상태다", Palette.TEXT]], 1.0])
	var local := _over(Term.MAP.x + 0.5 + Term._cells("당신이 ") + 0.5, row)
	var move := InputEventMouseMotion.new()
	move.position = m.term.get_global_transform() * local
	m._unhandled_input(move)
	assert_false(m.term.hint.is_empty(), "the word shows its entry")
	var wait := Keys.event("Period")
	wait.pressed = true
	m._unhandled_input(wait)
	await wait_until(func(): return not m.busy, 5)
	assert_eq(m.term.log_lines, [], "the line is gone")
	assert_true(m.term.hint.is_empty(), "so is its entry")
	assert_false(m.term.info.is_empty(), "the tile under the pointer shows again")


func _word_at(text: String, col: float) -> String:
	return Keywords.word_at([[text, Palette.TEXT]], 0.0, col)


func test_every_name_of_every_tab_is_a_word_with_an_entry() -> void:
	for tab in Codex.TABS.size():
		for e in Codex.entries(tab):
			var at := Keywords.locate(e.name)
			assert_ne(at, NONE, e.name)
			assert_false(Keywords.entry(e.name).is_empty(), e.name)
	assert_eq(Keywords.locate("모르는 말"), NONE)


func test_a_name_is_a_word_whole_or_before_a_particle_and_in_no_longer_word() -> void:
	assert_eq(_word_at("진흙이 깔렸다", 0.5), "진흙")
	assert_eq(_word_at("문을 열었다", 0.5), "문")
	assert_eq(_word_at("주문", 1.5), "", "문 inside 주문")
	assert_eq(_word_at("벽돌", 0.5), "", "벽 before 돌")
	assert_eq(_word_at("풀다", 0.5), "", "풀 before 다")
	assert_eq(_word_at("꺼진 등불", 3.0), "꺼진 등불", "the longest name wins")
	assert_eq(_word_at("진흙이다", 0.5), "진흙", "the particle 이다")


func test_a_name_in_two_tabs_is_the_state_or_the_floor_before_the_spell() -> void:
	var mud := Keywords.locate("진흙")
	assert_eq(mud.x, 4, "the tile, not the spell of the same name")
	assert_eq(Keywords.locate("둔갑").x, 5, "the status")


func test_an_english_name_is_a_word_in_any_case_and_not_inside_a_longer_one() -> void:
	Lang.locked = false
	Lang.use(&"en")
	assert_eq(_word_at("The mud is deep", 2.5), "mud")
	assert_eq(_word_at("Mudslide", 0.5), "")
	assert_eq(Keywords.locate("Mud").x, 4)
	Lang.use(&"ko")
	Lang.locked = true
	TranslationServer.set_locale("ko")
