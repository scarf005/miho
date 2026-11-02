class_name Magic
extends RefCounted
## What a creature (Actor) casts with: the spells it charges, when it may cast
## again and what it pays them with. Data only; the rules are in Mind and Aim.

var cooldown := 0
## The spells being charged, each {cards, dir}; empty when not charging.
var intent: Array[Dictionary] = []
var casts := 0
## The mana it has left to pay for spells with (Bestiary mana).
var mana := 0
## Rounds counted towards its next mana (Mind._regrow).
var regrow := 0
## The one spell it casts in place of those of its kind (`repertoire`), empty for
## none. Miho's is the spell her next copy takes (Bunsin.learn).
var imprint: Array[StringName] = []


func copy() -> Magic:
	var c := Magic.new()
	c.cooldown = cooldown
	c.intent = intent.duplicate(true)
	c.casts = casts
	c.mana = mana
	c.regrow = regrow
	c.imprint.assign(imprint)
	return c
