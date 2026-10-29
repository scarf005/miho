class_name Actor
extends RefCounted
## A creature on the board. Faction FOX is Miho; HEAVEN is everything else.

const FOX := 0
const HEAVEN := 1

var id := 0
var kind := &""
var faction := HEAVEN
var pos := Vector2i.ZERO
var hp := 1
var max_hp := 1
var cooldown := 0
## Cards of the spell being charged; empty when not charging.
var intent: Array[StringName] = []
var aim := Vector2i.ZERO
var rooted := 0
var stunned := 0
var casts := 0
var acted := 0


func alive() -> bool:
	return hp > 0


func info() -> Dictionary:
	return Bestiary.info(kind)


func next_cast() -> Array:
	var list: Array = info().get("casts", [])
	return list[casts % list.size()] if not list.is_empty() else []


func clone() -> Actor:
	var a := Actor.new()
	a.id = id
	a.kind = kind
	a.faction = faction
	a.pos = pos
	a.hp = hp
	a.max_hp = max_hp
	a.cooldown = cooldown
	a.intent = intent.duplicate()
	a.aim = aim
	a.rooted = rooted
	a.stunned = stunned
	a.casts = casts
	a.acted = acted
	return a
