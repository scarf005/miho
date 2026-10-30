class_name Settings
extends RefCounted
## The player's options and key bindings, kept in a ConfigFile at `path`
## (nothing is written when it is empty). Bindings live in the InputMap; this
## reads and writes them through Keys.

const PATH := "user://settings.cfg"
const NAMES := ["volume", "crt", "zoom", "speed", "replay", "muted"]
## Cell scales; 0 fits the whole map.
const ZOOMS := [0.0, 1.0, 1.25, 1.5]
const SPEEDS := [1.0, 2.0, 4.0]

var path := PATH
## Master volume, 0-100.
var volume := 100
var crt := true
var zoom := 0.0
var speed := 1.0
var replay := true
var muted := false


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


func to_config() -> ConfigFile:
	var c := ConfigFile.new()
	for n in NAMES:
		c.set_value("settings", n, get(n))
	for action in Keys.ACTIONS:
		c.set_value("keys", action, Keys.keys_of(action))
	return c


## Takes what `c` holds, keeping defaults for what it lacks or holds wrongly,
## and binds every action's keys: the saved ones, else the defaults.
func from_config(c: ConfigFile) -> void:
	volume = clampi(int(c.get_value("settings", "volume", volume)), 0, 100)
	crt = bool(c.get_value("settings", "crt", crt))
	zoom = _one_of(c.get_value("settings", "zoom", zoom), ZOOMS, zoom)
	speed = _one_of(c.get_value("settings", "speed", speed), SPEEDS, speed)
	replay = bool(c.get_value("settings", "replay", replay))
	muted = bool(c.get_value("settings", "muted", muted))
	Keys.reset()
	for action in Keys.ACTIONS:
		var keys = c.get_value("keys", action, false)
		if keys is Array:
			Keys.bind(action, keys)


static func _one_of(v: Variant, allowed: Array, fallback: float) -> float:
	return float(v) if (v is float or v is int) and allowed.has(float(v)) else fallback


## Sets the master bus to the volume, silent when muted or at 0.
func apply_sound() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(volume / 100.0))
	AudioServer.set_bus_mute(0, muted or volume == 0)
