# Phase 1 — Bootstrap + simulation foundation

This is the detailed implementation plan for phase 1 of `high_level_plan.md`.
It lands the project skeleton, the pure-GDScript core types needed to
construct and tick a `GameState`, and a headless test runner. Nothing draws
to the screen yet.

The phase ends when `./run-tests.sh` passes a small suite covering:
fresh-state creation, inventory add/remove, action progression, clock
rollover. `./run-headless.sh` boots and exits cleanly.

## Scope

### In scope
- Repo bootstrap: `project.godot`, `CLAUDE.md`, `run.sh`, `run-headless.sh`,
  `run-tests.sh`, `scenes/main.tscn`, `scripts/main.gd`.
- Pure-GDScript ports of the simulation foundation, under `scripts/core/`:
  - Data types: `TilePoint` (mapped to `Vector2i`, see Design decisions),
    `ItemId`, `EquippedWeapon`, `Season`, `GameActionKind`,
    `WorldTileType`, `ExpeditionStatus`.
  - State holders: `PlayerStats`, `PlayerState`, `InventoryState`,
    `ClockState`, `GameAction`, `GameState`.
  - Commands: `GameCommand` base + `MovePlayerCommand`,
    `StartActionCommand`, `CancelActionCommand`, `ConsumeFoodCommand`,
    `FuelFurnaceCommand`. `CraftRecipeCommand` is deferred to phase 5.
  - Glue: `GameBalance`, `GameStateFactory`, `SimulationStep`, plus
    minimal `WorldGrid`, `GameActionRules`, `SurvivalRules`.
- Tests under `tests/` for the four behaviors above plus a smoke test that
  proves every core script can be instantiated from a `SceneTree` (the
  practical version of "no `Node` imports").

### Deferred to later phases
- Tile rendering, input map, hover preview, HUD (phase 2+).
- Real `WorldGrid` rules (excavation, build validity, indoor flag) —
  phase 1 ports just enough of `WorldGrid` to construct a `GameState` and
  let `SimulationStep` compile and run; tile-type rules and indoor BFS are
  phase 2.
- `SurvivalRules` body (nutrition decay, temperature, starvation) — phase
  3. Phase 1 ships an empty no-op so `SimulationStep.Advance` can call it.
- `GameActionRules` action handlers for Excavate / BuildWall / BuildFurnace
  / Expedition / Attack — phase 2 onward. Phase 1 ships the dispatch
  skeleton with all action kinds as no-ops; `Craft` is dispatched but
  `RecipeRules` is not yet ported.
- Furnace bookkeeping inside `GameState` (`TryBuildFurnace`,
  `TryFuelFurnace`, heat bonus, advance) — phase 5. Phase 1's
  `GameState` has no furnace dictionary yet, and `FuelFurnaceCommand` is
  ported as a struct only — `SimulationStep` ignores it for now.
- Combat / expedition state (`ActiveCombat`, `BeginCombat`,
  `CompleteExpedition`, `ExpeditionsCompleted`, `CombatEncountersWon`,
  `LastCombatRoundOutcome`, `LastExpeditionOutcome`,
  `PendingExpeditionOutcome`) — phases 4 and 6. Keep the
  `ExpeditionStatus` enum since it's tiny and used in phase 4.

The deferrals are deliberate: phase 1 is "the bones the rest of the phases
hang flesh on." Anything ported now must stay portable to its phase-2+
implementation without a rewrite.

## Repo bootstrap

### `project.godot`
Hand-edited, mirrors `aerial/project.godot` minus the flight-sim input
actions. Required sections:

```
config_version=5

[application]
config/name="Alien"
run/main_scene="res://scenes/main.tscn"
config/features=PackedStringArray("4.6", "GL Compatibility")

[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"

[rendering]
renderer/rendering_method="gl_compatibility"
```

No `[input]` actions yet (phase 2 adds movement / build / excavate).
No `[autoload]`. The scene tree starts empty and `main.gd` builds it.

### `scenes/main.tscn`
One root `Node2D` with `scripts/main.gd` attached. Author it as text:

```
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/main.gd" id="1"]
[node name="Main" type="Node2D"]
script = ExtResource("1")
```

### `scripts/main.gd`
Phase 1 boots a `GameState` via `GameStateFactory.create_new()`, ticks it
each frame, and prints once per second so headless runs produce
verifiable output. No rendering. Roughly:

