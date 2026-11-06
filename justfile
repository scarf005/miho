godot := env_var_or_default("GODOT", "godot")
web_port := env_var_or_default("WEB_PORT", "4180")
# Emscripten 4.0.20, the version the Godot 4.7.2 web templates are built with.
nightly := env_var_or_default("MIHO_NIGHTLY", "nightly")
emsdk := env_var_or_default("MIHO_EMSDK", data_directory() / "emsdk-4.0.20")
template_src := env_var_or_default("MIHO_GODOT_SRC", data_directory() / "godot-4.7.2-src")
template := env_var_or_default("MIHO_WEB_TEMPLATE", data_directory() / "miho-web-template.zip")

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

# Refresh Godot's list of script classes. A checkout that gets a new class from a merge or a pull cannot start without it.
import:
    #!/usr/bin/env bash
    set -uo pipefail
    out=build/test
    mkdir -p "$out"
    # The import is slow, and only a changed list of script classes or a changed asset needs it.
    classes=$(rg --sort path '^(class_name|extends|@tool|@abstract)' src tests tools addons)
    if [ ! -e "$out/imported" ] \
        || [ -n "$(find src tests tools assets addons project.godot -type f -newer "$out/imported" ! -name '*.uid' ! -name '*.gd' -print -quit)" ] \
        || [ "$classes" != "$(cat "$out/classes" 2>/dev/null)" ]; then
        {{ godot }} --headless --path . --import >/dev/null 2>&1 || { echo "error: import failed" >&2; exit 1; }
        touch "$out/imported"
        printf '%s\n' "$classes" > "$out/classes"
    fi

# Start the game off the desktop, muted, for a few seconds and fail on any script error.
launch-check: rust import
    #!/usr/bin/env bash
    set -uo pipefail
    # gamescope does not pass on the exit status of what it runs.
    log=$(timeout 40 gamescope --backend headless -W 1280 -H 720 -w 1280 -h 720 -- sh -c '{{ godot }} --audio-driver Dummy --path . --quit-after 120; echo "game-exit=$?"' 2>&1)
    if rg 'SCRIPT ERROR' <<<"$log" | sort -u | rg .; then exit 1; fi
    rg -q 'game-exit=0' <<<"$log" || { echo "error: the game did not start or exit cleanly" >&2; exit 1; }

# Play on the desktop.
run: rust import
    {{ godot }} --path .

# Run the rule tests in parallel Godot shards (MIHO_TEST_JOBS, one per core by default),
# balanced by the script times of the last run. Each shard has its own user:// dir, log
# and JUnit file in build/test/shard-N. GUT skips a script that fails to load and still
# passes, so the run fails on a failing test, a script error, a skipped script, a
# crashed shard and a hung one (MIHO_TEST_TIMEOUT seconds). Prints the slowest tests.
test: rust import
    #!/usr/bin/env bash
    set -uo pipefail
    out=build/test
    mkdir -p "$out"
    touch "$out/times"
    jobs=${MIHO_TEST_JOBS:-$(nproc)}
    plan=$({{ just_executable() }} test-plan "$jobs")
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
            {{ godot }} --headless --path . -s addons/gut/gut_cmdln.gd -gconfig= -gexit -glog=1 -gdisable_colors -gpaint_after=0 \
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
        rg -I '^(TIME|STOREY) ' "${dirs[@]/%//log}" > "$out/times"
    fi
    echo "$SECONDS s on $jobs shards"
    exit "$failed"

# Run the given test scripts alone: just test-file tests/test_curse.gd tests/test_rules.gd
test-file +files: rust
    {{ godot }} --headless --path . -s addons/gut/gut_cmdln.gd -gconfig= {{ prepend("-gtest=res://", files) }} -gexit

# Print digests of what seeds build and play, to hold a speed change to the same result.
digest seeds="33" rounds="40": rust
    {{ godot }} --headless --path . -s tools/storey_digest.gd -- {{ seeds }} {{ rounds }}

