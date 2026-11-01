extends SceneTree
## Lists every Korean string literal under src/ that has no English entry in
## assets/i18n/*.po, as `path:line: "text"`, and exits 1 if there is one. A line
## ending in `# i18n: keep` is left out; so is src/mcp, which talks to agents.
## godot --headless --path . -s tools/i18n_check.gd

const ROOT := "res://src"
const TABLES := "res://assets/i18n"
const SKIP := "res://src/mcp"

var _hangul := RegEx.create_from_string("[가-힣]")


func _init() -> void:
	var known := _known()
	var missing: Array[String] = []
	for path in _scripts(ROOT):
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for k in lines.size():
			for text in _literals(lines[k]):
				if _hangul.search(text) != null and not known.has(text):
					missing.append('%s:%d: "%s"' % [path.trim_prefix("res://"), k + 1, text])
	for line in missing:
		print(line)
	quit(1 if not missing.is_empty() else 0)


## The message ids with a translation, as written in the .po files, which keep
## one `msgid "..."` and one `msgstr "..."` line to an entry.
func _known() -> Dictionary:
	var out := {}
	for file in DirAccess.get_files_at(TABLES):
		if not file.ends_with(".po"):
			continue
		var id := ""
		for line in FileAccess.get_file_as_string("%s/%s" % [TABLES, file]).split("\n"):
			if line.begins_with('msgid "'):
				id = line.trim_prefix('msgid "').trim_suffix('"')
			elif line.begins_with('msgstr "') and line != 'msgstr ""':
				out[id] = true
	return out


## The .gd files under `dir`, but not those under SKIP.
func _scripts(dir: String) -> Array[String]:
	var out: Array[String] = []
	if dir == SKIP:
		return out
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			out.append("%s/%s" % [dir, file])
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(_scripts("%s/%s" % [dir, sub]))
	return out


## The string literals of a line of code, as written between the quotes; none
## from a comment or a line marked to keep.
func _literals(line: String) -> Array[String]:
	var out: Array[String] = []
	if line.contains("# i18n: keep"):
		return out
	var at := 0
	while at < line.length():
		var c := line[at]
		if c == "#":
			break
		if c == '"':
			var end := at + 1
			while end < line.length() and line[end] != '"':
				end += 2 if line[end] == "\\" else 1
			out.append(line.substr(at + 1, end - at - 1))
			at = end
		at += 1
	return out
