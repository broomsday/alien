# Phase 4 — Expeditions + loot

This is the detailed implementation plan for phase 4 of `high_level_plan.md`.
It turns the placeholder `EXPEDITION` action that phases 1–3 ship as a
no-op-on-completion into a real away-and-back loot loop. The phase ports
`ExpeditionEncounterKind`, `ExpeditionOutcome`, and `ExpeditionResolver`
from `Alien.Core/Simulation/`, threads the resolver through
`GameActionRules.complete_action`, and extends `GameState` with the
expedition bookkeeping fields (`last_expedition_outcome`,
`pending_expedition_outcome`, `expeditions_completed`,
`complete_expedition`). On the client it adds a "Start Expedition" button
to the HUD plus an `E` key shortcut, and surfaces the away / returned /
interrupted status and the most recent loot summary as new HUD lines.

The phase ends when:

- `./run-tests.sh` passes a suite that now includes
  `tests/test_expedition_resolver.gd` (reward-bound and seeded-encounter
  cases) and three new cases in `tests/test_simulation_step.gd`
  (away-status + time consumption, one-time payout, interruption with no
  rewards). The phase-1 / 2 / 3 tests still pass.
- `./run.sh` opens a window in which pressing `E` (or clicking the new
  "Start Expedition" button on the HUD) starts an expedition: the
  HUD's `Action` line shows "Expedition" with progress climbing from 0 %
  to 100 % over 5 real seconds, the new `Expedition` line flips from
  `idle` to `away`, and on completion the inventory counts jump, the
  `Last` line summarises the loot, and the status flips to `returned`
  (for non-hostile rolls) — visibly the same in the OS through the
  inventory deltas. Cancelling mid-expedition with `C` flips the status
  to `interrupted` and adds zero items.
- `./run-headless.sh` still boots and exits cleanly with an updated
  "phase 4 boot ok" line.

## Scope

### In scope

Core (still no `Node` imports under `scripts/core/`):

- `simulation/expedition_encounter_kind.gd` — new. Two-value enum
  (`NONE`, `HOSTILE_ANIMAL`), matching `ExpeditionEncounterKind.cs`.
- `simulation/expedition_outcome.gd` — new. Plain `RefCounted` carrying
  `scrap_metal`, `fuel`, `canned_food`, `encounter_kind`, with a
  `total_items()` helper and an `apply_to(inventory)` method. Constructor
  asserts non-negative counts.
- `simulation/expedition_resolver.gd` — new. One static `resolve(state)`
  that ports the four `state.next_random_int(...)` calls verbatim and the
  "no fuel and no food → +1 food" backfill.
- `simulation/game_state.gd` — amend. Add fields
  `last_expedition_outcome` (Variant, null or `ExpeditionOutcome`),
  `pending_expedition_outcome` (Variant, null or `ExpeditionOutcome`),
  `expeditions_completed: int = 0`. Add `complete_expedition(outcome)`.
  Extend `try_start_action(...)` so an EXPEDITION start clears
  `last_expedition_outcome` / `pending_expedition_outcome`. Extend
  `cancel_action()` so an EXPEDITION cancel clears those fields too.
- `simulation/game_action_rules.gd` — amend. Replace the EXPEDITION
  fall-through in `complete_action` with a `ExpeditionResolver.resolve` →
  `state.complete_expedition` call. The encounter-driven combat dispatch
  is *deferred to phase 6* (see "Deferred to later phases" below); phase
  4 auto-completes regardless of encounter and the encounter kind is
  carried on the outcome for HUD display only.
- `simulation/expedition_status.gd` — amend. Add a small
  `display_name(kind) -> String` helper that maps the enum to "Idle",
  "Away", "Returned", "Interrupted". Used by the HUD.

Client:

- `scripts/client/hud.gd` — amend. Add two new labels (status +
  last-outcome) and a `Button` with text "Start Expedition (E)". The
  button emits a new `start_expedition_requested` signal. Button is the
  only HUD descendant whose `mouse_filter` is `MOUSE_FILTER_STOP`; every
  other Label / VBoxContainer keeps `MOUSE_FILTER_IGNORE` so world clicks
  outside the button still pass through.
- `scripts/client/input_reader.gd` — amend. Read the new
  `start_expedition` action and push a `StartActionCommand(EXPEDITION,
  null)`. Add a public `queue_command(command)` so `main.gd` can forward
  the HUD button's signal into `_pending` without `InputReader` having
  to know about the HUD.
- `scripts/main.gd` — amend. Connect the HUD signal to
  `_input_reader.queue_command(...)`. Bump the boot string to "phase 4".

Project config:

- `project.godot` — add a single `start_expedition` input action bound
  to physical key `E` (keycode 69). No autoloads, no display changes.

### Deferred to later phases

- **Combat dispatch on `HOSTILE_ANIMAL`.** The C# `complete_action`
  EXPEDITION branch dispatches to `state.BeginCombat(...)` when the
  encounter is hostile, deferring the loot via `pending_expedition_outcome`
  until `state.WinCombat` or losing it on `LoseCombat`. Phase 4 lacks
  `EnemyCatalog` / `CombatEncounter` / `CombatResolver`, so it
  unconditionally calls `state.complete_expedition(outcome)`. The
  encounter kind still rolls and is preserved on the outcome — phase 6
  changes one branch in `GameActionRules.complete_action` and adds the
  `state.begin_combat(...)` / `state.win_combat` / `state.lose_combat`
  methods alongside it. The phase-4 `pending_expedition_outcome` field
  stays unused (always null) until then; lands now so phase 6's diff is
  smaller.
