# Phase 3 — Survival economy + minimal HUD

This is the detailed implementation plan for phase 3 of `high_level_plan.md`.
It fills in the no-op `SurvivalRules` body that phases 1 and 2 deliberately
left empty: nutrition / hygiene decay, canned-food consumption, the
indoor / underground / surface temperature model, starvation and
hypothermia damage, and a psyche meter that recovers when the player is
comfortable and drains when they aren't. It also lands the first HUD —
on-screen `Label`s that read out the player's vitals, the clock, the
ambient temperature, and the inventory so that the systems are observable
in a running window.

The phase ends when:

- `./run-tests.sh` passes a suite that now includes a `SurvivalRules`
  test file covering decay, food consumption, starvation damage,
  hypothermia damage, psyche penalty / recovery, the underground vs.
  surface temperature differential, and a long-running winter survival
  smoke test.
- `./run.sh` opens a window that draws the world from phase 2 *and*
  shows the new HUD: clock, season + day, HP / Nutrition / Hygiene /
  Psyche / Temperature readouts, ambient temperature with
  surface / underground / indoors label, mode + active action,
  inventory counts. Standing still on the surface in summer drains
  nutrition and hygiene visibly. Left-clicking the player tile (which
  already issued `ConsumeFoodCommand` from phase 2) consumes one
  canned-food and refills nutrition. Walking into an excavated pocket
  flips the indoors label.
- `./run-headless.sh` still boots and exits cleanly. The phase-1 / 2
  tests still pass.

## Scope

### In scope

Core (still no `Node` imports under `scripts/core/`):

- `survival_rules.gd` — replace the three phase-1 stubs with the real
  bodies from `Alien.Core/Simulation/SurvivalRules.cs`. Includes the
  seasonal / underground / surface / expedition ambient-temperature
  curves, daylight factor, nutrition / hygiene / psyche / temperature
  drains, and starvation + hypothermia neglect damage.
- `game_state.gd` — add a `get_furnace_heat_bonus(tile_position) -> float`
  no-op that returns `0.0`. `SurvivalRules.get_ambient_temperature` calls
  it; phase 5 fills in the real lookup.
- `survival_constants.gd` (optional, see Open questions) — *not added*.
  Phase 3 keeps the tunables as private `const`s on `SurvivalRules`,
  matching the C# `private const float ...` shape and the convention
  already established by `GameBalance` / `BuildCosts`.

Client:

- `scripts/client/hud.gd` — `Control` whose `_ready()` builds a
  `VBoxContainer` of typed `Label` nodes; `refresh(state, mode)` writes
  one line per label each frame. Lives on the right side of the screen
  next to the world (no overlap with tiles); `mouse_filter` is
  `MOUSE_FILTER_IGNORE` everywhere so it never eats clicks meant for
  the world.
- `scripts/main.gd` — instantiate the HUD alongside the renderer and
  input reader; call `hud.refresh(state, mode)` once per `_process`
  tick.

Project config:

- No new input actions. No autoloads. No `[display]` changes.
- `project.godot` is untouched in phase 3.

### Deferred to later phases

- Furnace heat. The `get_furnace_heat_bonus` no-op is the smallest
  hook needed so `SurvivalRules.get_ambient_temperature` can call it
  unchanged in phase 5. Phase 5 lands the dictionary, the build /
  fuel paths, and the per-frame `advance_furnaces` call.
- Combat / expedition state. `SurvivalRules.get_ambient_temperature`
  reads `state.active_action.kind == EXPEDITION` to apply windchill;
  phase 4 will be the first place that path is *exercised*. Phase 3
  ports the branch verbatim — porting it now means phase 4 doesn't
  have to revisit `survival_rules.gd`.
- HUD bars. Phase 3 ships *labels*, not progress bars. A `ProgressBar`
  per stat is one line of code per stat, but tuning the colour /
  layout is a distraction for a phase whose point is the simulation.
  Phase 7 (winter pressure + balancing) is the natural place to
  upgrade the visual fidelity.
- Status ticker / "danger" line. The MonoGame port composes one with
  `BuildDangerText` (cold alert, "prepare for winter", etc.). It's
  cosmetic; phase 7 lands it alongside the screen tint.
- Window-title `StatusTitleFormatter`. The MonoGame port stuffs the
  status string into the OS window title. Godot can do the same via
  `get_window().title = ...`, but with on-screen labels the title
  becomes redundant. Skip.

## Core port (file-by-file)

All paths are under `scripts/core/`. Existing files are *amended*; new
files note their full path. Tests are listed in their own section below.

### `simulation/survival_rules.gd` (amend — replace body)

