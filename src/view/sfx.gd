class_name Sfx
extends Node2D
## Plays a sound for each event the screen shows, from where it happens, so a
## noise heard in the dark comes from its side and fades with distance. The
## music's tracks follow one another under them, at their own volume.

const DIR := "res://assets/sfx/%s.ogg"
const MUSIC := [
	"res://assets/music/ambient.ogg",
	"res://assets/music/bell.ogg",
	"res://assets/music/bow.ogg",
	"res://assets/music/drum.ogg",
]
## The creatures whose sight is a bad sign, and the sound of a bad sign, heard from nowhere.
const DREADED := [&"underworld", &"undead"]
const EERIE := &"eerie"
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
	&"tick",
	&"bite",
	&"door",
	&"root",
	&"stun",
	&"absorb",
	&"hiss",
	&"rustle",
	&"splash",
	&"creak",
	&"warn",
	&"shatter",
	&"tear",
	&"drum",
	&"page",
	&"stone",
	&"omen",
	&"dread",
	&"eerie",
	&"die",
	&"scream",
	&"cannon",
	&"mortar",
	&"explosion",
	&"pistol",
	&"rifle",
	&"shotgun",
	&"grenade",
	&"clang",
	&"flame",
	&"jet",
	&"ice",
	&"thunder",
	&"rumble",
	&"thorn",
	&"orb3",
	&"orb4",
	&"orb5",
]
## The events a spell's own sounds come from (`_spell_sounds`).
const SPELL_EVENTS := [&"cast", &"hit", &"burst", &"splash"]
## What a spell's element sounds like, as a compound has its `sound` (Cards.COMPOUND): its
## spray, and the sound a projectile carries on top of its own. 쇠 is a gun, told by its
## form (`_cast`).
const SLOT := {
	Cards.FIRE: &"flame",
	Cards.WATER: &"jet",
	Cards.WOOD: &"creak",
	Cards.EARTH: &"rumble",
}
## An orb's cast sound by its 구 count, and what it strikes with.
const ORB_CAST := [&"orb", &"orb", &"orb3", &"orb4", &"orb5"]
const ORB_HIT := [
	[&"blast"],
	[&"blast"],
	[&"blast", &"rumble"],
	[&"explosion"],
	[&"explosion", &"rumble"],
]
## Events heard the same wherever they happen. `spot` is the view's own event:
## Miho sees something useful for the first time.
const GLOBAL := [
	&"spot",
	&"card",
	&"heal",
	&"altar",
	&"creak",
	&"read",
	&"ascend",
	&"fall",
	&"won",
	&"lost",
	&"omen",
	&"arrive",
	&"cheat"
]
## How loud an event sounds from its place, in dB; those left out play at full.
## A step is -6 dB on bare ground and louder by STEP_DB for each tile its tread is heard.
const STEP_DB := 1.5
const STEP_TILES := 4
const LEVEL := {
	&"move": -6.0,
	&"charge": -4.0,
	&"notice": -4.0,
	&"feud": -4.0,
	&"noise": -8.0,
	&"push": -4.0,
	&"pull": -4.0,
	&"smash": -4.0,
	&"jar": -4.0,
	&"douse": -4.0,
	&"scald": -4.0,
	&"grow": -2.0,
	&"sprout": -2.0,
	&"gas": -6.0,
	&"cool": -8.0,
	&"dry": -8.0,
	&"quench": -8.0,
	&"thaw": -8.0,
	&"unroot": -8.0,
	&"unstun": -8.0,
	&"unblind": -8.0,
	&"untalon": -8.0,
	&"unflame": -8.0,
	&"sleep": -8.0,
	&"heat": -8.0,
	&"relight": -8.0,
	&"ignite": -10.0,
}
## The sound of what a jar holds when it breaks (Jars): a spill, a find, a tear, a fall of
## straw, a scatter of salt, a clatter of beans, a thud of coals. A stun and the coals' heat
## make their own sounds, so beans and coals add none of those.
const JAR_SOUNDS := {
	&"water": &"splash",
	Jars.KIMCHI: &"tick",
	&"effigy": &"tear",
	&"scarecrow": &"rustle",
	&"salt": &"rustle",
	&"beans": &"tick",
	&"coals": &"stone",
}
## The sound of a tile that forms where a compound reaches; the others are silent.
const BECOME := {World.BRIDGE: &"creak", World.SKY: &"fall"}
## The sound of a tile an element changes (Terrain.react), by the element.
const REACT := {
	Cards.METAL: &"rustle",
	Cards.EARTH: &"splash",
	Cards.WATER: &"root",
	Cards.FIRE: &"hiss",
}
const WORDS := {
	"탁": &"step",  # i18n: keep
	"휙": &"foxfire",  # i18n: keep
	"웅": &"orb",  # i18n: keep
	"쾅": &"blast",  # i18n: keep
	"콰르릉": &"thunder",  # i18n: keep
	"탕": &"blast",  # i18n: keep
	"화르륵": &"burn",  # i18n: keep
	"쿵": &"blast",  # i18n: keep
	"퍽": &"clash",  # i18n: keep
	"끽": &"hurt",  # i18n: keep
	"쨍": &"clash",  # i18n: keep
	"쨍그랑": &"shatter",  # i18n: keep
	"우지끈": &"fall",  # i18n: keep
	"사각": &"rustle",  # i18n: keep
	"바스락": &"rustle",  # i18n: keep
	"철벅": &"splash",  # i18n: keep
	"삐걱": &"creak",  # i18n: keep
	"드르륵": &"door",  # i18n: keep
	"둥": &"drum",  # i18n: keep
	"댕": &"gong",  # i18n: keep
	"찌익": &"tear",  # i18n: keep
	"푸드덕": &"hiss",  # i18n: keep
	"타닥": &"burn",  # i18n: keep
	"캥": &"foxfire",  # i18n: keep
}