- **`ActiveCombat` / combat-gated commands.** The C# `SimulationStep`
  guards `ConsumeFoodCommand`, `CraftRecipeCommand`, `FuelFurnaceCommand`,
  `MovePlayerCommand` with `state.ActiveCombat is null`, and
  `GameActionRules.CanStartAction` returns false unless the action is
  `Attack` when combat is active. Phase 4 has no combat, so those guards
  stay absent — `state.active_action != null` already blocks the
  start-action / fuel / move / craft paths during an expedition.
- **`Advance_WhenExpeditionTriggersCombat_DoesNotApplyRewardsImmediately`.**
  Phase 6 lands this test alongside `BeginCombat`. The phase-4 plan
  *deliberately omits* it — porting it now would require either a
  combat stub (extra surface) or asserting the auto-complete behaviour
  (the wrong invariant for phase 6 to inherit).
- **HUD danger / status ticker, screen tint.** Phase 7 is where the
  expedition / weather pressure shows up as a coloured overlay. Phase 4
  ships only the new `Expedition` and `Last` text lines.
- **`StartExpeditionCommand` as a dedicated command type.** The C#
  port reuses `StartActionCommand(GameActionKind.Expedition)` for
  expeditions; phase 4 follows suit. A dedicated command type would buy
  no validation — `GameActionRules.can_start_action` already short-circuits
  on `state.active_action != null` and on `state.player.is_alive() == false`,
  which is the only thing the EXPEDITION branch cares about — and would
  be a third place to update when phase 6 adds the combat guard. Reuse
  `StartActionCommand`.
- **Save / load.** Out of MVP per the high-level plan; not a phase-4
  concern.

## Core port (file-by-file)

All paths are under `scripts/core/`. New files note their full path;
amended files point at the changed sections. Tests are in their own
section below.

### `simulation/expedition_encounter_kind.gd` (new)

```gdscript
class_name ExpeditionEncounterKind
extends RefCounted

enum Kind {
	NONE,
	HOSTILE_ANIMAL,
}
```

Same shape as `Season`, `ItemId`, `GameActionKind`, etc. The phase 1
"enum-on-RefCounted-shell" pattern is the consistent home for every
core enum. Adding a member later (phase 6 may keep it as-is, but a
hypothetical "scavenger" encounter would slot in here) is a one-line
edit.

### `simulation/expedition_outcome.gd` (new)

```gdscript
class_name ExpeditionOutcome
extends RefCounted

var scrap_metal: int
var fuel: int
var canned_food: int
var encounter_kind: int

func _init(p_scrap_metal: int, p_fuel: int, p_canned_food: int, p_encounter_kind: int) -> void:
	assert(p_scrap_metal >= 0, "scrap_metal must be non-negative")
	assert(p_fuel >= 0, "fuel must be non-negative")
	assert(p_canned_food >= 0, "canned_food must be non-negative")
	scrap_metal = p_scrap_metal
	fuel = p_fuel
	canned_food = p_canned_food
	encounter_kind = p_encounter_kind

func total_items() -> int:
	return scrap_metal + fuel + canned_food

func apply_to(inventory: InventoryState) -> void:
	assert(inventory != null, "inventory required")
	if scrap_metal > 0:
		inventory.add(ItemId.Id.SCRAP_METAL, scrap_metal)
	if fuel > 0:
		inventory.add(ItemId.Id.FUEL, fuel)
	if canned_food > 0:
		inventory.add(ItemId.Id.CANNED_FOOD, canned_food)
```

Notes:

- `total_items()` is a function, not a property — GDScript has no
  `get`-only properties without `@onready` / `set/get` blocks, and
  phase 1 already established the lowercase getter-func convention
  (`current_hit_points()`, `time_of_day_hours()`). Match it.
- The `> 0` guards mirror the C# version. They matter: `inventory.add`
  asserts `amount > 0`, so passing `add(SCRAP_METAL, 0)` would crash a
  test that happened to roll `1 + state.NextRandomInt(4) = 1, fuel = 0,
  canned_food = 0` (then the backfill flips food to 1, but scrap stays
  ≥ 1 by construction so only fuel / food need the guard in practice;
  keep all three guards for parity).

### `simulation/expedition_resolver.gd` (new)

```gdscript
class_name ExpeditionResolver
extends RefCounted

static func resolve(state: GameState) -> ExpeditionOutcome:
	assert(state != null, "state required")

	var scrap_metal: int = 1 + state.next_random_int(4)
	var fuel: int = state.next_random_int(3)
	var canned_food: int = state.next_random_int(3)

	if fuel == 0 and canned_food == 0:
		canned_food = 1

	var encounter_kind: int = (
		ExpeditionEncounterKind.Kind.HOSTILE_ANIMAL
		if state.next_random_int(100) < 35
		else ExpeditionEncounterKind.Kind.NONE)

	return ExpeditionOutcome.new(scrap_metal, fuel, canned_food, encounter_kind)
```

Notes:

- Order of `next_random_int` calls is *load-bearing*: it determines
  which seeds produce hostile encounters, which the phase-4 tests rely
  on (the C# tests use seed `1u` for the no-encounter assertion and
  iterate seeds `1..12` to find a hostile encounter). Don't reorder.
- `state.next_random_int(...)` is the LCG already ported by phase 1
  on `GameState` — same multiplier (1664525), same increment
  (1013904223), same `& 0xFFFFFFFF` mask, same `% max_exclusive` shape.
  No new RNG plumbing.