Phase 1 left this as three no-op statics. Phase 3 replaces it with a
direct port of `SurvivalRules.cs`. The structure mirrors C# 1:1; only
naming (`PascalCase` → `snake_case`) and types (`uint`, `MathF` →
`int`, `cosf` / `sinf` builtins) differ.

Module-level tunables (private `const`s — `_` prefix):

```gdscript
const _NUTRITION_DECAY_PER_SECOND: float = 0.12
const _CANNED_FOOD_NUTRITION_RESTORE: float = 35.0
const _STARVATION_CRITICAL_THRESHOLD: float = 5.0
const _STARVATION_DAMAGE_PER_SECOND: float = 3.0
const _HYPOTHERMIA_DAMAGE_THRESHOLD: float = 20.0
const _HYPOTHERMIA_DAMAGE_PER_SECOND: float = 2.5
const _HYGIENE_DECAY_PER_SECOND: float = 0.03
const _BASE_PSYCHE_RECOVERY_PER_SECOND: float = 0.08
const _LOW_NUTRITION_PSYCHE_PENALTY_PER_SECOND: float = 0.18
const _LOW_TEMPERATURE_PSYCHE_PENALTY_PER_SECOND: float = 0.22
const _LOW_HYGIENE_PSYCHE_PENALTY_PER_SECOND: float = 0.10
const _SURFACE_TEMPERATURE_ADJUST_RATE_PER_SECOND: float = 9.0
const _EXPEDITION_TEMPERATURE_ADJUST_RATE_PER_SECOND: float = 12.0
const _SHELTERED_TEMPERATURE_ADJUST_RATE_PER_SECOND: float = 5.0
const _UNDERGROUND_TEMPERATURE_ADJUST_RATE_PER_SECOND: float = 6.0
const _WINTER_EXPEDITION_WINDCHILL: float = 6.0
const _LOW_NUTRITION_PSYCHE_THRESHOLD: float = 25.0
const _LOW_TEMPERATURE_PSYCHE_THRESHOLD: float = 35.0
const _LOW_HYGIENE_PSYCHE_THRESHOLD: float = 30.0
```

The three threshold constants for the psyche penalty are *implicit* in
C# (`<= 25f` / `<= 35f` / `<= 30f` are inline literals); pulling them
out as named constants keeps the GDScript readable without changing
behavior. Phase 7 will tune these when the pressure curve gets
balanced.

API:

```gdscript
class_name SurvivalRules
extends RefCounted

static func update(state: GameState, delta_seconds: float) -> void
static func try_consume_canned_food(state: GameState) -> bool
static func get_ambient_temperature(state: GameState) -> float
```

`update(state, delta_seconds)` body, mirroring C#:

```gdscript
assert(state != null, "state required")
assert(delta_seconds >= 0.0, "delta_seconds must be non-negative")

var ambient_temperature: float = get_ambient_temperature(state)
var is_underground: bool = state.player.tile_position.y >= state.world.surface_row
var is_indoors: bool = state.world.is_walkable(state.player.tile_position) \
		and state.world.is_indoors(state.player.tile_position)

state.set_environment_status(ambient_temperature, is_indoors, is_underground)

state.player.drain_nutrition(_NUTRITION_DECAY_PER_SECOND * delta_seconds)
state.player.reduce_hygiene(_HYGIENE_DECAY_PER_SECOND * delta_seconds)
state.player.move_temperature_toward(
		ambient_temperature,
		_get_temperature_adjust_rate(state, is_indoors, is_underground),
		delta_seconds)
_update_psyche(state, delta_seconds)

if state.player.current_nutrition <= _STARVATION_CRITICAL_THRESHOLD:
	state.player.apply_neglect_damage(_STARVATION_DAMAGE_PER_SECOND * delta_seconds)
if state.player.current_temperature <= _HYPOTHERMIA_DAMAGE_THRESHOLD:
	state.player.apply_neglect_damage(_HYPOTHERMIA_DAMAGE_PER_SECOND * delta_seconds)
```

`try_consume_canned_food(state)`:

```gdscript
assert(state != null, "state required")
if state.player.current_nutrition >= state.player.max_nutrition:
	return false
if not state.inventory.try_remove(ItemId.Id.CANNED_FOOD, 1):
	return false
state.player.restore_nutrition(_CANNED_FOOD_NUTRITION_RESTORE)
return true
```

`get_ambient_temperature(state)`:

