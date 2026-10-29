class_name Puppet
extends Node3D
## A paper cut-out standing on the board. It turns by flipping edge-on, hops
## between tiles, and drops flat when it falls.

const SHADER := preload("res://src/view/paper.gdshader")
const PAD := 0.07

static var _textures := {}

var card: MeshInstance3D
var material: ShaderMaterial
var tag: Label3D
var facing := 1
var height := 1.0


## The SVG with a transparent margin, so the paper border has room.
static func texture(path: String) -> Texture2D:
	if _textures.has(path):
		return _textures[path]
	var img: Image = (load(path) as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var pad := int(maxf(img.get_width(), img.get_height()) * PAD)
	var out := Image.create_empty(
		img.get_width() + pad * 2, img.get_height() + pad * 2, false, Image.FORMAT_RGBA8
	)
	out.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(pad, pad))
	out.generate_mipmaps()
	var tex := ImageTexture.create_from_image(out)
	_textures[path] = tex
	return tex


static func make(path: String, h: float, lift := 0.0) -> Puppet:
	var p := Puppet.new()
	var tex := texture(path)
	p.height = h
	var quad := QuadMesh.new()
	quad.size = Vector2(h * tex.get_width() / tex.get_height(), h)
	quad.center_offset = Vector3(0, h / 2 + lift, 0)
	p.material = ShaderMaterial.new()
	p.material.shader = SHADER
	p.material.set_shader_parameter("art", tex)
	p.card = MeshInstance3D.new()
	p.card.mesh = quad
	p.card.material_override = p.material
	p.card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	p.add_child(p.card)
	return p


func add_tag(size := 44) -> Label3D:
	tag = Label3D.new()
	tag.font = Fonts.serif()
	tag.font_size = size
	tag.outline_size = 10
	tag.outline_modulate = Palette.PAPER
	tag.modulate = Palette.INK
	tag.pixel_size = 0.0065
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.render_priority = 2
	tag.outline_render_priority = 1
	tag.position = Vector3(0, height + 0.22, 0)
	add_child(tag)
	return tag


func face(dx: int) -> void:
	if dx == 0 or signi(dx) == facing:
		return
	facing = signi(dx)
	create_tween().tween_property(card, "rotation:y", 0.0 if facing > 0 else PI, 0.16).set_trans(
		Tween.TRANS_SINE
	)
	var tails := get_node_or_null("Tails")
	if tails != null:
		create_tween().tween_property(tails, "scale:x", float(facing), 0.16)


func hop(to: Vector3, time: float, arc := 0.28) -> Tween:
	var from := position
	var t := create_tween()
	t.tween_method(
		func(k: float): position = from.lerp(to, k) + Vector3(0, sin(k * PI) * arc, 0),
		0.0,
		1.0,
		time
	)
	return t


func glide(to: Vector3, time: float) -> Tween:
	var t := create_tween()
	t.tween_property(self, "position", to, time)
	return t


func flash() -> void:
	material.set_shader_parameter("flash", 1.0)
	var t := create_tween()
	t.tween_method(func(v: float): material.set_shader_parameter("flash", v), 1.0, 0.0, 0.22)
	var base := card.position
	var s := create_tween()
	for i in 4:
		s.tween_property(card, "position", base + Vector3(0.06 * (1 - 2 * (i % 2)), 0, 0), 0.03)
	s.tween_property(card, "position", base, 0.03)


func fall() -> Tween:
	if tag != null:
		tag.visible = false
	var t := create_tween()
	t.tween_property(card, "rotation:x", -PI / 2, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_IN
	)
	t.tween_property(card, "scale", Vector3(0.01, 0.01, 0.01), 0.18)
	t.tween_callback(queue_free)
	return t


func pop_out() -> Tween:
	var t := create_tween()
	t.tween_property(self, "scale", Vector3(1.35, 1.35, 1.35), 0.06)
	t.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.1)
	t.tween_callback(queue_free)
	return t
