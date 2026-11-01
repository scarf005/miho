class_name Touch
extends Node
## Play with fingers. On a touch screen (a coarse pointer, or the first touch seen)
## the term shows no sidebar and its status rows give way to a TouchHud, the
## cells are sized from the screen in CSS pixels and its pixel ratio, and the
## finger does what the keys and the pointer do:
## tap a tile: walk or strike there (with talismans queued: aim, tap again to
## hurl); hold a tile, a talisman or the status: its info, until the next tap;
## swipe in one of 8 directions: a step (or a hurl with talismans queued);
## tap a talisman: queue it and aim at the nearest creature; tap the queue: hurl;
## tap a button: its key (Keys action); on a page: tap a row or tab, drag to
## scroll, swipe sideways to turn a tab or step a value.
## Touch rests on `main` (main.gd) for what a key or click already does.

## A point off the screen: the pointer is nowhere.
const OFF := Vector2(-1.0e5, -1.0e5)
## Cells across the screen in portrait, and rows down it in landscape, in play.
const COLS_TALL := 18
const ROWS_WIDE := 16
## Cells across the screen on a page.
const PAGE_COLS_TALL := 27
const PAGE_COLS_WIDE := 42
## The smallest cell an info box may shrink to, in CSS pixels.
const LEAST_CELL := 14.0
## Seconds a finger may take for a swipe; a slower move over the map drags it.
const FLICK := 0.3

var main: Node
var enabled := false
var gesture := Gesture.new()
var hud := TouchHud.new()
## Screen units per CSS pixel; the room the phone keeps for itself (top, right,
## bottom, left, CSS pixels). Read from the page whenever the layout is made.
var dpr := 1.0
var insets := Vector4.ZERO
var probing := true
## A long press is showing info: the next tap only closes it.
var frozen := false
var _scrolled := 0.0
## The drag over the map that has not yet made a whole tile, whether it is a pan and
## not a swipe, when the finger went down and the time of the last input.
var _pan := Vector2.ZERO
var _panning := false
var _since := 0.0
var _clock := 0.0
## What the layout was made for: the mode and whether there are saved spells.
var _laid: Array = []


## Reads the page: {dpr, insets, coarse} from "dpr,top,right,bottom,left,coarse",
## or empty when the string is not that.
static func parse(text: String) -> Dictionary:
	var f := text.split_floats(",")
	if f.size() != 6 or f[0] <= 0.0:
		return {}
	return {dpr = f[0], insets = Vector4(f[1], f[2], f[3], f[4]), coarse = f[5] > 0.0}


## How the screen is shared, in CSS pixels: the cell width, whether the screen is
## wider than tall, the map area, the HUD area and the rows between page entries.
## Cells are as wide as the screen's size asks, then rounded down to whole pixels
## of the font's grid at this pixel ratio, so they stay sharp.
static func plan(
	css: Vector2, inset: Vector4, ratio: float, page: bool, saved := true
) -> Dictionary:
	var safe := Rect2(inset.w, inset.x, css.x - inset.w - inset.y, css.y - inset.x - inset.z)
	var wide := safe.size.x > safe.size.y
	var ask := safe.size.x / (PAGE_COLS_WIDE if wide else PAGE_COLS_TALL)
	if not page:
		ask = (
			safe.size.y / (ROWS_WIDE * Term.CELL.y / Term.CELL.x)
			if wide
			else safe.size.x / COLS_TALL
		)
	var step := 16.0 if ratio >= 2.0 else 8.0
	var cw := maxf(step, floorf(ask * ratio / step) * step) / ratio
	var ch := cw * Term.CELL.y / Term.CELL.x
	var extent := TouchHud.extent(wide, not page, ch, saved)
	var map := safe
	var bar := safe
	if wide:
		map.size.x -= extent
		bar = Rect2(map.end.x, safe.position.y, extent, safe.size.y)
	else:
		map.size.y -= extent
		bar = Rect2(safe.position.x, map.end.y, safe.size.x, extent)
	var stride := ceili(TouchHud.TARGET / ch) if page else 1
	return {cw = cw, wide = wide, map = map, hud = bar, stride = stride}


