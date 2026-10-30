class_name Fonts
extends RefCounted
## The one font: NeoDunggeunmo Code, a monospace pixel font drawn on a 16 px
## grid (ASCII 8 px wide, Hangul 16 px). Drawn at whole multiples of 16 px
## without antialiasing, its pixels stay square.

const PIXEL := preload("res://assets/fonts/NeoDunggeunmo.ttf")

static var _crisp: FontFile


static func pixel() -> FontFile:
	if _crisp == null:
		_crisp = PIXEL.duplicate()
		_crisp.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		_crisp.hinting = TextServer.HINTING_NONE
		_crisp.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return _crisp
