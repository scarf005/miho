class_name Board
extends Node3D
## The paper-theatre diorama: one storey of the pavilion, its paper cast, and
## the forecast marks drawn on the floor.

signal shown(event: Dictionary)

const ART := "res://assets/art/%s.svg"
const HEIGHT := {
	&"miho": 1.56,
	&"dokkaebi": 1.37,
	&"jangseung": 1.89,
	&"cheonha": 2.41,
	&"jiha": 2.27,
	&"imugi": 1.17,
	&"cheonnyeon": 1.82,
	&"bulgae": 1.23,
	&"haetae": 1.49,
	&"bulgasari": 1.43,
	&"saja": 1.95,
}
const TILE_PX := 64

static var _floor_tex: Texture2D
static var _disc_tex: Texture2D
static var _ring_tex: Texture2D

var world: World
var storey: Node3D
var cast_root: Node3D
var marks: Node3D
var actors := {}
var shots := {}
var peaches := {}
var tails_root: Node3D
var speed := 1.0
var _mats := {}


static func to3(p: Vector2i) -> Vector3:
	return Vector3(p.x - 4, 0, p.y - 4)


static func from3(v: Vector3) -> Vector2i:
	return Vector2i(roundi(v.x + 4), roundi(v.z + 4))


func _ready() -> void:
	storey = Node3D.new()
	cast_root = Node3D.new()
	marks = Node3D.new()
	add_child(storey)
	add_child(cast_root)
	add_child(marks)
	_clouds()


# --- building -----------------------------------------------------------------


func build(w: World) -> void:
	world = w
	for n in storey.get_children() + cast_root.get_children() + marks.get_children():
		n.free()
	actors.clear()
	shots.clear()
	peaches.clear()
	tails_root = null
	_slab()
	for i in w.tiles.size():
		if w.tiles[i] == World.PILLAR:
			_pillar(Grid.at(i))
	if w.stairs.x >= 0:
		_stairs(w.stairs)
	if w.elixir.x >= 0:
		_altar(w.elixir)
	sync(w)


func _mat(color: Color, tex: Texture2D = null, unshaded := false) -> StandardMaterial3D:
	var key := [color, tex, unshaded]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.albedo_texture = tex
	m.roughness = 1.0
	m.metallic_specular = 0.0
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.no_depth_test = false
		m.render_priority = 1
	_mats[key] = m
	return m


func _box(size: Vector3, at: Vector3, color: Color, parent: Node3D = storey) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at
	mi.material_override = _mat(color)
	parent.add_child(mi)
	return mi


func _slab() -> void:
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(Grid.W, Grid.H)
	var mi := MeshInstance3D.new()
	mi.mesh = floor_mesh
	mi.material_override = _mat(Color.WHITE, _floor_texture())
	storey.add_child(mi)
	_box(Vector3(Grid.W + 0.5, 0.42, Grid.H + 0.5), Vector3(0, -0.22, 0), Palette.WOOD_DARK)
	_box(Vector3(Grid.W + 0.9, 0.12, Grid.H + 0.9), Vector3(0, -0.48, 0), Palette.SEOKGANJU)
	for side in [-1, 1]:
		_box(
			Vector3(0.1, 0.1, Grid.H + 0.3),
			Vector3(side * (Grid.W / 2.0 + 0.12), 0.3, 0),
			Palette.SEOKGANJU
		)
		for z in range(-4, 5, 2):
			_box(
				Vector3(0.12, 0.34, 0.12),
				Vector3(side * (Grid.W / 2.0 + 0.12), 0.17, z),
				Palette.SEOKGANJU
			)
	_box(Vector3(Grid.W + 0.3, 0.1, 0.1), Vector3(0, 0.3, Grid.H / 2.0 + 0.12), Palette.SEOKGANJU)


