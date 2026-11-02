class_name Ailments
extends RefCounted
## What a creature (Actor) is held by or marked with, in rounds left: the conditions
## of Status.ENDS (rooted, stunned, blind) and its statuses (wet, alight, frozen).
## Data only; the rules are in Status.

var rooted := 0
var stunned := 0
var blind := 0
## Rounds left of each status (Status).
var wet := 0
var alight := 0
var frozen := 0


func copy() -> Ailments:
	var c := Ailments.new()
	c.rooted = rooted
	c.stunned = stunned
	c.blind = blind
	c.wet = wet
	c.alight = alight
	c.frozen = frozen
	return c
