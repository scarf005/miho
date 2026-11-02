class_name Brain
extends RefCounted
## What a creature (Actor) knows and means to do: its alert, where it goes and what it
## has noticed. Data only; the rules are in Mind.

var acted := 0
var alert := Actor.REST
## Where it last saw Miho, or the spot it is searching.
var target := Vector2i.ZERO
var lost := 0
## Rounds left of wariness after being hurt: it does not go back to rest, and
## notices Miho one tile farther in the dark.
var wary := 0
## The ids of the changes (Notice) it has seen and reacted to.
var marked: Array[int] = []
var sees_me := false
## A guard (Yard) stands at its post: its state reads guarding.
var guard := false
## The drum it runs to strike instead of attacking (Drums), or (-1, -1).
var drum := Vector2i(-1, -1)
## Where it rests, and where a patrol is heading.
var home := Vector2i.ZERO
var post := Vector2i.ZERO


func copy() -> Brain:
	var c := Brain.new()
	c.acted = acted
	c.alert = alert
	c.target = target
	c.lost = lost
	c.wary = wary
	c.marked.assign(marked)
	c.sees_me = sees_me
	c.guard = guard
	c.drum = drum
	c.home = home
	c.post = post
	return c