```gdscript
extends Node2D

const GameStateFactoryScript = preload("res://scripts/core/simulation/game_state_factory.gd")
const SimulationStepScript = preload("res://scripts/core/simulation/simulation_step.gd")

var _state: GameState
var _step: SimulationStep
var _print_accum: float = 0.0

func _ready() -> void:
	_state = GameStateFactoryScript.create_new()
	_step = SimulationStepScript.new()

func _process(delta: float) -> void:
	_step.advance(_state, delta, [])
	_print_accum += delta
	if _print_accum >= 1.0:
		_print_accum = 0.0
		print("clock=%.1fh day=%d season=%s" % [
			_state.clock.time_of_day_hours,
			_state.clock.day_of_season,
			Season.keys()[_state.clock.season],
		])
```

This script only ever touches core types; it is the *only* place per-frame
ticking happens.

### Run scripts
Copy `aerial/run.sh` and `aerial/run-headless.sh` verbatim, dropping
`aerial`-specific user-arg handling. Keep `QUIT_AFTER` env override.
Add `run-tests.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
fail=0
for t in tests/test_*.gd; do
	if ! godot --headless --script "res://$t"; then
		echo "FAIL: $t"
		fail=1
	fi
done
exit "$fail"
```

`chmod +x` all three.

### `CLAUDE.md`
Near-copy of `aerial/CLAUDE.md`, with:
- Project name swapped to Alien.
- Tooling table updated: replace `--export-release` line with a short note
  about `run-tests.sh`.
- One added section "Core / client split" stating the rule from the
  high-level plan: nothing under `scripts/core/` may import `Node`,
  `SceneTree`, `PackedScene`, rendering APIs, or input APIs; the test
  suite includes a smoke test that instantiates every core script from a
  bare `SceneTree`. New core files must be added to that smoke test.
- Project layout block updated to match `high_level_plan.md`.

## Core port (file-by-file)

All paths are under `scripts/core/`. Each file is `extends RefCounted`
(unless noted) with `class_name` set, and uses static typing throughout.
Constructors are written as `_init(...)`; private fields are prefixed
with `_`; methods that mutate are exposed as plain funcs. Argument
validation that the C# version does with `ArgumentOutOfRangeException`
becomes `assert(...)`; GDScript asserts are stripped from release builds,
which is the right tradeoff for invariants the tests already cover.

### Types (small / enum-like)

- `world/tile_point.gd` — *not a class*. Use `Vector2i` directly
  everywhere a `TilePoint` would appear in the C# code (see Design
  decisions). This file holds a one-line `class_name TilePoint` shim only
  if needed for documentation; otherwise skip the file entirely.
- `world/world_tile_type.gd` — `class_name WorldTileType` with `enum
  Kind { AIR, SOIL, EXCAVATED_FLOOR, SCRAP_METAL_WALL, FURNACE }`. Phase
  2 adds the `IsOpenSpace`/`CanBeReplacedWithWall`/etc. extension
  methods; phase 1 just defines the enum.
- `inventory/item_id.gd` — `class_name ItemId` with `enum Id { SCRAP_METAL,
  FUEL, CANNED_FOOD, SIMPLE_WEAPON }`.
- `gameplay/equipped_weapon.gd` — `class_name EquippedWeapon` with `enum
  Slot { NONE, SIMPLE_WEAPON }`.
- `time/season.gd` — `class_name Season` with `enum Kind { SUMMER,
  AUTUMN, WINTER, SPRING }`.
- `simulation/game_action_kind.gd` — `class_name GameActionKind` with
  `enum Kind { EXCAVATE, BUILD_WALL, BUILD_FURNACE, EXPEDITION, CRAFT,
  ATTACK }`.
- `simulation/expedition_status.gd` — `class_name ExpeditionStatus` with
  `enum Kind { NONE, AWAY, RETURNED, INTERRUPTED }`. Used by phase 4 but
  cheap to land now so `GameState` doesn't have to grow a new field
  later.

### `inventory/inventory_state.gd` (`class_name InventoryState`)
Direct port. Backing field is `var _item_counts: Dictionary = {}` keyed by
`ItemId.Id` (an int). API:

```
func get_count(item_id: int) -> int
func has_at_least(item_id: int, amount: int) -> bool
func add(item_id: int, amount: int) -> void
func try_remove(item_id: int, amount: int) -> bool
```

Empty entries are deleted on full removal, matching the C# behavior.

