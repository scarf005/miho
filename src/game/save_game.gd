class_name SaveGame
extends RefCounted
## A run kept in a ConfigFile at `path` (nothing is read or written when it is
## empty). A run is fixed by its seed and the actions given to World.act, so
## that is all the file holds; `replay` plays them again to rebuild the world,
## the message log and the kill count. Beside it, in a file of its own, lie the last state
## written (Snapshot) and, once a run has gone back to one, the state its actions start from.
## `replay` starts from the last state and plays only the actions after it; a run the rules
## no longer fit goes on from the last state, without those actions.
## A round played waits in memory until `flush` (Autosave) writes what has changed.

const PATH := "user://save.cfg"
## Bumped when a change to the rules would make old actions play differently.
const VERSION := 86
## What the file of states adds to `path`.
const STATES := ".state"
## Actions between two states; a new storey writes one too.
const STATE_EVERY := 25
const ROLLED_BACK := "마지막 저장 지점으로 돌아왔다"

var path := PATH
var seed_value := 0
var actions: Array[Dictionary] = []
var kills := 0
## The travel exclusions of the storey Miho is on (Exclusions.zones). They are
## the player's marks, not actions, so they play no part in the replay.
var exclusions := {}
## What the replay has rebuilt so far, and how many actions it has played.
var world: World
var messages := Messages.new()
var played := 0
## {seed, last, base}: each of the last two a state, {world, log, kills, depth, played},
## `played` the count of the actions already in it.
var states := {}
## Whether the actions start from the state `base` in place of the seed.
var based := false
## Whether the actions no longer fit, so that `begin` goes back to the last state.
var stale := false
## What has changed since the files were written.
var _actions_changed := false
var _states_changed := false


func _init(at := PATH, seed_of := 0) -> void:
	path = at
	seed_value = seed_of


## The run saved at `from`, or null when there is none, or the file does not hold a run of
## this version and no state to go on from. The actions are not played yet.
static func load_from(from := PATH) -> SaveGame:
	var c := ConfigFile.new()
	if from == "" or c.load(from) != OK:
		return null
	var seed_of: Variant = c.get_value("run", "seed", false)
	var count: Variant = c.get_value("run", "kills", false)
	var list: Variant = c.get_value("run", "actions", false)
	var s := SaveGame.new(from, seed_of if seed_of is int else 0)
	s.states = _read_states(from + STATES, s.seed_value)
	s.based = c.get_value("run", "based", false)
	var zones: Variant = c.get_value("run", "exclusions", {})
	if (
		zones is Dictionary
		and zones.keys().all(func(k): return k is Vector2i)
		and zones.values().all(func(r): return r is int)
	):
		s.exclusions = zones
	if (
		c.get_value("run", "version", 0) != VERSION
		or not (seed_of is int and count is int and list is Array)
		or not list.all(func(a): return a is Dictionary and _shaped(a))
		or (s.based and not s.states.has("base"))
	):
		s.stale = true
		return s if s.states.has("last") else null
	s.kills = count
	s.actions.assign(list)
	return s


## Takes an action that was played, or removes the file at once when the run is `over`.
func record(action: Dictionary, total: int, over: bool) -> void:
	if over:
		erase()
		return
	actions.append(action.duplicate(true))
	kills = total
	_actions_changed = true


## Takes a state of the round just played, with its lines in `log`, when one is due.
func keep(w: World, log: Messages) -> void:
	if w.outcome == &"" and _state_due(w):
		states.last = {
			world = Snapshot.of(w),
			log = log.saved(),
			kills = kills,
			depth = w.depth,
			played = actions.size(),
		}
		_states_changed = true


## Writes what has changed since the last time.
func flush() -> void:
	if _actions_changed:
		write()
	if _states_changed:
		_write_states()


func write() -> void:
	_actions_changed = false
	if path == "":
		return
	var c := ConfigFile.new()
	c.set_value("run", "version", VERSION)
	c.set_value("run", "seed", seed_value)
	c.set_value("run", "kills", kills)
	c.set_value("run", "actions", actions)
	c.set_value("run", "exclusions", exclusions)
	c.set_value("run", "based", based)
	c.save(path)


## Removes the file: the run is over, or a new one replaces it.
func erase() -> void:
	_actions_changed = false
	_states_changed = false
	for file in [path, path + STATES]:
		if path != "" and FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)


## Starts playing the actions again on a new world, from the seed or the state they start from.
func begin() -> void:
	played = 0
	messages = Messages.new()
	if stale:
		fall_back()
		return
	var last: Dictionary = states.get("last", {})
	if last.get("played", actions.size() + 1) <= actions.size():
		played = last.played
		_start_from(last)
		return
	states.erase("last")
	if based:
		_start_from(states.base)
	else:
		world = World.create(seed_value)


func _start_from(state: Dictionary) -> void:
	world = Snapshot.world(state.world)
	messages.lines.assign(state.log.duplicate(true))


## Gives up the actions and goes on from the last state; false when there is none.
func fall_back() -> bool:
	if not states.has("last"):
		return false
	stale = false
	states.base = states.last
	based = true
	kills = states.base.kills
	states.base.played = 0
	actions.clear()
	begin()
	messages.add_text(ROLLED_BACK, world.round_no)
	states.base.log = messages.saved()
	write()
	_write_states()
	return true


## Plays the next action again, filling `world` and `messages`. One that does not fit the
## rules goes back to the last state; false when there is none.
func step() -> bool:
	var action := actions[played]
	if not world.can(action):
		return fall_back()
	var before := world.clone()
	messages.add_round(before, world, world.act(action))
	played += 1
	return true


## All of the actions at once; false when one does not fit the rules and no state is left.
func replay() -> bool:
	begin()
	while played < actions.size():
		if not step():
			return false
	return true


func _state_due(w: World) -> bool:
	var last: Dictionary = states.get("last", {})
	var due: bool = last.is_empty() or actions.size() % STATE_EVERY == 0 or last.depth != w.depth
	return path != "" and due


func _write_states() -> void:
	_states_changed = false
	if path == "":
		return
	states.seed = seed_value
	var f := FileAccess.open_compressed(
		path + STATES, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD
	)
	if f != null:
		f.store_var(states)


## The states at `from`, when they are of the run of `seed_of`.
static func _read_states(from: String, seed_of: int) -> Dictionary:
	var f := FileAccess.open_compressed(from, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	var v: Variant = f.get_var() if f != null else {}
	return v if v is Dictionary and v.get("seed") == seed_of else {}


## Whether the action has the parts World.can reads, of the right types.
static func _shaped(action: Dictionary) -> bool:
	match action.get("t"):
		&"wait":
			return true
		&"move", &"close":
			return action.get("dir") is Vector2i
		&"cast":
			var spells: Variant = action.get("spells")
			return spells is Array and spells.all(_spell_shaped)
		&"dispel":
			return action.get("kind") is StringName
		&"cheat":
			return Cheat.shaped(action)
	return false


static func _spell_shaped(spell: Variant) -> bool:
	return (
		spell is Dictionary
		and spell.get("dir") is Vector2i
		and spell.get("cards") is Array
		and spell.cards.all(func(c): return c is StringName)
	)
