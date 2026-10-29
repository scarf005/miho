class_name Fonts
extends RefCounted
## The bundled fonts, subset by `just fonts`. Noto Serif KR is variable; pin a weight.

const SERIF := preload("res://assets/fonts/NotoSerifKR-Miho.ttf")
const BRUSH := preload("res://assets/fonts/NanumBrushScript-Miho.ttf")

static var _weights := {}


static func serif(weight := 600) -> Font:
	if not _weights.has(weight):
		var f := FontVariation.new()
		f.base_font = SERIF
		f.variation_opentype = {
			TextServerManager.get_primary_interface().name_to_tag("wght"): weight
		}
		_weights[weight] = f
	return _weights[weight]
