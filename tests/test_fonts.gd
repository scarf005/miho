extends GutTest
## Every glyph the game draws must be in the pixel font.


func test_pixel_font_covers_every_string_in_the_game() -> void:
	var chars := {}
	for dir in ["res://src/core", "res://src/view"]:
		for file in DirAccess.get_files_at(dir):
			if file.ends_with(".gd"):
				for c in FileAccess.get_file_as_string(dir.path_join(file)):
					if c.unicode_at(0) > 0x7E:
						chars[c] = file
	assert_gt(chars.size(), 50)
	for c in chars:
		assert_true(Fonts.PIXEL.has_char(c.unicode_at(0)), "%s from %s" % [c, chars[c]])
