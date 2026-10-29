class_name Sfx
extends Node
## Plays a short sound for each animated event.

const DIR := "res://assets/sfx/%s.ogg"
const NAMES := [
	&"step",
	&"foxfire",
	&"burn",
	&"orb",
	&"blast",
	&"clash",
	&"hurt",
	&"fall",
	&"charge",
	&"card",
	&"ascend",
	&"win",
	&"lose",
	&"click",
]

var muted := false
var _players := {}


func _ready() -> void:
	for n in NAMES:
		if ResourceLoader.exists(DIR % n):
			var p := AudioStreamPlayer.new()
			p.stream = load(DIR % n)
			p.max_polyphony = 4
			add_child(p)
			_players[n] = p


func play(n: StringName) -> void:
	if not muted and _players.has(n):
		_players[n].play()


func on_event(e: Dictionary) -> void:
	match e.t:
		&"move":
			play(&"step")
		&"cast":
			play(&"orb" if e.cards.has(Cards.ORB) else &"foxfire")
		&"hit":
			play(&"blast")
		&"burst", &"splash":
			play(&"blast")
		&"clash", &"snuff", &"absorb":
			play(&"clash")
		&"hurt":
			play(&"hurt")
		&"die":
			play(&"fall")
		&"charge":
			play(&"charge")
		&"card", &"heal":
			play(&"card")
		&"ascend":
			play(&"ascend")
		&"won":
			play(&"win")
		&"lost":
			play(&"lose")
		&"omen", &"arrive":
			play(&"charge")