- The C# version is `static`; this GDScript shape mirrors it. Phase 1
  / 2 / 3 already use `class_name X extends RefCounted` + static funcs
  for `GameActionRules`, `SurvivalRules`, `BuildCosts`, etc.

### `simulation/game_state.gd` (amend)

Three new fields, one new method, two amended methods. The header
comment block at the top of the file lists what phases 4+ will add —
update it.

New fields, placed next to `expedition_status`:

```gdscript
# null or ExpeditionOutcome
var last_expedition_outcome: Variant = null
# null or ExpeditionOutcome — populated only when phase 6 wires up
# combat. Phase 4 always auto-completes, so this stays null.
var pending_expedition_outcome: Variant = null
var expeditions_completed: int = 0
```

Use `Variant` for the two outcome fields, mirroring the existing
`last_completed_action_kind: Variant` choice from phase 1. GDScript
doesn't have nullable typed references for `RefCounted` subclasses
without going through `Object` / `Variant`; matching the established
shape is one fewer thing to be clever about.

Amend `try_start_action`:

```gdscript
func try_start_action(action: GameAction) -> bool:
	assert(action != null, "action required")
	if active_action != null:
		return false
	active_action = action
	if action.kind == GameActionKind.Kind.EXPEDITION:
		expedition_status = ExpeditionStatus.Kind.AWAY
		last_expedition_outcome = null
		pending_expedition_outcome = null
	return true
```

Amend `cancel_action`:

```gdscript
func cancel_action() -> void:
	if active_action != null and active_action.kind == GameActionKind.Kind.EXPEDITION:
		expedition_status = ExpeditionStatus.Kind.INTERRUPTED
		last_expedition_outcome = null
		pending_expedition_outcome = null
	active_action = null
```

Both extensions match `GameState.cs`'s `TryStartAction` /
`CancelAction` line-for-line. Clearing `last_expedition_outcome` on
start matters because the HUD reads it: starting a new expedition
*after* a previous one returned should not show stale loot in the
"Last" line; the `null` reset blanks it back to "Last: --".

New method `complete_expedition`, placed next to
`complete_active_action`:

```gdscript
func complete_expedition(outcome: ExpeditionOutcome) -> void:
	assert(outcome != null, "outcome required")
	outcome.apply_to(inventory)
	last_expedition_outcome = outcome
	pending_expedition_outcome = null
	expedition_status = ExpeditionStatus.Kind.RETURNED
	expeditions_completed += 1
```

In C# this is `internal`; GDScript has no access modifier, but the only
caller is `GameActionRules.complete_action`. Lowercase "internal" by
convention — leave the name `complete_expedition` (no underscore prefix)
to match the public-API style of `complete_active_action`.

Update the deferred-phases comment block at the top of the file from

> Phase 4+ adds combat / expedition state (active_combat,
> last_combat_round_outcome, last_expedition_outcome,
> pending_expedition_outcome, expeditions_completed,
> combat_encounters_won and the begin_combat / win_combat /
> lose_combat / complete_expedition methods).

to

> Phase 4 adds expedition reward state (last_expedition_outcome,
> pending_expedition_outcome, expeditions_completed,
> complete_expedition). Phase 6 adds the combat side
> (active_combat, last_combat_round_outcome, combat_encounters_won,
> begin_combat / win_combat / lose_combat). Phase 5 adds the furnace
> bookkeeping (try_build_furnace, try_fuel_furnace,
> get_furnace_burn_seconds_remaining, has_active_furnace_at,
> active_furnace_count, advance_furnaces, get_furnace_heat_bonus).

So future readers know which fields landed when.

### `simulation/game_action_rules.gd` (amend)

Replace the `_:` fall-through case in `complete_action` with an explicit
EXPEDITION branch. No other case changes.

Before (current phase-3 shape):

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

After:

```gdscript
match action.kind:
	GameActionKind.Kind.EXCAVATE:
		if action.target_tile is Vector2i:
			state.world.try_excavate(action.target_tile)
	GameActionKind.Kind.BUILD_WALL:
		if action.target_tile is Vector2i:
			if state.inventory.try_remove(ItemId.Id.SCRAP_METAL, BuildCosts.SCRAP_METAL_WALL_SCRAP_COST):
				state.world.try_build_wall(action.target_tile)
	GameActionKind.Kind.EXPEDITION:
		# Phase 6 reads outcome.encounter_kind to dispatch
		# HOSTILE_ANIMAL into state.begin_combat(...). Phase 4 always
		# auto-completes; the encounter kind rides along for the HUD.
		var outcome: ExpeditionOutcome = ExpeditionResolver.resolve(state)
		state.complete_expedition(outcome)
	_:
		pass
```

The match still has a `_: pass` fall-through so BUILD_FURNACE / CRAFT /
ATTACK keep the phase-1 no-op behaviour; phase 5 / 6 fill them in.

`can_start_action` does *not* change. The phase-1 / 2 fall-through
(`_: return true` for unknown / placeholder kinds) is what allows
EXPEDITION to be valid right now — and phase 4 still wants that. The
only real precondition for an expedition is "no active action and the
player is alive", which is already enforced by the early return at the
top of `can_start_action`. No target_tile check is needed because the
EXPEDITION command carries `target_tile = null`.

### `simulation/expedition_status.gd` (amend)

Add a `display_name` static so the HUD doesn't have to know about
`Kind.keys()` indices. The enum body is unchanged.

