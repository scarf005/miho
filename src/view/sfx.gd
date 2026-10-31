class_name Sfx
extends Node2D
## Plays a sound for each event the screen shows, from where it happens, so a
## noise heard in the dark comes from its side and fades with distance. The
## music loops under them from the start, at its own volume.

const DIR := "res://assets/sfx/%s.ogg"
const MUSIC := "res://assets/music/ambient.ogg"
## Music level at full music volume, against the sound effects.
const MUSIC_DB := 0.0
const FIRE := "res://assets/sfx/fire_loop.ogg"
## How far in tiles a burning tile is heard, and how long its crackle fades.
const FIRE_RANGE := 10
const FIRE_FADE := 0.5
const SILENT_DB := -40.0
## The crackle sits above the other sounds, since distance softens it.
const FIRE_DB := 6.0
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
	&"deny",
	&"gong",
	&"trap",
	&"find",
	&"door",
	&"root",
	&"stun",
	&"absorb",
	&"hiss",
]
## Events heard the same wherever they happen.
const GLOBAL := [&"card", &"heal", &"ascend", &"fall", &"won", &"lost", &"omen", &"arrive"]
## How loud an event sounds from its place, in dB; those left out play at full.
const LEVEL := {
	&"move": -6.0,
	&"charge": -4.0,
	&"notice": -4.0,
	&"noise": -8.0,
	&"push": -4.0,
	&"smash": -4.0,
	&"douse": -4.0,
	&"scald": -4.0,
	&"grow": -2.0,
	&"sprout": -2.0,
	&"gas": -6.0,
	&"cool": -8.0,
	&"heat": -8.0,
	&"relight": -8.0,
	&"ignite": -10.0,
}
const WORDS := {
	"탁": &"step",
	"휙": &"foxfire",
	"웅": &"orb",
	"쾅": &"blast",
	"탕": &"blast",
	"화르륵": &"burn",
	"쿵": &"blast",
	"퍽": &"clash",
	"끽": &"hurt",
	"쨍": &"clash",
	"사각": &"step",
	"삐걱": &"click",
	"드르륵": &"door",
	"둥": &"blast",
	"댕": &"gong",
	"찌익": &"clash",
	"타닥": &"burn",
}

var listener: AudioListener2D
var _streams := {}
var _flat := {}
var _music: AudioStreamPlayer
var _fire: AudioStreamPlayer2D
var _fade: Tween
var _lit := false


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
	if ResourceLoader.exists(MUSIC):
		_music = AudioStreamPlayer.new()
		_music.stream = load(MUSIC)
		add_child(_music)
		_music.play()
	if ResourceLoader.exists(FIRE):
		_fire = AudioStreamPlayer2D.new()
		_fire.stream = load(FIRE)
		_fire.max_distance = FIRE_RANGE * Term.CELL.y
		_fire.attenuation = 1.2
		add_child(_fire)


## Sets the music volume, 0-100; silent at 0.
func set_music(volume: int) -> void:
	if _music != null:
		_music.volume_db = maxf(linear_to_db(volume / 100.0) + MUSIC_DB, -80.0)


## The burning tile Miho sees nearest, within FIRE_RANGE, or (-1, -1).
static func nearest_fire(w: World) -> Vector2i:
	var near := Vector2i(-1, -1)
	var best := FIRE_RANGE * FIRE_RANGE + 1
	for p: Vector2i in w.burning:
		var d := (p - w.player().pos).length_squared()
		if w.seen[Grid.index(p)] == 1 and d < best:
			near = p
			best = d
	return near


## Crackles from the nearest fire in sight, fading in when one starts to burn
## and out when none is left. `centre` maps a tile to its point in this space.
func watch(w: World, centre: Callable) -> void:
	if _fire == null:
		return
	var at := nearest_fire(w)
	var on := at != Vector2i(-1, -1)
	if on:
		_fire.position = centre.call(at)
		listener.position = centre.call(w.player().pos)
	if on == _lit:
		return
	_lit = on
	if _fade != null:
		_fade.kill()
	if on and not _fire.playing:
		_fire.volume_db = SILENT_DB
		_fire.play()
	_fade = create_tween()
	_fade.tween_property(_fire, "volume_db", FIRE_DB if on else SILENT_DB, FIRE_FADE)
	if not on:
		_fade.tween_callback(_fire.stop)


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
	var n := sound_of(e)
	if n == &"":
		return
	if e.t in GLOBAL:
		play(n)
	else:
		play_at(n, at, LEVEL.get(e.t, 0.0))


## The sound an event makes, or &"" for none. A noise Miho sees is never told
## as a noise, so what she sees sounds from the event that made it.
static func sound_of(e: Dictionary) -> StringName:
	match e.t:
		&"move":
			return &"step"
		&"cast":
			return &"orb" if e.cards.has(Cards.ORB) else &"foxfire"
		&"hit", &"burst", &"splash":
			return &"" if e.get("spray", false) else &"blast"
		&"drum":
			return &"" if e.wet else &"blast"
		&"clash", &"snuff", &"claw", &"melee", &"push", &"smash":
			return &"clash"
		&"absorb":
			return &"absorb"
		&"grow", &"card", &"heal":
			return &"card"
		&"trap":
			return &"gong" if e.kind == World.TRAP_ALARM else &"trap"
		&"find":
			return &"find"
		&"open", &"close":
			return &"door"
		&"root", &"freeze", &"sprout":
			return &"root"
		&"stun":
			return &"stun"
		&"gas":
			return &"" if e.kind == Gas.SMOKE else &"hiss"
		&"scald", &"cool", &"douse":
			return &"hiss"
		&"stick":
			return &"foxfire"
		&"ignite", &"heat", &"relight":
			return &"burn"
		&"hurt":
			return &"hurt"
		&"die":
			return &"fall"
		&"charge", &"notice", &"omen", &"arrive":
			return &"charge"
		&"ascend":
			return &"ascend"
		&"fall":
			return &"fall" if e.has("depth") else &""
		&"won":
			return &"win"
		&"lost":
			return &"lose"
		&"noise":
			return WORDS.get(e.word, &"step")
	return &""
