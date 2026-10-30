class_name Crt
extends RefCounted
## The barrel curve of crt.gdshader, so the pointer lands on what the curved
## screen shows under it. Points are in a viewport of size `view`.

const CURVE := 0.06


## The flat point drawn where the curved screen shows `seen`.
static func flat(seen: Vector2, view: Vector2) -> Vector2:
	var c := seen / view * 2.0 - Vector2.ONE
	c *= 1.0 + CURVE * c.dot(c)
	return (c * 0.5 + Vector2(0.5, 0.5)) * view


## Where the curved screen shows the flat point `drawn`; inverts `flat`.
static func seen(drawn: Vector2, view: Vector2) -> Vector2:
	var target := drawn / view * 2.0 - Vector2.ONE
	var c := target
	for i in 8:
		c = target / (1.0 + CURVE * c.dot(c))
	return (c * 0.5 + Vector2(0.5, 0.5)) * view