```gdscript
class_name ExpeditionStatus
extends RefCounted

enum Kind {
	NONE,
	AWAY,
	RETURNED,
	INTERRUPTED,
}

static func display_name(kind: int) -> String:
	match kind:
		Kind.NONE:
			return "Idle"
		Kind.AWAY:
			return "Away"
		Kind.RETURNED:
			return "Returned"
		Kind.INTERRUPTED:
			return "Interrupted"
		_:
			return "?"
```

The "Idle" → `NONE` mapping resolves the small mismatch between the C#
enum (`Idle / Away / Returned / Interrupted`) and the phase-1 GDScript
enum (`NONE / AWAY / RETURNED / INTERRUPTED`). The data shape stays as
phase 1 chose; the user-facing label matches the C# port.

### Untouched core files

`game_state_factory.gd`, `simulation_step.gd`, `survival_rules.gd`,
`game_action.gd`, `game_action_kind.gd`, `game_command.gd`, all command
structs, `player_state.gd`, `player_stats.gd`, `equipped_weapon.gd`,
`clock_state.gd`, `season.gd`, `inventory_state.gd`, `item_id.gd`,
`world_grid.gd`, `world_tile_type.gd`, `build_costs.gd`,
`game_balance.gd` — *no changes in phase 4.*

`SimulationStep.advance` already handles the EXPEDITION lifecycle
(start → tick → complete) without phase-4-specific dispatch — the
EXPEDITION branch is fully owned by `GameActionRules.complete_action`,
so no `simulation_step.gd` edit is needed. The header comment block in
`simulation_step.gd` lists "FuelFurnaceCommand → phase 5",
"CraftRecipeCommand → phase 5", "ActiveCombat checks → phase 6";
*do not* update that block in phase 4 since none of those branches land
here.

`game_state_factory.gd` continues to seed `0x00C0FFEE` by default. The
seeded test cases (`tests/test_expedition_resolver.gd`) build their own
`GameState` with explicit seeds, mirroring the C# tests — they do *not*
depend on the factory's default.

## Client port (HUD button + status lines)

### `scripts/client/hud.gd` (amend)

Two new labels, one new button, one new signal. Existing lines stay
in place.

Add at the top of the class body:

```gdscript
signal start_expedition_requested
```

Add fields next to the existing `_action_label`:

```gdscript
var _expedition_status_label: Label
var _last_expedition_label: Label
var _expedition_button: Button
```

In `_ready`, after the existing `_action_label = _make_label(box)` line:

```gdscript
_expedition_status_label = _make_label(box)
_last_expedition_label = _make_label(box)

_expedition_button = Button.new()
_expedition_button.text = "Start Expedition (E)"
_expedition_button.mouse_filter = Control.MOUSE_FILTER_STOP
_expedition_button.add_theme_font_size_override("font_size", _LABEL_FONT_SIZE)
_expedition_button.pressed.connect(_on_button_pressed)
box.add_child(_expedition_button)
```

Add the connect target:

```gdscript
func _on_button_pressed() -> void:
	start_expedition_requested.emit()
```

Extend `refresh(state, interaction_mode)` with three new lines, after
the existing `_action_label.text = _action_text(state)`:

```gdscript
_expedition_status_label.text = "Expedition %s   (%d done)" % [
	ExpeditionStatus.display_name(state.expedition_status),
	state.expeditions_completed,
]
_last_expedition_label.text = _last_expedition_text(state)
_expedition_button.disabled = not _can_start_expedition(state)
```

Add the two helpers next to `_action_text`:

```gdscript
static func _last_expedition_text(state: GameState) -> String:
	if state.last_expedition_outcome == null:
		return "Last: --"
	var outcome: ExpeditionOutcome = state.last_expedition_outcome
	var encounter_text: String = "calm"
	if outcome.encounter_kind == ExpeditionEncounterKind.Kind.HOSTILE_ANIMAL:
		encounter_text = "hostile animal"
	return "Last: +%d scrap, +%d fuel, +%d food (%s)" % [
		outcome.scrap_metal,
		outcome.fuel,
		outcome.canned_food,
		encounter_text,
	]

static func _can_start_expedition(state: GameState) -> bool:
	return GameActionRules.can_start_action(state, GameActionKind.Kind.EXPEDITION, null)
```

Notes:

- The Button is the *only* child whose `mouse_filter` is `STOP`. The
  root `Control`, the `VBoxContainer`, and every `Label` keep
  `MOUSE_FILTER_IGNORE` from phase 3. That means a click on the
  button area is captured (and emits `pressed`); a click on any other
  HUD pixel falls through to the `_input` reader and is treated as a
  world click. Verify in `./run.sh`: clicking the empty space below
  the button still moves / consumes-food the same way as phase 3.
- Disabling the button when `can_start_action` returns false (player
  dead, or any active action) means the only way to queue a fresh
  expedition mid-action is to first cancel — matching the underlying
  rule. No need for "queue a follow-up expedition" UX in MVP.
- The "Idle" / "Away" / "Returned" / "Interrupted" text comes from
  `ExpeditionStatus.display_name` (added in this phase) so the HUD
  doesn't `keys()[...]`-index its way to the label.

### `scripts/client/input_reader.gd` (amend)

Two changes. First, add a public method so `main.gd` can push commands
without `InputReader` knowing about the HUD:

```gdscript
func queue_command(command: GameCommand) -> void:
	assert(command != null, "command required")
	_pending.append(command)
```

Second, extend the existing `_input` action chain with a new branch.
The existing chain is:

