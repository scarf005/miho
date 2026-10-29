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

# Format and lint GDScript.
lint:
    gdformat --check src tests
    gdlint src tests

# Re-subset the bundled fonts after changing Korean or Hanja text.
fonts:
    uv run --quiet tools/fonts.py

# Export the web build to build/web.
web:
    mkdir -p build/web
    {{ godot }} --headless --path . --export-release Web build/web/index.html

# Export and serve the web build on localhost.
serve: web
    python3 -m http.server {{ web_port }} --bind 127.0.0.1 --directory build/web