## Every stream is read once for the whole run, not once per Sfx.
static var _streams := {}
static var _fire_stream: AudioStream

var listener: AudioListener2D
var _flat := {}
var _music: AudioStreamPlayer
var _track := randi() % MUSIC.size()
var _dreaded := {}
var _fire: AudioStreamPlayer2D
var _fade: Tween
var _lit := false


func _ready() -> void:
	listener = AudioListener2D.new()
	add_child(listener)
	listener.make_current()
	if _streams.is_empty():
		for n in NAMES:
			if ResourceLoader.exists(DIR % n):
				_streams[n] = load(DIR % n)
		for track: String in MUSIC:
			if ResourceLoader.exists(track):
				_streams[track] = load(track)
		_fire_stream = load(FIRE) if ResourceLoader.exists(FIRE) else null
	_music = AudioStreamPlayer.new()
	_music.finished.connect(_next_track)
	add_child(_music)
	_next_track()
	if _fire_stream != null:
		_fire = AudioStreamPlayer2D.new()
		_fire.stream = _fire_stream
		_fire.max_distance = FIRE_RANGE * Term.CELL.y
		_fire.attenuation = 1.2
		add_child(_fire)


func _next_track() -> void:
	_track = (_track + 1) % MUSIC.size()
	_music.stream = _streams.get(MUSIC[_track])
	_music.play()


## Sets the music volume, 0-100; silent at 0.
func set_music(volume: int) -> void:
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
	if not dreaded(w, _dreaded).is_empty():
		play(EERIE)
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
	if not _streams.has(n):
		return
	if not _flat.has(n):
		var p := AudioStreamPlayer.new()
		p.stream = _streams[n]
		p.max_polyphony = 4
		add_child(p)
		_flat[n] = p
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
	for n in sounds_of(e):
		if e.t in GLOBAL or n == EERIE:
			play(n)
		else:
			play_at(n, at, level_of(e))


## How loud an event sounds from its place, in dB.
static func level_of(e: Dictionary) -> float:
	var db: float = LEVEL.get(e.t, 0.0)
	return db + STEP_DB * mini(e.loud, STEP_TILES) if e.t == &"move" else db


## Every sound an event makes: its own, the layers of a spell's cast and
## impact, and the bright chime when a peach raises the most health.
static func sounds_of(e: Dictionary) -> Array[StringName]:
	if e.t in SPELL_EVENTS:
		return _spell_sounds(e)
	var out: Array[StringName] = []
	if sound_of(e) != &"":
		out.append(sound_of(e))
	if e.t == &"heal" and e.get("grew", false):
		out.append(&"find")
	if _ominous(e):
		out.append(EERIE)
	return out


## Whether the event is a bad sign: a statue wakes or a guise is seen through.
static func _ominous(e: Dictionary) -> bool:
	return e.t == &"wake" or e.t == &"unmask" and e.get("why") == &"beside"


## The creatures of the dead in sight of Miho that were never in sight before, now
## noted in `known`.
static func dreaded(w: World, known: Dictionary) -> Array[Actor]:
	var out: Array[Actor] = []
	for id: int in Travel.in_sight(w):
		var a := w.actor(id)
		var key := [w.get_instance_id(), id]
		if not known.has(key) and a.info().get("group") in DREADED:
			known[key] = true
			out.append(a)
	return out


