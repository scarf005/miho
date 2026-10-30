class_name Actor
extends RefCounted
## A creature on the board. Faction FOX is Miho; HEAVEN is everything else.
## A heaven creature is resting, searching a spot it heard or saw something
## at, or hunting Miho after it saw her.

const FOX := 0
const HEAVEN := 1

const REST := 0
const SEARCH := 1
const HUNT := 2

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
var blind := 0
var casts := 0
var acted := 0
var alert := REST
## Where it last saw Miho, or the spot it is searching.
var target := Vector2i.ZERO
var lost := 0
var sees_me := false
## Where it rests, and where a patrol is heading.
var home := Vector2i.ZERO
var post := Vector2i.ZERO


func alive() -> bool:
	return hp > 0


func info() -> Dictionary:
	return Bestiary.info(kind)


func next_cast() -> Array:
	var list: Array = info().get("casts", [])
	return list[casts % list.size()] if not list.is_empty() else []


func clone() -> Actor:
	var a := Actor.new()
	for p in [
		"id",
		"kind",
		"faction",
		"pos",
		"hp",
		"max_hp",
		"cooldown",
		"aim",
		"rooted",
		"stunned",
		"blind",
		"casts",
		"acted",
		"alert",
		"target",
		"lost",
		"sees_me",
		"home",
		"post",
	]:
		a.set(p, get(p))
	a.intent = intent.duplicate()
	return a
