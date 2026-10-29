class_name Hud
extends CanvasLayer
## Talisman cards, Miho's lives and tails, the nine-storey marker, the spell
## being composed, and the stat card of whatever the pointer rests on.

signal card_pressed(card: StringName)

const EFFECT := {
	Cards.FIRE: "번짐",
	Cards.WATER: "밀침",
	Cards.WOOD: "묶음",
	Cards.METAL: "꿰뚫음",
	Cards.EARTH: "기절",
}

var cards_row: HBoxContainer
var talismans := {}
var spell_line: Label
var lives: Label
var tails: Label
var pagoda: Pagoda
var info: PanelContainer
var info_text: Label
var banner: Label
var sub_banner: Label
var veil: ColorRect
var spell_panel: PanelContainer
var root: Control


func _ready() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var frame := Frame.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(frame)

	pagoda = Pagoda.new()
	pagoda.position = Vector2(58, 72)
	pagoda.size = Vector2(70, 230)
	root.add_child(pagoda)

	lives = _label(30, Palette.JANGDAN)
	lives.position = Vector2(58, 316)
	root.add_child(lives)
	tails = _label(28, Palette.INK)
	tails.position = Vector2(58, 358)
	root.add_child(tails)

	cards_row = HBoxContainer.new()
	cards_row.add_theme_constant_override("separation", 10)
	cards_row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	cards_row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	cards_row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	cards_row.position.y -= 18
	root.add_child(cards_row)
	for c in Cards.ALL:
		var t := Talisman.new()
		t.card = c
		t.index = Cards.ALL.find(c) + 1
		t.pressed.connect(func(): card_pressed.emit(c))
		cards_row.add_child(t)
		talismans[c] = t

	spell_panel = _paper_panel()
	spell_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	spell_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	spell_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	spell_panel.position.y -= 150
	spell_line = _label(22, Palette.INK)
	spell_panel.add_child(spell_line)
	root.add_child(spell_panel)

	info = _paper_panel()
	info.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	info.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	info.position = Vector2(-58, 72)
	info_text = _label(22, Palette.INK)
	info.add_child(info_text)
	info.visible = false
	root.add_child(info)

	veil = ColorRect.new()
	veil.color = Color(Palette.HANJI, 0.92)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(veil)
	banner = Label.new()
	banner.add_theme_font_override("font", Fonts.BRUSH)
	banner.add_theme_font_size_override("font_size", 150)
	banner.add_theme_color_override("font_color", Palette.INK)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.set_anchors_preset(Control.PRESET_CENTER)
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	banner.position.y -= 90
	root.add_child(banner)
	sub_banner = _label(26, Palette.INK)
	sub_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_banner.set_anchors_preset(Control.PRESET_CENTER)
	sub_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	sub_banner.position.y += 60
	root.add_child(sub_banner)
	curtain("", "")


func _paper_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.PAPER
	box.border_color = Palette.INK
	box.set_border_width_all(2)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", box)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


## Pulls the current picture out sideways like a 종이연극 card, revealing what is behind.
func slide(picture: Texture2D) -> Tween:
	var card := TextureRect.new()
	card.texture = picture
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.stretch_mode = TextureRect.STRETCH_SCALE
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(card)
	var t := card.create_tween()
	t.tween_interval(0.12)
	(
		t
		. tween_property(card, "position:x", -root.size.x - 40, 0.55)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN_OUT)
	)
	t.tween_callback(card.queue_free)
	return t


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", Fonts.serif())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A full-screen card for the title and the ending; empty title hides it.
func curtain(title: String, sub: String) -> void:
	veil.visible = title != ""
	banner.text = title
	sub_banner.text = sub
	banner.visible = title != ""
	sub_banner.visible = title != ""


