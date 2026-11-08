class_name Fonts
extends RefCounted
## The one font: NeoDunggeunmo Code, a monospace pixel font drawn on a 16 px
## grid (ASCII 8 px wide, Hangul 16 px). Drawn at whole multiples of 16 px
## without antialiasing, its pixels stay square. DotGothic16, a pixel font of the
## same grid, draws the kana and kanji it lacks.

const PIXEL := preload("res://assets/fonts/NeoDunggeunmo.ttf")
const JAPANESE := preload("res://assets/fonts/DotGothic16-Regular.ttf")

static var _crisp: FontFile


static func pixel() -> FontFile:
	if _crisp == null:
		_crisp = _plain(PIXEL)
		_crisp.fallbacks = [_plain(JAPANESE)]
	return _crisp


static func _plain(font: FontFile) -> FontFile:
	var out: FontFile = font.duplicate()
	out.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	out.hinting = TextServer.HINTING_NONE
	out.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return out