```gdscript
if event.is_action_pressed("mode_excavate"):
	interaction_mode = GameInteractionMode.Kind.EXCAVATE
elif event.is_action_pressed("mode_build_wall"):
	interaction_mode = GameInteractionMode.Kind.BUILD_WALL
elif event.is_action_pressed("cancel_action"):
	_pending.append(CancelActionCommand.new())
```

Add one more `elif`:

```gdscript
elif event.is_action_pressed("start_expedition"):
	_pending.append(StartActionCommand.new(GameActionKind.Kind.EXPEDITION, null))
```

The `null` target_tile is the same shape `StartActionCommand` already
supports for non-targeted actions (its constructor declares
`p_target_tile: Variant = null`), and phase 1's
`GameActionRules.can_start_action` falls through `_: return true` for
EXPEDITION whether or not a target tile is supplied.

`_on_left_click` / `_on_right_click` are unchanged — left-click is
still "consume food on player tile / move otherwise"; right-click is
still "start the current interaction-mode action". No expedition-specific
mouse mapping.

### `scripts/main.gd` (amend)

Two new lines plus a one-line handler. Add the signal connection right
after the existing `add_child(_hud)`:

```gdscript
_hud.start_expedition_requested.connect(_on_start_expedition_requested)
```

And the handler at the bottom of the file:

```gdscript
func _on_start_expedition_requested() -> void:
	_input_reader.queue_command(StartActionCommand.new(GameActionKind.Kind.EXPEDITION, null))
```

Bump the boot print's literal `phase 3` → `phase 4`. The headless run
script grep-matches on the leading "alien_godot:" prefix only, so the
phase number is informational, but every phase has updated it.

### `scripts/client/world_renderer.gd`, `tile_layout.gd`, `game_session.gd`, `game_interaction_mode.gd`, `scenes/main.tscn`

Untouched.

The renderer doesn't gain expedition-specific overlays in phase 4 (a
"player is on expedition" tile tint is a phase-7 polish item; the HUD
text is the canonical signal in phase 4). `GameInteractionMode` is for
left/right-click-driven actions — expeditions are key/button driven, so
no new mode is added; if phase 6's combat needs an "Attack" mode,
that's the next time the enum extends.

### `project.godot` (amend)

Add the new input action to the `[input]` block, following the
phase-2 pattern. Physical keycode 69 is `E`.

```
start_expedition={
"deadzone": 0.5,
"events": [Object(InputEventKey,"physical_keycode":69)]
}
```

No `[autoload]` / `[display]` / `[rendering]` changes.

## Tests

All tests are `extends SceneTree` scripts under `tests/`, named
`test_*.gd`, and exit with `quit(0)` on success. The smoke test
(`tests/test_core_smoke.gd`) automatically picks up the three new
core files; no manual registration.

### `tests/test_expedition_resolver.gd` (new)

Direct port of the two C# `ExpeditionResolverTests` cases, plus one
addition that locks in the `apply_to` contract.

```gdscript
extends SceneTree

const GameStateFactoryScript = preload("res://scripts/core/simulation/game_state_factory.gd")
const ExpeditionResolverScript = preload("res://scripts/core/simulation/expedition_resolver.gd")
const ExpeditionEncounterKindScript = preload("res://scripts/core/simulation/expedition_encounter_kind.gd")
const ExpeditionOutcomeScript = preload("res://scripts/core/simulation/expedition_outcome.gd")
const InventoryStateScript = preload("res://scripts/core/inventory/inventory_state.gd")
const ItemIdScript = preload("res://scripts/core/inventory/item_id.gd")

func _init() -> void:
	_test_resolve_uses_only_allowed_mvp_reward_types()
	_test_resolve_across_seeds_can_generate_hostile_animal_encounter()
	_test_outcome_apply_to_increments_inventory_for_positive_counts_only()
	print("test_expedition_resolver: ok")
	quit(0)

func _test_resolve_uses_only_allowed_mvp_reward_types() -> void:
	var state: GameState = GameStateFactoryScript.create_new(1)
	var outcome: ExpeditionOutcome = ExpeditionResolverScript.resolve(state)
	assert(outcome.scrap_metal >= 0, "scrap_metal must be non-negative")
	assert(outcome.fuel >= 0, "fuel must be non-negative")
	assert(outcome.canned_food >= 0, "canned_food must be non-negative")
	assert(state.inventory.get_count(ItemIdScript.Id.SIMPLE_WEAPON) == 0,
		"resolver must not yield a SIMPLE_WEAPON in MVP")
	assert(
		outcome.encounter_kind == ExpeditionEncounterKindScript.Kind.NONE
		or outcome.encounter_kind == ExpeditionEncounterKindScript.Kind.HOSTILE_ANIMAL,
		"encounter_kind must be one of the two enum values")

func _test_resolve_across_seeds_can_generate_hostile_animal_encounter() -> void:
	var found_hostile: bool = false
	for seed in range(1, 13):
		var state: GameState = GameStateFactoryScript.create_new(seed)
		var outcome: ExpeditionOutcome = ExpeditionResolverScript.resolve(state)
		if outcome.encounter_kind == ExpeditionEncounterKindScript.Kind.HOSTILE_ANIMAL:
			found_hostile = true
			break
	assert(found_hostile, "expected at least one hostile encounter across seeds 1..12")

func _test_outcome_apply_to_increments_inventory_for_positive_counts_only() -> void:
	var inventory: InventoryState = InventoryStateScript.new()
	# Zero food; non-zero scrap+fuel. apply_to must not call inventory.add(0).
	var outcome: ExpeditionOutcome = ExpeditionOutcomeScript.new(
		2, 1, 0, ExpeditionEncounterKindScript.Kind.NONE)
	outcome.apply_to(inventory)
	assert(inventory.get_count(ItemIdScript.Id.SCRAP_METAL) == 2,
		"expected 2 scrap, got %d" % inventory.get_count(ItemIdScript.Id.SCRAP_METAL))
	assert(inventory.get_count(ItemIdScript.Id.FUEL) == 1,
		"expected 1 fuel, got %d" % inventory.get_count(ItemIdScript.Id.FUEL))
	assert(inventory.get_count(ItemIdScript.Id.CANNED_FOOD) == 0,
		"expected 0 food, got %d" % inventory.get_count(ItemIdScript.Id.CANNED_FOOD))
```