func refresh(w: World, picked: Array[StringName]) -> void:
	var me := w.player()
	lives.text = "◆".repeat(maxi(me.hp, 0)) + "◇".repeat(maxi(me.max_hp - me.hp, 0))
	tails.text = ["", "일", "이", "삼", "사", "오", "육", "칠", "팔", "구"][w.max_tails()] + "미호"
	pagoda.depth = w.depth
	pagoda.queue_redraw()
	var spell := Spell.make(picked)
	for c in talismans:
		var t: Talisman = talismans[c]
		t.owned = w.cards.has(c)
		t.picked = picked.has(c)
		t.queue_redraw()
	spell_panel.visible = not picked.is_empty()
	if picked.is_empty():
		spell_line.text = ""
	elif spell == null:
		spell_line.text = "+".join(picked.map(func(c): return Cards.NAME[c])) + " · 형식(여우불·구슬) 필요"
	else:
		spell_line.text = describe(spell) + ("" if spell.cost() <= w.tails else "  · 꼬리 부족")


## One line of stats for a spell: name, cost, count, damage, effects.
static func describe(spell: Spell) -> String:
	var parts: Array[String] = [spell.title(), "꼬리 %d" % spell.cost()]
	if spell.count() > 1:
		parts.append("×%d" % spell.count())
	if spell.line:
		parts.append("피해 1, %d칸부터 2" % Spell.MOMENTUM)
	else:
		parts.append("피해 1")
	parts.append("한 턴 %d칸" % spell.speed())
	if spell.homing():
		parts.append("휘어 쫓음")
	elif spell.seek:
		parts.append("가까운 적 추적 · %d턴" % spell.life())
	for e in spell.elements():
		parts.append(EFFECT[e])
	return " · ".join(parts)


func show_actor(a: Actor) -> void:
	var info_d := a.info()
	var lines: Array[String] = [
		"%s  %s" % [info_d.name, "◆".repeat(a.hp) + "◇".repeat(a.max_hp - a.hp)]
	]
	if info_d.has("casts"):
		for cast in info_d.casts:
			lines.append(describe(Spell.make(cast)))
		if not a.intent.is_empty():
			lines.append("다음 턴 시전: " + Spell.make(a.intent).title())
		elif a.cooldown > 0:
			lines.append("%d턴 뒤 준비" % a.cooldown)
	match info_d.get("absorb", &""):
		&"fire":
			lines.append("불이 든 주문을 삼킴")
		&"nofire":
			lines.append("불이 든 주문만 통함")
	if info_d.has("drop"):
		lines.append("쓰러뜨리면 부적: " + Cards.NAME[info_d.drop])
	if a.rooted > 0:
		lines.append("묶임")
	if a.stunned > 0:
		lines.append("기절")
	_info(lines)


func show_shot(s: Shot) -> void:
	var lines: Array[String] = [s.spell.title() + ("  (미호)" if s.faction == Actor.FOX else "")]
	lines.append(describe(s.spell))
	if s.spell.line:
		lines.append("지금 맞으면 피해 %d" % s.spell.damage(s.distance() + 1))
	if s.life > 0:
		lines.append("%d턴 남음" % s.life)
	_info(lines)


func hide_info() -> void:
	info.visible = false


func _info(lines: Array[String]) -> void:
	info_text.text = "\n".join(lines)
	info.visible = true
	info.reset_size()
	info.position.x = root.size.x - 58 - info.size.x


