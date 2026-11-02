extends SceneTree
## Times the storage shapes docs/plan-ecs.md chose between: one read, and one clone of 40
## creatures, for each. godot --headless --path . -s tools/bench_storage.gd

const N := 40
const READS := 2000000


class Flat:
	extends RefCounted
	var rooted := 0
	var _hidden := 0
	var through: int:
		get:
			return _hidden


class Part:
	extends RefCounted
	var rooted := 0
	var stunned := 0
	var blind := 0
	var wet := 0
	var alight := 0
	var frozen := 0

	func copy() -> Part:
		var c := Part.new()
		c.rooted = rooted
		c.stunned = stunned
		c.blind = blind
		c.wet = wet
		c.alight = alight
		c.frozen = frozen
		return c


class Nested:
	extends RefCounted
	var status := Part.new()


## 7 parts of 6 fields: 42 fields, as Actor has.
class Parts:
	extends RefCounted
	var a := Part.new()
	var b := Part.new()
	var c := Part.new()
	var d := Part.new()
	var e := Part.new()
	var f := Part.new()
	var g := Part.new()

	func copy() -> Parts:
		var o := Parts.new()
		o.a = a.copy()
		o.b = b.copy()
		o.c = c.copy()
		o.d = d.copy()
		o.e = e.copy()
		o.f = f.copy()
		o.g = g.copy()
		return o


func _init() -> void:
	_reads()
	_clones()
	quit()


func _reads() -> void:
	var flat := Flat.new()
	var nested := Nested.new()
	var col := PackedInt32Array()
	col.resize(N)
	var table := {}
	for i in N:
		table[i] = Part.new()
	var sum := 0
	var t := Time.get_ticks_usec()
	for i in READS:
		sum += flat.rooted
	_say("read a.rooted", t, READS)
	t = Time.get_ticks_usec()
	for i in READS:
		sum += flat.through
	_say("read through a getter", t, READS)
	t = Time.get_ticks_usec()
	for i in READS:
		sum += nested.status.rooted
	_say("read a.status.rooted", t, READS)
	t = Time.get_ticks_usec()
	for i in READS:
		sum += col[i % N]
	_say("read column[slot]", t, READS)
	t = Time.get_ticks_usec()
	for i in READS:
		sum += table[i % N].rooted
	_say("read table[id].rooted", t, READS)
	print(sum)


func _clones() -> void:
	var actors: Array[Actor] = []
	var parts: Array[Parts] = []
	for i in N:
		actors.append(Actor.new())
		parts.append(Parts.new())
	var t := Time.get_ticks_usec()
	for k in 200:
		for a in actors:
			a.clone()
	_say("clone 40 Actors as now", t, 200)
	t = Time.get_ticks_usec()
	for k in 200:
		for a in parts:
			a.copy()
	_say("clone 40 of 7 parts, 42 fields", t, 200)
	var cols: Array[PackedInt32Array] = []
	for i in 42:
		var c := PackedInt32Array()
		c.resize(N)
		cols.append(c)
	t = Time.get_ticks_usec()
	for k in 200:
		for c in cols:
			var d := c.duplicate()
			d[0] = 1
	_say("clone 42 columns of 40", t, 200)


func _say(what: String, since: int, n: int) -> void:
	var us := float(Time.get_ticks_usec() - since)
	print("%-32s %10.3f us each" % [what, us / n])
