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
	&"die",
	&"scream",
	&"cannon",
	&"mortar",
	&"explosion",
	&"pistol",
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
## What a spell's element or compound sounds like: its spray, and the sound a
## projectile carries on top of its own. 쇠 is a gun, told by its form (`_cast`).
const SLOT := {
	Cards.FIRE: &"flame",
	Cards.WATER: &"jet",
	Cards.WOOD: &"creak",
	Cards.EARTH: &"rumble",
	&"wildfire": &"flame",
	&"lava": &"rumble",
	&"shrapnel": &"grenade",
	&"frost": &"ice",
	&"rain": &"jet",
	&"steam": &"hiss",
	&"molten": &"flame",
	&"thorn": &"thorn",
	&"split": &"rumble",
	&"mud": &"splash",
	&"volcano": &"flame",
	&"furnace": &"flame",
	&"hail": &"ice",
	&"frostbloom": &"ice",
	&"swamp": &"splash",
	&"geyser": &"jet",
	&"quench": &"hiss",
	&"charthorn": &"thorn",
	&"palisade": &"thorn",
	&"beacon": &"flame",
	&"ironrain": &"grenade",
	&"ironroot": &"thorn",
	&"magpie": &"creak",
	&"mist": &"jet",
	&"sinkhole": &"rumble",
	&"newmoon": &"rumble",
	&"discord": &"charge",
	&"thunder": &"thunder",
	&"stillness": &"hiss",
	Cards.SAMSARA: &"card",
	Cards.CONQUEST: &"explosion",
	Cards.DRAGON: &"thunder",
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
	&"heat": -8.0,
	&"relight": -8.0,
	&"ignite": -10.0,
}
## The sound of what a jar holds when it breaks (Jars): a spill, a find, a tear, a fall of straw.
const JAR_SOUNDS := {
	&"water": &"splash",
	Jars.KIMCHI: &"tick",
	&"effigy": &"tear",
	&"scarecrow": &"rustle",
}
## The sound of a tile that forms where a compound reaches; the others are silent.
const BECOME := {World.BRIDGE: &"creak", World.SKY: &"fall"}
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
	"쨍그랑": &"shatter",
	"우지끈": &"fall",
	"사각": &"rustle",
	"바스락": &"rustle",
	"철벅": &"splash",
	"삐걱": &"creak",
	"드르륵": &"door",
	"둥": &"drum",
	"댕": &"gong",
	"찌익": &"tear",
	"타닥": &"burn",
	"캥": &"foxfire",
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
	for n in sounds_of(e):
		if e.t in GLOBAL:
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
	if e.get("spray", false) or (spell != null and spell.shape == Spell.LEAP):
		return out
	if spell == null:
		out.append(&"foxfire" if cast else &"blast")
	elif e.t == &"splash":
		out.append(&"explosion" if spell.mortar() else &"flame")
	elif spell.shape == Spell.SPRAY:
		out.append(_gun(spell) if spell.slots[0] == Cards.METAL else SLOT.get(spell.slots[0], &""))
	elif cast:
		out.append_array(_cast(spell))
	elif not spell.mortar():
		out.append_array(_impact(spell))
	out.assign(out.filter(func(n): return n != &""))
	return out


static func _gun(spell: Spell) -> StringName:
	return &"pistol" if spell.level() < 2 else &"shotgun"


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
		if SLOT.has(slot):
			out.append(SLOT[slot])
			break
	return out


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
		&"leap", &"swap":
			return &"foxfire"
		&"crumble":
			return &"fall"
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
		&"clash", &"snuff", &"claw", &"melee", &"push":
			return &"clash"
		&"absorb":
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
		&"root", &"freeze", &"sprout", &"guise":
			return &"root"
		&"stun":
			return &"stun"
		&"unroot":
			return &"rustle"
		&"unstun", &"unblind":
			return &"tick"
		&"become":
			return BECOME.get(e.get("tile", -1), &"")
		&"gas":
			return &"" if e.kind == Gas.SMOKE else &"hiss"
		&"scald", &"cool", &"douse", &"unmask", &"dry", &"quench", &"thaw":
			return &"hiss"
		&"stick", &"yelp":
			return &"foxfire"
		&"ignite", &"heat", &"relight", &"alight":
			return &"burn"
		&"hurt":
			return &"hurt"
		&"die":
			return &"die"
		&"charge", &"notice", &"feud":
			return &"charge"
		&"omen", &"arrive":
			return &"omen"
		&"wake":
			return &"stone"
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
