# Phase 2 — World grid + excavation / wall building

This is the detailed implementation plan for phase 2 of `high_level_plan.md`.
It fleshes out the half-ported `WorldGrid` from phase 1 with real tile-type
rules, lands the first slice of the client layer (`scripts/client/`) so the
simulation finally becomes visible in a window, and wires excavation +
wall-building all the way through from mouse input to tile mutation.

The phase ends when:

- `./run-tests.sh` passes a suite that now includes `WorldGrid` rules,
  `GameActionRules` per-kind validity, and the excavation / wall-building
  / movement branches of `SimulationStep`.
- `./run.sh` opens a window, draws the 24×16 world with five distinct tile
  colors, shows a hover overlay (green / red) under the mouse, lets `1` /
  `2` flip between Excavate / Build-Wall modes, lets right-click queue the
  matching action (Excavate turns soil to floor; Build-Wall consumes one
  scrap and replaces an open tile with a wall), lets left-click move the
  player to a walkable tile, and lets `C` cancel an in-progress action.
- `./run-headless.sh` still boots cleanly.

## Scope

### In scope

Core (still no `Node` imports under `scripts/core/`):

- `WorldTileType` static helpers: `is_open_space`, `is_blocking`,
  `can_be_replaced_with_wall`, `can_be_replaced_with_furnace`. These are
  read-only classification helpers, so they live on `WorldTileType` itself
  rather than a separate "extensions" file (see Open questions in phase 1).
- `WorldGrid` rules from C# that phase 1 deferred: `is_excavatable`,
  `can_build_wall_at`, `can_build_furnace_at`, `try_excavate`,
  `try_build_wall`, `try_build_furnace`, `is_indoors` (BFS), and a real
  `is_walkable` that consults `is_open_space`.
- `GameActionRules`: per-kind validity for `EXCAVATE` and `BUILD_WALL`
  (target in bounds, target tile excavatable / replaceable, target ≠ player
  tile for builds, scrap available for builds), and the matching
  completion bodies (`world.try_excavate(...)` /
  `inventory.try_remove(SCRAP_METAL, 1)` + `world.try_build_wall(...)`).
- `simulation/build_costs.gd` — a tiny `class_name BuildCosts` shell with
  one constant for `SCRAP_METAL_WALL_SCRAP_COST = 1`. Phase 5's
  `RecipeCatalog` will subsume this; today's job is to keep the magic
  number out of `GameActionRules` while we wait for the recipes.

Client (the *first* code under `scripts/client/`):

- `client/tile_layout.gd` — value object owning a tile-pixel mapping
  (`tile_to_rect`, `pixel_to_tile`, `is_visible`). No camera scrolling
  yet; phase 2 fixes the layout origin and tile size.
- `client/world_renderer.gd` — `Node2D` whose `_draw()` walks the visible
  region and paints each tile via a per-tile draw function. Also draws
  the player marker, the active-action target highlight, and the hover
  preview overlay.
- `client/input_reader.gd` — `RefCounted` (or a plain `Node` so it can
  receive `_input` callbacks; see Design decisions). Holds the current
  `interaction_mode`, exposes `take_commands() -> Array[GameCommand]`,
  and tracks the hovered tile each frame.
- `client/game_session.gd` — `Node` that owns one `GameState` + one
  `SimulationStep` and exposes `update(delta_seconds, commands)`. Mirrors
  the C# `ClientGameSession` exactly.
- `client/game_interaction_mode.gd` — tiny `class_name GameInteractionMode`
  with `enum Kind { EXCAVATE, BUILD_WALL }` plus a static
  `to_action_kind(mode)` lookup. Furnace mode is deferred to phase 5.
- `scripts/main.gd` — refactored: instantiate `GameSession`,
  `WorldRenderer`, `InputReader`; in `_process(delta)` read commands,
  advance the session, push the hovered tile + interaction mode to the
  renderer, `queue_redraw()`.

Project config:

- `project.godot` `[input]` section with three text-edited actions:
  `mode_excavate` (key `1`), `mode_build_wall` (key `2`),
  `cancel_action` (key `C`). Mouse buttons are read directly via
  `InputEventMouseButton` — no actions for those.
- Phase 2 adds the input section by hand. No autoloads.

### Deferred to later phases

- `BUILD_FURNACE` action handling end-to-end. The `WorldGrid` helpers
  (`can_build_furnace_at`, `try_build_furnace`) land now because they're
  trivially small and live alongside the wall helpers, but
  `GameActionRules` continues to no-op the BUILD_FURNACE completion, and
  the input reader has no Build-Furnace mode key (`3`). Phase 5 lands
  the action, the cost (4 scrap + 1 fuel), the per-tile state for an
  active furnace, and the right-click-on-furnace-to-fuel path.
