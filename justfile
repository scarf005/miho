godot := env_var_or_default("GODOT", "godot")
web_port := env_var_or_default("WEB_PORT", "4180")
# Emscripten 4.0.20, the version the Godot 4.7.2 web templates are built with.
emsdk := env_var_or_default("MIHO_EMSDK", data_directory() / "emsdk-4.0.20")

# List recipes.
default:
    @just --list

# Build the Rust extension (rust/) for the desktop.
rust:
    cargo build --release --quiet --manifest-path rust/Cargo.toml

# Build the Rust extension for the web, as an Emscripten side module.
rust-web:
    #!/usr/bin/env bash
    set -euo pipefail
    source "{{ emsdk }}/emsdk_env.sh" >/dev/null 2>&1
    cd rust  # for .cargo/config.toml
    cargo +nightly build --release --quiet -Zbuild-std --target wasm32-unknown-emscripten

# Play on the desktop.
run: rust
    {{ godot }} --path .

# Run the rule tests.
test: rust
    {{ godot }} --headless --path . --import
    {{ godot }} --headless --path . -s addons/gut/gut_cmdln.gd

# Serve the game to an AI agent over MCP on stdio (see .mcp.json).
mcp: rust
    {{ godot }} --headless --path . --import >&2
    {{ godot }} --headless --no-header --path . -s src/mcp/server.gd

# Format and lint GDScript.
lint:
    gdformat --check src tests
    gdlint src tests

# Export the web build to build/web.
web: rust-web
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
    cp build/web/miho_native.wasm build/artifact/
    gzip -9 -c build/web/index.wasm > build/artifact/wasm-gz.wasm
    gzip -9 -c build/web/index.side.wasm > build/artifact/side-gz.wasm

# Time storey generation, a round, forecasts and a Continue replay.
bench: rust
    {{ godot }} --headless --path . --import
    {{ godot }} --headless --path . -s tools/bench.gd
    {{ godot }} --headless --path . -s tools/bench_round.gd
