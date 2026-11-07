class_name Shake
extends RefCounted
## The map shaking when the ground gives way or a creature slams into a wall. Only the
## view: no rule reads it.

## What shakes the map: a collapse (`quake`), a sinkhole, whose tiles become sky, and a
## push into a wall (Fall `crash`).
const TYPES := [&"quake", &"become", &"crash"]
## How far the map moves at most, in screen units, and how long it shakes, in seconds.
const AMOUNT := 2.0
const LIFE := 0.3
## Oscillations a second on each axis.
const RATE := Vector2(37.0, 29.0)


## Whether event `e` shakes the map.
static func by(e: Dictionary) -> bool:
	return e.t in TYPES and e.get("tile", World.SKY) == World.SKY


## How far the map is moved `age` seconds after the shake began, fading to none.
static func offset(age: float) -> Vector2:
	if age < 0.0 or age >= LIFE:
		return Vector2.ZERO
	var fade := 1.0 - age / LIFE
	return Vector2(sin(age * RATE.x), cos(age * RATE.y)) * AMOUNT * fade
