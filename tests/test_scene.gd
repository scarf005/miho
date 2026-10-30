extends GutTest
## The game scene's scripts compile; nothing else loads them in tests.


func test_every_view_script_compiles() -> void:
	for file in DirAccess.get_files_at("res://src/view"):
		if file.ends_with(".gd"):
			var script: GDScript = load("res://src/view".path_join(file))
			assert_true(script != null and script.can_instantiate(), file)
