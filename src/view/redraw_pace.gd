class_name RedrawPace
extends Node
## Asks `term` to draw again: every frame while something on it moves, at once on input, and
## CALM_FRAME apart otherwise, when only the flames waver. A frame nobody asked for is not drawn
## (application/run/low_processor_mode), which is what a phone's battery and a web page feel.

const CALM_FRAME := 0.05

var term: Term
var _calm := 0.0


func _init(of: Term) -> void:
	term = of
	name = "RedrawPace"


func _process(delta: float) -> void:
	_calm += delta
	if _calm >= CALM_FRAME or _moving():
		_calm = 0.0
		term.queue_redraw()


func _input(_event: InputEvent) -> void:
	term.queue_redraw()


func _moving() -> bool:
	return (
		term._animating
		or term.sim != null
		or not (term._popups.is_empty() and term._flashes.is_empty() and term._ghosts.is_empty())
	)