- `RecipeCatalog` / `RecipeRules` / `CraftRecipeCommand` — phase 5.
  Phase 2 fakes the wall cost via `BuildCosts`.
- HUD (status bars, clock readout, expedition button) — phase 3 onward.
  Phase 2 ships *no* HUD; the player's position and the current
  interaction mode are the only on-screen affordances. (We can print the
  mode name to the window title for clarity — see Design decisions.)
- `set_environment_status` is *not* wired to the now-real `is_indoors` /
  underground checks each frame. Phase 3's `SurvivalRules` is the
  natural caller because indoor / underground only matter when the
  temperature model exists. Phase 2 just makes `is_indoors` correct and
  testable.
- Camera scrolling, dynamic tile size, visible-window clipping — the
  24×16 world fits at a fixed tile size in 1280×720 with margin. Phase
  2's `TileLayout` is a candidate to grow into the C# `WorldViewLayout`
  later.
- Sprite assets. Tiles are `draw_rect(...)`; the player is a small
  centered rect on the player's tile. SVG procedural assets (if any)
  arrive when the visual fidelity demands them, not before.
- Combat / expedition state and the per-frame `state.advance_furnaces`
  call — still phase 4 / 5 / 6.

## Core port (file-by-file)

All paths are under `scripts/core/`. Existing files are *amended*; new
files note their full path. Tests are listed in their own section below.

### `world/world_tile_type.gd` (amend)

Phase 1 only declared the enum. Phase 2 adds four static helpers that
mirror `WorldTileTypeExtensions.cs`:

```gdscript
class_name WorldTileType
extends RefCounted

enum Kind { AIR, SOIL, EXCAVATED_FLOOR, SCRAP_METAL_WALL, FURNACE }

static func is_open_space(kind: int) -> bool:
    return kind == Kind.AIR or kind == Kind.EXCAVATED_FLOOR or kind == Kind.FURNACE

static func is_blocking(kind: int) -> bool:
    return not is_open_space(kind)

static func can_be_replaced_with_wall(kind: int) -> bool:
    return kind == Kind.AIR or kind == Kind.EXCAVATED_FLOOR

static func can_be_replaced_with_furnace(kind: int) -> bool:
    return kind == Kind.EXCAVATED_FLOOR
```

`is_blocking` is included even though phase 2 doesn't call it, because
the C# port carries it and it's one line — keeps the surface area
matched without inventing a name in phase 4 / 5.

### `world/world_grid.gd` (amend)

Replace the phase-1 always-true `is_walkable` and add the deferred
methods. Drop the phase-1 TODO comment at the top of the file. The
neighbor table lives as a module-level `const`:

```gdscript
const _NEIGHBOR_OFFSETS: Array[Vector2i] = [
    Vector2i(0, -1),
    Vector2i(1, 0),
    Vector2i(0, 1),
    Vector2i(-1, 0),
]
```

New methods (signature-faithful to `WorldGrid.cs`):

```
func is_excavatable(tile: Vector2i) -> bool
func can_build_wall_at(tile: Vector2i) -> bool
func can_build_furnace_at(tile: Vector2i) -> bool
func is_walkable(tile: Vector2i) -> bool          # replaces phase-1 stub
func try_excavate(tile: Vector2i) -> bool
func try_build_wall(tile: Vector2i) -> bool
func try_build_furnace(tile: Vector2i) -> bool
func is_indoors(tile: Vector2i) -> bool
```

Implementation notes:

- All bounds-checked; `is_excavatable` requires `tile.y >= surface_row`.
- `try_*` short-circuit via the matching `can_*` / `is_*` predicate, then
  call `set_tile`. They return `bool` (consumed by `GameActionRules`).
- `is_indoors` BFS:
  - First: `assert(is_within_bounds(tile))`. If `not is_open_space(get_tile(tile))`, return `false`.
  - `var visited: Dictionary = {}` keyed by `Vector2i`.
  - Frontier: `Array[Vector2i]`, used like a queue with `pop_front()`.
  - On dequeue, if the current tile touches `x == 0 or x == width - 1
    or y == 0 or y == height - 1 or y < surface_row`, return `false`
    immediately. (The C# version uses these as "open to the outside"
    — a sealed pocket cannot reach any of them.)
  - Otherwise enqueue any unvisited in-bounds neighbour whose tile
    `is_open_space`.
  - If the BFS exhausts the frontier, return `true`.
- `Vector2i` is a built-in value type in GDScript and hashes correctly as
  a `Dictionary` key — no boxing needed.