Notes:

- The seed loop `1..12` is the same range the C# test uses. The first
  hostile seed in that range depends on the order of
  `next_random_int` calls *and* on the LCG implementation; both are
  ported verbatim from C#, so the same seeds produce the same encounter
  rolls. If a future refactor changes the field order in `resolve`,
  this test will fail loudly — that's the point.
- The third case (apply_to zero-count handling) doesn't have a direct
  C# counterpart but is cheap insurance against future refactors that
  drop one of the `> 0` guards in `apply_to`.

### `tests/test_simulation_step.gd` (amend — add three cases)

Append three new helpers and call them from `_init`. Cases mirror the
relevant C# `SimulationStepTests`:

1. `_test_advance_when_expedition_starts_sets_away_status_and_consumes_time`
   - `state = GameStateFactory.create_new()`. Capture
     `starting_time = state.clock.time_of_day_seconds`.
   - `step.advance(state, 2.0, [StartActionCommand.new(EXPEDITION)])`.
   - Assert `state.active_action != null`,
     `state.active_action.kind == EXPEDITION`,
     `state.expedition_status == AWAY`,
     `state.clock.time_of_day_seconds > starting_time`.
2. `_test_advance_when_expedition_completes_adds_rewards_exactly_once`
   - `state = GameStateFactory.create_new(1)` (the C# test uses seed
     `1u`, which rolls `NONE` for the encounter — phase 4 will
     auto-complete just like phase 6 will for `NONE`, so this case is
     stable across phase 6).
   - Capture starting scrap / fuel / food counts.
   - `step.advance(state, 5.0, [StartActionCommand.new(EXPEDITION)])`.
   - Assert `state.last_expedition_outcome != null`,
     `state.expedition_status == RETURNED`,
     `state.expeditions_completed == 1`,
     `state.inventory.get_count(SCRAP_METAL) == starting_scrap +
     outcome.scrap_metal`, same for fuel and food.
   - `step.advance(state, 5.0, [])` (no commands).
   - Assert the inventory counts are unchanged from the previous
     assertions — i.e. the rewards aren't re-applied each tick.
3. `_test_advance_when_expedition_cancelled_does_not_apply_rewards`
   - `state = GameStateFactory.create_new()`.
   - Capture starting scrap.
   - `step.advance(state, 1.0, [StartActionCommand.new(EXPEDITION)])`.
   - `step.advance(state, 0.0, [CancelActionCommand.new()])`.
   - Assert `state.expedition_status == INTERRUPTED`,
     `state.last_expedition_outcome == null`,
     `state.expeditions_completed == 0`,
     scrap unchanged.

The existing
`_test_advance_when_expedition_is_cancelled_sets_interrupted_status`
test from phase 1 already asserts the status flip; case 3 above is a
*superset* (it adds the `last_expedition_outcome` and rewards-untouched
checks). Replace the phase-1 case with this stricter one — the
`_init()` registration list shrinks back to the same length.

The existing `_test_advance_starts_and_completes_action_over_time`
case uses the default seed and asserts `state.last_completed_action_kind
== EXPEDITION`. Phase 4 still satisfies that because
`GameState.complete_active_action` sets `last_completed_action_kind`
*after* the inner `GameActionRules.complete_action` call regardless of
whether the EXPEDITION branch ran. Leave it alone.

Required imports at the top of `test_simulation_step.gd` (already
present except for the last):

```gdscript
const GameStateFactoryScript = preload("res://scripts/core/simulation/game_state_factory.gd")
const SimulationStepScript = preload("res://scripts/core/simulation/simulation_step.gd")
const StartActionCommandScript = preload("res://scripts/core/simulation/start_action_command.gd")
const CancelActionCommandScript = preload("res://scripts/core/simulation/cancel_action_command.gd")
const MovePlayerCommandScript = preload("res://scripts/core/simulation/move_player_command.gd")
const GameActionKindScript = preload("res://scripts/core/simulation/game_action_kind.gd")
const ExpeditionStatusScript = preload("res://scripts/core/simulation/expedition_status.gd")
const WorldTileTypeScript = preload("res://scripts/core/world/world_tile_type.gd")
const ItemIdScript = preload("res://scripts/core/inventory/item_id.gd")
# new in phase 4 — case 2 reads outcome.scrap_metal / fuel / canned_food
```

The `ExpeditionOutcome` type is already loaded transitively because
`state.last_expedition_outcome` is `Variant`; no `preload` needed for
the assertions to compile. If a future refactor pushes the assertions
into a static helper that needs the typed reference, add the preload
then.

### Existing tests (should still pass without edits)

- `test_inventory_state.gd`, `test_clock_state.gd`,
  `test_world_tile_type.gd`, `test_world_grid.gd`,
  `test_game_action_rules.gd` — no expedition path; unaffected.
