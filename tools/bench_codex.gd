extends SceneTree
## Times what the 도감's examples cost: building a scene, which a selection pays at
## once, and a round of one, the slowest of each over every entry.
## godot --headless --path . -s tools/bench_codex.gd


func _init() -> void:
	var build := 0
	var build_most := 0
	var builds := 0
	var round_most := 0
	var rounds := 0
	var round_all := 0
	var slowest := ""
	for tab in Codex.TABS.size():
		for e in Codex.entries(tab):
			if e.scene.is_empty():
				continue
			var t := Time.get_ticks_usec()
			var w := CodexScene.build(e.scene)
			var took := Time.get_ticks_usec() - t
			build += took
			build_most = maxi(build_most, took)
			builds += 1
			for action in CodexScene.actions(e.scene):
				if not w.can(action):
					break
				t = Time.get_ticks_usec()
				var before := w.clone()
				var events := w.act(action)
				Perceived.of(before, w, events)
				took = Time.get_ticks_usec() - t
				round_all += took
				rounds += 1
				if took > round_most:
					round_most = took
					slowest = e.name
	print("scenes %d: build mean %d us, most %d us" % [builds, build / builds, build_most])
	print(
		"rounds %d: mean %d us, most %d us (%s)" % [rounds, round_all / rounds, round_most, slowest]
	)
	var codex := Codex.new()
	codex.room = Vector2i(66, 30)
	for tab in Codex.TABS.size():
		codex.go(tab)
		var t := Time.get_ticks_usec()
		var count := Codex.entries(tab).size()
		for k in count:
			codex.select(k)
			codex.panel()
		print("tab %d: panel of a selection %d us" % [tab, (Time.get_ticks_usec() - t) / count])
	quit()
