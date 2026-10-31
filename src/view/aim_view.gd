class_name AimView
extends RefCounted
## The aim preview: a forecast cast drawn into the term's tints, marks and
## lines. It shows the tiles each projectile crosses or each spray covers, the
## line a leap takes with Miho where it lands, a line from Miho to the
## creature each homing one chases, the harm each creature takes, the wooden
## walls that grow and the ground compounds change. `known` is what Miho
## knows of `world` (World.known_clone), which the forecast ran on.


static func paint(
	f: Forecast, world: World, known: World, term: Term, tints: Dictionary, marks: Dictionary
) -> void:
	var aimed := {}
	for id in f.paths:
		var path: Dictionary = f.paths[id]
		for p in path.tiles:
			tints[p] = Color(Palette.SIDE[path.faction], 0.35)
		var target := known.actor(path.target)
		var cast_now := not world.shots.any(func(s): return s.id == id)
		if target != null and path.faction == Actor.FOX and cast_now:
			var k: int = aimed.get(target.id, 0)
			aimed[target.id] = k + 1
			term.lines.append([path.tiles[0], target.pos, Color(Palette.SIDE[0], 0.7), k])
	for e in f.sprays:
		var color := Palette.card(Spell.make(e.cards).slots[0])
		for p: Vector2i in e.tiles:
			tints[p] = Color(color, 0.22)
	for leap: Array in f.leaps:
		var d := Grid.line_dir(leap[0], leap[1])
		for i in range(1, Grid.cheb(leap[0], leap[1]) + 1):
			tints[leap[0] + d * i] = Color(Palette.SIDE[0], 0.35)
		marks[leap[1]] = [Bestiary.info(&"miho").glyph, Palette.SIDE[0]]
	for p in f.sprouts:
		tints[p] = Color(Palette.TILES[World.WOOD_WALL][1], 0.5)
	for p in f.grounds:
		tints[p] = Color(Palette.TILES[f.grounds[p]][1], 0.5)
	for p in f.heated:
		tints[p] = Color(Palette.HOT[1], 0.5)
	for id in f.harm:
		# A creature the round kills is gone from `after`: mark where it stood.
		var a := f.after.actor(id) if f.after.actor(id) != null else known.actor(id)
		if a != null:
			marks[a.pos] = [str(f.harm[id]), Palette.HURT]
	for id in f.falls:
		var a := world.actor(id)
		if a != null:
			marks[a.pos] = ["▼", Palette.HURT]