# Print which shard runs which test script, from the times of the last run: just test-plan 10
test-plan jobs:
    @LC_ALL=C wc -l tests/test_*.gd | rg -v ' total$' | awk -v times=build/test/times -v jobs={{ jobs }} -f tools/test_plan.awk

# Run `just test` in a transient unit that holds the suite lock while other sessions share the machine;
# prints its CPU time: just test-unit miho-x /path/to/log, and a last argument 1 for a serial run.
test-unit unit log jobs="":
    flock "$XDG_RUNTIME_DIR/miho-test.lock" systemd-run --user --wait --collect --slice=bnwork.slice --unit={{ unit }} --working-directory="$PWD" -E MIHO_TEST_JOBS={{ jobs }} -p RuntimeMaxSec=1200 -p MemoryMax=12G -p MemorySwapMax=0 -p StandardOutput=append:{{ log }} -p StandardError=append:{{ log }} {{ just_executable() }} test

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
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p build/web
    # The template from `just web-template` is used when it exists, else the official one.
    # Its fallback text server reads no ICU data, and the editor packs a file of that name in place of its own.
    if [ -f "{{ template }}" ]; then
        [ -e build/export_presets.bak ] || cp export_presets.cfg build/export_presets.bak
        trap 'mv build/export_presets.bak export_presets.cfg; rm -f icudt_godot.dat' EXIT
        sed -i 's|^custom_template/release=.*|custom_template/release="{{ template }}"|' export_presets.cfg
        printf 0 > icudt_godot.dat
    fi
    {{ godot }} --headless --path . --export-release Web build/web/index.html

# Build the Godot 4.7.2 web template without 3D, advanced GUI and unused modules (about 15 min on 8 cores, 12 GB).
web-template:
    #!/usr/bin/env bash
    set -euo pipefail
    [ -d "{{ template_src }}" ] || git clone --depth 1 --branch 4.7.2-stable https://github.com/godotengine/godot.git "{{ template_src }}"
    source "{{ emsdk }}/emsdk_env.sh" >/dev/null 2>&1
    cd "{{ template_src }}"
    # Modules the game does not use (2D drawing, GDScript, ogg, regex, freetype stay). The fallback text server shapes Hangul.
    mods="astcenc basis_universal bcdec betsy bmp camera csg cvtt dds enet etcpak fbx gltf gridmap hdr interactive_music jolt_physics jpg jsonrpc ktx lightmapper_rd mbedtls meshoptimizer mobile_vr mp3 msdfgen multiplayer navigation_2d navigation_3d noise objectdb_profiler openxr raycast svg text_server_adv tga theora tinyexr upnp vhacd visual_shader webp webrtc websocket webxr xatlas_unwrap zip"
    args=(); for m in $mods; do args+=("module_${m}_enabled=no"); done
    uvx scons platform=web target=template_release threads=no dlink_enabled=yes \
        disable_3d=yes disable_advanced_gui=yes module_text_server_fb_enabled=yes optimize=size lto=full production=yes \
        "${args[@]}" -j"$(nproc)"
    cp bin/godot.web.template_release.wasm32.nothreads.dlink.zip "{{ template }}"

# Publish the web template for CI, on a tag that deploys nothing (.github/actions/web, deploy.yml).
web-template-release version="4.7.2":
    gh release create "web-template-{{ version }}" "{{ template }}#miho-web-template.zip" --target "$(git rev-parse HEAD)" --latest=false --title "Web template {{ version }}" --notes "Godot {{ version }} web template from \`just web-template\`."

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