### `simulation/build_costs.gd` (new)

Tiny one-constant shell so `GameActionRules` doesn't carry a magic
number, and so phase 5 has an obvious file to delete when `RecipeRules`
arrives:

```gdscript
class_name BuildCosts
extends RefCounted

# Phase 5 replaces this with RecipeCatalog / RecipeRules. Phase 2 keeps
# the wall cost in one place so GameActionRules can stay readable.
const SCRAP_METAL_WALL_SCRAP_COST: int = 1
```

`Furnace` cost (4 scrap + 1 fuel) intentionally not added — the
BUILD_FURNACE action body still no-ops in phase 2.

### `simulation/game_action_rules.gd` (amend)

Tighten `can_start_action` and fill in `complete_action` for the two
phase-2 kinds. The C# version reads roughly:

```
return actionKind switch
{
    Excavate => target is TilePoint t && state.World.IsExcavatable(t),
    BuildWall => target is TilePoint t
        && t != state.Player.TilePosition
        && RecipeRules.CanAfford(state.Inventory, RecipeId.ScrapMetalWall)
        && state.World.CanBuildWallAt(t),
    BuildFurnace => target is TilePoint t
        && t != state.Player.TilePosition
        && RecipeRules.CanAfford(state.Inventory, RecipeId.Furnace)
        && state.World.CanBuildFurnaceAt(t),
    Attack => false,
    _ => true,
};
```

Phase 2 ports the first two branches; `BUILD_FURNACE`, `EXPEDITION`,
`CRAFT`, `ATTACK` all keep their phase-1 default-true / no-op
behavior. Roughly:

```gdscript
static func can_start_action(state: GameState, action_kind: int, target_tile: Variant) -> bool:
    if not state.player.is_alive() or state.active_action != null:
        return false
    match action_kind:
        GameActionKind.Kind.EXCAVATE:
            return target_tile is Vector2i and state.world.is_excavatable(target_tile)
        GameActionKind.Kind.BUILD_WALL:
            if not (target_tile is Vector2i):
                return false
            if target_tile == state.player.tile_position:
                return false
            if state.inventory.get_count(ItemId.Id.SCRAP_METAL) < BuildCosts.SCRAP_METAL_WALL_SCRAP_COST:
                return false
            return state.world.can_build_wall_at(target_tile)
        # BUILD_FURNACE / EXPEDITION / CRAFT fall through to true; ATTACK / future
        # combat phases override later.
        _:
            return true
```

`complete_action`: add real bodies for `EXCAVATE` and `BUILD_WALL`,
leave the others as `pass`. The wall body pays before mutating, matching
the C# `TryPayRecipe` contract:

```gdscript
match action.kind:
    GameActionKind.Kind.EXCAVATE:
        if action.target_tile is Vector2i:
            state.world.try_excavate(action.target_tile)
    GameActionKind.Kind.BUILD_WALL:
        if action.target_tile is Vector2i:
            if state.inventory.try_remove(ItemId.Id.SCRAP_METAL, BuildCosts.SCRAP_METAL_WALL_SCRAP_COST):
                state.world.try_build_wall(action.target_tile)
    _:
        pass
```

The "pay-then-build" order matters: if the inventory was raided between
`can_start_action` and `complete_action` (impossible today, but possible
in phase 4 once expeditions consume scrap mid-flight), we don't want a
free wall.

### Untouched core files

`game_state.gd`, `game_state_factory.gd`, `simulation_step.gd`,
`survival_rules.gd`, `player_state.gd`, all command structs, `game_action.gd`,
`game_action_kind.gd`, `expedition_status.gd`, `clock_state.gd`,
`inventory_state.gd`, `player_stats.gd`, `equipped_weapon.gd`, `season.gd`,
`item_id.gd`, `game_command.gd` — *no changes in phase 2.*

`SimulationStep.advance` already routes `MovePlayerCommand` through
`state.world.is_walkable(...)`; phase 1 just had `is_walkable` always
return true. Phase 2's real implementation now means that move commands
that target a wall, soil, or out-of-bounds tile are silently dropped, as
expected.

## Client port (first arrival)

All paths are under `scripts/client/`. The directory does not exist
yet — create it. None of these files may be `extends RefCounted` *and*
need `_input` / `_draw`; the renderer and the optional input node
extend `Node2D` / `Node` accordingly.

### `client/game_interaction_mode.gd` (new)

