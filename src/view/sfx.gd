class_name Sfx
extends Node2D
## Plays a sound for each event the screen shows, from where it happens, so a
## noise heard in the dark comes from its side and fades with distance.

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
const WORDS := {
	"탁": &"step",
	"휙": &"foxfire",
	"웅": &"orb",
	"쾅": &"blast",
	"쿵": &"blast",
	"퍽": &"clash",
	"끽": &"hurt",
	"쨍": &"clash",
	"사각": &"step",
	"삐걱": &"click",
	"타닥": &"burn",
}

var listener: AudioListener2D
var _streams := {}
var _flat := {}


func _ready() -> void:
	listener = AudioListener2D.new()
	add_child(listener)
	listener.make_current()
	for n in NAMES:
		if ResourceLoader.exists(DIR % n):
			_streams[n] = load(DIR % n)
			var p := AudioStreamPlayer.new()
			p.stream = _streams[n]
			p.max_polyphony = 4
			add_child(p)
			_flat[n] = p


## A sound with no place: interface and storey changes.
func play(n: StringName) -> void:
	if _flat.has(n):
		_flat[n].play()


## A sound at a point in this node's space; quieter when heard, not seen.
func play_at(n: StringName, at: Vector2, volume_db := 0.0) -> void:
	if not _streams.has(n):
		return
	var p := AudioStreamPlayer2D.new()
	p.stream = _streams[n]
	p.position = at
	p.volume_db = volume_db
	p.max_distance = 1400.0
	p.attenuation = 1.2
	p.finished.connect(p.queue_free)
	add_child(p)
	p.play()


func on_event(e: Dictionary, at: Vector2) -> void:
	match e.t:
		&"move":
			play_at(&"step", at, -6.0)
		&"cast":
			play_at(&"orb" if e.cards.has(Cards.ORB) else &"foxfire", at)
		&"hit", &"burst", &"splash":
			play_at(&"blast", at)
		&"clash", &"snuff", &"absorb", &"claw", &"club":
			play_at(&"clash", at)
		&"hurt":
			play_at(&"hurt", at)
		&"die":
			play_at(&"fall", at)
		&"charge", &"notice":
			play_at(&"charge", at, -4.0)
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
		&"noise":
			play_at(WORDS.get(e.word, &"step"), at, -8.0)
