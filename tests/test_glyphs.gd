extends GutTest
## Map glyphs follow terminal DCSS: one glyph may cover several kinds of tile, as every
## wall is `#`, and the foreground colour tells them apart.

## Colour distance below which two marks of one glyph read as the same.
const MIN_APART := 0.15


## Every mark the map draws, as {name, glyph, colour}.
func _marks() -> Array:
	var out := []
	for t in Palette.TILES:
		out.append(
			{name = "tile %d" % t, glyph = Palette.TILES[t][0], colour = Palette.TILES[t][1]}
		)
	var singles := {
		burning = Palette.BURNING,
		hot = Palette.HOT,
		stairs = Palette.STAIRS,
		elixir = Palette.ELIXIR,
		peach = Palette.PEACH,
		body = Palette.BODY,
	}
	for key in singles:
		out.append({name = key, glyph = singles[key][0], colour = singles[key][1]})
	for gas in Palette.GAS:
		out.append(
			{name = "gas %d" % gas, glyph = Palette.GAS[gas][0], colour = Palette.GAS[gas][1]}
		)
	return out


func _distance(a: Color, b: Color) -> float:
	return Vector3(a.r, a.g, a.b).distance_to(Vector3(b.r, b.g, b.b))


func test_every_tile_kind_is_told_apart_from_every_other_by_glyph_or_colour() -> void:
	var marks := _marks()
	assert_gt(marks.size(), 40)
	for i in marks.size():
		for j in range(i + 1, marks.size()):
			var a: Dictionary = marks[i]
			var b: Dictionary = marks[j]
			if a.glyph == b.glyph:
				assert_gt(
					_distance(a.colour, b.colour),
					MIN_APART,
					"%s and %s share %s and its colour" % [a.name, b.name, a.glyph]
				)


func test_every_glyph_the_map_draws_is_in_the_mcp_legend() -> void:
	var listed := {}
	for word in Observation.LEGEND.split(" "):
		listed[word.substr(0, 1)] = true
	var glyphs := _marks().map(func(m): return m.glyph)
	glyphs.append(Observation.REMEMBERED_FLOOR)
	for glyph in glyphs:
		assert_true(listed.has(glyph), "legend lists %s" % glyph)


func test_the_map_text_draws_floor_in_sight_apart_from_floor_remembered() -> void:
	assert_ne(Palette.TILES[World.FLOOR][0], Observation.REMEMBERED_FLOOR)
	assert_string_contains(Observation.LEGEND, ".floor(in sight) ·floor(remembered)")


func test_glyphs_follow_dcss() -> void:
	assert_eq(Palette.TILES[World.FLOOR][0], ".")
	assert_eq(Palette.BODY[0], "%")
	assert_eq(Palette.PEACH[0], "%")
	for wall in [World.WALL, World.WALL_CRACKED, World.WOOD_WALL, World.WINDOW]:
		assert_eq(Palette.TILES[wall][0], "#", "tile %d" % wall)
	for water in [World.POND, World.SHALLOW, World.MUD]:
		assert_eq(Palette.TILES[water][0], "~", "tile %d" % water)
	assert_eq(Palette.TILES[World.PILLAR][0], "ß")
	for plate in [World.TRAP_ALARM, World.TRAP_COLLAPSE, World.TRAP_FIRE, World.TRAP_VINE]:
		assert_eq(Palette.TILES[plate][0], "^", "tile %d" % plate)
	assert_eq(Palette.BURNING[0], "§")
	assert_eq(Palette.STAIRS[0], "<")
	assert_eq(Palette.ELIXIR[0], "!")


func test_deep_water_reads_deeper_than_shallow_water() -> void:
	assert_lt(Palette.TILES[World.POND][1].v, Palette.TILES[World.SHALLOW][1].v)
	assert_lt(Palette.TILES[World.POND][1].g, Palette.TILES[World.SHALLOW][1].g)
