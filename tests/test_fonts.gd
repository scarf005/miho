extends GutTest
## The bundled fonts are subset; every glyph the game writes must be in them.


func _source_chars() -> Dictionary:
	var chars := {}
	var dirs := ["res://src/core", "res://src/view"]
	for dir in dirs:
		for file in DirAccess.get_files_at(dir):
			if file.ends_with(".gd"):
				for c in FileAccess.get_file_as_string(dir.path_join(file)):
					if c.unicode_at(0) > 0x7E:
						chars[c] = file
	return chars


func test_serif_subset_covers_every_string_in_the_game() -> void:
	var chars := _source_chars()
	assert_gt(chars.size(), 100)
	for c in chars:
		assert_true(
			Fonts.SERIF.has_char(c.unicode_at(0)),
			"%s from %s missing; run just fonts" % [c, chars[c]]
		)