- `test_game_state_factory.gd` — checks player / world / inventory /
  clock at t=0; doesn't touch `last_expedition_outcome` /
  `expeditions_completed`. Unaffected.
- `test_survival_rules.gd` — no expedition tests in phase 3;
  `_get_temperature_adjust_rate` and the windchill branch read
  `state.active_action.kind == EXPEDITION` without depending on the
  resolver's body. Unaffected.
- `test_core_smoke.gd` — recursive walker picks up the three new
  files; new files extend `RefCounted`, no `Node` imports, so the
  smoke test is happy.

### Client tests?

Same call as phase 2 / 3: no headless tests for `hud.gd` or
`input_reader.gd`. The HUD depends on a running display server (font,
theme, button rendering) and the input reader depends on
`InputEvent` plumbing; the smoke test's role is to catch core/client
leakage, which it still does. Visual verification is what `./run.sh`
provides.

## Run / verify

After all files exist and `./run-tests.sh` is green:

```
./run-headless.sh
# expected: "alien_godot: phase 4 boot ok — mode=Excavate clock=6.00h
# day=1 season=SUMMER player=(12, 5)" then exit cleanly.

./run.sh
# window opens. HUD now shows two new lines under Action:
#   Expedition Idle   (0 done)
#   Last: --
# and a "Start Expedition (E)" button below them.
```

Visual checks in `./run.sh`:

- Press `E`. `Action` flips from "Action idle" to
  "Action Expedition   0%"; `Expedition` flips from `Idle (0 done)`
  to `Away (0 done)`. The button greys out (disabled because
  `active_action != null`).
- After ~5 real seconds the action completes. `Expedition` flips to
  `Returned (1 done)`. `Last` shows e.g.
  `Last: +3 scrap, +1 fuel, +2 food (calm)` or `(hostile animal)`,
  depending on the seed-progression that round. Inventory counters
  on the existing line bump by exactly those amounts. The button
  re-enables.
- Press `E` again, then `C` mid-flight (within the 5 s window).
  `Expedition` flips to `Interrupted (1 done)` (counter doesn't
  increment). `Last` shows whatever it showed before — the
  interrupted run did not produce a new outcome. The button re-enables.
  Inventory is unchanged from the moment of cancel (no rewards
  applied).
- Click the "Start Expedition (E)" button instead of pressing the
  key. Same `idle → away` flip. Watch the cursor: clicking the
  button does *not* dispatch a `MovePlayerCommand` (because the
  button captures the click); clicking the empty HUD area below the
  button *does* still pass through to the world (e.g. moves the
  player if it lines up with a tile).
- During an expedition, right-click the world. The hover overlay still
  draws (phase 2 behaviour) but no new action starts —
  `GameActionRules.can_start_action` returns false while
  `active_action != null`. The hover overlay is therefore red on
  every tile during an expedition, which is the existing phase-2
  signal that the action can't start.
- Walk the player onto a soil tile (after digging a pocket) and start
  an expedition from underground: the temperature label briefly drops
  toward the surface ambient (phase 3 already routes `is_indoors`
  ≠ EXPEDITION-ambient). At winter this is the phase-3 winter
  windchill case in action.

Regression check: phase-3 visual behaviours all still work — clock
ticks, nutrition / hygiene drift visible, indoor / surface label
flips after enclosing a pocket, left-click on player tile consumes a
food, `1` / `2` toggle excavate/build mode, `C` cancels.

If any of the above fails, fix before declaring phase 4 done.

## Design decisions worth flagging

- **Auto-complete on hostile encounter, deferred combat dispatch.**
  The C# `complete_action` EXPEDITION branch reads the encounter and
  either completes the expedition or begins combat. Phase 4 ports the
  resolver and the encounter field but always calls
  `state.complete_expedition`. Alternatives considered:
  (a) clamp encounter to `NONE` in the resolver until phase 6 — but
  that would change the LCG call sequence, breaking the seeded test
  (`Resolve_AcrossDifferentSeedsCanGenerateHostileAnimalEncounter`)
  and forcing a re-port of the resolver in phase 6;
  (b) leave the player in `AWAY` with a `pending_expedition_outcome`
  on hostile rolls — but phase 4 has no way to resolve that state,
  trapping the player. (c) auto-complete and document — kept the
  resolver byte-identical to the C#, kept the test stable across
  phases, and required a one-branch swap in phase 6. (c) wins.
- **`pending_expedition_outcome` field lands now even though it's
  always null.** Same rationale as phase 3's
  `get_furnace_heat_bonus` no-op: keeping the storage shape stable
  shrinks phase 6's diff and keeps tests / HUD safe to read the
  field unconditionally. Cost is one `var = null` declaration.
- **Reuse `StartActionCommand(EXPEDITION, null)` over a dedicated
  `StartExpeditionCommand`.** A new command type would need its own
  `simulation_step` branch and offer no validation that
  `StartActionCommand` doesn't already provide via
  `GameActionRules.can_start_action`. The C# port reuses
  `StartActionCommand`; matching that keeps the dispatch table
  shorter.
- **Button + key binding for the HUD trigger, not a third
  `interaction_mode`.** Excavate / Build-Wall are tile-targeted
  modes resolved on right-click. Expedition has no target tile, so
  shoehorning it into the mode toggle would mean special-casing the
  right-click path. A button with an `E` shortcut is the smallest
  change that lands the high-level plan's "expedition button" bullet
  *and* keeps muscle memory available for keyboard-only play.