```gdscript
assert(state != null, "state required")
if state.active_action != null and state.active_action.kind == GameActionKind.Kind.EXPEDITION:
	var expedition_ambient: float = _get_surface_ambient_temperature(state.clock)
	if state.clock.season == Season.Kind.WINTER:
		expedition_ambient -= _WINTER_EXPEDITION_WINDCHILL
	return expedition_ambient

var player_tile: Vector2i = state.player.tile_position
var is_underground: bool = player_tile.y >= state.world.surface_row
var is_indoors: bool = state.world.is_walkable(player_tile) and state.world.is_indoors(player_tile)

if is_underground:
	return min(100.0,
			_get_underground_ambient_temperature(state.clock.season, is_indoors)
			+ state.get_furnace_heat_bonus(player_tile))
return min(100.0,
		_get_surface_ambient_temperature(state.clock)
		+ state.get_furnace_heat_bonus(player_tile))
```

Private helpers:

```gdscript
static func _get_temperature_adjust_rate(state: GameState, is_indoors: bool, is_underground: bool) -> float:
	if state.active_action != null and state.active_action.kind == GameActionKind.Kind.EXPEDITION:
		return _EXPEDITION_TEMPERATURE_ADJUST_RATE_PER_SECOND
	if is_indoors:
		return _SHELTERED_TEMPERATURE_ADJUST_RATE_PER_SECOND
	if is_underground:
		return _UNDERGROUND_TEMPERATURE_ADJUST_RATE_PER_SECOND
	return _SURFACE_TEMPERATURE_ADJUST_RATE_PER_SECOND

static func _update_psyche(state: GameState, delta_seconds: float) -> void:
	var penalty_per_second: float = 0.0
	if state.player.current_nutrition <= _LOW_NUTRITION_PSYCHE_THRESHOLD:
		penalty_per_second += _LOW_NUTRITION_PSYCHE_PENALTY_PER_SECOND
	if state.player.current_temperature <= _LOW_TEMPERATURE_PSYCHE_THRESHOLD:
		penalty_per_second += _LOW_TEMPERATURE_PSYCHE_PENALTY_PER_SECOND
	if state.player.current_hygiene <= _LOW_HYGIENE_PSYCHE_THRESHOLD:
		penalty_per_second += _LOW_HYGIENE_PSYCHE_PENALTY_PER_SECOND
	if penalty_per_second > 0.0:
		state.player.reduce_psyche(penalty_per_second * delta_seconds)
		return
	state.player.restore_psyche(_BASE_PSYCHE_RECOVERY_PER_SECOND * delta_seconds)

static func _get_daylight_factor(day_progress: float) -> float:
	var angle: float = (day_progress * PI * 2.0) - (PI / 2.0)
	return max(0.0, sin(angle))

static func _get_underground_ambient_temperature(season: int, is_indoors: bool) -> float:
	match season:
		Season.Kind.SUMMER:
			return 58.0 if is_indoors else 50.0
		Season.Kind.AUTUMN:
			return 42.0 if is_indoors else 34.0
		Season.Kind.WINTER:
			return 24.0 if is_indoors else 14.0
		Season.Kind.SPRING:
			return 46.0 if is_indoors else 38.0
		_:
			return 44.0

static func _get_surface_ambient_temperature(clock: ClockState) -> float:
	var daylight_factor: float = _get_daylight_factor(clock.day_progress())
	match clock.season:
		Season.Kind.SUMMER:
			return 50.0 + (30.0 * daylight_factor)
		Season.Kind.AUTUMN:
			return 26.0 + (22.0 * daylight_factor)
		Season.Kind.WINTER:
			return -2.0 + (14.0 * daylight_factor)
		Season.Kind.SPRING:
			return 34.0 + (24.0 * daylight_factor)
		_:
			return 50.0
```

Notes:

- `clock.day_progress()` is already a method (phase 1 ports it as a func,
  not a property). Match the existing call site shape.
