extends GutTest
## The one rule that colours a word by what it means (Keywords), through the
## hover, the 도감 and the log.

const ME := Vector2i(4, 8)


func _world() -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	for y in range(1, Grid.H - 1):
		for x in range(1, Grid.W - 1):
			w.tiles[Grid.index(Vector2i(x, y))] = World.FLOOR
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.hp = 3
	me.max_hp = 3
	me.pos = ME
	w.actors.append(me)
	w.sense()
	return w


## The run that holds exactly `word`, anywhere in `lines`, or empty.
func _run(lines: Array, word: String) -> Array:
	for line: Array in lines:
		for run: Array in line:
			if run[0] == word:
				return run
	return []


func test_fierce_is_red_on_yellow_and_flammable_orange() -> void:
	var fierce := _run([Keywords.runs("인화성.", Palette.DIM)], "인화성")
	assert_eq(fierce[1], Palette.FIERCE_TEXT)
	assert_eq(Keywords.back(fierce), Palette.FIERCE_BACK)
	var flammable := _run([Keywords.runs("가연성.", Palette.DIM)], "가연성")
	assert_eq(flammable[1], Palette.FLAMMABLE)
	assert_eq(Keywords.back(flammable).a, 0.0, "orange text has no background")


func test_a_word_is_coloured_only_whole() -> void:
	for text in ["비인화성", "기절했다", "묶임이", "가연성질"]:
		assert_eq(Keywords.runs(text, Palette.TEXT), [[text, Palette.TEXT]], text)
	var runs := Keywords.runs("묶임: 3초", Palette.TEXT)
	assert_eq(runs.map(func(r): return r[0]), ["묶임", ": 3초"])


func test_a_run_with_a_colour_of_its_own_is_left_alone_unless_it_is_only_the_word() -> void:
	var own := [["묶임: 3초", Palette.HURT]]
	assert_eq(Keywords.paint(own), own)
	var name := Keywords.paint([["젖음", Palette.CARD[Cards.WATER]]])
	assert_eq(name[0][1], Palette.BAD)


func test_a_status_is_coloured_by_what_it_does_to_its_holder() -> void:
	for word: String in Status.NAME.values() + ["묶임", "기절", "눈멂"]:
		assert_eq(Keywords.runs(word, Palette.TEXT)[0][1], Palette.BAD, word)
	assert_eq(Keywords.runs("둔갑", Palette.TEXT)[0][1], Palette.GOOD)
	assert_eq(Keywords.runs("경계", Palette.TEXT), [["경계", Palette.TEXT]], "neutral stays plain")


func test_a_panel_row_keeps_its_column_and_gains_the_colour() -> void:
	var row := Keywords.paint([["·", Palette.TEXT, 2.0], ["묶임", Palette.TEXT, 4.0]])
	assert_eq(Keywords.column(row[1], 0.0), 4.0)
	assert_eq(row[1][1], Palette.BAD)


func test_the_hover_and_the_dogam_colour_a_word_the_same() -> void:
	var term: Term = autofree(Term.new())
	var w := _world()
	var at := ME + Vector2i(1, 0)
	w.set_tile(at, World.STRAW)
	var foe := FloorGen.spawn(w, &"dokkaebi", ME + Vector2i(0, 1))
	foe.ailments.rooted = 3
	w.sense()
	term.info = Info.at(w, at)
	var hover_fierce := _run(term.info, "인화성")
	term.info = Info.creature(w, foe)
	var hover_rooted := _run(term.info, "묶임")
	assert_false(hover_fierce.is_empty())
	assert_false(hover_rooted.is_empty())
	var codex := Codex.new()
	var seen := 0
	for k in Codex.TABS.size():
		codex.go(k)
		var names := Codex.entries(k).map(func(e): return e.name)
		for word in ["인화성", "묶임"]:
			if not names.has(word):
				continue
			codex.select(names.find(word))
			term.panel = codex.panel()
			var hover := hover_fierce if word == "인화성" else hover_rooted
			for shown: Array in [_run(term.panel.rows, word), _run(term.panel.aside, word)]:
				assert_eq(shown[1], hover[1], word)
				assert_eq(Keywords.back(shown), Keywords.back(hover), word)
				seen += 1
	assert_eq(seen, 4, "each word in the list and the detail")


func test_the_hover_box_the_dogam_flow_and_the_log_rows_keep_the_background() -> void:
	var line := Keywords.paint([["인화성", Palette.TEXT], [" 짚이 아주 잘 탄다", Palette.TEXT]])
	var box := InfoBox.layout([line], Vector2(40, 18))
	assert_eq(Keywords.back(box.columns[0][1][0][0]), Palette.FIERCE_BACK)
	var flowed := Codex.flow([line], 3.0)
	assert_eq(Keywords.back(flowed[0][0]), Palette.FIERCE_BACK)
	var rows := Keywords.rows_of([["가 ", Palette.TEXT]] + [line[0]], 3.0)
	assert_eq(Keywords.back(rows.back().back()), Palette.FIERCE_BACK)


func test_the_term_holds_hover_and_panel_text_painted() -> void:
	var term: Term = autofree(Term.new())
	term.info = [[["인화성.", Palette.DIM]]]
	assert_eq(Keywords.back(term.info[0][0]), Palette.FIERCE_BACK)
	term.panel = {rows = [[["·", Palette.TEXT, 2.0], ["묶임", Palette.TEXT, 4.0]]]}
	assert_eq(term.panel.rows[0][1][1], Palette.BAD)


func _rooted_line(w: World, id: int) -> Array:
	var events := [{t = &"root", id = id, at = w.actor(id).pos}]
	return Messages.shown({variants = {&"ko": Messages.of(w, w, events)[0]}, n = 1})


func test_the_log_colours_being_rooted_by_who_suffers_it() -> void:
	var w := _world()
	var foe := FloorGen.spawn(w, &"dokkaebi", ME + Vector2i(2, 0))
	w.sense()
	assert_eq(_rooted_line(w, w.player().id).back()[1], Palette.BAD)
	assert_eq(_rooted_line(w, foe.id).back()[1], Palette.BAD_FOE)
	assert_ne(Palette.BAD_FOE, Palette.TEXT, "it still tells")
	assert_ne(Palette.BAD_FOE, Palette.BAD)