# Build the Rust extension for a download build with cargo-zigbuild (Android: the NDK): linux, windows, macos or android.
rust-dist platform:
    #!/usr/bin/env bash
    set -euo pipefail
    cd rust
    export CARGO_PROFILE_RELEASE_STRIP=symbols
    case "{{ platform }}" in
        # glibc 2.31 floor; copied over the desktop build, where native.gdextension looks for it.
        linux)
            cargo zigbuild --release --quiet --target x86_64-unknown-linux-gnu.2.31
            install -D target/x86_64-unknown-linux-gnu/release/libmiho_native.so target/release/libmiho_native.so ;;
        windows) cargo zigbuild --release --quiet --target x86_64-pc-windows-gnu ;;
        macos) cargo zigbuild --release --quiet --target universal2-apple-darwin ;;
        android)
            ndk=${ANDROID_NDK_ROOT:-$(printf '%s\n' "${ANDROID_HOME:?}"/ndk/* | sort -V | tail -n 1)}
            bin=$ndk/toolchains/llvm/prebuilt/linux-x86_64/bin
            CC_aarch64_linux_android=$bin/aarch64-linux-android24-clang AR_aarch64_linux_android=$bin/llvm-ar \
                CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER=$bin/aarch64-linux-android24-clang \
                cargo build --release --quiet --target aarch64-linux-android ;;
        *) echo "error: unknown platform {{ platform }}" >&2; exit 1 ;;
    esac

# Export a download build to build/dist as miho-<platform>.zip (.apk on android; MIHO_ANDROID_KEYSTORE with _USER and _PASSWORD signs it, else a throwaway key): just dist 0.3.1 linux
dist version platform: rust import
    #!/usr/bin/env bash
    set -euo pipefail
    {{ just_executable() }} --justfile "{{ justfile() }}" --working-directory . rust-dist {{ platform }}
    v={{ trim_start_match(version, "v") }}
    code=$(awk -F. '{ print $1 * 10000 + $2 * 100 + $3 }' <<<"$v")
    out=build/dist
    conf=
    mkdir -p "$out"
    cp export_presets.cfg "$out/presets.bak"
    trap 'mv "$out/presets.bak" export_presets.cfg; [ -z "$conf" ] || gio trash "$conf"' EXIT
    sed -i -e "s|^version/name=.*|version/name=\"$v\"|" -e "s|^version/code=.*|version/code=$code|" \
        -e "s|^application/short_version=.*|application/short_version=\"$v\"|" -e "s|^application/version=.*|application/version=\"$v\"|" \
        -e "s|^application/file_version=.*|application/file_version=\"$v.0\"|" -e "s|^application/product_version=.*|application/product_version=\"$v.0\"|" \
        export_presets.cfg
    case "{{ platform }}" in
        linux)
            mkdir -p "$out/linux"
            {{ godot }} --headless --path . --export-release Linux
            (cd "$out/linux" && zip -X -q -r -FS ../miho-linux.zip .) ;;
        windows)
            mkdir -p "$out/windows"
            {{ godot }} --headless --path . --export-release Windows
            (cd "$out/windows" && zip -X -q -r -FS ../miho-windows.zip .) ;;
        macos) {{ godot }} --headless --path . --export-release macOS ;;
        android)
            conf=$(mktemp -d -p "${XDG_CACHE_HOME:-$HOME/.cache}")
            if [ -z "${MIHO_ANDROID_KEYSTORE:-}" ]; then
                key="$conf/throwaway.keystore"
                keytool -genkeypair -keystore "$key" -alias miho -keyalg RSA -keysize 2048 -validity 10000 \
                    -storepass miho-throwaway -dname CN=miho 2>/dev/null
                set -- "$key" miho miho-throwaway
            else
                set -- "$MIHO_ANDROID_KEYSTORE" "${MIHO_ANDROID_KEYSTORE_USER:?}" "${MIHO_ANDROID_KEYSTORE_PASSWORD:?}"
            fi
            XDG_CONFIG_HOME=$conf GODOT_ANDROID_KEYSTORE_RELEASE_PATH=$1 GODOT_ANDROID_KEYSTORE_RELEASE_USER=$2 \
                GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=$3 {{ godot }} --headless --path . --export-release Android ;;
        *) echo "error: unknown platform {{ platform }}" >&2; exit 1 ;;
    esac

# Push the builds in build/dist to the itch channels linux, windows, mac and android with the version: just itch-downloads 0.3.1
itch-downloads version *platforms="linux windows macos android":
    #!/usr/bin/env bash
    set -euo pipefail
    for p in {{ platforms }}; do
        file=build/dist/miho-$p.zip
        [ "$p" = android ] && file=build/dist/miho-android.apk
        butler push "$file" "scarf005/miho:${p/macos/mac}" --userversion "{{ trim_start_match(version, "v") }}"
    done

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

# Print the first seeds that draw a 미궁, with its storey and concept, to pass to `just shot --seed= --depth=`.
maze-seeds:
    {{ godot }} --headless --path . -s tools/maze_seeds.gd

# Print the first seeds with the tile beside the trail's exit on storey 1 and the key that steps onto it, to pass to `just shot --seed= --keys=at:X:Y,<key>`.
outside-seeds:
    {{ godot }} --headless --path . -s tools/outside_seeds.gd

# Capture a fixed set of scenes into dir (.screenshots/frames/a) with `just shot`, CRT and swaying off except in the crt scene, to compare two builds with `just frames-diff`.
frames dir:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p '{{ dir }}'
    scenes=(
        "title --seed=3"
        "map --seed=3 --keys=Space"
        "aim --seed=3 --keys=Space,spawn:haetae:2:0,1,aim:2:0"
        "hover --seed=3 --keys=Space,spawn:haetae:2:0,aim:2:0"
        "codex-list --seed=3 --keys=Space,Slash,Left,Down"
        "codex-detail --seed=3 --keys=Space,Slash,Right,Right,Down,Down"
        "options --seed=3 --keys=Space,Escape"
        "cast --seed=3 --keys=Space,spawn:haetae:2:0,1,aim:2:0,film:Space:1:0.15"
        "crt --seed=3 --keys=Space --crt=50"
    )
    for scene in "${scenes[@]}"; do
        read -r name args <<<"$scene"
        just shot "{{ dir }}/$name.png" --still --crt=0 $args >/dev/null 2>&1 || { echo "error: scene $name failed" >&2; exit 1; }
        echo "$name"
    done

# Compare the PNGs of two `just frames` runs; names the scenes that differ and exits 1. A still scene must match to the pixel. The CRT shader flickers the brightness by 1.2% with the clock, so in the crt scene a pixel counts as different only past 3%. A cast scene is caught mid-flight with a fading noise word: it differs past an RMSE of 1% of the range.
frames-diff a b:
    #!/usr/bin/env bash
    set -uo pipefail
    status=0
    for f in '{{ a }}'/*.png; do
        name=$(basename "$f" .png)
        other='{{ b }}'/"$name.png"
        if [ ! -f "$other" ]; then
            differs=1
        elif [[ "$name" == cast* ]]; then
            differs=$(compare -metric RMSE "$f" "$other" null: 2>&1 | rg -o '\(([0-9.e-]+)\)' -r '$1' | awk '{ print ($1 > 0.01) }')
        else
            fuzz=0
            [[ "$name" == crt* ]] && fuzz=3
            differs=$(compare -metric AE -fuzz "$fuzz%" "$f" "$other" null: 2>&1 | cut -d' ' -f1 | awk '{ print ($1 > 0) }')
        fi
        if [ "${differs:-1}" != 0 ]; then
            echo "differs: $name"
            status=1
        fi
    done
    for f in '{{ b }}'/*.png; do
        if [ ! -f '{{ a }}'/"$(basename "$f")" ]; then
            echo "differs: $(basename "$f" .png)"
            status=1
        fi
    done
    exit $status

# Time storey generation, a round, forecasts, a Continue replay, the 도감, spell examples and a draw of a lit map.
bench: rust
    {{ godot }} --headless --path . --import
    {{ godot }} --headless --path . -s tools/bench.gd
    {{ godot }} --headless --path . -s tools/bench_round.gd
    {{ godot }} --headless --path . -s tools/bench_mind.gd
    {{ godot }} --headless --path . -s tools/bench_codex.gd
    {{ godot }} --headless --path . -s tools/bench_example.gd
    {{ godot }} --headless --path . -s tools/bench_term.gd

# List what each 도감 example does in its window as markdown rows; MISS marks one that does not show what its entry says.
audit-codex: rust import
    {{ godot }} --headless --path . -s tools/audit_codex.gd

# Replay the saved runs of tools/oracle/ and compare their hashes with tools/oracle.expected; exits 1 on any difference.
oracle: rust import
    #!/usr/bin/env bash
    set -uo pipefail
    mkdir -p build
    {{ godot }} --headless --path . -s tools/oracle.gd > build/oracle.log 2>&1
    status=$?
    rg -x '[0-9a-z-]+ [0-9a-f]{64}' build/oracle.log > build/oracle.out
    if [ "$status" -ne 0 ] || rg -q 'SCRIPT ERROR' build/oracle.log; then
        rg -v '^(Initialize godot-rust|Godot Engine|[0-9a-z-]+ [0-9a-f]{64}$)' build/oracle.log >&2
        diff tools/oracle.expected build/oracle.out
        exit 1
    fi
    diff tools/oracle.expected build/oracle.out || exit 1
    echo "oracle ok: $(tail -n 1 build/oracle.out)"
    just oracle-text

# Hash the game's text (spells, 도감, glossary, tile and creature hovers) in Korean and English and compare with tools/text_oracle.expected; names the groups that differ, exits 1.
oracle-text: rust import
    #!/usr/bin/env bash
    set -uo pipefail
    mkdir -p build
    {{ godot }} --headless --path . -s tools/text_oracle.gd > build/text_oracle.log 2>&1
    status=$?
    rg -x '[0-9a-z.]+ [0-9a-f]{64}' build/text_oracle.log > build/text_oracle.out
    if [ "$status" -ne 0 ] || rg -q 'SCRIPT ERROR' build/text_oracle.log; then
        rg -v '^(Initialize godot-rust|Godot Engine|[0-9a-z.]+ [0-9a-f]{64}$)' build/text_oracle.log >&2
        exit 1
    fi
    if ! diff -q tools/text_oracle.expected build/text_oracle.out >/dev/null; then
        echo "text oracle differs in:" >&2
        diff tools/text_oracle.expected build/text_oracle.out | rg '^[<>] ' | cut -d' ' -f2 | sort -u | rg -vx all >&2
        exit 1
    fi
    echo "text oracle ok: $(tail -n 1 build/text_oracle.out)"

# Play the bot again, write tools/oracle/*.cfg, tools/oracle.expected and tools/text_oracle.expected, and print what the runs cover; only for a change of rules on purpose.
oracle-record: rust import
    #!/usr/bin/env bash
    set -uo pipefail
    {{ godot }} --headless --path . -s tools/oracle.gd -- --record | rg -v '^(Initialize godot-rust|Godot Engine)'
    {{ godot }} --headless --path . -s tools/text_oracle.gd -- --record | rg -v '^(Initialize godot-rust|Godot Engine)'

# Print the oracle hash of one save file that is not in the set; exits 1 for a save of another version.
oracle-save path: rust import
    #!/usr/bin/env bash
    set -uo pipefail
    {{ godot }} --headless --path . -s tools/oracle.gd -- --save={{ path }} | rg -v '^(Initialize godot-rust|Godot Engine)'

# Time one read and one clone of 40 creatures in each storage shape of docs/plan-ecs.md.
bench-storage: rust import
    {{ godot }} --headless --path . -s tools/bench_storage.gd

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

# Print, per storey, how many of N builds place a creature of a kind: just placed mulgwisin 50
placed kind seeds="50": rust
    {{ godot }} --headless --path . -s tools/placed.gd -- {{ kind }} {{ seeds }} | rg '^storey'

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
