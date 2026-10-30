godot := env_var_or_default("GODOT", "godot")
web_port := env_var_or_default("WEB_PORT", "4180")

# List recipes.
default:
    @just --list

# Play on the desktop.
run:
    {{ godot }} --path .

# Run the rule tests.
test:
    {{ godot }} --headless --path . --import
    {{ godot }} --headless --path . -s addons/gut/gut_cmdln.gd

# Serve the game to an AI agent over MCP on stdio (see .mcp.json).
mcp:
    {{ godot }} --headless --path . --import >&2
    {{ godot }} --headless --no-header --path . -s src/mcp/server.gd

# Format and lint GDScript.
lint:
    gdformat --check src tests
    gdlint src tests

# Export the web build to build/web.
web:
    mkdir -p build/web
    {{ godot }} --headless --path . --export-release Web build/web/index.html

# Export and serve the web build on localhost.
serve: web
    python3 -m http.server {{ web_port }} --bind 127.0.0.1 --directory build/web

# Pack the web build for a claude.ai artifact in build/artifact.
artifact: web
    mkdir -p build/artifact
    cp web/artifact.html build/artifact/index.html
    cp build/web/index.js build/web/index.png build/web/index.audio.worklet.js build/web/index.audio.position.worklet.js build/artifact/
    cp build/web/index.pck build/artifact/pck.wasm
    gzip -9 -c build/web/index.wasm > build/artifact/wasm-gz.wasm

# Time storey generation, a round, forecasts and a Continue replay.
bench:
    {{ godot }} --headless --path . --import
    {{ godot }} --headless --path . -s tools/bench.gd
    {{ godot }} --headless --path . -s tools/bench_round.gd