### `gameplay/player_stats.gd` (`class_name PlayerStats`)
Direct port. `_init(max_health: int)`. Properties: `max_health`,
`current_health`. `is_dead`, `take_damage(amount: int)`. Trivial.

### `gameplay/player_state.gd` (`class_name PlayerState`)
Direct port of the constructor signature, but `tile_position` is a
`Vector2i`. Health is held by composition (`var health: PlayerStats`).
All `Move/Drain/Restore/Reduce/MoveTemperatureToward/ApplyNeglectDamage`
methods port one-to-one. Damage buffer (`_damage_buffer`) stays.

Default values match the C# constructor defaults exactly: `max_temperature
= 100`, `current_temperature = 70`, `equipped_weapon = NONE`, etc. The
factory will override `current_temperature` to 72 at startup, again
matching C#.

### `time/clock_state.gd` (`class_name ClockState`)
Direct port. Constants:

```gdscript
const SECONDS_PER_DAY: float = 24.0 * 60.0 * 60.0
const DAYS_PER_SEASON: int = 30
```

`_init(season: int, day_of_season: int, time_of_day_seconds: float, year: int = 1)`
with the same range asserts. Methods: `advance(delta_seconds: float)`,
`get_days_until_season(target: int) -> int`, plus the `time_of_day_hours`
and `day_progress` accessors. Internal `_advance_day()` and the
`_get_next_season(season)` helper are private.

### `simulation/game_action.gd` (`class_name GameAction`)
Direct port. `_init(kind: int, duration_seconds: float, description:
String, target_tile = null)` — `target_tile` typed as `Variant` since it
can be `null` or `Vector2i`. The optional-target nullability is faithful
to the C# `TilePoint?`. `progress` clamps to `[0,1]`, `is_complete`
returns `elapsed_seconds >= duration_seconds`, `advance(delta)`
saturates at the duration.

### `simulation/game_command.gd` and command structs
`game_command.gd` is a one-line base:

```gdscript
class_name GameCommand
extends RefCounted
```

Each concrete command is a tiny script with `class_name`, `extends
GameCommand`, and an `_init` that captures the payload. Examples:

- `move_player_command.gd` — `var target_tile: Vector2i`
- `start_action_command.gd` — `var action_kind: int`, `var target_tile`
  (Variant, default `null`)
- `cancel_action_command.gd` — empty
- `consume_food_command.gd` — empty
- `fuel_furnace_command.gd` — `var target_tile: Vector2i`

`craft_recipe_command.gd` is *not* created in phase 1. Crafting lands in
phase 5 alongside `RecipeId`.

### `simulation/game_balance.gd` (`class_name GameBalance`)
One constant for now:

```gdscript
const CLOCK_SECONDS_PER_REAL_SECOND: float = 144.0
```

### `world/world_grid.gd` (`class_name WorldGrid`)
Phase 1 ports just what `GameState` and `GameStateFactory` need to
function:

- Constructor `_init(width: int, height: int, surface_row: int, tiles:
  PackedInt32Array)`.
- `Width`, `Height`, `SurfaceRow` getters.
- `static func create_default(width, height, surface_row) -> WorldGrid` —
  fills above-surface with `AIR`, below with `SOIL`.
- `is_within_bounds(tile: Vector2i) -> bool`.
- `get_tile(tile: Vector2i) -> int` (returns the enum value).
- `set_tile(tile: Vector2i, kind: int) -> void`.
- `is_walkable(tile: Vector2i) -> bool` — phase 1 returns `true` for any
  in-bounds tile. Phase 2 replaces this with the real "open space" rule.

`is_excavatable`, `can_build_wall_at`, `can_build_furnace_at`,
`try_excavate`, `try_build_wall`, `try_build_furnace`, `is_indoors`, the
`NeighborOffsets`, and the `WorldTileTypeExtensions` helpers are *not*
implemented in phase 1 — they belong to phase 2. Comment a single TODO
at the top of the file pointing at phase 2 so it's obvious the file is
intentionally partial.

### `simulation/game_action_rules.gd` (`class_name GameActionRules`)
A static-style helper (one autoloadable class with `static` funcs). Phase
1 ports the *dispatch shape* but leaves the bodies empty:

- `static func can_start_action(state, kind, target_tile) -> bool` —
  returns `false` when player is dead or an action is already active;
  otherwise returns `true`. The per-kind validity checks (`is_excavatable`,
  `can_build_wall_at`, `can_afford`, etc.) come in phases 2 / 5.
- `static func try_create_action(state, command) -> GameAction` — when
  `can_start_action` is true, builds a `GameAction` with the right
  duration / description from the lookups below. Returns `null`
  otherwise.
- `static func complete_action(state, action) -> void` — empty switch on
  `action.kind`; each case is a `pass`. Phase 2 fills in
  Excavate / BuildWall / BuildFurnace, etc.
- `static func _get_duration_seconds(kind) -> float` — the same table as
  C# (`Excavate=1.75`, `BuildWall=2.5`, `BuildFurnace=3`, `Expedition=5`,
  `Craft=2`, `Attack=1.5`).
- `static func _get_description(kind) -> String` — the same lookup.

This is enough for the action-progression test (StartAction → Advance →
elapsed/complete) to pass without touching the world.

### `simulation/survival_rules.gd` (`class_name SurvivalRules`)
Phase 1 ships two no-op statics so `SimulationStep` and `GameStateFactory`
compile:

- `static func update(state, delta_seconds: float) -> void` — `pass`.
- `static func try_consume_canned_food(state) -> bool` — `return false`.
- `static func get_ambient_temperature(state) -> float` — returns
  `state.player.current_temperature` (so the factory can call it without
  needing the seasonal curve).

A `# TODO(phase 3): real implementation` comment marks each.

