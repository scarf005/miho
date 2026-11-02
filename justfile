godot := env_var_or_default("GODOT", "godot")
web_port := env_var_or_default("WEB_PORT", "4180")
# Emscripten 4.0.20, the version the Godot 4.7.2 web templates are built with.
nightly := env_var_or_default("MIHO_NIGHTLY", "nightly")
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
    cargo +{{ nightly }} build --release --quiet -Zbuild-std --target wasm32-unknown-emscripten

# Play on the desktop.
run: rust
    {{ godot }} --path .

# Run the rule tests in parallel Godot shards (MIHO_TEST_JOBS, one per core by default),
# balanced by the script times of the last run. Each shard has its own user:// dir, log
# and JUnit file in build/test/shard-N. GUT skips a script that fails to load and still
# passes, so the run fails on a failing test, a script error, a skipped script, a
# crashed shard and a hung one (MIHO_TEST_TIMEOUT seconds). Prints the slowest tests.
test: rust
    #!/usr/bin/env bash
    set -uo pipefail
    out=build/test
    mkdir -p "$out"
    touch "$out/times"
    # The import is slow, and only a new class_name or a changed asset needs it.
    if [ ! -e "$out/imported" ] \
        || [ -n "$(find src tests tools assets addons project.godot -type f -newer "$out/imported" ! -name '*.uid' ! -name '*.gd' -print -quit)" ] \
        || find src tests tools addons -name '*.gd' -newer "$out/imported" -exec rg -l '^class_name' {} + | rg -q .; then
        {{ godot }} --headless --path . --import >/dev/null 2>&1 || { echo "error: import failed" >&2; exit 1; }
        touch "$out/imported"
    fi
    jobs=${MIHO_TEST_JOBS:-$(nproc)}
    # Longest script first onto the least loaded shard. A script with no time yet counts by its lines.
    plan=$(LC_ALL=C wc -l tests/test_*.gd | rg -v ' total$' | awk -v times="$out/times" '
        BEGIN { while ((getline line < times) > 0) { split(line, f, " "); ms[f[2]] = f[1] } }
        { n = split($2, p, "/"); print ((p[n] in ms) ? ms[p[n]] : $1 * 15), $2 }' \
        | sort -rn | awk -v jobs="$jobs" '
        { best = 0; for (i = 1; i < jobs; i++) if (load[i] < load[best]) best = i
          load[best] += $1; print best, $2 }')
    [ -n "$plan" ] || { echo "error: no test scripts" >&2; exit 1; }
    pids=()
    shards=()
    dirs=()
    for i in $(seq 0 $((jobs - 1))); do
        list=$(rg "^$i " <<<"$plan" | cut -d' ' -f2 | sed 's|^|res://|' | paste -sd,)
        [ -n "$list" ] || continue
        d=$out/shard-$i
        mkdir -p "$d/data"
        : > "$d/junit.xml"
        XDG_DATA_HOME=$PWD/$d/data timeout -k 10 "${MIHO_TEST_TIMEOUT:-600}" \
            {{ godot }} --headless --path . -s addons/gut/gut_cmdln.gd -gconfig= -gexit -glog=1 -gdisable_colors \
            -gpre_run_script=res://tools/test_times.gd -gjunit_xml_file="$d/junit.xml" \
            -gtest="$list" > "$d/log" 2>&1 &
        pids+=($!)
        shards+=("$i")
        dirs+=("$d")
    done
    failed=0
    for k in "${!pids[@]}"; do
        i=${shards[$k]}
        d=$out/shard-$i
        wait "${pids[$k]}"
        status=$?
        shard_failed=0
        [ "$status" -eq 0 ] || { echo "error: shard $i exited with $status (124 is a timeout)" >&2; shard_failed=1; }
        if rg -q 'SCRIPT ERROR|Ignoring script' "$d/log"; then
            echo "error: a script failed to load in shard $i" >&2
            shard_failed=1
        fi
        for s in $(rg "^$i " <<<"$plan" | cut -d' ' -f2); do
            rg -q "<testsuite name=\"$s\" tests=\"[1-9]" "$d/junit.xml" || { echo "error: $s ran no test" >&2; shard_failed=1; }
        done
        if [ "$shard_failed" -ne 0 ]; then
            rg -v '^\* test_|^$|^res://tests/|passed\.$|^TIME ' "$d/log" | tail -n 80 >&2
            failed=1
        fi
    done
    : > "$out/tests"
    awk -v out="$out/tests" '
        /<testcase / {
            match($0, /name="[^"]*"/); n = substr($0, RSTART + 6, RLENGTH - 7)
            match($0, /classname="[^"]*"/); c = substr($0, RSTART + 11, RLENGTH - 12)
            match($0, /time="[^"]*"/); t = substr($0, RSTART + 6, RLENGTH - 7)
            match($0, /assertions="[^"]*"/); a += substr($0, RSTART + 12, RLENGTH - 13)
            tests++; sum += t; printf "%.3f %s %s\n", t, c, n >> out
        }
        END { printf "%d tests, %d asserts, %.1f s of test time\n", tests, a, sum }' "${dirs[@]/%//junit.xml}"
    sort -rn "$out/tests" | head -n 10 | sed 's/^/slowest: /'
    if [ "$failed" -eq 0 ]; then
        rg -I '^TIME ' "${dirs[@]/%//log}" | cut -d' ' -f2,3 > "$out/times"
    fi
    echo "$SECONDS s on $jobs shards"
    exit "$failed"

# Serve the game to an AI agent over MCP on stdio (see .mcp.json).
mcp: rust
    {{ godot }} --headless --path . --import >&2
    {{ godot }} --headless --no-header --path . -s src/mcp/server.gd

# List every Korean string in the game, to read them all at once.
strings:
    rg -o --no-filename '"[^"]*[가-힣][^"]*"' src | sort -u

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

# Time storey generation, a round, forecasts, a Continue replay, the 도감 and spell examples.
bench: rust
    {{ godot }} --headless --path . --import
    {{ godot }} --headless --path . -s tools/bench.gd
    {{ godot }} --headless --path . -s tools/bench_round.gd
    {{ godot }} --headless --path . -s tools/bench_codex.gd
    {{ godot }} --headless --path . -s tools/bench_example.gd

# Replay a save (minus its last `back` actions) and explore from there; exits 1 on a back-and-forth loop.
explore-check save="~/.local/share/godot/app_userdata/미호/save.cfg" rounds="400" back="0": rust
    {{ godot }} --headless --path . --import
    {{ godot }} --headless --path . -s tools/explore_check.gd -- {{ save }} {{ rounds }} {{ back }}

# Print every Korean string literal under src/ with no English entry in assets/i18n; exits 1 if any.
i18n-check: rust
    #!/usr/bin/env bash
    set -uo pipefail
    {{ godot }} --headless --path . --import >/dev/null 2>&1
    out=$({{ godot }} --headless --path . -s tools/i18n_check.gd 2>&1); status=$?
    rg -v '^(Initialize godot-rust|Godot Engine)' <<<"$out" || true
    exit "$status"

# Print how often each event room appears and can be opened over N seeds x 9 storeys.
event-rooms seeds="200": rust
    {{ godot }} --headless --path . --import
    {{ godot }} --headless --path . -s tools/event_rooms.gd -- {{ seeds }}

# Print each storey's faults, event and set room rates and build time over N seeds, on one skeleton if named.
maps seeds="100" skeleton="": rust
    {{ godot }} --headless --path . --import
    {{ godot }} --headless --path . -s tools/maps.gd -- {{ seeds }} {{ skeleton }}

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

# Print how a plain bot fares from storey 1 over N seeds as Markdown: deaths, killers, one-blow deaths; on N processes.
survive seeds="200" procs="7": rust
    #!/usr/bin/env bash
    set -euo pipefail
    {{ godot }} --headless --path . --import >/dev/null 2>&1
    dir=$(mktemp -d -p "${XDG_CACHE_HOME:-$HOME/.cache}")
    trap 'gio trash "$dir"' EXIT
    pids=()
    for i in $(seq 0 $(({{ procs }} - 1))); do
        {{ godot }} --headless --path . -s tools/survive.gd -- --seeds={{ seeds }} --shard=$i/{{ procs }} --out="$dir" >/dev/null 2>&1 &
        pids+=($!)
    done
    for pid in "${pids[@]}"; do wait "$pid"; done
    {{ godot }} --headless --path . -s tools/survive.gd -- --merge="$dir" 2>/dev/null | rg -v '^(Initialize godot-rust|Godot Engine)'
