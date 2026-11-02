class_name Snapshot
extends RefCounted
## A World as plain data, by the names of its fields, so a change to the rules can still read
## it: a field it no longer has is left out, a field it did not have keeps its default, and a
## creature of a kind it no longer has is gone. Caches (a name that starts with `_`) are left
## to build again. Tile numbers are kept as they are, so a new tile goes at the end of its table.

const KIND := "@"
static var _classes := {
	"Actor": Actor,
	"Shot": Shot,
	"Spell": Spell,
	"Ailments": Ailments,
	"Magic": Magic,
	"Brain": Brain,
	"Ties": Ties,
	"Buffs": Buffs,
}


static func of(w: World) -> Dictionary:
	var out := _fields(w)
	out.erase("rng")
	out.rng = [w.rng.seed, w.rng.state]
	return out


static func world(data: Dictionary) -> World:
	var w := World.new()
	_fill(w, data)
	w.rng.seed = data.rng[0]
	w.rng.state = data.rng[1]
	for kept: Dictionary in w.storeys.values():
		_whole(kept)
	return w


## A kept storey as Storeys puts it back: every field of World.STOREY, typed as the world has it.
static func _whole(kept: Dictionary) -> void:
	var blank := World.new()
	for f in World.STOREY:
		var value: Variant = kept.get(f, blank.get(f))
		if blank.get(f) is Array:
			blank.get(f).assign(value)
			value = blank.get(f)
		kept[f] = value


## The script variables of `o` by name, but its caches.
static func _fields(o: Object) -> Dictionary:
	var out := {}
	for p: Dictionary in o.get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and not p.name.begins_with("_"):
			out[p.name] = _plain(o.get(p.name))
	return out


static func _plain(v: Variant) -> Variant:
	if v is Array:
		return v.map(_plain)
	if v is Dictionary:
		var out := {}
		for k: Variant in v:
			out[k] = _plain(v[k])
		return out
	if v is RandomNumberGenerator:
		return null
	if typeof(v) >= TYPE_PACKED_BYTE_ARRAY:
		return v.duplicate()
	if v is Object:
		var out := _fields(v)
		out[KIND] = v.get_script().get_global_name()
		return out
	return v


static func _native(v: Variant) -> Variant:
	if v is Array:
		return v.map(_native).filter(func(e): return e != null)
	if typeof(v) >= TYPE_PACKED_BYTE_ARRAY:
		return v.duplicate()
	if not v is Dictionary:
		return v
	if v.has(KIND):
		return _made(v)
	var out := {}
	for k: Variant in v:
		out[k] = _native(v[k])
	return out


## The object `data` tells of, or null for a creature or a part the rules no longer have.
static func _made(data: Dictionary) -> Object:
	if not _classes.has(data[KIND]) or data[KIND] == "Actor" and not Bestiary.KINDS.has(data.kind):
		return null
	var o: Object = _classes[data[KIND]].new()
	_fill(o, data)
	return o


## Sets the fields of `o` that `data` names. A typed list takes what it holds in place.
static func _fill(o: Object, data: Dictionary) -> void:
	for k: String in data:
		if k == KIND or k == "rng" or not k in o:
			continue
		var value: Variant = _native(data[k])
		if o.get(k) is Array:
			o.get(k).assign(value)
		else:
			o.set(k, value)