```gdscript
class_name GameInteractionMode
extends RefCounted

enum Kind { EXCAVATE, BUILD_WALL }

static func to_action_kind(mode: int) -> int:
    match mode:
        Kind.EXCAVATE:
            return GameActionKind.Kind.EXCAVATE
        Kind.BUILD_WALL:
            return GameActionKind.Kind.BUILD_WALL
        _:
            assert(false, "unknown interaction mode")
            return GameActionKind.Kind.EXCAVATE

static func display_name(mode: int) -> String:
    match mode:
        Kind.EXCAVATE: return "Excavate"
        Kind.BUILD_WALL: return "Build Wall"
        _: return "?"
```

Phase 5 adds `BUILD_FURNACE` here.

### `client/tile_layout.gd` (new)

Self-contained; a `RefCounted` so multiple consumers (renderer + input
reader) can share one instance. No `Node` deps, but lives under
`client/` because its purpose is rendering / hit-testing.

```gdscript
class_name TileLayout
extends RefCounted

const TILE_SIZE_PX: int = 36
const ORIGIN_X: int = 24
const ORIGIN_Y: int = 24

var world: WorldGrid

func _init(p_world: WorldGrid) -> void:
    assert(p_world != null, "world required")
    world = p_world

func tile_to_rect(tile: Vector2i) -> Rect2:
    return Rect2(
        Vector2(ORIGIN_X + tile.x * TILE_SIZE_PX, ORIGIN_Y + tile.y * TILE_SIZE_PX),
        Vector2(TILE_SIZE_PX - 1, TILE_SIZE_PX - 1))

func pixel_to_tile(p: Vector2) -> Variant:
    var tx := int(floor((p.x - ORIGIN_X) / TILE_SIZE_PX))
    var ty := int(floor((p.y - ORIGIN_Y) / TILE_SIZE_PX))
    var t := Vector2i(tx, ty)
    return t if world.is_within_bounds(t) else null

func is_visible(_tile: Vector2i) -> bool:
    return true   # phase 2: the whole world fits on screen
```

The constants are exposed as `const` on the class so the renderer and
the input reader can use them without having to thread an instance
through. `pixel_to_tile` returns `null` when the cursor is outside the
world rectangle.

### `client/world_renderer.gd` (new)

`Node2D`. The whole point of the per-tile draw function is that this
file grows naturally into sprite composition later — for now each call
emits one `draw_rect`.

```gdscript
class_name WorldRenderer
extends Node2D

const _TILE_COLORS: Dictionary = {
    WorldTileType.Kind.AIR: Color8(76, 119, 168),
    WorldTileType.Kind.SOIL: Color8(99, 74, 53),
    WorldTileType.Kind.EXCAVATED_FLOOR: Color8(52, 87, 97),
    WorldTileType.Kind.SCRAP_METAL_WALL: Color8(154, 161, 171),
    WorldTileType.Kind.FURNACE: Color8(167, 96, 57),
}
const _PLAYER_COLOR: Color = Color8(164, 214, 90)
const _ACTION_TARGET_COLOR: Color = Color(0.84, 0.73, 0.34, 0.4)
const _HOVER_OK_COLOR: Color = Color(0.36, 0.74, 0.43, 0.43)
const _HOVER_BAD_COLOR: Color = Color(0.77, 0.28, 0.28, 0.43)

var state: GameState
var layout: TileLayout
var hovered_tile: Variant = null   # Vector2i or null
var interaction_mode: int = GameInteractionMode.Kind.EXCAVATE

func setup(p_state: GameState, p_layout: TileLayout) -> void:
    state = p_state
    layout = p_layout

func _draw() -> void:
    if state == null or layout == null:
        return
    for y in range(state.world.height):
        for x in range(state.world.width):
            _draw_tile(Vector2i(x, y))
    _draw_active_action_target()
    _draw_hover_overlay()
    _draw_player()

func _draw_tile(tile: Vector2i) -> void:
    var rect := layout.tile_to_rect(tile)
    var kind := state.world.get_tile(tile)
    draw_rect(rect, _TILE_COLORS.get(kind, Color.MAGENTA), true)

func _draw_active_action_target() -> void:
    if state.active_action == null: return
    if not (state.active_action.target_tile is Vector2i): return
    draw_rect(layout.tile_to_rect(state.active_action.target_tile), _ACTION_TARGET_COLOR, true)

func _draw_hover_overlay() -> void:
    if not (hovered_tile is Vector2i): return
    var ok := GameActionRules.can_start_action(
        state,
        GameInteractionMode.to_action_kind(interaction_mode),
        hovered_tile)
    draw_rect(layout.tile_to_rect(hovered_tile), _HOVER_OK_COLOR if ok else _HOVER_BAD_COLOR, true)

func _draw_player() -> void:
    var rect := layout.tile_to_rect(state.player.tile_position)
    var inset := rect.size.x * 0.25
    var inner := Rect2(rect.position + Vector2(inset, inset), rect.size - Vector2(inset * 2, inset * 2))
    draw_rect(inner, _PLAYER_COLOR, true)
```