- `min`, `max`, `sin`, `PI` are GDScript builtins — no import.
- Winter surface ambient can go negative (literal `-2.0` from C#). The
  `min(100.0, ...)` cap is a *ceiling*, not a floor; the player's
  `current_temperature` is what gets clamped to `[0, max_temperature]`
  inside `move_temperature_toward`. Negative ambient is intentional —
  it drives the hypothermia path.

### `simulation/game_state.gd` (amend)

Add one method. Phase 5 will replace the body; phase 3 just needs the
hook so `SurvivalRules.get_ambient_temperature` can call it without a
type check.

```gdscript
# Phase 5 fills in the real furnace dictionary lookup. Phase 3 ships
# this as a no-op so SurvivalRules.get_ambient_temperature can call it
# unconditionally.
func get_furnace_heat_bonus(_tile_position: Vector2i) -> float:
	return 0.0
```

Place it next to `set_environment_status` in the file. The leading
underscore on the parameter silences GDScript's unused-parameter
warning until phase 5 wires it up.

### Untouched core files

`game_state_factory.gd`, `simulation_step.gd`, `player_state.gd`, all
command structs, `game_action*.gd`, `expedition_status.gd`,
`clock_state.gd`, `inventory_state.gd`, `player_stats.gd`,
`equipped_weapon.gd`, `season.gd`, `item_id.gd`, `game_command.gd`,
`world_grid.gd`, `world_tile_type.gd`, `build_costs.gd`,
`game_action_rules.gd`, `game_balance.gd` — *no changes in phase 3.*

The factory call `state.set_environment_status(SurvivalRules.get_ambient_temperature(state), false, false)`
is preserved verbatim. Once phase 3 lands, the first `SimulationStep.advance`
overwrites it with the proper indoor/underground flags computed from the
BFS. The factory's call still serves the documentation purpose of
showing what `current_ambient_temperature` looks like at t=0, and it
matches the C# factory line-for-line.

`SimulationStep.advance` already calls `SurvivalRules.update(state, delta_seconds)`
unconditionally and `SurvivalRules.try_consume_canned_food(state)` from
the `ConsumeFoodCommand` branch. Phase 3 just makes those calls do real
work — no dispatch changes needed.

## Client port (HUD)

### `client/hud.gd` (new)

`Control` so we get layout / anchor support. The whole thing is built in
`_ready()` so the scene file remains a one-line root. `refresh(state, mode)`
is the only public method besides setup.

```gdscript
class_name Hud
extends Control

const _PADDING_PX: int = 12
const _LABEL_FONT_SIZE: int = 14

var _clock_label: Label
var _location_label: Label
var _vitals_label: Label
var _psyche_label: Label
var _temperature_label: Label
var _inventory_label: Label
var _mode_label: Label
var _action_label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_KEEP_SIZE)
	custom_minimum_size = Vector2(360, 0)

	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	box.position = Vector2(_PADDING_PX, _PADDING_PX)
	add_child(box)

	_clock_label = _make_label(box)
	_location_label = _make_label(box)
	_vitals_label = _make_label(box)
	_psyche_label = _make_label(box)
	_temperature_label = _make_label(box)
	_inventory_label = _make_label(box)
	_mode_label = _make_label(box)
	_action_label = _make_label(box)

func refresh(state: GameState, interaction_mode: int) -> void:
	_clock_label.text = "Y%d %s D%02d %05.2fh" % [
		state.clock.year,
		Season.Kind.keys()[state.clock.season],
		state.clock.day_of_season,
		state.clock.time_of_day_hours(),
	]
	_location_label.text = "Tile %d,%d  %s" % [
		state.player.tile_position.x,
		state.player.tile_position.y,
		_location_text(state),
	]
	_vitals_label.text = "HP %d/%d   Nutr %0.0f   Hyg %0.0f" % [
		state.player.current_hit_points(),
		state.player.max_hit_points(),
		state.player.current_nutrition,
		state.player.current_hygiene,
	]
	_psyche_label.text = "Psyche %0.0f / %0.0f" % [
		state.player.current_psyche,
		state.player.max_psyche,
	]
	_temperature_label.text = "Body %0.1f°  Ambient %0.1f°" % [
		state.player.current_temperature,
		state.current_ambient_temperature,
	]
	_inventory_label.text = "Scrap %d   Fuel %d   Food %d" % [
		state.inventory.get_count(ItemId.Id.SCRAP_METAL),
		state.inventory.get_count(ItemId.Id.FUEL),
		state.inventory.get_count(ItemId.Id.CANNED_FOOD),
	]
	_mode_label.text = "Mode %s" % GameInteractionMode.display_name(interaction_mode)
	_action_label.text = _action_text(state)

static func _make_label(parent: VBoxContainer) -> Label:
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", _LABEL_FONT_SIZE)
	parent.add_child(label)
	return label

static func _location_text(state: GameState) -> String:
	if state.is_player_indoors:
		return "indoors"
	if state.is_player_underground:
		return "underground"
	return "surface"

static func _action_text(state: GameState) -> String:
	if state.active_action == null:
		return "Action idle"
	return "Action %s %3.0f%%" % [
		state.active_action.description,
		state.active_action.progress() * 100.0,
	]
```

Notes:

- `mouse_filter = MOUSE_FILTER_IGNORE` on the root Control *and* every
  child Label is what keeps the HUD from eating clicks meant for the
  world. The default is `PASS`, which captures input on hit-tested
  rectangles; setting `IGNORE` makes the entire hierarchy transparent
  to mouse hits. This is the same pattern phase 7 will reuse for any
  other passive overlay.
- Labels are typed as `Label`, not `Variant`, so changes to the API
  surface a compile-time error rather than a runtime one.
- Anchored top-right with a 360-px minimum width sits clear of the
  world rectangle (24×16 tiles × 36 px = 864×576 with a 24-px origin
  margin, so tiles end at x=888; the HUD starts ~920). At 1280×720
  there's room for both. Phase 7 / camera-scrolling work can reflow.
- `Season.Kind.keys()` is the same call the phase-1 boot print uses;
  it returns `["SUMMER", "AUTUMN", "WINTER", "SPRING"]`. If we ever
  want lower-case display names we can add a `Season.display_name`
  static; phase 3 keeps it consistent with the existing print.
- `state.player.current_hit_points()` / `max_hit_points()` are funcs
  on `PlayerState`; that's the shape phase 1 chose (no `@property`
  decorator in GDScript, just lowercase getter funcs).
