# Alien — Godot 4 (GDScript)

This file mirrors the project guidance in `CLAUDE.md` so Codex follows the same workflow and architectural constraints.

A Godot 4.6 project. The single most important rule: **prefer code over the editor**. Every behavior, scene, and resource should be reproducible from a fresh checkout by running scripts and reading text files — never by clicking through the editor UI.

## Toolchain

- **Engine binary:** `/home/broom/.local/bin/godot` (Godot 4.6.2-stable, Linux x86_64)
- **Run from project root:** `cd /home/broom/Games/alien_godot`

## Run / build commands

| Goal | Command |
| --- | --- |
| Headless import (refresh `.godot/`, no UI) | `godot --headless --import` |
| Run game headless, quit after N frames | `./run-headless.sh` (defaults to 5; `QUIT_AFTER=600 ./run-headless.sh`) — Godot's `--quit-after` counts frames, not seconds. 60 frames ~= 1s at 60fps. |
| Run game with display | `./run.sh` |
| Run a specific scene | `./run.sh res://scenes/foo.tscn` |
| Run one-off GDScript file (no scene) | `godot --headless --script res://tools/some_tool.gd` |
| Run the full headless test suite | `./run-tests.sh` |
| Run a single test | `godot --headless --script res://tests/test_foo.gd` |
| Syntax-check every script | `godot --headless --check-only --script res://scripts/main.gd` (per file) |

When using the headless run loop during development, always pass `--quit-after` (or call `get_tree().quit()` from code) so the process doesn't hang. After editing scripts, re-run `--import` only if you added/renamed files; pure `.gd` edits don't need it.

## Code-first rules (non-negotiable)

1. **Build scenes in `_ready()`, not in the editor.** A `.tscn` should usually be a single root node with a script attached. The script populates children. This makes diffs reviewable, regressions bisectable, and merges painless.
   - Exception: a small leaf scene that's instanced many times (a bullet, an enemy) and has no logic worth expressing in code may be a hand-edited `.tscn`. Still hand-edit it as text, never via the editor.
2. **Hand-write `.tscn` and `.tres` as text.** Both are plain text. If you must touch one, edit it directly. Do not save from the editor — the editor reorders fields, rewrites UIDs, and adds noise to diffs.
3. **No binary assets unless unavoidable.** Default to procedural visuals: `ColorRect`, `Polygon2D`, `ImmediateMesh`, `Curve`, `Gradient`, shaders. If a sprite is required, prefer SVG (`.svg`) over PNG and check it in alongside the script that uses it.
4. **No editor-only state.** Don't rely on values set in the inspector. Set defaults in `@export` declarations and override at instantiation in code. If a node needs configuration, expose it via `@export` *and* call `set_*` in code so the source of truth is the script.
5. **Autoloads via `project.godot`, not the editor's Project Settings dialog.** Edit the `[autoload]` section by hand.
6. **Input maps in `project.godot`.** Same reason. The `[input]` section is text — edit it.
7. **One responsibility per script.** Composition over inheritance; small nodes with focused scripts beat a god-node with a 600-line script.

## Core / client split (non-negotiable)

This project mirrors the MonoGame source's hard split between pure simulation and engine-aware code.

- **`scripts/core/`** is pure GDScript. Files here may **not** import or reference `Node`, `SceneTree`, `PackedScene`, rendering APIs, or input APIs. They `extends RefCounted` (or are static-only `class_name` shells) and use only built-in value types (`int`, `float`, `String`, `Vector2i`, `Dictionary`, `Array`, `PackedInt32Array`, ...).
- **`scripts/client/`** (added in phase 2 onward) is the only place that touches the engine — `_draw`, `_process`, input, scene graph.
- **Tile coords are `Vector2i`.** The C# port had a `TilePoint` record struct; we use `Vector2i` directly to avoid per-tile allocations and to get a fast hash key for `Dictionary`. Variable names that hold tile coords end in `_tile` or `tile_position` so the meaning is clear.
- The test suite enforces the split: `tests/test_core_smoke.gd` recursively loads every script under `scripts/core/` and instantiates it from a bare `SceneTree`. If a core file accidentally pulls in a `Node`-shaped dep, that test fails. New files under `scripts/core/` are picked up automatically — no manual registration.

