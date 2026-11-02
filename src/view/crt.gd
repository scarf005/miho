class_name Crt
extends RefCounted
## The strength of crt.gdshader, 0-100, as its uniforms, and the barrel curve it
## bends the screen with, so the pointer lands on what the curved screen shows
## under it. Points are in a viewport of size `view`.

const MIDDLE := 50
## The uniforms at MIDDLE, where 0 has none of the effect.
const NOW := {
	&"curve": 0.02, &"fringe": 0.0006, &"glow": 0.35, &"scan": 0.18, &"grille": 0.08, &"rim": 0.15
}
## The uniforms at 100: the effect before 2026-11-02 (abb9c86, d1f0c31, 02ff8a0).
const FULL := {
	&"curve": 0.06, &"fringe": 0.0012, &"glow": 0.55, &"scan": 0.28, &"grille": 0.12, &"rim": 0.35
}


## Each uniform at `strength`: none at 0, NOW at MIDDLE, FULL at 100, straight lines between.
static func params(strength: int) -> Dictionary:
	var up := strength > MIDDLE
	var t := float(strength - MIDDLE) / MIDDLE if up else float(strength) / MIDDLE
	var out := {}
	for k in NOW:
		out[k] = lerpf(NOW[k] if up else 0.0, FULL[k] if up else NOW[k], t)
	return out


## The flat point drawn where the curved screen shows `seen`.
static func flat(seen: Vector2, view: Vector2, strength: int) -> Vector2:
	var c := seen / view * 2.0 - Vector2.ONE
	c *= 1.0 + params(strength).curve * c.dot(c)
	return (c * 0.5 + Vector2(0.5, 0.5)) * view


## Where the curved screen shows the flat point `drawn`; inverts `flat`.
static func seen(drawn: Vector2, view: Vector2, strength: int) -> Vector2:
	var curve: float = params(strength).curve
	var target := drawn / view * 2.0 - Vector2.ONE
	var c := target
	for i in 8:
		c = target / (1.0 + curve * c.dot(c))
	return (c * 0.5 + Vector2(0.5, 0.5)) * view
