class_name SaveGame
extends RefCounted
## A run kept in a ConfigFile at `path` (nothing is read or written when it is
## empty). A run is fixed by its seed and the actions given to World.act, so
## that is all the file holds; `replay` plays them again to rebuild the world,
## the message log and the kill count.

const PATH := "user://save.cfg"
## Bumped when a change to the rules would make old actions play differently.
const VERSION := 34

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


func _init(at := PATH, seed_of := 0) -> void:
	path = at
	seed_value = seed_of


## The run saved at `from`, or null when there is none or the file does not
## hold a run of this version. The actions are not played yet.
static func load_from(from := PATH) -> SaveGame:
	var c := ConfigFile.new()
	if from == "" or c.load(from) != OK:
		return null
	var seed_of: Variant = c.get_value("run", "seed", false)
	var count: Variant = c.get_value("run", "kills", false)
	var list: Variant = c.get_value("run", "actions", false)
	if (
		c.get_value("run", "version", 0) != VERSION
		or not (seed_of is int and count is int and list is Array)
		or not list.all(func(a): return a is Dictionary and _shaped(a))
	):
		return null
	var s := SaveGame.new(from, seed_of)
	s.kills = count
	var zones: Variant = c.get_value("run", "exclusions", {})
	if (
		zones is Dictionary
		and zones.keys().all(func(k): return k is Vector2i)
		and zones.values().all(func(r): return r is int)
	):
		s.exclusions = zones
	s.actions.assign(list)
	return s


## Takes an action that was played and saves, or removes the file when the run
## is `over`.
func record(action: Dictionary, total: int, over: bool) -> void:
	if over:
		erase()
		return
	actions.append(action.duplicate(true))
	kills = total
	write()


func write() -> void:
	if path == "":
		return
	var c := ConfigFile.new()
	c.set_value("run", "version", VERSION)
	c.set_value("run", "seed", seed_value)
	c.set_value("run", "kills", kills)
	c.set_value("run", "actions", actions)
	c.set_value("run", "exclusions", exclusions)
	c.save(path)


## Removes the file: the run is over, or a new one replaces it.
func erase() -> void:
	if path != "" and FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## Starts playing the actions again on a new world from the seed.
func begin() -> void:
	world = World.create(seed_value)
	messages = Messages.new()
	played = 0


## Plays the next action again, filling `world` and `messages`. False when it
## does not fit the rules.
func step() -> bool:
	var action := actions[played]
	if not world.can(action):
		return false
	var before := world.clone()
	for line in Messages.of(before, world, world.act(action)):
		messages.add(line, world.round_no)
	played += 1
	return true


## All of the actions at once; false when one does not fit the rules.
func replay() -> bool:
	begin()
	while played < actions.size():
		if not step():
			return false
	return true


## Whether the action has the parts World.can reads, of the right types.
static func _shaped(action: Dictionary) -> bool:
	match action.get("t"):
		&"wait":
			return true
		&"move":
			return action.get("dir") is Vector2i
		&"cast":
			var spells: Variant = action.get("spells")
			return spells is Array and spells.all(_spell_shaped)
	return false


static func _spell_shaped(spell: Variant) -> bool:
	return (
		spell is Dictionary
		and spell.get("dir") is Vector2i
		and spell.get("cards") is Array
		and spell.cards.all(func(c): return c is StringName)
	)