## The sounds a spell makes where it is cast and where it strikes, heaviest
## first: none for a spray's hit (its cast is heard), a leap, or a 비격진's
## strike (its burst is heard). A projectile adds the sound of the element it
## carries. 쇠 makes a gun: a bullet cracks and hits metal, 철갑탄 and a
## cannonball fire a cannon, and a 비격진 a mortar that bursts in an explosion.
static func _spell_sounds(e: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	var spell := Spell.make(e.get("cards", []))
	var cast: bool = e.t == &"cast"
	if cast and e.get("bolt", false):
		out.append(&"thunder")
		return out
	if e.get("spray", false) or (spell != null and spell.shape == Spell.LEAP):
		return out
	if spell == null:
		out.append(&"foxfire" if cast else &"blast")
	elif e.t == &"splash":
		out.append(&"explosion" if spell.mortar() else (&"flame" if spell.has(Cards.FIRE) else &""))
	elif spell.shape == Spell.SPRAY:
		out.append(_gun(spell) if spell.slots[0] == Cards.METAL else _slot(spell.slots[0]))
	elif cast:
		out.append_array(_cast(spell))
	elif not spell.mortar():
		out.append_array(_impact(spell))
	out.assign(out.filter(func(n): return n != &""))
	return out


static func _gun(spell: Spell) -> StringName:
	return [&"pistol", &"rifle", &"shotgun", &"shotgun", &"shotgun"][spell.level() - 1]


## A projectile's cast sound, and the sound of its first element on top.
static func _cast(spell: Spell) -> Array[StringName]:
	var out: Array[StringName] = []
	if spell.mortar():
		return [&"mortar"]
	if spell.pierces() or (spell.orb and spell.has(Cards.METAL)):
		out.append(&"cannon")
	elif spell.has(Cards.METAL):
		out.append(&"pistol")
	else:
		out.append(ORB_CAST[spell.count(Cards.ORB) - 1] if spell.orb else &"foxfire")
	for slot in spell.elements():
		if _slot(slot) != &"":
			out.append(_slot(slot))
			break
	return out


## What slot `c` sounds like, or nothing.
static func _slot(c: StringName) -> StringName:
	return SLOT.get(c, Cards.COMPOUND[c].get("sound", &"") if Cards.COMPOUND.has(c) else &"")


## What a projectile sounds like where it strikes a creature or a wall.
static func _impact(spell: Spell) -> Array[StringName]:
	var out: Array[StringName] = []
	if spell.orb:
		out.assign(ORB_HIT[spell.count(Cards.ORB) - 1])
	elif not spell.has(Cards.METAL):
		out.append(&"blast")
	if spell.has(Cards.METAL):
		out.append(&"clang")
	return out


## The sound an event makes, or &"" for none. A noise Miho sees is never told
## as a noise, so what she sees sounds from the event that made it; a step
## sounds by the word of the tile stepped onto.
static func sound_of(e: Dictionary) -> StringName:
	match e.t:
		&"move":
			return WORDS.get(e.word, &"step")
		&"leap":
			return &"hiss"
		&"swap":
			return &"foxfire"
		&"ally":
			return &"stone" if Raise.undead(e.kind) else &"foxfire"
		&"crumble":
			return &"fall"
		&"pull":
			return &"splash"
		&"cast", &"hit", &"burst", &"splash":
			var sounds := _spell_sounds(e)
			return &"" if sounds.is_empty() else sounds[0]
		&"blast":
			return &"blast"
		&"drum":
			return &"" if e.wet else &"drum"
		&"smash":
			return &"blast" if Terrain.wall(e.was) else WORDS[Tiles.of(e.was, "hit")[1]]
		&"collapse":
			return &"blast"
		&"clash", &"snuff", &"claw", &"melee", &"push", &"crash":
			return &"clash"
		&"absorb", &"resist":
			return &"absorb"
		&"heal":
			return &"bite" if e.get("peach", false) or e.get("kimchi", false) else &"card"
		&"jar":
			return JAR_SOUNDS[e.what]
		&"grow", &"card", &"altar", &"creak":
			return &"card"
		&"read", &"scroll":
			return &"page"
		&"trap":
			return &"gong" if e.kind == World.TRAP_ALARM else &"trap"
		&"find":
			return &"tick" if e.kind == World.DOOR else &"warn"
		&"spot":
			return &"tick"
		&"cheat":
			return &"click"
		&"open", &"close":
			return &"door"
		&"root", &"freeze", &"sprout", &"guise", &"talon", &"raise":
			return &"root"
		&"stun":
			return &"stun"
		&"unroot", &"cloak":
			return &"rustle"
		&"unstun", &"unblind", &"untalon":
			return &"tick"
		&"become":
			if e.has("element"):
				return REACT[e.element]
			return BECOME.get(e.get("tile", -1), &"")
		&"gas":
			return &"" if e.kind == Gas.SMOKE else &"hiss"
		&"scald", &"cool", &"douse", &"unmask", &"uncloak", &"dry", &"quench", &"thaw", &"sleep":
			return &"hiss"
		&"unflame", &"unraise":
			return &"hiss"
		&"fade":
			return &"hiss" if e.get("dropped", false) else &""
		&"flame":
			return &"flame"
		&"stick", &"yelp":
			return &"foxfire"
		&"ignite", &"heat", &"relight", &"alight":
			return &"burn"
		&"hurt":
			return &"hurt"
		&"die":
			return &"hiss" if e.get("gone", false) else &"die"
		&"charge", &"notice", &"feud":
			return &"charge"
		&"omen":
			return &"omen"
		&"arrive":
			return &"dread"
		&"wake", &"rise":
			return &"stone"
		&"curse":
			return EERIE
		&"ascend":
			return &"ascend"
		&"fall":
			return &"scream" if e.has("depth") else &""
		&"won":
			return &"win"
		&"lost":
			return &"lose"
		&"noise":
			return WORDS.get(e.word, &"charge" if Bestiary.shouted(e.word) else &"step")
	return &""