## The key that moves one step in `dir`, as a Keys action.
static func move_action(dir: Vector2i) -> StringName:
	for action in Keys.MOVES:
		if Keys.MOVES[action] == dir:
			return action
	return &""


## `keys` as told for keyboard and mouse, else `touch_text` on a touch screen.
func say(keys: String, touch_text := "") -> String:
	return touch_text if enabled else keys


## Takes the page's pixel ratio and insets, and whether the pointer is coarse.
func start() -> void:
	var p := _probe()
	if not p.is_empty():
		enabled = p.coarse
	_dress()


func _probe() -> Dictionary:
	var p := {
		dpr = DisplayServer.screen_get_scale(),
		insets = Vector4.ZERO,
		coarse = DisplayServer.is_touchscreen_available()
	}
	if OS.has_feature("web"):
		var read := parse(
			str(JavaScriptBridge.eval("window.miho ? window.miho.probe() : ''", true))
		)
		p = read if not read.is_empty() else p
	if probing:
		dpr = p.dpr
		insets = p.insets
	return p


## What a touch screen changes at once: the pixels and the status.
func _dress() -> void:
	if not enabled:
		return
	main.get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	gesture.scale = dpr
	main.term.bar = hud


## Lays the term out for this screen and mode.
func fit() -> void:
	var term: Term = main.term
	if probing:
		_probe()
	gesture.scale = dpr
	hud.mode = _mode()
	hud.page = _page()
	_laid = _shape()
	var page: bool = main.overlay != &""
	var size: Vector2 = main.get_viewport().get_visible_rect().size / dpr
	var p := plan(size, insets, dpr, page, not term.saved.is_empty())
	var k: float = p.cw * dpr / Term.CELL.x
	term.side = Vector2i(Term.MAP.x, 0) if p.wide and hud.mode == &"play" else Vector2i.ZERO
	term.foot = 0
	term.centred = true
	term.bar = hud
	term.readable = LEAST_CELL * dpr
	PanelView.stride = p.stride
	term.fit(p.map.size * dpr, k, p.map.position * dpr)
	hud.unit = dpr / k
	hud.wide = p.wide
	hud.area = Rect2((p.hud.position * dpr - term.position) / k, p.hud.size * dpr / k)


func _mode() -> StringName:
	if main.overlay != &"":
		return &"menu"
	match main.state:
		&"title":
			return &"saved" if main.pending != null else &"title"
		&"over":
			return &"over"
	return &"play"


## The page the HUD has buttons for: the spellbook only when it lists a spell.
func _page() -> StringName:
	var spells: bool = main.overlay == &"spells" and not main.menu.spells().is_empty()
	return &"spells" if spells else &""


## What the layout depends on besides the screen.
func _shape() -> Array:
	return [_mode(), main.term.saved.is_empty()]


func _process(_delta: float) -> void:
	if not enabled:
		return
	if _shape() != _laid and main.state != &"replay":
		main._fit()
	hud.mode = _mode()
	hud.page = _page()
	tick(_now())


## Time passes with fingers down: a long press may begin.
func tick(now: float) -> void:
	for e in gesture.tick(now):
		_gesture(e)


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


## A touch or a drag from the screen. The first one makes this a touch screen.
func input(event: InputEvent, now := _now()) -> void:
	if not enabled:
		enabled = true
		_dress()
		main._apply()
		if main.state == &"title":
			main._show_title()
	var out := []
	_clock = now
	if event is InputEventScreenTouch:
		_scrolled = 0.0
		if event.pressed:
			_since = now
			_pan = Vector2.ZERO
			_panning = false
		hud.release()
		out = (
			gesture.down(event.index, event.position, now)
			if event.pressed
			else gesture.up(event.index, event.position, now)
		)
	elif event is InputEventScreenDrag:
		out = gesture.move(event.index, event.position, now)
	for e in out:
		_gesture(e)


func _gesture(e: Dictionary) -> void:
	if main.busy or main.walking or main.state == &"replay":
		return
	if frozen and e.t != &"hold":
		_close_info()
		if e.t == &"tap":
			return
	match e.t:
		&"tap":
			_tap(e.pos)
		&"hold":
			_hold(e.pos)
		&"swipe":
			_swipe(e.dir, e.from)
		&"drag":
			_drag(e.delta, e.by, e.from)