- The temperature line uses the degree sign as a literal Unicode
  character. Godot's default font supports it; if a future system
  font swap drops it, we'll switch to "F" or "C" (the units are
  unspecified — the C# port treats them as opaque numbers, and so
  does this HUD).

### `scripts/main.gd` (amend)

Add the HUD wiring. Three new lines plus the `refresh` call in
`_process`:

```gdscript
extends Node2D

var _session: GameSession
var _layout: TileLayout
var _renderer: WorldRenderer
var _input_reader: InputReader
var _hud: Hud

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

	_hud = Hud.new()
	add_child(_hud)
	_hud.refresh(_session.state, _input_reader.interaction_mode)

	print("alien_godot: phase 3 boot ok — mode=%s clock=%.2fh day=%d season=%s player=%s" % [
		GameInteractionMode.display_name(_input_reader.interaction_mode),
		_session.state.clock.time_of_day_hours(),
		_session.state.clock.day_of_season,
		Season.Kind.keys()[_session.state.clock.season],
		_session.state.player.tile_position,
	])

func _process(delta: float) -> void:
	var commands: Array[GameCommand] = _input_reader.take_commands()
	_session.update(delta, commands)
	_renderer.hovered_tile = _input_reader.hovered_tile
	_renderer.interaction_mode = _input_reader.interaction_mode
	_renderer.queue_redraw()
	_hud.refresh(_session.state, _input_reader.interaction_mode)
```

The boot-message string changes only `phase 2` → `phase 3` so the
headless smoke test still has a deterministic line to scan for.

### `scenes/main.tscn`

Untouched. Phase 1 made it a one-line root with the script attached;
phase 2 didn't change it; phase 3 doesn't either. The HUD is built in
code by `main.gd`.

## Tests

All tests are `extends SceneTree` scripts under `tests/`, named
`test_*.gd`, and exit with `quit(0)` on success. The phase-1 smoke
test (`test_core_smoke.gd`) automatically picks up the amended core
files; no manual registration. New `scripts/client/hud.gd` is *not*
covered by the smoke test (it extends `Control`, which is correct for
a client file).

### `tests/test_survival_rules.gd` (new)

A direct port of the non-furnace cases in `Alien.Core.Tests/Simulation/SurvivalRulesTests.cs`,
plus an explicit hypothermia case. The two C# tests that depend on
furnaces (`Advance_ActiveFurnaceRaisesNearbyAmbientTemperature`,
`Advance_UndergroundShelterAndFurnaceMateriallyReduceWinterExposureRisk`)
are *deferred to phase 5* — they need `try_build_furnace` /
`try_fuel_furnace` / `advance_furnaces` / `get_furnace_heat_bonus`
which haven't been ported yet.

The test file is one `SceneTree`-extending script with all cases run
inline (`func _init()` calls each `_test_*` helper, asserts inside,
`quit(0)` at the end). Pattern matches phase 2's
`test_simulation_step.gd`.

Cases:

1. `decreases_nutrition_over_time`
   - `state = GameStateFactory.create_new()`. Capture
     `starting = state.player.current_nutrition`. Advance 10 s, no
     commands. Assert `current_nutrition < starting`.
2. `decreases_hygiene_over_time`
   - Same shape on `current_hygiene`.
3. `consume_food_restores_nutrition_and_consumes_inventory`
   - Drain 50 nutrition. Capture
     `starting_food = inventory.get_count(CANNED_FOOD)`. Advance 0 s
     with one `ConsumeFoodCommand`. Assert nutrition > 50 and food
     count is `starting_food - 1`.
