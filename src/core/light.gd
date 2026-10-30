class_name Light
extends RefCounted
## Brogue-style light: every source adds its colour to the tiles it reaches,
## fading with distance (Brogue CE Light.c paintLight: 100 - (100 - fade) *
## dist / radius). Walls and closed doors cast shadows. A negative colour is
## darkness. A tile is lit when its brightest channel reaches LIT.

const LIT := 0.3
const FADE := 0.25

const LANTERN := Vector3(1.0, 0.6, 0.28)
const LANTERN_RADIUS := 6
const SIDE: Array[Vector3] = [Vector3(0.45, 0.72, 1.0), Vector3(1.0, 0.3, 0.2)]
const FIRE := Vector3(1.0, 0.55, 0.15)
const FIRE_RADIUS := 3
## Moonlight on skybridges: bright enough to be lit anywhere along the span.
const MOON := Vector3(0.4, 0.5, 0.75)
const DARK := Vector3(-1.4, -1.4, -1.4)


## Strength (0 to 1) a source gives each tile it reaches.
static func spread(at: Vector2i, radius: int, opaque: Callable) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(Grid.W * Grid.H)
	var seen := Sight.field(at, radius, opaque)
	for i in seen.size():
		if seen[i] == 1:
			var d := Vector2(Grid.at(i) - at).length()
			out[i] = maxf(0.0, 1.0 - (1.0 - FADE) * d / maxf(1.0, radius))
	return out


## Sum of every source; each source is {at, radius, color}.
static func field(sources: Array[Dictionary], opaque: Callable) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(Grid.W * Grid.H)
	for src in sources:
		var s := spread(src.at, src.radius, opaque)
		var c: Vector3 = src.color
		for i in s.size():
			if s[i] > 0.0:
				out[i] += c * s[i]
	return out


static func level(c: Vector3) -> float:
	return maxf(0.0, maxf(c.x, maxf(c.y, c.z)))