## 우물마루: short boards set between beams, one well per tile.
static func _floor_texture() -> Texture2D:
	if _floor_tex != null:
		return _floor_tex
	var size := TILE_PX * Grid.W
	var img := Image.create_empty(size, size, true, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var beam := Color("#8a6238")
	for ty in Grid.H:
		for tx in Grid.W:
			var o := Vector2i(tx, ty) * TILE_PX
			var boards := 3
			for b in boards:
				var shade := Palette.WOOD.darkened(rng.randf_range(-0.04, 0.1))
				var y0 := o.y + b * TILE_PX / boards
				img.fill_rect(Rect2i(o.x, y0, TILE_PX, TILE_PX / boards), shade)
				img.fill_rect(Rect2i(o.x, y0, TILE_PX, 1), shade.darkened(0.25))
				for k in 3:
					var gx := o.x + rng.randi_range(6, TILE_PX - 10)
					img.fill_rect(
						Rect2i(gx, y0 + rng.randi_range(4, 14), rng.randi_range(5, 12), 1),
						shade.darkened(0.12)
					)
			img.fill_rect(Rect2i(o.x, o.y, TILE_PX, 4), beam)
			img.fill_rect(Rect2i(o.x, o.y, 4, TILE_PX), beam)
			img.fill_rect(Rect2i(o.x + TILE_PX - 2, o.y, 2, TILE_PX), beam.darkened(0.2))
			img.fill_rect(Rect2i(o.x, o.y + TILE_PX - 2, TILE_PX, 2), beam.darkened(0.2))
	img.generate_mipmaps()
	_floor_tex = ImageTexture.create_from_image(img)
	return _floor_tex


func _pillar(p: Vector2i) -> void:
	var at := to3(p)
	_box(Vector3(0.78, 0.14, 0.78), at + Vector3(0, 0.07, 0), Palette.STONE)
	var post := CylinderMesh.new()
	post.top_radius = 0.27
	post.bottom_radius = 0.29
	post.height = 0.95
	var mi := MeshInstance3D.new()
	mi.mesh = post
	mi.position = at + Vector3(0, 0.6, 0)
	mi.material_override = _mat(Palette.SEOKGANJU)
	storey.add_child(mi)
	var band := CylinderMesh.new()
	band.top_radius = 0.3
	band.bottom_radius = 0.3
	band.height = 0.2
	var bi := MeshInstance3D.new()
	bi.mesh = band
	bi.position = at + Vector3(0, 1.12, 0)
	bi.material_override = _mat(Palette.NOEROK)
	storey.add_child(bi)
	var cap := CylinderMesh.new()
	cap.top_radius = 0.31
	cap.bottom_radius = 0.31
	cap.height = 0.05
	var ci := MeshInstance3D.new()
	ci.mesh = cap
	ci.position = at + Vector3(0, 1.0, 0)
	ci.material_override = _mat(Palette.JU)
	storey.add_child(ci)


func _stairs(p: Vector2i) -> void:
	var at := to3(p)
	for i in 4:
		_box(
			Vector3(0.9, 0.16 + i * 0.22, 0.32),
			at + Vector3(0, (0.16 + i * 0.22) / 2, -0.62 - i * 0.3),
			Palette.WOOD
		)
	_box(Vector3(0.08, 1.4, 1.4), at + Vector3(-0.5, 0.7, -1.05), Palette.SEOKGANJU)
	_box(Vector3(0.08, 1.4, 1.4), at + Vector3(0.5, 0.7, -1.05), Palette.SEOKGANJU)
	var glow := _flat(p, _ring_texture(), Palette.HWANG, 0.95)
	glow.position.y = 0.012


func _altar(p: Vector2i) -> void:
	var at := to3(p)
	_box(Vector3(0.8, 0.3, 0.8), at + Vector3(0, 0.15, 0), Palette.STONE)
	var gourd := Puppet.make(ART % "elixir", 0.8, 0.3)
	gourd.position = at
	storey.add_child(gourd)


func _clouds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for i in 14:
		var c := Puppet.make(ART % "cloud", rng.randf_range(1.3, 2.4))
		var angle := TAU * i / 14.0 + rng.randf_range(-0.2, 0.2)
		var r := rng.randf_range(6.8, 9.5)
		c.position = Vector3(
			cos(angle) * r, rng.randf_range(-3.2, -1.2), sin(angle) * r * 0.8 - 1.0
		)
		c.card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(c)
		var t := c.create_tween().set_loops()
		var drift := rng.randf_range(0.15, 0.3)
		(
			t
			. tween_property(c, "position:y", c.position.y + drift, rng.randf_range(2.5, 4.0))
			. set_trans(Tween.TRANS_SINE)
		)
		t.tween_property(c, "position:y", c.position.y, rng.randf_range(2.5, 4.0)).set_trans(
			Tween.TRANS_SINE
		)


# --- the cast -----------------------------------------------------------------


func sync(w: World) -> void:
	world = w
	var seen := {}
	for a in w.actors:
		if not a.alive():
			continue
		seen[a.id] = true
		var p: Puppet = actors.get(a.id)
		if p == null:
			p = Puppet.make(ART % a.kind, HEIGHT[a.kind])
			p.add_tag()
			cast_root.add_child(p)
			actors[a.id] = p
			if a.faction == Actor.FOX:
				_tails(p)
			else:
				p.face(-1)
		p.position = to3(a.pos)
		_tag(a, p)
	for id in actors.keys():
		if not seen.has(id):
			if is_instance_valid(actors[id]):
				actors[id].queue_free()
			actors.erase(id)
	var live := {}
	for s in w.shots:
		live[s.id] = true
		if not shots.has(s.id):
			_wisp(s.id, s.faction, s.spell, s.pos)
		shots[s.id].position = to3(s.pos)
	for id in shots.keys():
		if not live.has(id):
			if is_instance_valid(shots[id]):
				shots[id].queue_free()
			shots.erase(id)
	for tile in peaches.keys():
		if not w.peaches.has(tile):
			peaches[tile].queue_free()
			peaches.erase(tile)
	for tile in w.peaches:
		if not peaches.has(tile):
			var peach := Puppet.make(ART % "peach", 0.55)
			peach.position = to3(tile)
			storey.add_child(peach)
			peaches[tile] = peach
	show_tails(w.tails)


func _tag(a: Actor, p: Puppet) -> void:
	var hp := "◆".repeat(maxi(a.hp, 0)) + "◇".repeat(maxi(a.max_hp - a.hp, 0))
	var top := ""
	if not a.intent.is_empty():
		top = "".join(a.intent.map(func(c): return Cards.GLYPH[c])) + "\n"
	elif a.faction == Actor.HEAVEN and a.cooldown > 0:
		top = "①②③④⑤⑥⑦⑧⑨"[mini(a.cooldown, 9) - 1] + "\n"
	var status := ""
	if a.rooted > 0:
		status += "木"
	if a.stunned > 0:
		status += "土"
	p.tag.text = top + hp + ("\n" + status if status != "" else "")
	p.tag.modulate = (
		Palette.SIDE[a.faction].darkened(0.25) if a.intent.is_empty() else Palette.SIDE[1]
	)
	p.tag.position.y = p.height + 0.18 + (0.18 if top != "" else 0.0)


func _tails(p: Puppet) -> void:
	var pivot := Node3D.new()
	pivot.name = "Tails"
	p.add_child(pivot)
	tails_root = Node3D.new()
	tails_root.position = Vector3(-0.04, 0.32, -0.05)
	pivot.add_child(tails_root)
	for i in World.FLOORS:
		var t := Puppet.make(ART % "tail", 1.3)
		t.card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		t.position = Vector3(0, 0, -0.01 * i)
		tails_root.add_child(t)


## Fans the tails Miho still has behind her; spent ones are hidden.
func show_tails(n: int) -> void:
	if tails_root == null:
		return
	for i in tails_root.get_child_count():
		var t: Node3D = tails_root.get_child(i)
		t.visible = i < n
		t.rotation.z = deg_to_rad(8 + (i - (n - 1) / 2.0) * 15.0)


func _wisp(id: int, faction: int, spell: Spell, at: Vector2i) -> Puppet:
	var side := "fox" if faction == Actor.FOX else "heaven"
	var art := ("orb_" if spell.line else "fire_") + side
	var p := Puppet.make(ART % art, 0.5 if spell.line else 0.55, 0.22)
	p.position = to3(at)
	cast_root.add_child(p)
	shots[id] = p
	var bob := p.create_tween().set_loops()
	bob.tween_property(p.card, "position:y", 0.06, 0.35).set_trans(Tween.TRANS_SINE)
	bob.tween_property(p.card, "position:y", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
	return p


# --- playing a round ------------------------------------------------------------


## Animates a round's events, then snaps every piece to the final state.
func play(events: Array[Dictionary], after: World) -> void:
	var last := {}
	for i in events.size():
		var e := events[i]
		if e.has("shot"):
			last[e.shot] = i
	var i := 0
	while i < events.size():
		var batch: Array[int] = [i]
		while _parallel(events[i]) and i + 1 < events.size() and _parallel(events[i + 1]):
			i += 1
			batch.append(i)
		var wait := 0.0
		for k in batch:
			var e := events[k]
			if e.t == &"ascend":
				shown.emit(e)
				return
			wait = maxf(wait, _show(e, after, last.get(e.get("shot", -1), -1) == k))
			shown.emit(e)
		if wait > 0.0:
			await get_tree().create_timer(wait / speed).timeout
		i += 1
	sync(after)


func _parallel(e: Dictionary) -> bool:
	return e.t in [&"fly", &"move", &"spawn"]


func _show(e: Dictionary, after: World, final_event: bool) -> float:
	var t := 0.0
	match e.t:
		&"move", &"push":
			var p: Puppet = actors.get(e.id)
			if p != null:
				p.face(e.to.x - e.from.x)
				if e.t == &"move":
					p.hop(to3(e.to), 0.13 / speed)
				else:
					p.glide(to3(e.to), 0.12 / speed)
				t = 0.13
		&"spawn":
			if not shots.has(e.shot):
				var s := _wisp(e.shot, e.faction, Spell.make(e.cards), e.at)
				s.scale = Vector3(0.2, 0.2, 0.2)
				s.create_tween().tween_property(s, "scale", Vector3.ONE, 0.1 / speed)
			t = 0.08
		&"fly":
			var s: Puppet = shots.get(e.shot)
			if s != null:
				s.glide(to3(e.to), 0.07 / speed)
			t = 0.07
		&"hit":
			var p: Puppet = actors.get(e.id)
			if p != null:
				p.flash()
			t = 0.1
		&"hurt":
			_popup(
				e.at, "-%d" % e.n, Palette.SIDE[1] if e.id != after.player().id else Palette.JANGDAN
			)
			t = 0.12
		&"die":
			var p: Puppet = actors.get(e.id)
			if p != null:
				p.fall()
				actors.erase(e.id)
			t = 0.2
		&"burst", &"clash", &"snuff", &"fade":
			_puff(e.at)
			var other: int = e.get("other", -1)
			if other >= 0 and shots.has(other):
				shots[other].pop_out()
				shots.erase(other)
			if e.t == &"snuff" and shots.has(e.shot):
				shots[e.shot].pop_out()
				shots.erase(e.shot)
			t = 0.08
		&"splash":
			_splash(e.at, Palette.SIDE[e.faction])
			t = 0.14
		&"slam", &"absorb", &"root", &"stun":
			t = 0.08
		&"cast", &"charge":
			var p: Puppet = actors.get(e.id)
			if p != null:
				p.hop(p.position, 0.12 / speed, 0.15)
			t = 0.1
	if (
		final_event
		and e.has("shot")
		and e.t != &"snuff"
		and after.shots.all(func(s): return s.id != e.shot)
	):
		var s: Puppet = shots.get(e.shot)
		if s != null:
			s.pop_out()
			shots.erase(e.shot)
	return t


func _popup(at: Vector2i, text: String, color: Color) -> void:
	var l := _label(text, color, 48)
	l.position = to3(at) + Vector3(0, 1.1, 0.2)
	marks.add_child(l)
	var t := l.create_tween()
	t.tween_property(l, "position:y", l.position.y + 0.5, 0.6 / speed)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.6 / speed).set_delay(0.25 / speed)
	t.tween_callback(l.queue_free)


func _puff(at: Vector2i) -> void:
	var q := _flat(at, _disc_texture(), Palette.PAPER, 0.5)
	q.position.y = 0.4
	var t := q.create_tween()
	t.tween_property(q, "scale", Vector3(2.0, 2.0, 2.0), 0.16 / speed)
	t.tween_callback(q.queue_free)


func _splash(at: Vector2i, color: Color) -> void:
	var q := _flat(at, _ring_texture(), color, 0.3)
	q.position.y = 0.05
	var t := q.create_tween()
	t.tween_property(q, "scale", Vector3(3.2, 3.2, 3.2), 0.18 / speed)
	t.tween_callback(q.queue_free)


# --- forecast marks -------------------------------------------------------------


func clear_marks() -> void:
	for n in marks.get_children():
		n.queue_free()


## Draws where every projectile goes next round, what it hits and for how much,
## plus each creature's coming harm. `danger` maps Miho's options to her harm.
func draw_forecast(f: Forecast, danger: Dictionary, aim_dirs: Array) -> void:
	clear_marks()
	for id in f.paths:
		var path: Dictionary = f.paths[id]
		var color: Color = Palette.SIDE[path.faction]
		var tiles: Array = path.tiles
		for k in range(1, tiles.size()):
			_dotted(tiles[k - 1], tiles[k], color, 0.85)
		if path.live and path.spell != null and path.spell.line and not path.spell.homing():
			var rest := Forecast.ray(f.after, tiles[-1], path.dir)
			var prev: Vector2i = tiles[-1]
			for p in rest:
				_dotted(prev, p, color, 0.35)
				prev = p
	for a in f.after.actors + _fallen(f):
		var n: int = f.harm.get(a.id, 0)
		if n > 0:
			var mark := _label(
				"-%d" % n, Palette.SIDE[1] if a.faction == Actor.FOX else Palette.SIDE[0], 40
			)
			mark.position = to3(a.pos) + Vector3(0.36, 0.55, 0.3)
			marks.add_child(mark)
	for a in world.actors:
		if a.faction == Actor.HEAVEN and not a.intent.is_empty():
			var spell := Spell.make(a.intent)
			if spell.line and not spell.homing():
				var prev := a.pos
				var k := 1
				for p in Forecast.ray(world, a.pos, a.aim):
					_dotted(prev, p, Palette.SIDE[1], 0.55 if k + 1 >= Spell.MOMENTUM else 0.3)
					prev = p
					k += 1
	for tile in danger:
		var n: int = danger[tile]
		if n > 0:
			var q := _flat(tile, _disc_texture(), Palette.SIDE[1], 0.22)
			q.scale = Vector3(1.6, 1.6, 1.6)
			var l := _label("%d" % n, Palette.SIDE[1], 30)
			l.position = to3(tile) + Vector3(0, 0.12, 0)
			marks.add_child(l)
	for d in aim_dirs:
		var tile: Vector2i = world.player().pos + d
		if world.open_floor(tile):
			_flat(tile, _ring_texture(), Palette.SIDE[0], 0.5)


func _fallen(f: Forecast) -> Array:
	return world.actors.filter(func(a): return f.deaths.has(a.id))


func _dotted(a: Vector2i, b: Vector2i, color: Color, alpha: float) -> void:
	for k in 3:
		var at := to3(a).lerp(to3(b), (k + 1) / 3.0)
		var q := _flat(Vector2i.ZERO, _disc_texture(), color, alpha)
		q.position = at + Vector3(0, 0.03, 0)
		q.scale = Vector3(0.18, 0.18, 0.18) if k < 2 else Vector3(0.3, 0.3, 0.3)


func _flat(tile: Vector2i, tex: Texture2D, color: Color, alpha: float) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.9, 0.9)
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.position = to3(tile) + Vector3(0, 0.02, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.material_override = _mat(Color(color, alpha), tex, true)
	marks.add_child(mi)
	return mi


func _label(text: String, color: Color, size: int) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = Fonts.serif()
	l.font_size = size
	l.outline_size = 12
	l.modulate = color
	l.outline_modulate = Palette.PAPER
	l.pixel_size = 0.006
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 3
	l.outline_render_priority = 2
	return l


static func _disc_texture() -> Texture2D:
	if _disc_tex == null:
		_disc_tex = _circle(false)
	return _disc_tex


static func _ring_texture() -> Texture2D:
	if _ring_tex == null:
		_ring_tex = _circle(true)
	return _ring_tex


static func _circle(ring: bool) -> Texture2D:
	var n := 64
	var img := Image.create_empty(n, n, true, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var r := Vector2(x - n / 2.0 + 0.5, y - n / 2.0 + 0.5).length() / (n / 2.0)
			var a := 1.0 if r < 0.96 else 0.0
			if ring:
				a = 1.0 if r < 0.96 and r > 0.78 else 0.0
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
