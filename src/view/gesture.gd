class_name Gesture
extends RefCounted
## What one finger on the screen means: a tap, a long press (hold), a swipe in
## one of 8 directions, or a drag along one axis. A second finger cancels the
## gesture until all are up. Each call returns the events it ends or starts:
## {t = &"tap" | &"hold", pos}, {t = &"swipe", dir, from} and {t = &"drag", delta, by, from}:
## `delta` is the travel along the axis the drag locked to, `by` the whole of it.
## Distances are in CSS pixels times `scale`, the screen units per CSS pixel.

## How far a finger may wander and still be a tap or a hold.
const SLOP := 12.0
## How far a finger must travel to make a swipe.
const SWIPE := 24.0
## Seconds a finger rests before it is a hold.
const HOLD := 0.45
## Directions by screen angle, 45 degrees apart from east, clockwise.
const DIRS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(1, 1),
	Vector2i(0, 1),
	Vector2i(-1, 1),
	Vector2i(-1, 0),
	Vector2i(-1, -1),
	Vector2i(0, -1),
	Vector2i(1, -1),
]

var scale := 1.0
var _fingers := {}
var _dead := false
var _from := Vector2.ZERO
var _last := Vector2.ZERO
var _since := 0.0
var _axis := -1
var _held := false


## The direction a movement `v` points to, of 8.
static func dir_of(v: Vector2) -> Vector2i:
	return DIRS[posmod(roundi(v.angle() / (PI / 4.0)), 8)]


## Whether a finger is on the screen. The browser reports the drag of a finger
## as pointer motion too.
func touching() -> bool:
	return not _fingers.is_empty()


func down(id: int, pos: Vector2, now: float) -> Array:
	_fingers[id] = true
	if _fingers.size() > 1:
		_dead = true
		return []
	_dead = false
	_from = pos
	_last = pos
	_since = now
	_axis = -1
	_held = false
	return []


func move(id: int, pos: Vector2, _now: float) -> Array:
	if _dead or not _fingers.has(id):
		return []
	var v := pos - _from
	if _axis < 0:
		if _held or v.length() <= SLOP * scale:
			return []
		_axis = 0 if absf(v.x) > absf(v.y) else 1
	var delta := Vector2(pos.x - _last.x, 0.0) if _axis == 0 else Vector2(0.0, pos.y - _last.y)
	var by := pos - _last
	_last = pos
	return [{t = &"drag", delta = delta, by = by, from = _from}] if delta != Vector2.ZERO else []


func up(id: int, pos: Vector2, _now: float) -> Array:
	if not _fingers.erase(id) or _dead:
		_dead = not _fingers.is_empty()
		return []
	var v := pos - _from
	if _held:
		return []
	if _axis < 0:
		return [{t = &"tap", pos = _from}]
	if v.length() >= SWIPE * scale:
		return [{t = &"swipe", dir = dir_of(v), from = _from}]
	return []


## A finger that has rested still for HOLD seconds is a hold, once.
func tick(now: float) -> Array:
	if _fingers.size() != 1 or _dead or _held or _axis >= 0 or now - _since < HOLD:
		return []
	_held = true
	return [{t = &"hold", pos = _from}]