### `simulation/game_state.gd` (`class_name GameState`)
Port the *non-deferred* surface area:

- Constructor: `_init(player: PlayerState, world: WorldGrid, inventory:
  InventoryState, clock: ClockState, random_seed: int = 0x00C0FFEE)`.
- Public members (all read-only from outside via getter func or `var`
  with `set` discipline — GDScript has no `private set`, so use a leading
  underscore on the backing var and expose a getter):
  - `player`, `world`, `inventory`, `clock` — assigned in `_init`.
  - `active_action: GameAction` (nullable).
  - `last_completed_action_kind` (nullable int).
  - `current_ambient_temperature: float`.
  - `is_player_indoors: bool`, `is_player_underground: bool`.
  - `expedition_status: int` (defaults to `NONE`).
- Methods kept now:
  - `try_start_action(action: GameAction) -> bool` — same expedition
    side-effects as C# (sets `AWAY`, clears outcomes). Outcome fields
    that don't exist yet are simply not touched.
  - `cancel_action() -> void` — same: if expedition, status →
    `INTERRUPTED`.
  - `set_environment_status(temp, indoors, underground) -> void`.
  - `complete_active_action() -> void` — calls
    `GameActionRules.complete_action(self, completed)` and records
    `last_completed_action_kind`.
  - `next_random_int(max_exclusive: int) -> int` — port of the LCG
    (`* 1664525 + 1013904223`). Use `int` arithmetic with a `& 0xFFFFFFFF`
    mask each step to stay 32-bit, since GDScript ints are 64-bit signed
    and the C# code relies on `uint` overflow.
- Methods *deferred* (do not port in phase 1; they'll be added in their
  feature phases):
  - All furnace methods (`try_build_furnace`, `try_fuel_furnace`,
    `get_furnace_burn_seconds_remaining`, `has_active_furnace_at`,
    `active_furnace_count`, `advance_furnaces`, `get_furnace_heat_bonus`)
    — phase 5.
  - All combat / expedition methods (`begin_combat`, `record_combat_round`,
    `win_combat`, `lose_combat`, `complete_expedition`) and the
    associated state fields — phases 4 and 6.

### `simulation/game_state_factory.gd` (`class_name GameStateFactory`)
Direct port, modulo the deferred state. `static func create_new(seed: int
= 0x00C0FFEE) -> GameState`:

```
world = WorldGrid.create_default(24, 16, 6)
player = PlayerState.new(
	Vector2i(world.width / 2, world.surface_row - 1),
	PlayerStats.new(100),
	100.0, 100.0, 0,            # nutrition + combat skill
	100.0, 72.0,                 # temperature
	EquippedWeapon.Slot.NONE,
	100.0, 100.0, 100.0, 100.0   # hygiene + psyche
)
inventory = InventoryState.new()
inventory.add(ItemId.Id.SCRAP_METAL, 8)
inventory.add(ItemId.Id.FUEL, 3)
inventory.add(ItemId.Id.CANNED_FOOD, 4)
clock = ClockState.new(Season.Kind.SUMMER, 1, 6.0 * 60.0 * 60.0)
state = GameState.new(player, world, inventory, clock, seed)
state.set_environment_status(SurvivalRules.get_ambient_temperature(state), false, false)
return state
```