func _close_info() -> void:
	frozen = false
	main._point(OFF)


static func _click(pos: Vector2) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = pos
	return e


static func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e


func _tap(pos: Vector2) -> void:
	var term: Term = main.term
	var local: Vector2 = main._local(pos)
	var button := hud.button_at(term, local)
	if button != &"":
		hud.pressed = button
		hud.pressed_at = term._time
		main.sfx.play(&"click")
		_press(button)
	elif main.overlay == &"spells":
		var row := PanelView.row_at(term, local)
		if row >= 0:
			main.menu.select(row)
			term.panel = main.menu.panel()
	elif main.overlay != &"":
		main._panel_input(_click(pos))
	elif main.state == &"title" and main.pending == null:
		main._begin()
	elif main.state == &"play":
		_play_tap(pos, local)


func _press(id: StringName) -> void:
	match id:
		&"back":
			main._panel_input(_key(KEY_ESCAPE))
		&"continue":
			main._continue()
		&"new":
			main._restart()
		&"enter":
			main._panel_input(_key(KEY_ENTER))
		_ when Keys.SLOTS.has(id) and main.overlay != &"":
			main.menu.save(id)
			main.settings.save()
			main._apply()
			main.term.panel = main.menu.panel()
		_:
			main._do(id, false)


func _play_tap(pos: Vector2, local: Vector2) -> void:
	var term: Term = main.term
	var card := hud.card_at(term, local)
	var saved := hud.saved_at(term, local)
	var tile := term.tile_at(local)
	if Grid.inside(term.side_at(local)):
		main._point(pos)
		frozen = not main.term.info.is_empty()
	elif hud.cast_at(term, local):
		main._do(&"confirm", false)
	elif saved != &"":
		main._do(saved, false)
	elif card != &"":
		main._add(card)
		main._aim()
	elif not Grid.inside(tile):
		return
	elif main.picked.is_empty():
		main._point(pos)
		main._click(_click(pos))
		main._point(OFF)
	elif tile == main.hover:
		main._click(_click(pos))
	else:
		main._point(pos)


func _hold(pos: Vector2) -> void:
	if main.overlay != &"" or main.state != &"play":
		return
	main._point(pos)
	frozen = not main.term.info.is_empty() or Grid.inside(main.hover)


func _swipe(dir: Vector2i, from: Vector2) -> void:
	var local: Vector2 = main._local(from)
	if _panning or hud.area.has_point(local) or local.x < main.term.side.x * Term.CELL.x:
		return
	if main.overlay != &"":
		if dir.y == 0:
			var more: bool = (dir.x < 0) == (main.menu.page == &"codex")
			main._panel_input(_key(KEY_RIGHT if more else KEY_LEFT))
	elif main.state == &"play":
		main._do(move_action(dir), false)


## A drag over a page scrolls it by the rows it is drawn with; over the HUD's rows it
## scrolls them, and over the map, once it is slower than a swipe, it pans the map
## by whole tiles.
func _drag(delta: Vector2, by: Vector2, from: Vector2) -> void:
	var term: Term = main.term
	var local: Vector2 = main._local(from)
	if main.overlay == &"":
		if hud.scroll(term, local, delta.x / term.scale.x) or main.state != &"play":
			return
		if hud.area.has_point(local) or local.x < term.side.x * Term.CELL.x:
			return
		_pan += by
		_panning = _panning or _clock - _since >= FLICK
		if _panning:
			var tiles := Vector2i(_pan / (term.scale.x * Term.CELL))
			_pan -= Vector2(tiles) * term.scale.x * Term.CELL
			term.pan(-tiles)
		return
	var aside := PanelView.aside_at(term, main._local(from))
	var row := term.scale.y * Term.CELL.y * (1 if aside else PanelView.stride)
	_scrolled -= delta.y
	var rows := int(_scrolled / row)
	_scrolled -= rows * row
	if rows != 0:
		main.menu.scroll_by(rows, aside)
		term.panel = main.menu.panel()
