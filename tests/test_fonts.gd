extends GutTest
## Every glyph the game draws must be in the pixel font, except the hearts
## Term draws as pixels. The Japanese font draws the kana and kanji of the
## Japanese table.


func test_pixel_font_covers_every_string_in_the_game() -> void:
	var chars := {}
	for dir in ["res://src/core", "res://src/game", "res://src/text", "res://src/view"]:
		for file in DirAccess.get_files_at(dir):
			if file.ends_with(".gd"):
				for c in FileAccess.get_file_as_string(dir.path_join(file)):
					if c.unicode_at(0) > 0x7E and c != "♥" and c != "♡":
						chars[c] = file
	for c in FileAccess.get_file_as_string("res://assets/i18n/ja.po"):
		if c.unicode_at(0) > 0x7E and c != "♥" and c != "♡":
			chars[c] = "ja.po"
	assert_gt(chars.size(), 50)
	for c in chars:
		var code: int = c.unicode_at(0)
		var drawn: bool = Fonts.PIXEL.has_char(code) or Fonts.JAPANESE.has_char(code)
		assert_true(drawn, "%s from %s" % [c, chars[c]])