- **HUD-to-command bridge via signal + `InputReader.queue_command`.**
  Direct coupling (HUD calls `_session.update`) leaks the simulation
  ownership to the HUD; storing a `_pending` array on the HUD itself
  duplicates phase-2's queue. Emitting a Godot `signal` and routing
  through the existing `InputReader._pending` keeps the command
  pipeline single-threaded and matches the same shape that phase 2's
  keyboard / mouse paths already use.
- **`ExpeditionStatus.display_name` static helper.** Phase 3 used
  `Season.Kind.keys()[state.clock.season]` to print the season,
  accepting "SUMMER" all-caps. The C# enum for status is
  `Idle / Away / Returned / Interrupted` — Title-Case, and "Idle"
  ≠ "NONE". A 5-line static keeps the HUD line readable without
  forcing the enum value name to change.
- **Encounter kind on the outcome, not as a separate field on
  `GameState`.** The C# version stores only the *outcome* on the
  state (`LastExpeditionOutcome`), not a separate "last encounter
  kind". Mirroring that means the HUD reads
  `state.last_expedition_outcome.encounter_kind`. If phase 6 wants
  a "last encounter resolved" line independent of expedition outcome,
  add a field then.
- **No screen tint / sound for expedition state.** Phase 7 owns the
  visual-pressure pass; a temperate-windchill colour shift on the
  world during an expedition is the right hook for that phase, not
  this one. Stage cleanliness > flashy MVP.

## Implementation order

Bottom-up, each step independently testable:

1. Add `expedition_encounter_kind.gd` and `expedition_outcome.gd`.
   Re-run `tests/test_core_smoke.gd` — it should still pass (the
   new files are pure `RefCounted`).
2. Add `expedition_resolver.gd`. Add
   `tests/test_expedition_resolver.gd` with all three cases. Run it.
3. Amend `game_state.gd` (new fields, amended `try_start_action` /
   `cancel_action`, new `complete_expedition`). Re-run
   `test_core_smoke.gd`.
4. Amend `expedition_status.gd` with the `display_name` helper.
5. Amend `game_action_rules.gd` to dispatch EXPEDITION through the
   resolver. Run `tests/test_game_action_rules.gd` — it should still
   pass (no new validity rules).
6. Amend `tests/test_simulation_step.gd` with the three new cases (and
   replace the phase-1 cancellation case with the stricter version).
   Run it.
7. `./run-tests.sh` end-to-end — phase-1 / 2 / 3 cases must still
   pass alongside the new ones.
8. Amend `project.godot` with the `start_expedition` input action.
9. Amend `client/input_reader.gd` (`queue_command`, new key handler).
10. Amend `client/hud.gd` (signal, two labels, button, `refresh`
    extension). Wire the HUD signal through `main.gd`.
11. Amend `scripts/main.gd` (signal connection, handler, boot string).
12. `./run-headless.sh` — verify the boot print updates and the
    process exits cleanly.
13. `./run.sh` — verify each visual check in "Run / verify". Pay
    particular attention to: (a) clicking the empty HUD area below
    the button still passes through to the world, (b) the `Last`
    line clears when a fresh expedition starts, (c) cancelling
    mid-expedition does not increment `expeditions_completed`.
14. Final `./run-tests.sh` pass. Phase 4 complete.

## Open questions

- **Should `expeditions_completed` reset to zero when the player
  dies?** The C# port doesn't reset it — and there's no game-over
  loop yet (saves are out of MVP). Skipping the reset is the C#
  shape; if phase 7's "winning the loop is punishing" pass introduces
  a death-restart, that's the natural place to revisit. Phase 4
  matches C#: monotonic counter, never decremented.
- **Should the HUD show pending expedition outcome details (e.g.
  "loot earned but combat pending")?** Phase 4 always auto-completes,
  so `pending_expedition_outcome` is always null and the question
  is moot. Phase 6 will land the HUD branch. Don't pre-add the
  branch in `_last_expedition_text` — `null` is the right value to
  read in phase 4 and adding the phase-6 branch now would require
  fake test coverage.
- **Should the "Start Expedition (E)" button show duration or
  expected outcome ranges?** No — the loot table is part of the
  game's *discovery*, and the duration is fixed at 5 game seconds
  which the action progress bar (phase 7 polish) will eventually
  show. Phase 4's button is a verb, not a tooltip.
- **Are 5 game-seconds enough for the expedition to feel like a
  real "away" period?** With the phase-1 / 2 game-clock multiplier of
  `144×` real-seconds, 5 game seconds is ~12 real minutes of
  *simulated* time but only ~5 real seconds of wall-clock
  *experienced* time. The MonoGame port uses the same tuning. Phase 7
  is the balancing pass — promote `_get_duration_seconds(EXPEDITION)`
  to `GameBalance` if the duration becomes a tunable, otherwise
  leave it inline.
- **Should the resolver's encounter probability (35 %) live on
  `GameBalance`?** Same answer as phase 3's psyche thresholds: keep
  it as a private literal in the resolver (matching the C#'s `< 35`
  inline literal) until phase 7 wants a designer-tunable. The plan
  rule from the high-level doc applies: promote a number to a
  resource only when it actually needs to be hot-tuned.
- **Should `ExpeditionOutcome.encounter_kind` be typed as
  `ExpeditionEncounterKind.Kind` instead of `int`?** GDScript
  doesn't expose typed enum aliases at the field level the way C#
  does — every enum value is an `int` at runtime. Phase 1's pattern
  is `var kind: int` with assertions / comparisons against
  `Kind.X`; matching it. Don't invent a new typing convention here.
