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

# Run the rule tests. GUT skips a test script that fails to load and still
# passes, so a script error fails the run here.
test: rust
    #!/usr/bin/env bash
    set -euo pipefail
    {{ godot }} --headless --path . --import
    status=0
    out=$({{ godot }} --headless --path . -s addons/gut/gut_cmdln.gd 2>&1) || status=$?
    printf '%s\n' "$out"
    if rg -q 'SCRIPT ERROR|Ignoring script' <<<"$out"; then
        echo "error: a script failed to load (see SCRIPT ERROR above)" >&2
        exit 1
    fi
    exit "$status"

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

# Save a scripted run's screenshot (see src/view/capture.gd), muted, in headless
# gamescope: just shot .screenshots/x.png --seed=3 --keys=1,Right
shot path *args: rust
    #!/usr/bin/env bash
    set -euo pipefail
    {{ godot }} --headless --path . --import >/dev/null
    mkdir -p "$(dirname '{{ path }}')"
    sink=$(pactl load-module module-null-sink sink_name=miho_shot)
    trap 'pactl unload-module "$sink"' EXIT
    PULSE_SINK=miho_shot gamescope --backend headless -W 1280 -H 720 -w 1280 -h 720 -- \
        {{ godot }} --path . -- --shot="$(realpath -m '{{ path }}')" {{ args }}

# Time storey generation, a round, forecasts and a Continue replay.
bench: rust
    {{ godot }} --headless --path . --import
    {{ godot }} --headless --path . -s tools/bench.gd
    {{ godot }} --headless --path . -s tools/bench_round.gd

# Replay a save (minus its last `back` actions) and explore from there; exits 1 on a back-and-forth loop.
explore-check save="~/.local/share/godot/app_userdata/미호/save.cfg" rounds="400" back="0": rust
    {{ godot }} --headless --path . --import
    {{ godot }} --headless --path . -s tools/explore_check.gd -- {{ save }} {{ rounds }} {{ back }}

# Print how often each event room appears and can be opened over N seeds x 27 storeys.
event-rooms seeds="200": rust
    {{ godot }} --headless --path . --import
    {{ godot }} --headless --path . -s tools/event_rooms.gd -- {{ seeds }}

# Print Miho's power against each depth's creatures as Markdown; measures on N processes (about 40 min on 7).
power procs="7": rust
    #!/usr/bin/env bash
    set -euo pipefail
    {{ godot }} --headless --path . --import >/dev/null 2>&1
    dir=$(mktemp -d -p "${XDG_CACHE_HOME:-$HOME/.cache}")
    trap 'gio trash "$dir"' EXIT
    pids=()
    for i in $(seq 0 $(({{ procs }} - 1))); do
        {{ godot }} --headless --path . -s tools/power.gd -- --shard=$i/{{ procs }} --memo="$dir" >/dev/null 2>&1 &
        pids+=($!)
    done
    for pid in "${pids[@]}"; do wait "$pid"; done
    {{ godot }} --headless --path . -s tools/power.gd -- --memo="$dir" 2>/dev/null | rg -v '^(Initialize godot-rust|Godot Engine)'
