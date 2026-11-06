class_name Buffs
extends RefCounted
## The buffs a creature (Actor) holds on itself and the form 둔갑 would give it.
## Data only; the rules are in Guise.

## 둔갑 (Guise): the kind of the last creature of heaven that fell, the kind
## it looks like, whether it is in guise, and the rounds in a row it has stood
## next to a creature of heaven in guise.
var prey := &""
var form := &""
var guise := false
var beside := 0
## Whether it holds 쇠발톱 (her claws harm more), 은신 (the hat's rule, Hat) and
## 불여우 (it counts as a fire creature: `nature_kind`), 사령술 (Raise) and 도약 (the next
## fall harms nothing: Fall).
var talon := false
var cloak := false
var flame := false
var raise := false
var vault := false


func copy() -> Buffs:
	var c := Buffs.new()
	c.prey = prey
	c.form = form
	c.guise = guise
	c.beside = beside
	c.talon = talon
	c.cloak = cloak
	c.flame = flame
	c.raise = raise
	c.vault = vault
	return c
