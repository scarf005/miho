class_name Settings
extends RefCounted
## The player's options and key bindings, kept in a ConfigFile at `path`
## (nothing is written when it is empty). Bindings live in the InputMap; this
## reads and writes them through Keys.

const PATH := "user://settings.cfg"
const NAMES := ["volume", "music", "crt", "zoom", "speed", "language"]
## Cell scales; 0 fits the whole map.
const ZOOMS := [0.0, 1.0, 1.25, 1.5]
const SPEEDS := [1.0, 2.0, 4.0]
## Bumped when default keys change. Files saved before version 2 hold every
## action's keys; the ones that were defaults then (RETIRED) give way to the
## new defaults, while keys the player chose stay.
const KEYS_VERSION := 2
const RETIRED := {&"explore": ["X"], &"log": ["P"]}

var path := PATH
## Master volume, 0-100.
var volume := 100
## Music volume, 0-100, under the master volume.
var music := 60
var crt := true
var zoom := 0.0
var speed := 1.0
## The language code (Lang.NAMES); with none saved, the system's.
var language := String(Lang.detect())
## The highlight replay of each storey left behind: off, with no row in the options
## and not read from the file, until it is wanted again.
var replay := false
## Saved spells: slot action (Keys.SLOTS) -> Spell.key().
var spells := {}


## Settings from the file at `from`, or the defaults; binds the keys either way.
static func load_from(from := PATH) -> Settings:
	var s := Settings.new()
	s.path = from
	var c := ConfigFile.new()
	s.from_config(c if c.load(from) == OK else ConfigFile.new())
	return s


func save() -> void:
	if path != "":
		to_config().save(path)


## The options, and the keys of the actions whose keys differ from the
## defaults, so that new defaults reach players who saved before.
func to_config() -> ConfigFile:
	var c := ConfigFile.new()
	for n in NAMES:
		c.set_value("settings", n, get(n))
	c.set_value("settings", "keys_version", KEYS_VERSION)
	for slot in spells:
		c.set_value("spells", slot, spells[slot])
	for action in Keys.ACTIONS:
		var keys := Keys.keys_of(action)
		if keys != Keys.ACTIONS[action][1]:
			c.set_value("keys", action, keys)
	return c


## Takes what `c` holds, keeping defaults for what it lacks or holds wrongly,
## and binds every action's keys: the saved ones, else the defaults. Saved
## keys of actions that no longer exist are ignored.
func from_config(c: ConfigFile) -> void:
	volume = clampi(int(c.get_value("settings", "volume", volume)), 0, 100)
	music = clampi(int(c.get_value("settings", "music", music)), 0, 100)
	crt = bool(c.get_value("settings", "crt", crt))
	zoom = _one_of(c.get_value("settings", "zoom", zoom), ZOOMS, zoom)
	speed = _one_of(c.get_value("settings", "speed", speed), SPEEDS, speed)
	var code = c.get_value("settings", "language", language)
	language = code if code is String and Lang.NAMES.has(StringName(code)) else language
	spells = {}
	for slot in Keys.SLOTS:
		var key = c.get_value("spells", slot, "")
		if key is String and Spell.from_key(key) != null:
			spells[slot] = key
	Keys.reset()
	var old: bool = c.get_value("settings", "keys_version", 1) < KEYS_VERSION
	for action in Keys.ACTIONS:
		var keys = c.get_value("keys", action, false)
		if keys is Array and not (old and keys == RETIRED.get(action, [])):
			Keys.bind(action, keys)


static func _one_of(v: Variant, allowed: Array, fallback: float) -> float:
	return float(v) if (v is float or v is int) and allowed.has(float(v)) else fallback


## Shows every string in the language.
func apply_language() -> void:
	Lang.use(language)


## Sets the master bus to the volume, silent at 0.
func apply_sound() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(volume / 100.0))
	AudioServer.set_bus_mute(0, volume == 0)
