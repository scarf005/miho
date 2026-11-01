extends GutTest
## A touch screen is shared by its size and pixel ratio: the map, the HUD and
## the cells, inside the phone's safe area, with every target at least 44 CSS
## pixels.

const TARGET := TouchHud.TARGET


func test_the_page_is_read_from_its_pixel_ratio_insets_and_pointer() -> void:
	assert_eq(
		Touch.parse("3,47,0,34,0,1"), {dpr = 3.0, insets = Vector4(47, 0, 34, 0), coarse = true}
	)
	assert_eq(Touch.parse("2,0,0,0,0,0").coarse, false)
	assert_eq(Touch.parse(""), {})
	assert_eq(Touch.parse("0,0,0,0,0,0"), {}, "no pixel ratio, no reading")


func test_a_tall_phone_puts_the_hud_under_a_map_18_cells_wide() -> void:
	var p := Touch.plan(Vector2(390, 844), Vector4.ZERO, 3.0, false)
	assert_false(p.wide)
	assert_gte(p.map.size.x / p.cw, 18.0)
	assert_eq(p.map.end.y, p.hud.position.y, "the HUD starts where the map ends")
	assert_eq(p.map.size.x, 390.0)
	assert_eq(fmod(p.cw * 3.0, 16.0), 0.0, "cells are whole pixels of the font's grid")


func test_a_wide_phone_puts_the_hud_beside_a_map_16_rows_tall() -> void:
	var p := Touch.plan(Vector2(844, 390), Vector4.ZERO, 3.0, false)
	assert_true(p.wide)
	assert_eq(p.map.end.x, p.hud.position.x)
	assert_gte(p.map.size.y / (p.cw * Term.CELL.y / Term.CELL.x), 16.0)
	assert_gte(p.hud.size.x, 300.0)


func test_the_map_and_the_hud_stay_inside_the_phone_s_safe_area() -> void:
	var tall := Touch.plan(Vector2(390, 844), Vector4(47, 0, 34, 0), 3.0, false)
	assert_gte(tall.map.position.y, 47.0)
	assert_lte(tall.hud.end.y, 844.0 - 34.0)
	var wide := Touch.plan(Vector2(844, 390), Vector4(0, 47, 21, 47), 3.0, false)
	assert_gte(wide.map.position.x, 47.0, "left")
	assert_lte(wide.hud.end.x, 844.0 - 47.0, "right")
	assert_lte(wide.hud.end.y, 390.0 - 21.0, "bottom")


func test_a_page_has_the_cells_to_show_the_tabs_and_rows_a_finger_can_pick() -> void:
	for css in [Vector2(390, 844), Vector2(844, 390)]:
		var p := Touch.plan(css, Vector4.ZERO, 3.0, true)
		var ch: float = p.cw * Term.CELL.y / Term.CELL.x
		assert_gte(p.map.size.x / p.cw, 27.0, "the tabs of the 도감 fit: %s" % css)
		assert_gte(p.stride * ch, TARGET, "a row is %s CSS px apart" % (p.stride * ch))


func test_every_target_of_the_hud_is_at_least_44_css_pixels_in_both_orientations() -> void:
	for css in [Vector2(390, 844), Vector2(844, 390), Vector2(360, 640)]:
		var p := Touch.plan(css, Vector4.ZERO, 3.0, false)
		var unit := 2.0
		var area := Rect2(p.hud.position * unit, p.hud.size * unit)
		for item in TouchHud.layout(&"play", area, unit, p.wide, Cards.ALL.size()):
			if item.kind == &"stat":
				continue
			assert_gte(item.rect.size.x / unit, TARGET, "%s wide at %s" % [item.id, css])
			assert_gte(item.rect.size.y / unit, TARGET, "%s tall at %s" % [item.id, css])
			assert_true(
				area.encloses(item.rect), "%s %s is on the HUD at %s" % [item.id, item.rect, css]
			)


func test_the_buttons_of_the_other_modes_are_at_least_44_css_pixels_too() -> void:
	for mode in [&"menu", &"saved", &"over"]:
		for wide in [false, true]:
			var area := Rect2(0, 0, 390, 120)
			for item in TouchHud.layout(mode, area, 1.0, wide, 0):
				assert_gte(minf(item.rect.size.x, item.rect.size.y), TARGET, "%s" % mode)