4. `critical_nutrition_damages_health`
   - Drain 100 nutrition. Capture starting health (100). Advance 5 s.
     Assert health < 100. (Mirrors C#.)
5. `low_temperature_damages_health` *(phase-3-specific)*
   - `state.player.move_temperature_toward(0.0, 500.0, 1.0)` to drop
     the player to ~0 in one tick. Then advance 5 s, no commands.
     Assert health < 100. The test exists to lock in the hypothermia
     branch — the C# tests cover it implicitly through the winter
     test, but a single-purpose case will catch a regression in the
     branch directly.
6. `comfortable_state_recovers_psyche`
   - Reduce psyche by 12. Advance 15 s. Assert psyche > 88. (Mirrors
     C#.)
7. `cold_hungry_dirty_state_drops_psyche`
   - Drain nutrition 80, hygiene 75, push temperature down via
     `move_temperature_toward(10.0, 500.0, 1.0)`. Capture starting
     psyche. Advance 10 s. Assert psyche < starting. (Mirrors C#.)
8. `underground_at_night_stays_warmer_than_surface`
   - Build two parallel states using a small helper:
     ```
     surface_world = WorldGrid.create_default(12, 10, 4)
     underground_world = WorldGrid.create_default(12, 10, 4)
     underground_world.set_tile(Vector2i(5, 6), WorldTileType.Kind.EXCAVATED_FLOOR)
     surface_state = _make_state(surface_world, Vector2i(5, 3), Season.Kind.SUMMER, 0.0)
     underground_state = _make_state(underground_world, Vector2i(5, 6), Season.Kind.SUMMER, 0.0)
     ```
   - Advance each state 10 s. Assert
     `underground.player.current_temperature > surface.player.current_temperature`
     and the same on `current_ambient_temperature`. (Mirrors C#.)
9. `winter_surface_harsher_than_summer`
   - Same helper. Two states on the same world (no shelter), one in
     `SUMMER` and one in `WINTER`. Advance each 20 s in 1-s steps
     (the C# `AdvanceInSteps` helper — port it as a private func in
     this test file). Assert winter ambient < summer ambient, winter
     body temp < summer body temp, and winter health < summer health.
     (Mirrors C#.)
10. `excavated_winter_shelter_keeps_player_alive`
    - Build the C# `CreateShelterWorld(withFurnace: false)` shape: a
      4-tile pocket of `EXCAVATED_FLOOR` at (5,5)–(6,6), no furnace.
      Place player at (5,5). Winter, day 1, midnight.
    - Advance 180 s in 1-s steps. Assert
      `state.player.is_alive()`, `state.world.is_indoors(Vector2i(5,5))`,
      `state.player.health.current_health == 100`. (Mirrors C#.)

The two helpers (`_make_state`, `_advance_in_steps`) are private to
this test file; if a later test wants them too, they migrate to a
shared `tests/_test_helpers.gd`. Phase 3 doesn't need that yet.

Helper sketches for clarity:

```gdscript
func _make_state(world: WorldGrid, player_tile: Vector2i, season: int, time_of_day_seconds: float) -> GameState:
	var player := PlayerState.new(
			player_tile,
			PlayerStats.new(100),
			100.0, 100.0, 0,
			100.0, 70.0)
	var inventory := InventoryState.new()
	inventory.add(ItemId.Id.CANNED_FOOD, 2)
	var clock := ClockState.new(season, 1, time_of_day_seconds)
	return GameState.new(player, world, inventory, clock)

func _advance_in_steps(state: GameState, total_seconds: float, step_seconds: float = 1.0) -> void:
	var sim := SimulationStep.new()
	var elapsed := 0.0
	while elapsed < total_seconds:
		var dt: float = min(step_seconds, total_seconds - elapsed)
		sim.advance(state, dt, [])
		elapsed += dt
```

`PlayerState`'s constructor takes a 12-arg signature in phase 1. The
helper above uses the seven required args plus `max_temperature` and
`current_temperature`; the rest fall back to the constructor defaults,
which already match the phase-1 spec (hygiene 100/100, psyche
100/100, weapon NONE).

### Existing tests (no changes)

- `test_inventory_state.gd` — unaffected.
- `test_clock_state.gd` — unaffected.
- `test_game_state_factory.gd` — unaffected. The factory's
  `set_environment_status` call now uses the real
  `get_ambient_temperature`, but the factory test only asserts player
  HP / nutrition / temperature / hygiene / psyche / inventory counts /
  clock fields / no-active-action / player-in-bounds. None of those
  touch `state.current_ambient_temperature`, so the existing
  assertions still pass.
- `test_world_tile_type.gd`, `test_world_grid.gd`, `test_game_action_rules.gd` —
  unaffected.
- `test_simulation_step.gd` — *should* still pass. The phase-1 cases
  start an EXPEDITION action and advance up to 5 s; with phase 3
  active, `SurvivalRules.update` will drain ~0.6 nutrition, ~0.15
  hygiene, and adjust temperature toward winter / summer ambient. The
  assertions in those tests are about action progress and
  `last_completed_action_kind` only — none read `current_nutrition` /
  `current_hygiene` / `current_temperature` — so they stay green.
  Phase-2 cases (excavate, build, move) advance 0–3 s, which is too
  little to push any vital below a damage threshold from a fresh
  start; assertions about world tiles and inventory counts still
  hold.
- `test_core_smoke.gd` — unaffected; the recursive walker picks up
  the amended `survival_rules.gd` and `game_state.gd` automatically.

### Client tests?

Same call as phase 2: no headless tests for `hud.gd`. It depends on
the scene tree, control layout, and a font being available to a
running display server. The smoke test guarantees nothing under
`client/` leaks into `core/`. Visual verification is what `./run.sh`
provides for this phase.

## Run / verify

After all files exist and `./run-tests.sh` is green:

```
./run-headless.sh
# expected: "alien_godot: phase 3 boot ok — mode=Excavate clock=6.00h
# day=1 season=SUMMER player=(12, 5)" then exit cleanly.

./run.sh
# window opens. HUD visible at top-right. Tile colors as in phase 2.
```

Visual checks in `./run.sh`:

- The clock label ticks every real second (game clock advances at
  144× wall-clock rate by default; one real second ≈ 2.4 game minutes).
  `Y1 SUMMER D01 06.04h` → `Y1 SUMMER D01 06.05h` after a real second.
- `Nutr` decreases by `0.12 × delta` per real second. Visible decimal
  drift in the label within a few seconds (label is `%0.0f`, so a
  visible drop takes ~8 s; that's expected).
- Standing on the surface in summer at 06:00, `Ambient` reads ≈ 50.0
  (sin term is 0 at sunrise). At noon it climbs toward 80 (50 +
  30 × 1).
- Walking the player onto an excavated tile (after digging out a
  small pocket: dig the surface tile under the player, then the tile
  to the side, then a wall back over the entrance) flips the location
  label from `surface` to `underground`, and once enclosed,
  `indoors`. `Ambient` jumps to the underground curve (50 / 58 in
  summer). This is the simplest end-to-end demonstration that
  `is_indoors` works in a running window.
- Left-click the player tile while `Nutr` is below 100 — the
  `ConsumeFoodCommand` from phase 2 now actually does something; food
  count drops by one and nutrition jumps by 35.
- `C` still cancels an in-progress action (phase 2). `1` / `2` still
  toggle the interaction mode (phase 2). `Mode` label updates
  immediately.

Regression check: all phase-2 visual behaviors (hover overlay, action
target highlight, excavate / build) still work. The HUD doesn't
overlap the world rectangle (verify by hovering the rightmost tile
column — its red/green overlay is still visible).

If any of the above fails, fix before declaring phase 3 done.

## Design decisions worth flagging

- **Constants live on `SurvivalRules`, not in a new
  `survival_constants.gd`.** The C# version uses `private const float`
  inside the class. GDScript's `const` on a `class_name` script is
  module-private by convention (leading underscore), and pulling them
  into a separate file would mean a second source of truth that drifts.
  Phase 7 will tune these — the underscore-prefixed constants give
  greppable names like `_NUTRITION_DECAY_PER_SECOND` without inviting
  outside callers.
- **`get_furnace_heat_bonus` lands now as a no-op.** The alternative is
  a `state.has_method("get_furnace_heat_bonus")` check inside
  `SurvivalRules.get_ambient_temperature`. That's two lines of guard
  in a hot path and a stale-API risk. A two-line no-op stub on
  `GameState` is cheaper, makes phase 5's diff smaller, and keeps the
  signature stable for tests.
- **`get_ambient_temperature` reads `state.active_action.kind` directly,
  not via a `is_expedition_active()` helper.** Phase 4 will add an
  `active_combat` field; the C# call shape (`state.ActiveAction?.Kind ==
  GameActionKind.Expedition`) is what gets ported. Inventing a helper
  here means inventing matching helpers for phase 4 / 6 / 7, which is
  premature.
- **HUD is `Control` + `VBoxContainer` + `Label`s, not `_draw` on
  `Node2D`.** `_draw` would force us to ship font measurement, manual
  line layout, and theme-color logic — none of which earn their
  complexity for "show eight stats." Godot's `Label` does this for
  free. The world renderer stays on `_draw` because tiles are
  geometrically uniform and we'll grow it into sprite composition;
  text isn't.
- **`mouse_filter = MOUSE_FILTER_IGNORE` on the HUD root and every
  child.** Default `PASS` would still let the world receive clicks
  *under* the HUD because mouse-filter PASS doesn't block — but events
  *do* fire `_gui_input` on the Control, which phase-3 `Hud` doesn't
  use. `IGNORE` short-circuits the hit-test entirely; no surprise
  callbacks if a future label has `_gui_input`. Cheaper to set once
  here than to remember it later.
- **Long-running tests run in 1-s steps, not one big advance.** The
  `move_temperature_toward` / `apply_neglect_damage` paths are
  rate-limited; a single `advance(state, 30.0, [])` would cap the
  per-tick deltas at one application of each rate, which is *not*
  what the C# tests assert. The C# `AdvanceInSteps` helper drives
  many small ticks for the same reason. Match it.
- **Hypothermia test is an *addition*, not a port.** The C# suite
  doesn't have an explicit "low temperature applies neglect damage"
  case — it tests the branch implicitly through the winter survival
  test. The high-level plan calls out "temperature differential" as a
  phase-3 test target; an explicit one-line case (test #5) catches a
  regression of the threshold or the rate without depending on the
  full season curve.
- **No `ProgressBar`s.** They'd be three lines per stat, but each
  one would also need a min/max/value mapping, a colour theme, and a
  decision about how to render Psyche (continuous? threshold-tinted?).
  Phase 3's job is to make the simulation *visible*, not pretty. Bars
  fold into phase 7's pass on the winter UI.
- **Window-title formatter not ported.** The C# port writes the same
  status string into the OS window title (`StatusTitleFormatter`).
  Once on-screen labels exist, the window title is redundant noise
  in the OS taskbar. If we ever decide we want it back (e.g., for
  recording demos where the screen capture crops the HUD), it's a
  one-line `get_window().title = ...` per tick.

## Implementation order

Bottom-up, each step independently testable:

1. Amend `game_state.gd` with the `get_furnace_heat_bonus` no-op.
   Re-run `tests/test_core_smoke.gd` — it should still pass.
2. Replace `survival_rules.gd` with the real bodies. Add
   `tests/test_survival_rules.gd` with cases 1–7 (the short ones
   that don't need the helpers). Run them.
3. Add `_make_state` and `_advance_in_steps` helpers in
   `tests/test_survival_rules.gd`. Add cases 8–10 (the multi-state /
   long-running ones). Run them.
4. Re-run `./run-tests.sh` end-to-end — phase-1 / 2 cases must still
   pass alongside the new ones.
5. `./run-headless.sh` — verify the boot print updates to "phase 3"
   and exits cleanly.
6. Add `client/hud.gd`. Wire it into `main.gd` with the HUD instance
   and `_process` `refresh` call.
7. `./run.sh` — verify the visual checks in "Run / verify". Pay
   particular attention to: (a) the HUD doesn't eat clicks meant for
   the world, (b) the location label flips after digging a pocket and
   sealing it, (c) `ConsumeFoodCommand` actually restores nutrition.
8. Final `./run-tests.sh` pass. Phase 3 complete.

## Open questions

- **Should psyche thresholds (25 / 35 / 30) be configurable?** Phase 7
  is the natural balancing pass. For now they're named `const`s on
  `SurvivalRules`, which is one find-and-replace away from a tunable.
  Promote to a `.tres` only if phase 7 ends up wanting a designer to
  edit them without a code change — that's the rule from the high-
  level plan ("If a number ever needs hot-tuning without a code edit,
  promote that single number to a resource").
- **Should `Hud` extend `CanvasLayer` instead of `Control`?**
  `CanvasLayer` decouples the HUD's transform from the parent
  `Node2D`, which matters once the world starts to scroll under a
  camera. Phase 2 deferred camera scrolling; `Control` is enough
  until then. Phase 7 (or whichever phase introduces scrolling) will
  wrap the HUD in a `CanvasLayer` then; one-line refactor.
- **Should the existing factory call to `set_environment_status` be
  removed?** It's redundant after phase 3 because the first
  `SimulationStep.advance` overwrites it. Argument for removing:
  fewer lines, single source of truth (only `SurvivalRules.update`
  ever calls `set_environment_status`). Argument for keeping: matches
  the C# factory line-for-line, and a test that builds a state and
  inspects `current_ambient_temperature` *before* ticking would
  otherwise see `0.0`. Keep for now; revisit if phase 4/5 wants the
  invariant tightened.
- **Should the underground / indoors check be cached per tick instead
  of recomputed inside `get_ambient_temperature` *and*
  `update`?** The BFS is `O(open-tiles)` and runs twice per tick in
  phase 3. For a 24×16 world it's microseconds, but phase 7's larger
  world might want a single `state.refresh_environment(...)` helper
  that computes everything once. Phase 3 ports the C# shape verbatim
  (which has the same redundancy); call out the optimization
  opportunity here so phase 7 can pick it up.
- **Should `Hud.refresh` accept a `hovered_tile` argument?** The C#
  status string includes hover coords. Phase 3's HUD doesn't, on the
  rationale that the hover overlay is visible in-world. If a tester
  asks for a numeric hover readout, add it as a one-line label —
  trivial.
