class_name Dither
extends RefCounted
## Ordered dithering (a 4x4 Bayer matrix) for the storey below where it shows
## through the sky: dots with no glyph, so it does not read as map Miho can walk.
## What can be walked on is sparse and what blocks the way is dense.

const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
## One dot in pixels; the matrix repeats a whole number of times in a cell.
const DOT := Vector2i(4, 5)
## Of the matrix's 16 dots, how many are lit.
const OPEN := 4
const SOLID := 8

static var _textures := {}


## The cell's pattern for tile kind `t` of the storey below, white on clear.
static func of(t: int) -> Texture2D:
	var level := OPEN if Tiles.walk[t] == 1 else SOLID
	if not _textures.has(level):
		_textures[level] = ImageTexture.create_from_image(image(level))
	return _textures[level]


## The cell's pattern with the matrix's `level` lowest dots lit.
static func image(level: int) -> Image:
	var out := Image.create(int(Term.CELL.x), int(Term.CELL.y), false, Image.FORMAT_RGBA8)
	for y in out.get_height():
		for x in out.get_width():
			if BAYER[(y / DOT.y) % 4 * 4 + (x / DOT.x) % 4] < level:
				out.set_pixel(x, y, Color.WHITE)
	return out