class Talisman:
	extends Control
	## A yellow 부적 with its red glyph; the key number sits in the corner.
	signal pressed

	var card := &""
	var index := 0
	var owned := false
	var picked := false

	func _init() -> void:
		custom_minimum_size = Vector2(74, 116)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if (
			event is InputEventMouseButton
			and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT
		):
			pressed.emit()
			accept_event()

	func _draw() -> void:
		var lift := -14.0 if picked else 0.0
		var r := Rect2(Vector2(0, 8 + lift), Vector2(size.x, size.y - 8))
		if not owned:
			draw_rect(r, Color(Palette.PAPER, 0.5))
			draw_rect(r, Color(Palette.INK, 0.3), false, 2.0)
			draw_string(
				Fonts.serif(),
				Vector2(8, 30 + lift),
				str(index),
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				16,
				Color(Palette.INK, 0.4)
			)
			return
		draw_rect(r, Palette.HWANG)
		draw_rect(r.grow(-5), Palette.JANGDAN, false, 2.0)
		draw_rect(r.grow(-9), Palette.JANGDAN, false, 1.0)
		if picked:
			draw_rect(r.grow(3), Palette.SIDE[0], false, 4.0)
		draw_string(
			Fonts.serif(),
			Vector2(0, r.position.y + 66),
			Cards.GLYPH[card],
			HORIZONTAL_ALIGNMENT_CENTER,
			size.x,
			46,
			Palette.JANGDAN
		)
		draw_string(
			Fonts.serif(),
			Vector2(0, r.position.y + 96),
			Cards.NAME[card],
			HORIZONTAL_ALIGNMENT_CENTER,
			size.x,
			17,
			Palette.INK
		)
		draw_string(
			Fonts.serif(),
			Vector2(12, r.position.y + 24),
			str(index),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			15,
			Palette.INK
		)


class Frame:
	extends Control
	## The wooden stage of a 종이연극: 석간주 posts and a beam painted in 단청.

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var post := 34.0
		var beam := 48.0
		draw_rect(Rect2(0, 0, post, h), Palette.SEOKGANJU)
		draw_rect(Rect2(w - post, 0, post, h), Palette.SEOKGANJU)
		draw_line(Vector2(post, beam), Vector2(post, h), Palette.INK, 2)
		draw_line(Vector2(w - post, beam), Vector2(w - post, h), Palette.INK, 2)
		draw_rect(Rect2(0, 0, w, beam), Palette.NOEROK)
		draw_rect(Rect2(0, beam - 6, w, 6), Palette.SEOKGANJU)
		draw_rect(Rect2(0, 0, w, 5), Palette.SEOKGANJU)
		draw_line(Vector2(0, beam), Vector2(w, beam), Palette.INK, 2)
		var step := 76.0
		var x := step / 2
		while x < w:
			var c := Vector2(x, beam / 2 - 1)
			draw_circle(c, 15, Palette.JU)
			draw_circle(c, 10, Palette.PAPER)
			draw_circle(c, 5, Palette.HWANG)
			for k in 4:
				var a := k * PI / 2 + PI / 4
				draw_circle(c + Vector2(cos(a), sin(a)) * 12.5, 3, Palette.CHEONG)
			var d := Vector2(x + step / 2, beam / 2 - 1)
			draw_colored_polygon(
				PackedVector2Array(
					[d + Vector2(0, -9), d + Vector2(9, 0), d + Vector2(0, 9), d + Vector2(-9, 0)]
				),
				Palette.HWANG
			)
			x += step


class Pagoda:
	extends Control
	## Nine roofs stacked like 황룡사 구층목탑; the current storey is lit.
	var depth := 1

	func _draw() -> void:
		var h := size.y / World.FLOORS
		for i in World.FLOORS:
			var storey := World.FLOORS - i
			var y := i * h
			var w := size.x * (0.55 + 0.45 * storey / float(World.FLOORS))
			var x := (size.x - w) / 2
			var color := Palette.INK if storey < depth else Color(Palette.INK, 0.25)
			if storey == depth:
				color = Palette.JANGDAN
			var roof := PackedVector2Array(
				[
					Vector2(x - 6, y + h * 0.55),
					Vector2(x + w * 0.2, y + h * 0.15),
					Vector2(x + w * 0.8, y + h * 0.15),
					Vector2(x + w + 6, y + h * 0.55)
				]
			)
			draw_colored_polygon(roof, color)
			draw_rect(Rect2(x + w * 0.18, y + h * 0.55, w * 0.64, h * 0.4), Color(color, 0.5))
