extends SceneTree
## An MCP server on stdio, so an AI agent can play Miho headless:
## `godot --headless --no-header --path . -s src/mcp/server.gd`, after the class
## cache exists (`godot --headless --path . --import`).
##
## Newline-delimited JSON-RPC: it reads one request per line until end of input
## and prints one response line per request (GameTools has the protocol).
## Stdin is read with OS.read_string_from_stdin, which blocks for a whole line
## when given a buffer larger than the line (the default 1024 would split long
## ones) and returns it without the newline; an empty string is the end of
## input, so an empty line also ends the server. Godot cannot open /dev/stdout
## (FileAccess fails with ERR_FILE_CANT_OPEN), so replies go through print.
## --quiet would silence print, so --no-header drops the startup banner instead.
## Engine warnings and errors go to stderr, never into the protocol stream.

const LINE_MAX := 1 << 20


func _initialize() -> void:
	var tools := GameTools.new()
	var line := OS.read_string_from_stdin(LINE_MAX)
	while line != "":
		var reply: Variant = _reply(tools, JSON.parse_string(line))
		if reply != null:
			print(JSON.stringify(reply))
		line = OS.read_string_from_stdin(LINE_MAX)
	quit()


static func _reply(tools: GameTools, request: Variant) -> Variant:
	if request == null:
		return GameTools.error(null, -32700, "Parse error")
	if not request is Dictionary:
		return GameTools.error(null, -32600, "Invalid request")
	return tools.handle(request)