## GDScript style

- `extends` first, then `class_name` if needed, then `@export` vars, then `@onready` vars, then private vars, then `_ready` / `_process` / `_input`, then methods.
- **Use static typing everywhere.** `var hp: int = 10`, `func damage(amount: int) -> void:`. Untyped GDScript is slower and silently hides bugs.
- Tabs for indentation (Godot's default — `.gd` files are tab-indented; the editor enforces this).
- `snake_case` for variables/functions/files, `PascalCase` for classes and node names, `SCREAMING_SNAKE` for constants.
- Signals: declare with typed args (`signal hit(damage: int)`). Connect with `Callable` syntax: `sig.connect(_on_hit)`.
- Prefer `@export` over hard-coded magic numbers — but provide a sensible default in the declaration so the editor isn't required.
- Don't use `get_node("Path/To/Thing")` strings scattered around. Either `@onready var foo: Node = $Path/To/Thing` once at the top, or build the child in code and keep a reference.

## Project layout

```text
alien_godot/
├── project.godot          # Engine config — edit by hand
├── run.sh / run-headless.sh / run-tests.sh
├── scenes/
│   └── main.tscn          # Single root, script-populated
├── scripts/
│   ├── main.gd            # Bootstraps the world in _ready()
│   ├── core/              # Pure simulation (no Node imports)
│   │   ├── world/         # WorldGrid, tile types
│   │   ├── gameplay/      # PlayerState, PlayerStats, EquippedWeapon
│   │   ├── inventory/     # InventoryState, ItemId
│   │   ├── time/          # ClockState, Season
│   │   └── simulation/    # GameState, SimulationStep, commands, balance
│   └── client/            # (phase 2+) renderer, input, HUD
├── resources/             # Reserved; not used in MVP
├── tests/                 # Headless SceneTree test scripts
└── tools/                 # One-off headless utilities
```

Add directories as needed; keep `scripts/` grouped by feature, not by node type.

## Testing

Godot has no built-in unit-test runner. Write tests as headless GDScript that exits with non-zero on failure:

```gdscript
# tests/test_player.gd
extends SceneTree

func _init() -> void:
	var p := preload("res://scripts/core/gameplay/player_stats.gd").new(100)
	assert(p.max_health == 100, "default max_health wrong")
	quit(0)
```

Run: `godot --headless --script res://tests/test_player.gd` — or `./run-tests.sh` for all of them.

A test is a `SceneTree` script that calls `quit(0)` on success, `quit(1)` on failure. Keep them fast (no `_process` loops) so the whole suite runs in seconds. Each test file is run in its own process by `run-tests.sh`, so a single failure doesn't poison the rest.

## Debugging loop

1. Edit a `.gd` file.
2. Run `./run-headless.sh` — read the output.
3. Use `print()`, `print_debug()`, or `push_error("msg")` for instrumentation. `push_error` returns non-zero exit on `--quit-after` runs, which is useful for CI.
4. Don't open the editor to inspect state — instrument the code and re-run.

If you genuinely need the editor to investigate something visual, open it once, take notes, then close it and encode the findings as code or comments.

## When the rules don't fit

If you hit a case where the editor really is the right tool (e.g., authoring a complex animation curve, tweaking a shader visually), do this:
1. Note in your response *why* code-first didn't fit.
2. Save the result as text (`.tres`/`.tscn` are already text — just check them in).
3. Add a comment in the relevant script pointing at the resource and explaining what was done in the editor.

Don't silently introduce editor-authored state — surface it so future changes know to use the same workflow.

## Quick reference

- Engine docs: https://docs.godotengine.org/en/4.6/
- GDScript reference: https://docs.godotengine.org/en/4.6/tutorials/scripting/gdscript/gdscript_basics.html
- Class reference (offline): `godot --doctool .` writes XML class docs to the project — useful for greppable API lookup.