The "per-tile function" is `_draw_tile` — the contract from the
high-level plan ("a tile may eventually draw a floor base, then any
object/feature on top, then overlays"). Future sprite composition
threads through that one function.

### `client/input_reader.gd` (new)

The MonoGame `GameInputReader` reads polled keyboard / mouse state every
frame and produces a list of commands. Godot prefers the event-driven
API (`_input`), but for this phase we want a simple per-frame
"what commands were issued since last frame?" pump with no buffering
beyond one frame. A `Node` lets us receive `_input` callbacks directly
without main forwarding to it.

```gdscript
class_name InputReader
extends Node

var session: GameSession
var layout: TileLayout
var interaction_mode: int = GameInteractionMode.Kind.EXCAVATE
var hovered_tile: Variant = null
var _pending: Array[GameCommand] = []

func setup(p_session: GameSession, p_layout: TileLayout) -> void:
    session = p_session
    layout = p_layout

func take_commands() -> Array[GameCommand]:
    var out := _pending
    _pending = []
    return out

func _input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        hovered_tile = layout.pixel_to_tile(event.position)
        return
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT:
            _on_left_click()
        elif event.button_index == MOUSE_BUTTON_RIGHT:
            _on_right_click()
        return
    if event.is_action_pressed("mode_excavate"):
        interaction_mode = GameInteractionMode.Kind.EXCAVATE
    elif event.is_action_pressed("mode_build_wall"):
        interaction_mode = GameInteractionMode.Kind.BUILD_WALL
    elif event.is_action_pressed("cancel_action"):
        _pending.append(CancelActionCommand.new())

func _on_left_click() -> void:
    if not (hovered_tile is Vector2i): return
    if hovered_tile == session.state.player.tile_position:
        _pending.append(ConsumeFoodCommand.new())
    else:
        _pending.append(MovePlayerCommand.new(hovered_tile))

func _on_right_click() -> void:
    if not (hovered_tile is Vector2i): return
    var kind := GameInteractionMode.to_action_kind(interaction_mode)
    _pending.append(StartActionCommand.new(kind, hovered_tile))
```

Notes:

- `ConsumeFoodCommand` is wired in even though `SurvivalRules.try_consume_canned_food`
  no-ops until phase 3. Doing it now avoids reshuffling `_on_left_click`
  later, and is faithful to the MonoGame input reader.
- `_pending` flushes on `take_commands()`; `main.gd` calls it once per
  `_process` tick.
- The `Node` extension is *only* for `_input` callbacks. The class still
  doesn't appear under `scripts/core/` and so doesn't violate the split.

### `client/game_session.gd` (new)

Mirrors `ClientGameSession` exactly, with one twist: the simulation
runs on `_process`-style updates driven from `main.gd`, so the session
itself stays a passive container.

```gdscript
class_name GameSession
extends Node

var state: GameState
var step: SimulationStep

func _init(p_random_seed: int = 0x00C0FFEE) -> void:
    state = GameStateFactory.create_new(p_random_seed)
    step = SimulationStep.new()

func update(delta_seconds: float, commands: Array) -> void:
    step.advance(state, delta_seconds, commands)
```

The seed parameter on the constructor is gratuitous in phase 2 (no
expedition / combat tests need it yet) but is the same ergonomic as the
C# version and costs nothing.

### `scripts/main.gd` (refactor)

Replace the phase-1 print-on-first-tick with the real wiring:

```gdscript
extends Node2D

var _session: GameSession
var _layout: TileLayout
var _renderer: WorldRenderer
var _input_reader: InputReader

func _ready() -> void:
    _session = GameSession.new()
    add_child(_session)

    _layout = TileLayout.new(_session.state.world)

    _renderer = WorldRenderer.new()
    _renderer.setup(_session.state, _layout)
    add_child(_renderer)

    _input_reader = InputReader.new()
    _input_reader.setup(_session, _layout)
    add_child(_input_reader)

    print("alien_godot: phase 2 boot ok — mode=%s" % GameInteractionMode.display_name(_input_reader.interaction_mode))

func _process(delta: float) -> void:
    var commands := _input_reader.take_commands()
    _session.update(delta, commands)
    _renderer.hovered_tile = _input_reader.hovered_tile
    _renderer.interaction_mode = _input_reader.interaction_mode
    _renderer.queue_redraw()
```

The headless run (no input, no display) still produces a well-formed
session; `take_commands()` returns an empty array, `update` advances
the clock, `_draw` is never called by the headless server. This
preserves the phase-1 "boot ok" print.

### `project.godot` (`[input]` section)

Add a section after `[display]`:

```
[input]

mode_excavate={
"deadzone": 0.5,
"events": [Object(InputEventKey,"physical_keycode":49)]
}
mode_build_wall={
"deadzone": 0.5,
"events": [Object(InputEventKey,"physical_keycode":50)]
}
cancel_action={
"deadzone": 0.5,
"events": [Object(InputEventKey,"physical_keycode":67)]
}
```

Physical keycodes: `49 = 1`, `50 = 2`, `67 = C`. Use the exact format
the editor produces so the file stays diff-friendly when somebody
inevitably opens the editor (against the rules) and re-saves. Test by
running once in the editor — Godot will *not* reformat these if they
already match its serialization.

## Tests

All tests are `extends SceneTree` scripts under `tests/`, named
`test_*.gd`, exit with `quit(0)` on success. The phase-1 smoke test
(`test_core_smoke.gd`) automatically picks up new files under
`scripts/core/` — no manual registration. New `scripts/client/` files
are *not* covered by the smoke test (and shouldn't be: they may extend
`Node`).

### `tests/test_world_grid.gd` (new)

Covers the rules added in phase 2.

1. `is_excavatable_returns_true_only_for_soil_below_surface_in_bounds`
   - Default 8×8 world, surface row 3.
   - `(3, 4)` (soil below) → true. `(3, 3)` (soil at surface) → also true
     (surface row counts; the C# rule is `tile.Y >= SurfaceRow`).
   - `(3, 2)` (air above) → false. After
     `set_tile((3, 4), EXCAVATED_FLOOR)`, `(3, 4)` → false.
   - `(-1, 4)` (out of bounds) → false.
2. `can_build_wall_at_classifies_tile_kinds`
   - Air → true. Excavated floor → true. Soil → false. Wall → false.
     Furnace → false.
3. `can_build_furnace_at_only_excavated_floor`
   - Excavated floor → true. Air → false. Soil → false.
4. `is_walkable_matches_open_space`
   - Air / Excavated / Furnace → true. Soil / Wall → false.
     Out of bounds → false.
5. `try_excavate_mutates_and_returns_true_then_false`
   - First call returns true, tile becomes excavated. Second call returns
     false (already excavated, not "soil").
6. `try_build_wall_only_in_replaceable_cells`
   - Air → wall, true. Soil → unchanged, false.
7. `is_indoors_when_pocket_is_sealed_returns_true`
   - `WorldGrid.create_default(8, 8, 3)`. `set_tile((3, 4), EXCAVATED_FLOOR)`.
   - `is_indoors((3, 4))` → true. (Mirrors the C# test verbatim.)
8. `is_indoors_when_pocket_is_open_to_surface_returns_false`
   - As above, plus `set_tile((3, 3), EXCAVATED_FLOOR)` and
     `set_tile((3, 2), AIR)` (already air; the C# test is explicit, do
     the same). `is_indoors((3, 4))` → false.
9. `is_indoors_when_tile_is_blocking_returns_false`
   - `is_indoors((3, 5))` (soil) → false.

### `tests/test_world_tile_type.gd` (new)

Direct sanity checks on `is_open_space` / `is_blocking` /
`can_be_replaced_with_*`. Five lines per assertion. Cheap to write,
catches typos in the enum values.

### `tests/test_game_action_rules.gd` (new)

Validity checks; doesn't touch `SimulationStep`.

1. `can_start_excavate_only_with_target_tile_that_is_excavatable`
   - Build a fresh state. `EXCAVATE` with `null` target → false.
     `EXCAVATE` with surface-row tile → true. Mutate that tile to
     `EXCAVATED_FLOOR`. `EXCAVATE` with the same tile → false.
2. `can_start_build_wall_requires_scrap_and_replaceable_tile`
   - Default state has 8 scrap. Pick an `AIR` tile that isn't the player
     tile. `BUILD_WALL` → true.
   - Same check on the player tile → false.
   - Drain scrap (`try_remove(SCRAP_METAL, 8)`). Same target → false.
3. `can_start_action_returns_false_when_an_action_is_active`
   - Start any action, then check that any new `EXCAVATE` request is
     rejected (mirrors phase 1, but make sure it still holds with the
     real validity body — easy regression to break).

### `tests/test_simulation_step.gd` (extend)

Leave the three phase-1 cases in place. Append:

4. `advance_when_excavation_completes_converts_soil_to_excavated_floor`
   - State factory; pick `excavation_target = Vector2i(player.x, surface_row)`.
   - One advance call with `StartActionCommand(EXCAVATE, excavation_target)`
     and `delta_seconds = 2.0`. Assert tile became
     `EXCAVATED_FLOOR` and `last_completed_action_kind == EXCAVATE`.
5. `advance_when_build_wall_completes_consumes_scrap_and_sets_wall_tile`
   - Pick `build_target = Vector2i(player.x + 1, player.y)` (above
     surface — that's `AIR`).
   - Capture `starting_scrap`. Advance 3.0s with
     `StartActionCommand(BUILD_WALL, build_target)`.
   - Assert tile is `SCRAP_METAL_WALL` and inventory has
     `starting_scrap - 1` scrap.
6. `advance_when_build_target_is_invalid_does_not_start_action`
   - `invalid_target = Vector2i(player.x, surface_row)` (soil — not
     replaceable). Advance 0s with `StartActionCommand(BUILD_WALL, invalid_target)`.
   - Assert `active_action == null` and the tile is still soil.
7. `advance_when_move_command_targets_walkable_tile_moves_player`
   - `destination = Vector2i(player.x + 2, player.y)` (above surface,
     air). Advance 0s with `MovePlayerCommand(destination)`. Assert
     `player.tile_position == destination`.
8. `advance_when_move_command_targets_blocked_tile_does_not_move`
   - `destination = Vector2i(player.x, surface_row + 1)` (soil). Advance
     0s. Assert player did not move. (This is the test that proves
     `is_walkable` is real now and not the phase-1 stub.)

### `tests/test_core_smoke.gd` (no change required)

The recursive walker picks up the new core files (`build_costs.gd`,
the amended `world_grid.gd` / `world_tile_type.gd` / `game_action_rules.gd`)
automatically. Verify the walker still passes after the amendments.

### Client tests?

We deliberately do *not* add headless tests for `WorldRenderer`,
`InputReader`, or `GameSession`. They depend on a running scene tree
and on event delivery, which is out of scope for the headless test
runner. The smoke test guarantees nothing under `client/` leaks into
`core/`. Visual verification is what `./run.sh` is for in this phase.

## Run / verify

After all files exist:

```
godot --headless --import        # refresh .godot/ for the new files
./run-tests.sh                    # 5 test files, ~all green
./run-headless.sh                 # boots, prints "phase 2 boot ok", quits
./run.sh                          # window opens; mouse-hover + 1/2 + RMB
                                  # + LMB + C all behave as documented
```

In the visible run, verify by eye:

- Above-surface rows are blue (air); the row at `surface_row` and below
  is brown (soil).
- Hovering an above-surface tile in `Excavate` mode shows the red
  overlay (`is_excavatable` requires `tile.y >= surface_row`); hovering
  a soil tile shows green; right-click on the green tile starts a
  ~1.75s amber action highlight; the tile turns floor-colored when the
  action completes.
- Switching to `Build Wall` (`2`) and right-clicking an air tile
  starts a build; the tile turns wall-colored on completion and
  the (invisible) inventory drops by one scrap. With no on-screen
  inventory yet, verify by spamming until the tenth wall fails to
  start (8 scrap = 8 walls) — the hover should turn red.
- `C` cancels an in-progress action.

If the visible run regresses anything in phase 1 (clock advancing,
boot OK), fix before declaring phase 2 done.

## Design decisions worth flagging

- **`InputReader` extends `Node`, not `RefCounted`.** Godot's `_input`
  callback only fires on `Node`-derived classes that are in the scene
  tree. Phase 2 puts `InputReader` in the scene tree under `Main` so
  the engine handles delivery; the alternative — forwarding events from
  `main.gd._input` to a `RefCounted` reader — is a layer of indirection
  for no benefit. The `client/` rule (no `core/` dependency on
  `Node`) is what matters; client code is *expected* to extend `Node`.
- **No camera scrolling in phase 2.** The 24×16 world fits at 36px
  tiles in 1280×720 (864×576 + 24px margin). `TileLayout` exposes
  `is_visible()` so future scrolling is a one-liner — the renderer's
  loop already tolerates a culling predicate. We deliberately avoid
  `WorldViewLayout`'s dynamic-tile-size logic until the world grows
  bigger than the viewport.
- **Hover overlay reuses `GameActionRules.can_start_action`.** This is
  the same predicate the simulation uses to accept a command — there's
  no second source of truth for "is this a valid target?". The MonoGame
  `GameRenderer.CanExecuteInteraction` does the same routing.
- **`BuildCosts` rather than inlined magic numbers.** A two-line shell
  is cheaper than a debate about where the "1" lives. Phase 5's
  `RecipeCatalog` deletes this file; until then it's the one place to
  patch a wall-cost balance question.
- **`Vector2i` as `Dictionary` key in `is_indoors`.** GDScript hashes
  `Vector2i` natively; no wrapper needed. The C# version uses
  `HashSet<TilePoint>`; the GDScript equivalent is a `Dictionary` with
  values set to `true` (or any sentinel — we use `1`).
- **`ConsumeFoodCommand` wired in phase 2 even though it does nothing.**
  The MonoGame port issues this on left-click on the player tile. We
  do the same. In phase 3 it'll start working; nothing else has to
  move.
- **No HUD this phase.** "Tests for scrap consumption" is
  test-suite-level, not visual. Adding a HUD now means choosing
  between `Control` nodes (which we'll likely use) and
  `_draw`-on-Node2D (consistent with the world renderer but ugly for
  text). Phase 3 needs a HUD anyway (nutrition / temperature
  bars); fold both decisions there.
- **`is_indoors` is built but not yet *called* per frame.** The C#
  port calls it from `SurvivalRules`, which arrives in phase 3. Phase
  2 ships and tests the function in isolation. Hooking it into
  `set_environment_status` belongs to whichever phase introduces a
  consumer for the indoor flag.
- **Input map keys via physical keycode.** Avoids locale issues
  (`AZERTY`, `Dvorak`). The C# port uses `Keys.D1` / `Keys.D2`
  which is also physical. Same intent.

## Implementation order

Bottom-up, each step independently testable:

1. Amend `world_tile_type.gd` with the four static helpers.
2. Amend `world_grid.gd`: real `is_walkable`, `is_excavatable`,
   `can_build_*_at`, `try_*`, `is_indoors` BFS,
   `_NEIGHBOR_OFFSETS`. Drop the phase-1 TODO.
3. Add `tests/test_world_tile_type.gd` and `tests/test_world_grid.gd`.
   Run them — these are pure-core, no client dependency.
4. Add `simulation/build_costs.gd`. Amend `game_action_rules.gd` with
   real `can_start_action` for `EXCAVATE` / `BUILD_WALL` and real
   completion bodies. Add `tests/test_game_action_rules.gd`. Run.
5. Extend `tests/test_simulation_step.gd` with the five new cases.
   Run. (Phase-1 cases must still pass.)
6. Re-run `tests/test_core_smoke.gd` — confirm all amended core files
   still instantiate cleanly.
7. Edit `project.godot` to add the `[input]` section. Re-run
   `godot --headless --import` to make sure the file parses.
8. Create `scripts/client/` directory. Add `game_interaction_mode.gd`,
   `tile_layout.gd`, `game_session.gd`, `world_renderer.gd`,
   `input_reader.gd` in that order (each one only depends on the ones
   above it).
9. Refactor `scripts/main.gd` to wire them up.
10. `./run-headless.sh` — verify boot still prints OK.
11. `./run.sh` — verify the four interactions (1, 2, RMB, LMB, C) work
    as documented under "Run / verify".
12. Final `./run-tests.sh` pass. Phase 2 complete.

## Open questions

- **Should `_NEIGHBOR_OFFSETS` be exposed as `static const` on
  `WorldGrid`?** The C# version keeps it private. GDScript's `const`
  on a class is module-private by convention but still externally
  reachable. Keep it module-private (leading underscore) for now;
  promote if phase 5's furnace heat radius wants the same neighbour
  table.
- **Should `GameInteractionMode` live under `core/` or `client/`?** The
  C# version puts it under the client (`Alien.Client`). It encodes
  *interaction state* — a player-facing concept that the simulation
  doesn't read — so it correctly belongs under `client/`. Keep it
  there.
- **What happens if `_input` fires before `setup()` on `InputReader`?**
  Defensively, `_input` returns early when `session == null`. In
  practice, `add_child` happens after `setup` in `main._ready`, so
  this shouldn't trigger; but the early return is a single line and
  saves a confused crash if the order ever flips.
- **Mouse position in `_input` vs. `get_viewport().get_mouse_position()`?**
  `event.position` from `InputEventMouseButton` / `InputEventMouseMotion`
  is already in viewport coordinates and matches `_draw` coordinates as
  long as `Main` (and thus `WorldRenderer`) sit at the origin. They do.
  If we ever offset the renderer's transform, switch to
  `to_local(event.position)`.
- **Should phase 2 ship a small "current mode" Label at the top-left?**
  It's three lines of `Control` setup. Tempting, but inconsistent with
  "no HUD this phase." Punt; phase 3's HUD will have a slot for it.