### `simulation/simulation_step.gd` (`class_name SimulationStep`)
Direct port of the dispatch loop, with the deferred branches dropped:

```
func advance(state: GameState, delta_seconds: float, commands: Array) -> void:
	for command in commands:
		_apply_command(state, command)
	state.clock.advance(delta_seconds * GameBalance.CLOCK_SECONDS_PER_REAL_SECOND)
	if state.active_action != null:
		state.active_action.advance(delta_seconds)
		if state.active_action.is_complete:
			state.complete_active_action()
	SurvivalRules.update(state, delta_seconds)
```

`_apply_command` mirrors the C# switch, but:
- `CancelActionCommand` always cancels (matches C#).
- `ConsumeFoodCommand` calls `SurvivalRules.try_consume_canned_food` (no-op
  in phase 1; will work in phase 3).
- `MovePlayerCommand` calls `state.world.is_walkable(...)` (always true in
  phase 1) and then `state.player.move_to(...)`.
- `StartActionCommand` runs through `GameActionRules.try_create_action`
  and `state.try_start_action`.
- `FuelFurnaceCommand` and `CraftRecipeCommand` are handled by an
  unreachable `pass` (the latter doesn't even have a class yet); this is
  fine because nothing emits those commands in phase 1.

The `state.active_combat` and `state.advance_furnaces` calls from the C#
version are simply omitted; they'll be added in their respective phases.

## Tests

All tests are `extends SceneTree` scripts in `tests/`, named `test_*.gd`,
exit with `quit(0)` on success and `quit(1)` (via `assert`) on failure.
Add a `tests/.gdignore` so Godot doesn't try to import test scripts as
class libraries.

### `tests/test_inventory_state.gd`
Mirrors the two C# inventory tests:
1. Add 5 scrap, remove 2, expect 3 and `try_remove` returned true.
2. Add 1 fuel, try to remove 2, expect false and count still 1.

### `tests/test_clock_state.gd`
Mirrors the three C# clock tests:
1. Day boundary into next season: start at last day of summer, 60s before
   midnight, advance 120s, expect autumn / day 1 / 60s.
2. Configured clock scale: advance `10 min real * scale`, expect day 2 at
   06:00.
3. `get_days_until_season(WINTER)` from summer-day-1 returns 60.

### `tests/test_game_state_factory.gd`
Mirrors the C# factory test: build via `create_new()`, assert clock
season/day/hour, inventory counts (8/3/4), HP (100/100), temperature 72,
hygiene/psyche 100, no active action, player position in bounds.

### `tests/test_simulation_step.gd`
Phase-1-appropriate subset of the C# `SimulationStepTests` — the ones
that don't require world rules:

1. `advance_starts_and_completes_action_over_time`: queue
   `StartActionCommand(EXPEDITION)`, advance 1.25s → progress ≈ 0.25,
   active. Advance another 3.75s → action cleared,
   `last_completed_action_kind == EXPEDITION`. (Expedition completion in
   phase 1 is a no-op inside `complete_action`, which is fine for this
   assertion.)
2. `advance_when_action_is_already_running_ignores_new_start`: two
   `StartActionCommand`s in one batch, second is ignored.
3. `advance_when_expedition_is_cancelled_sets_interrupted_status`: start
   expedition, then `CancelActionCommand`, expect `expedition_status ==
   INTERRUPTED` and no action active.

The world / build / excavate / fuel / combat tests from C# are deferred —
their target phases will land them.

### `tests/test_core_smoke.gd`
The "core has no `Node` deps" test. One-shot script that `preload`s and
`.new()`s every script under `scripts/core/`. If any file accidentally
imports `Node`, instantiation from a `SceneTree` script will fail or
print warnings. Walk the directory at runtime via `DirAccess` so adding a
new core file automatically opts in.

```gdscript
extends SceneTree

func _init() -> void:
	var failures: Array[String] = []
	_visit("res://scripts/core", failures)
	if failures.size() > 0:
		for f in failures:
			push_error(f)
		quit(1)
	else:
		print("test_core_smoke: ok (%d files)" % _count("res://scripts/core"))
		quit(0)
```

(`_visit` recursively `load`s every `.gd` and either calls `.new()` on
classes that take no args or just confirms `load` succeeds for ones that
do — pragmatic, not exhaustive.)

## Run / verify

After all files exist:

```
godot --headless --import           # generates .godot/
./run-tests.sh                      # all five test scripts pass
./run-headless.sh                   # boots, prints clock once a second, exits in 5s
```

If any of those fail, fix before declaring phase 1 done. The headless run
proves the editor is *not* required for a clean checkout to play —
mirrors the aerial workflow.

## Design decisions worth flagging

- **`TilePoint` → `Vector2i`.** GDScript already has a value-type integer
  vector; introducing a `RefCounted` wrapper would mean per-tile
  allocations and a slower hash key in `Dictionary`. The C# `TilePoint`
  is a `record struct`, semantically identical to `Vector2i`. The cost
  is a slight loss of nominal typing — a `Vector2i` could mean "tile" or
  "pixel coord" elsewhere. We accept that and document it in `CLAUDE.md`
  under the core/client section.
- **Argument validation as `assert`, not exceptions.** GDScript has no
  exceptions in the C# sense. `assert` produces a runtime error in debug
  and is stripped in release. The tests cover the success paths; the
  invariant checks exist mainly as documentation.
- **Static funcs for "rules" classes.** `GameActionRules`,
  `RecipeRules` (later), `SurvivalRules`, `ExpeditionResolver` (later),
  `CombatResolver` (later), and `GameStateFactory` are all-static in C#.
  GDScript supports `static func`, so they ship as `class_name` shells
  with all-static methods — no autoload, no instances.
- **Random seed.** GDScript's int is 64-bit signed; the C# LCG relies on
  `uint` overflow. Mask with `& 0xFFFFFFFF` after each multiply-add to
  preserve the 32-bit sequence. The phase-4 expedition tests will lock
  this down by seed; phase 1 only ports the function.
- **`CraftRecipeCommand` deferral.** It would force porting `RecipeId` /
  `RecipeCatalog` early. Skipping it now means phase 5 is the only place
  crafting lands, which keeps the layering clean.
- **Test runner is shell, not GDScript.** `run-tests.sh` shells out to
  `godot --headless --script` per test file. Each test runs in a fresh
  process so a `quit(1)` doesn't poison the rest. This matches the
  aerial setup.

## Implementation order

Build bottom-up so each step can be smoke-tested in isolation:

1. Repo bootstrap files (`project.godot`, `scenes/main.tscn`, empty
   `scripts/main.gd`, run scripts, `CLAUDE.md`). Verify
   `godot --headless --import` succeeds.
2. Enums + `PlayerStats` + `InventoryState` + `ClockState`. Add
   `tests/test_inventory_state.gd` and `tests/test_clock_state.gd`. Run
   them — they don't depend on anything else and prove the test runner
   works.
3. `Vector2i` adoption + minimal `WorldGrid` + `EquippedWeapon` +
   `PlayerState`. No tests yet; these are dependencies.
4. `GameAction`, `GameCommand` + concrete command structs,
   `GameBalance`, `SurvivalRules` no-op stub.
5. `GameState`, `GameActionRules` skeleton, `GameStateFactory`. Add
   `tests/test_game_state_factory.gd`. Run it.
6. `SimulationStep`. Add `tests/test_simulation_step.gd`. Run it.
7. Wire `main.gd` to construct + tick a state once a frame and print.
   Verify with `./run-headless.sh`.
8. `tests/test_core_smoke.gd` — the recursive instantiation check.
9. Final `./run-tests.sh` pass. Phase 1 complete.

## Open questions

- Do we want a `tests/run_all.gd` wrapper that runs every test in one
  process (faster, but a single failure halts the rest), or stick with
  the per-file shell loop? Default to per-file for now; revisit if the
  suite gets slow enough that the process startup cost dominates.
- Should `PlayerState`'s constructor keep all of its phase-3+ fields
  (hygiene, psyche, temperature) now? Yes — the C# constructor already
  has them, and dropping them would mean an awkward signature change in
  phase 3. Phase 1 just doesn't *exercise* them in tests.
- `WorldTileType` extension methods (`IsOpenSpace`, `CanBeReplacedWithWall`,
  `CanBeReplacedWithFurnace`) — phase 2 lands these on `WorldTileType`
  itself as static funcs (e.g. `WorldTileType.is_open_space(kind)`),
  rather than a separate "extensions" file. Noted here so phase 2 doesn't
  accidentally invent a new shape.
