# Phase 5 — Crafting + furnace + weapon

This is the detailed implementation plan for phase 5 of `high_level_plan.md`.
It lands the structured recipe layer that earlier phases left as TODO
markers (`BuildCosts.SCRAP_METAL_WALL_SCRAP_COST`, the `_:` fall-through
branches in `GameActionRules.complete_action`, the no-op
`game_state.get_furnace_heat_bonus`, the dangling `FuelFurnaceCommand`),
and turns them into a coherent slice: a `RecipeCatalog` of three recipes
(`SCRAP_METAL_WALL`, `FURNACE`, `SIMPLE_WEAPON`), a furnace that can be
placed on excavated floor and burns down a fuel-seconds counter that
warms nearby tiles, and a craftable starter weapon that takes the
`EquippedWeapon` slot from `NONE` to `SIMPLE_WEAPON`. On the client it
adds a `BUILD_FURNACE` interaction mode (`3` key), a "Craft Weapon"
button, and right-click-on-a-furnace-tile-to-fuel.

The phase ends when:

- `./run-tests.sh` passes a suite that now includes
  `tests/test_recipe_rules.gd` (missing-resource failure, simple-weapon
  craft, no double-equip), `tests/test_furnace_state.gd` (build / fuel
  / advance / heat-radius / burn-out), and four new cases in
  `tests/test_simulation_step.gd` (build-furnace completion, fuel
  furnace activates heat, craft simple weapon end-to-end, fuel-furnace
  fails on non-furnace tile). `tests/test_game_action_rules.gd` gains
  one case for `BUILD_FURNACE` validity. The phase-1 / 2 / 3 / 4 tests
  still pass.
- `./run.sh` opens a window in which:
  - Pressing `3` flips the mode label to `Build Furnace`. Right-clicking
    an excavated-floor tile starts a 3-second `BuildFurnace` action;
    on completion the tile turns into a Furnace (distinct colour from
    the existing palette) and the inventory drops by 4 scrap + 1 fuel.
  - Right-clicking a Furnace tile (in any mode) consumes 1 fuel and
    starts the burn timer; the new HUD `Furnaces` line shows
    `1 active`. Standing next to it warms the player tile (the
    `Ambient` reading on the HUD jumps up; over time `Body`
    follows).
  - Clicking the new `Craft Weapon (3 scrap)` HUD button consumes 3
    scrap, increments the inventory's `SimpleWeapon` count, equips
    the weapon, and the new HUD `Weapon` line flips from `--` to
    `Simple`. Crafting is rejected when the weapon is already equipped
    or when resources are short — the button is disabled in both cases.
  - The phase-3 winter shelter test from `_test_excavated_winter_shelter_keeps_player_alive`
    keeps surviving; placing+fuelling a furnace inside the shelter now
    pushes ambient noticeably higher.
- `./run-headless.sh` still boots and exits cleanly with an updated
  `phase 5 boot ok` line.

## Scope

### In scope

Core (still no `Node` imports under `scripts/core/`):

- `crafting/recipe_id.gd` — new. Three-value enum (`SCRAP_METAL_WALL`,
  `FURNACE`, `SIMPLE_WEAPON`), matching `RecipeId.cs`. New directory
  `scripts/core/crafting/`.
- `crafting/recipe_cost.gd` — new. Plain `RefCounted` carrying
  `item_id: int` and `amount: int`, with a non-negative-amount assert.
- `crafting/recipe_definition.gd` — new. Plain `RefCounted` carrying
  `recipe_id: int` and `costs: Array[RecipeCost]`.
- `crafting/recipe_catalog.gd` — new. Static `get(recipe_id) ->
  RecipeDefinition`. The dictionary is built lazily on first access and
  cached in a static `_recipes` var.
- `crafting/recipe_rules.gd` — new. Static `can_afford(inventory,
  recipe_id) -> bool`, `can_craft(state, recipe_id) -> bool`, and
  `try_craft(state, recipe_id) -> bool`. Mirrors `RecipeRules.cs`
  one-for-one. The `SIMPLE_WEAPON` branch consumes scrap, adds the
  inventory item, and calls `state.player.equip_weapon(...)`.

- `simulation/craft_recipe_command.gd` — new. Plain
  `extends GameCommand` with one `recipe_id: int` field, like
  `MovePlayerCommand` / `FuelFurnaceCommand`.
- `simulation/game_state.gd` — amend. Add private dictionary
  `_furnace_burn_seconds_remaining: Dictionary` (Vector2i → float),
  add `try_build_furnace`, `try_fuel_furnace`,
  `get_furnace_burn_seconds_remaining`, `has_active_furnace_at`,
  `active_furnace_count`, `advance_furnaces`. Replace the no-op
  `get_furnace_heat_bonus` with the Manhattan-distance lookup
  (`0→22, 1→16, 2→10, 3→5, _→0`). Update the comment block at the top.
- `simulation/game_action_rules.gd` — amend.
  - `can_start_action`: route `BUILD_WALL` and `BUILD_FURNACE`
    affordability through `RecipeRules.can_afford(...)`. Add a
    `BUILD_FURNACE` branch: target in bounds, target ≠ player tile,
    `RecipeRules.can_afford(state.inventory, RecipeId.Id.FURNACE)`,
    `state.world.can_build_furnace_at(tile)`. The existing
    `BUILD_WALL` branch swaps from
    `state.inventory.get_count(SCRAP_METAL) < BuildCosts.SCRAP_METAL_WALL_SCRAP_COST`
    to a `RecipeRules.can_afford(state.inventory, RecipeId.Id.SCRAP_METAL_WALL)`
    call.
  - `complete_action`: replace the inline `try_remove(SCRAP_METAL, 1)`
    in the `BUILD_WALL` branch with a `_try_pay_recipe(state,
    RecipeId.Id.SCRAP_METAL_WALL)` helper. Add a `BUILD_FURNACE`
    branch that calls `_try_pay_recipe(state, RecipeId.Id.FURNACE)` →
    `state.try_build_furnace(tile)`. Add the private helper.
- `simulation/simulation_step.gd` — amend. Wire the deferred command
  branches for `CraftRecipeCommand` and `FuelFurnaceCommand`. Insert a
  `state.advance_furnaces(delta_seconds)` call between the active-action
  tick and the `SurvivalRules.update(...)` call (matches the C# order
  in `SimulationStep.cs`). Update the header comment block.
- `simulation/build_costs.gd` — **delete**. Phase 2 added it as a
  placeholder for "the wall costs one scrap" until phase 5 brought
  recipes; no other caller depends on it now that `GameActionRules`
  reads `RecipeCatalog`.

Client:

- `client/game_interaction_mode.gd` — amend. Add a `BUILD_FURNACE`
  member to `enum Kind` and the matching `to_action_kind` /
  `display_name` rows.
- `client/input_reader.gd` — amend. Read the new `mode_build_furnace`
  action (`3` key) and switch `interaction_mode`. Add a
  fuel-on-right-click branch: if `hovered_tile` is already a
  `FURNACE` tile, queue `FuelFurnaceCommand(hovered_tile)` instead
  of `StartActionCommand(...)` regardless of the current
  interaction mode. Mirrors the C# input reader's
  `_interactionMode == BuildFurnace && state.World.GetTile(tile) ==
  Furnace` branch but generalised so the player doesn't have to be
  in furnace mode to top up an existing furnace (one less papercut
  for keyboard-light players).
- `client/world_renderer.gd` — amend. The `_TILE_COLORS` palette
  already includes a furnace colour (carried over since phase 2),
  so no palette work is needed. Add a tiny "burning" overlay on
  active furnace tiles: a half-opacity orange rect inset from the
  base furnace tile, drawn only when `state.has_active_furnace_at(tile)`.
- `client/hud.gd` — amend. Add three labels (`Furnaces`, `Weapon`,
  `Heat at player`) and one `Craft Weapon (3 scrap)` button. Like
  the phase-4 `Start Expedition` button: `MOUSE_FILTER_STOP` on the
  button only; everything else stays `MOUSE_FILTER_IGNORE`. The
  button emits a new `craft_weapon_requested` signal.
- `scripts/main.gd` — amend. Connect the new HUD signal and forward
  to `_input_reader.queue_command(...)`. Bump the boot string from
  `phase 4` to `phase 5`.

Project config:

- `project.godot` — add a single `mode_build_furnace` input action
  bound to physical key `3` (keycode 51). No `[autoload]` or
  `[display]` changes.

### Deferred to later phases

- **Combat dispatch on `HOSTILE_ANIMAL` and the `ATTACK` action body.**
  Phase 4 made every expedition auto-complete via
  `state.complete_expedition(...)`. Phase 5 keeps that branch
  unchanged: the C# `GameActionRules.CompleteAction` switches into
  `state.BeginCombat(...)` when the encounter is hostile, but that
  requires `EnemyCatalog` / `CombatEncounter` / `CombatResolver` and
  the `state.active_combat` field — all phase 6. The phase-4 doc
  already explains the rationale; phase 5 doesn't touch it.
- **`active_combat` guards on craft / fuel / move commands.** The
  C# `SimulationStep` guards `CraftRecipeCommand`, `FuelFurnaceCommand`,
  and `MovePlayerCommand` with `state.ActiveCombat is null`. Phase 5
  has no combat state to guard against, and adding the guards now
  would force fake test coverage. Phase 6 lands them alongside the
  combat dispatch.
- **A general crafting popup with all three recipes.** The C# port
  has a `HudOverlayScreen` enum and a "Crafting" overlay panel that
  lists each recipe with a craft button. In our HUD, the only
  non-tile-targeted recipe is `SIMPLE_WEAPON` — `SCRAP_METAL_WALL`
  and `FURNACE` are normally placed via the right-click + interaction
  mode flow, *not* the crafting panel. Calling
  `RecipeRules.try_craft(state, SCRAP_METAL_WALL)` from a button
  consumes 1 scrap with no other effect (the wall has no tile to
  build on); same trap for `FURNACE`. So the HUD ships only the
  `Craft Weapon` button for now. A full panel is a phase-7 polish
  candidate.
- **Furnace-specific HUD overlay (flame icon, burn-time bar).** The
  client gets a half-opacity orange overlay on lit furnace tiles
  (cheap, useful) but not a per-furnace progress bar. The HUD
  `Furnaces` label shows the count and the highest remaining burn
  seconds at the player's tile. Anything fancier waits for phase 7.
- **Recipe-driven save / load.** Saves are out of MVP per the
  high-level plan; the furnace dictionary's `Vector2i → float` shape
  is friendly to a future `ConfigFile` / JSON dump, but phase 5
  doesn't introduce a serializer.
- **Hot-tunable recipe costs.** Phase 7 may promote them to a
  `.tres`. Phase 5 mirrors the C# inline literals.
- **Recipe queueing / multi-step crafting.** The C# `Craft`
  `GameActionKind` exists with a 2-second duration but is never
  actually exercised — `CraftRecipeCommand` resolves immediately
  inside `SimulationStep` without going through `active_action`.
  Phase 5 keeps that shape: the `Craft` branch in
  `GameActionRules._get_duration_seconds` / `_get_description`
  stays, and `complete_action` keeps the `_:` fall-through for
  `CRAFT` (no body). If a future phase wants timed crafting,
  promote `CraftRecipeCommand` into a `StartActionCommand(CRAFT,
  recipe_id)` and add the body — but don't do it speculatively now.

## Core port (file-by-file)

All paths are under `scripts/core/`. New files note their full path;
amended files point at the changed sections. Tests are in their own
section below.

### `crafting/recipe_id.gd` (new)

```gdscript
class_name RecipeId
extends RefCounted

enum Id {
	SCRAP_METAL_WALL,
	FURNACE,
	SIMPLE_WEAPON,
}
```

Same enum-on-RefCounted-shell as `ItemId`, `Season`, `GameActionKind`,
`ExpeditionEncounterKind`. Mirrors `RecipeId.cs`.

### `crafting/recipe_cost.gd` (new)

```gdscript
class_name RecipeCost
extends RefCounted

var item_id: int
var amount: int

func _init(p_item_id: int, p_amount: int) -> void:
	assert(p_amount > 0, "amount must be positive")
	item_id = p_item_id
	amount = p_amount
```

The C# version is a `readonly record struct`. GDScript has no
zero-allocation value-type equivalent, so it lands as a small
`RefCounted`. Asserting `amount > 0` matches the
`InventoryState.try_remove(amount > 0)` precondition — a zero-cost
recipe would be a bug, not a feature.

### `crafting/recipe_definition.gd` (new)

```gdscript
class_name RecipeDefinition
extends RefCounted

var recipe_id: int
var costs: Array[RecipeCost]

func _init(p_recipe_id: int, p_costs: Array[RecipeCost]) -> void:
	assert(p_costs != null, "costs required")
	recipe_id = p_recipe_id
	costs = p_costs
```

The C# `RecipeDefinition` takes `params RecipeCost[]`; GDScript has
no varargs, so callers pass an `Array[RecipeCost]` literal. Used
only inside `RecipeCatalog`, so the verbose construction is a
one-time cost.

### `crafting/recipe_catalog.gd` (new)

```gdscript
class_name RecipeCatalog
extends RefCounted

static var _recipes: Dictionary = {}

static func get_recipe(recipe_id: int) -> RecipeDefinition:
	if _recipes.is_empty():
		_build()
	var recipe: RecipeDefinition = _recipes.get(recipe_id, null)
	assert(recipe != null, "unknown recipe_id %d" % recipe_id)
	return recipe

static func _build() -> void:
	_recipes[RecipeId.Id.SCRAP_METAL_WALL] = RecipeDefinition.new(
		RecipeId.Id.SCRAP_METAL_WALL,
		[RecipeCost.new(ItemId.Id.SCRAP_METAL, 1)] as Array[RecipeCost])
	_recipes[RecipeId.Id.FURNACE] = RecipeDefinition.new(
		RecipeId.Id.FURNACE,
		[
			RecipeCost.new(ItemId.Id.SCRAP_METAL, 4),
			RecipeCost.new(ItemId.Id.FUEL, 1),
		] as Array[RecipeCost])
	_recipes[RecipeId.Id.SIMPLE_WEAPON] = RecipeDefinition.new(
		RecipeId.Id.SIMPLE_WEAPON,
		[RecipeCost.new(ItemId.Id.SCRAP_METAL, 3)] as Array[RecipeCost])
```

Notes:

- The function name is `get_recipe` (not `get`) because `get` is a
  Godot reserved Object method name; calling it on a non-Object
  (`RefCounted` subclass) would be fine but shadowing the built-in
  is asking for trouble in client code that holds a `RecipeCatalog`
  reference.
- `static var` was added in Godot 4.2; we're on 4.6. The lazy build
  matches GDScript's lack of static initialisers — calling the
  catalog from a test under `--headless --script test_*.gd` (no
  scene tree) still works.
- The cost arrays are `Array[RecipeCost]` so a typo in the
  initialiser surfaces at parse time, not at access. The `as
  Array[RecipeCost]` casts are required because GDScript's array
  literals default to `Array` (untyped) — without the cast the
  `Array[RecipeCost]` field assignment fails at runtime.

### `crafting/recipe_rules.gd` (new)

```gdscript
class_name RecipeRules
extends RefCounted

static func can_afford(inventory: InventoryState, recipe_id: int) -> bool:
	assert(inventory != null, "inventory required")
	var recipe: RecipeDefinition = RecipeCatalog.get_recipe(recipe_id)
	for cost in recipe.costs:
		if not inventory.has_at_least(cost.item_id, cost.amount):
			return false
	return true

static func can_craft(state: GameState, recipe_id: int) -> bool:
	assert(state != null, "state required")
	if not can_afford(state.inventory, recipe_id):
		return false
	if recipe_id == RecipeId.Id.SIMPLE_WEAPON:
		return state.inventory.get_count(ItemId.Id.SIMPLE_WEAPON) == 0 \
			and state.player.equipped_weapon == EquippedWeapon.Slot.NONE
	return true

static func try_craft(state: GameState, recipe_id: int) -> bool:
	assert(state != null, "state required")
	if not can_craft(state, recipe_id):
		return false
	var recipe: RecipeDefinition = RecipeCatalog.get_recipe(recipe_id)
	for cost in recipe.costs:
		if not state.inventory.try_remove(cost.item_id, cost.amount):
			return false
	if recipe_id == RecipeId.Id.SIMPLE_WEAPON:
		state.inventory.add(ItemId.Id.SIMPLE_WEAPON, 1)
		state.player.equip_weapon(EquippedWeapon.Slot.SIMPLE_WEAPON)
	return true
```

Notes:

- The `try_remove` loop matches the C# version: each cost is paid
  individually, so a half-paid recipe leaves the inventory short.
  In practice `can_craft` already checked affordability so the loop
  succeeds, but the early `return false` is preserved 1:1 with C#
  for the same reason: it's the contract the tests assert.
- The `SIMPLE_WEAPON` branch is the only post-payment side effect
  in MVP. `SCRAP_METAL_WALL` and `FURNACE` recipes only describe
  the resource transfer; placing the tile is the
  `BUILD_WALL` / `BUILD_FURNACE` action's job (paid via
  `_try_pay_recipe` in `GameActionRules`, not via
  `RecipeRules.try_craft`). That's exactly the C# split.

### `simulation/craft_recipe_command.gd` (new)

```gdscript
class_name CraftRecipeCommand
extends GameCommand

var recipe_id: int

func _init(p_recipe_id: int) -> void:
	recipe_id = p_recipe_id
```

Same shape as `MovePlayerCommand` / `FuelFurnaceCommand`.

### `simulation/game_state.gd` (amend)

The biggest core diff in phase 5. Six new methods, one replaced
no-op, one new private field, one updated comment block.

Update the header comment from

> Phase 4 adds expedition reward state (last_expedition_outcome,
> pending_expedition_outcome, expeditions_completed,
> complete_expedition). Phase 6 adds the combat side
> (active_combat, last_combat_round_outcome, combat_encounters_won,
> begin_combat / win_combat / lose_combat). Phase 5 adds the furnace
> bookkeeping (try_build_furnace, try_fuel_furnace,
> get_furnace_burn_seconds_remaining, has_active_furnace_at,
> active_furnace_count, advance_furnaces, get_furnace_heat_bonus).

to

> Phase 4 adds expedition reward state (last_expedition_outcome,
> pending_expedition_outcome, expeditions_completed,
> complete_expedition). Phase 5 adds furnace bookkeeping
> (try_build_furnace, try_fuel_furnace,
> get_furnace_burn_seconds_remaining, has_active_furnace_at,
> active_furnace_count, advance_furnaces, get_furnace_heat_bonus —
> now a real Manhattan-distance lookup). Phase 6 adds the combat side
> (active_combat, last_combat_round_outcome, combat_encounters_won,
> begin_combat / win_combat / lose_combat).

Add the private field next to `_random_state`:

```gdscript
# Vector2i -> float seconds remaining on each furnace's current burn.
var _furnace_burn_seconds_remaining: Dictionary = {}
```

Replace the phase-3 no-op `get_furnace_heat_bonus` with the real lookup:

```gdscript
func get_furnace_heat_bonus(tile_position: Vector2i) -> float:
	var highest_bonus: float = 0.0
	for furnace_tile in _furnace_burn_seconds_remaining:
		var burn_seconds: float = _furnace_burn_seconds_remaining[furnace_tile]
		if burn_seconds <= 0.0:
			continue
		var distance: int = absi(tile_position.x - furnace_tile.x) + absi(tile_position.y - furnace_tile.y)
		var bonus: float = 0.0
		match distance:
			0:
				bonus = 22.0
			1:
				bonus = 16.0
			2:
				bonus = 10.0
			3:
				bonus = 5.0
			_:
				bonus = 0.0
		highest_bonus = maxf(highest_bonus, bonus)
	return highest_bonus
```

Notes:

- Manhattan distance, same falloff table as `GameState.cs:223-232`.
  Don't switch to Euclidean — the C# tests assume the L1 metric and
  the phase-3 winter shelter test, which is mutated in this phase
  to add a furnace, depends on the (0, 0) → 22 bonus.
- The dictionary iterates in insertion order in GDScript ≥ 4.0; the
  `highest_bonus` reduction makes that detail irrelevant. Don't
  promote the iteration order to a load-bearing invariant.
- `absi` is the integer absolute-value built-in (Godot 4); using
  `abs` works but returns a float for `int` inputs in some Godot
  versions, which then forces a needless `int(...)` round-trip.

Add the build / fuel / lifecycle methods next to `complete_expedition`:

```gdscript
func try_build_furnace(tile_position: Vector2i) -> bool:
	if not world.try_build_furnace(tile_position):
		return false
	_furnace_burn_seconds_remaining[tile_position] = 0.0
	return true

func try_fuel_furnace(tile_position: Vector2i, fuel_seconds: float) -> bool:
	assert(fuel_seconds > 0.0, "fuel_seconds must be positive")
	if world.get_tile(tile_position) != WorldTileType.Kind.FURNACE:
		return false
	if not inventory.try_remove(ItemId.Id.FUEL, 1):
		return false
	var current_seconds: float = _furnace_burn_seconds_remaining.get(tile_position, 0.0)
	_furnace_burn_seconds_remaining[tile_position] = current_seconds + fuel_seconds
	return true

func get_furnace_burn_seconds_remaining(tile_position: Vector2i) -> float:
	return _furnace_burn_seconds_remaining.get(tile_position, 0.0)

func has_active_furnace_at(tile_position: Vector2i) -> bool:
	return get_furnace_burn_seconds_remaining(tile_position) > 0.0

func active_furnace_count() -> int:
	var count: int = 0
	for tile in _furnace_burn_seconds_remaining:
		if _furnace_burn_seconds_remaining[tile] > 0.0:
			count += 1
	return count

func advance_furnaces(delta_seconds: float) -> void:
	assert(delta_seconds >= 0.0, "delta_seconds must be non-negative")
	if delta_seconds == 0.0 or _furnace_burn_seconds_remaining.is_empty():
		return
	for tile in _furnace_burn_seconds_remaining.keys():
		_furnace_burn_seconds_remaining[tile] = maxf(0.0,
			_furnace_burn_seconds_remaining[tile] - delta_seconds)
```

Notes:

- `try_build_furnace` mirrors the C# pay-then-build via the
  `WorldGrid` predicate: if the tile isn't replaceable (i.e. not
  `EXCAVATED_FLOOR`), we don't reserve dictionary space for it.
  The dictionary entry is created with `0.0` so a freshly built
  furnace is *not* yet active — fueling is a separate step.
- `try_fuel_furnace`'s order of checks is load-bearing: tile-must-be-
  furnace before inventory.try_remove. Reversing them would let a
  failed fuel call eat fuel from the inventory if the tile turned
  out to be wrong. Same guarantee as `GameState.cs:172`.
- `active_furnace_count` is a function rather than a property
  because GDScript fields can't have lazy getters without `static
  set/get` blocks, and phase 1 already settled the
  "lowercase-getter-func" convention (`current_hit_points()`,
  `time_of_day_hours()`).
- The C# `AdvanceFurnaces` materialises the keys with `[..
  _furnaceBurnSecondsRemaining.Keys]` to allow modification during
  iteration. `Dictionary.keys()` in GDScript returns a fresh
  `Array`, so no extra copy is needed — but write `.keys()`
  explicitly to make the "snapshot then mutate" intent obvious
  to the next reader.

The `try_start_action` and `cancel_action` methods are unchanged
in phase 5; the furnace dictionary is invariant under expedition
start / cancel because furnaces are environmental state, not
expedition state. Same for the LCG / random fields.

### `simulation/game_action_rules.gd` (amend)

The header comment changes from

> Phase 2 lands per-kind validity for EXCAVATE / BUILD_WALL and the matching
> completion bodies. BUILD_FURNACE / EXPEDITION / CRAFT keep their phase-1
> default-true / no-op behavior; ATTACK / combat phases override later.

to

> Phase 5 adds BUILD_FURNACE validity + completion (RecipeCatalog-driven)
> and migrates BUILD_WALL's affordability check from BuildCosts to
> RecipeRules.can_afford. The CRAFT GameActionKind keeps its phase-1
> default-true validity / no-op completion — phase-5 crafting is driven
> by CraftRecipeCommand inside SimulationStep, not by an active GameAction.
> ATTACK / combat phases override later.

`can_start_action` body:

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
			if not RecipeRules.can_afford(state.inventory, RecipeId.Id.SCRAP_METAL_WALL):
				return false
			return state.world.can_build_wall_at(target_tile)
		GameActionKind.Kind.BUILD_FURNACE:
			if not (target_tile is Vector2i):
				return false
			if target_tile == state.player.tile_position:
				return false
			if not RecipeRules.can_afford(state.inventory, RecipeId.Id.FURNACE):
				return false
			return state.world.can_build_furnace_at(target_tile)
		_:
			return true
```

`complete_action` body:

```gdscript
static func complete_action(state: GameState, action: GameAction) -> void:
	match action.kind:
		GameActionKind.Kind.EXCAVATE:
			if action.target_tile is Vector2i:
				state.world.try_excavate(action.target_tile)
		GameActionKind.Kind.BUILD_WALL:
			if action.target_tile is Vector2i:
				if _try_pay_recipe(state, RecipeId.Id.SCRAP_METAL_WALL):
					state.world.try_build_wall(action.target_tile)
		GameActionKind.Kind.BUILD_FURNACE:
			if action.target_tile is Vector2i:
				if _try_pay_recipe(state, RecipeId.Id.FURNACE):
					state.try_build_furnace(action.target_tile)
		GameActionKind.Kind.EXPEDITION:
			# Phase 6 reads outcome.encounter_kind to dispatch
			# HOSTILE_ANIMAL into state.begin_combat(...). Phase 5 still
			# auto-completes; the encounter kind rides along for the HUD.
			var outcome: ExpeditionOutcome = ExpeditionResolver.resolve(state)
			state.complete_expedition(outcome)
		_:
			pass

static func _try_pay_recipe(state: GameState, recipe_id: int) -> bool:
	var recipe: RecipeDefinition = RecipeCatalog.get_recipe(recipe_id)
	for cost in recipe.costs:
		if not state.inventory.try_remove(cost.item_id, cost.amount):
			return false
	return true
```

Notes:

- The pay-then-build order on `BUILD_FURNACE` matches `BUILD_WALL`:
  the C# `TryPayRecipe` is *all-or-nothing* but the Godot port is
  also "first cost fails → bail", which is identical *given*
  `can_start_action` already verified `can_afford`. The only race
  condition between the validity check and completion is "the
  player ran an expedition that drained scrap" — but `active_action
  != null` blocks that path. The pay-then-build order is therefore
  defensive but not strictly required; keeping it parallels the C#
  one-for-one.
- The `_:` fall-through still covers `CRAFT` and `ATTACK`. `CRAFT`
  remains a no-op in this phase (the high-level plan's "crafting
  panel" is wired through `CraftRecipeCommand`, not a queued
  action). `ATTACK` is phase 6.
- The duration / description tables (`_get_duration_seconds`,
  `_get_description`) are *unchanged*. `BUILD_FURNACE` already had
  a 3-second duration and a "Building Furnace" description ported
  in phase 1.

### `simulation/simulation_step.gd` (amend)

Two new branches in `_apply_command` and one new line in `advance`.

`advance`:

```gdscript
func advance(state: GameState, delta_seconds: float, commands: Array) -> void:
	assert(state != null, "state required")
	assert(delta_seconds >= 0.0, "delta_seconds must be non-negative")
	for command in commands:
		_apply_command(state, command)
	state.clock.advance(delta_seconds * GameBalance.CLOCK_SECONDS_PER_REAL_SECOND)
	if state.active_action != null:
		state.active_action.advance(delta_seconds)
		if state.active_action.is_complete():
			state.complete_active_action()
	state.advance_furnaces(delta_seconds)
	SurvivalRules.update(state, delta_seconds)
```

The `state.advance_furnaces(delta_seconds)` call goes *between* the
active-action tick and `SurvivalRules.update` — same order as
`SimulationStep.cs:31-32`. That ordering matters: a furnace that
just burned out should stop contributing heat to the survival
update on the same frame, not the next one.

`_apply_command` with the new branches:

```gdscript
func _apply_command(state: GameState, command: GameCommand) -> void:
	assert(command != null, "command required")
	if command is CancelActionCommand:
		state.cancel_action()
		return
	if not state.player.is_alive():
		return
	if command is ConsumeFoodCommand:
		SurvivalRules.try_consume_canned_food(state)
	elif command is CraftRecipeCommand:
		if state.active_action == null:
			var craft_command: CraftRecipeCommand = command
			RecipeRules.try_craft(state, craft_command.recipe_id)
	elif command is FuelFurnaceCommand:
		if state.active_action == null:
			var fuel_command: FuelFurnaceCommand = command
			state.try_fuel_furnace(fuel_command.target_tile, _FUEL_FURNACE_SECONDS)
	elif command is MovePlayerCommand:
		if state.active_action == null:
			var move_command: MovePlayerCommand = command
			if state.world.is_walkable(move_command.target_tile):
				state.player.move_to(move_command.target_tile)
	elif command is StartActionCommand:
		var start_command: StartActionCommand = command
		var action: GameAction = GameActionRules.try_create_action(state, start_command)
		if action != null:
			state.try_start_action(action)
```

Add the constant near the top of the file:

```gdscript
const _FUEL_FURNACE_SECONDS: float = 90.0
```

Notes:

- `90.0` mirrors `SimulationStep.cs:62` (`fuelSeconds: 90f`). Every
  fuel call adds 90 game-clock-seconds (≈ 0.625 real seconds at the
  144× clock multiplier). That's ~5 in-game minutes per fuel per
  furnace — short enough to feel meaningful, long enough that
  fueling isn't an every-second chore.
- Keep `_FUEL_FURNACE_SECONDS` as a private const here rather than
  on `GameBalance`. Phase 7's "winter pressure + balancing" pass
  is the natural place to promote it. Match
  `SurvivalRules._WINTER_EXPEDITION_WINDCHILL`'s precedent.
- The `state.active_action == null` guards on `CraftRecipeCommand`
  and `FuelFurnaceCommand` mirror the C# `when state.ActiveAction is
  null` filter. Phase 4's expedition guard already covers the case
  where the player hits "Craft Weapon" while away.
- Update the header comment block: `CraftRecipeCommand → wired in
  phase 5`, `FuelFurnaceCommand → wired in phase 5`, `ActiveCombat
  checks → phase 6` is the only line that stays.

### `simulation/build_costs.gd` (delete)

Phase 2 introduced `class_name BuildCosts` with one constant
(`SCRAP_METAL_WALL_SCRAP_COST = 1`) as a placeholder until phase 5
brought structured recipes. With phase 5 reading
`RecipeCatalog.get_recipe(SCRAP_METAL_WALL).costs`, no other call
site references `BuildCosts`. Delete the file *and* its
`build_costs.gd.uid` sibling.

Audit before deleting: `rg "BuildCosts" scripts/ tests/` should
turn up zero hits after the `game_action_rules.gd` edit. The smoke
test reloads the core directory each run, so the deletion is
self-verifying.

### Untouched core files

`game_state_factory.gd`, `game_action.gd`, `game_action_kind.gd`,
`game_command.gd`, `cancel_action_command.gd`,
`consume_food_command.gd`, `move_player_command.gd`,
`start_action_command.gd`, `expedition_*.gd`,
`player_state.gd`, `player_stats.gd`, `equipped_weapon.gd`,
`clock_state.gd`, `season.gd`, `inventory_state.gd`, `item_id.gd`,
`world_grid.gd`, `world_tile_type.gd`, `survival_rules.gd`,
`game_balance.gd` — *no changes in phase 5.*

`SurvivalRules.get_ambient_temperature` already calls
`state.get_furnace_heat_bonus(...)` (phase 3 wired the call site).
Phase 5 turns that no-op into a real lookup, so the existing
windchill / winter / underground branches transparently start
benefiting from nearby furnaces with no edit to `survival_rules.gd`.

`PlayerState.equip_weapon(int)` already exists from phase 1 and is
called by `RecipeRules.try_craft(SIMPLE_WEAPON)` directly. The
weapon enum (`EquippedWeapon.Slot.NONE` / `.SIMPLE_WEAPON`) is
also in place from phase 1.

`GameStateFactory.create_new` continues to seed 8 scrap, 3 fuel,
4 food. That gives a fresh game enough to: build a wall (1 scrap),
build a furnace (4 scrap + 1 fuel), craft a weapon (3 scrap),
*and* still have 1 fuel to fuel the furnace — exactly enough for
the phase-5 visual checks.

## Client port

### `client/game_interaction_mode.gd` (amend)

```gdscript
class_name GameInteractionMode
extends RefCounted

enum Kind { EXCAVATE, BUILD_WALL, BUILD_FURNACE }

static func to_action_kind(mode: int) -> int:
	match mode:
		Kind.EXCAVATE:
			return GameActionKind.Kind.EXCAVATE
		Kind.BUILD_WALL:
			return GameActionKind.Kind.BUILD_WALL
		Kind.BUILD_FURNACE:
			return GameActionKind.Kind.BUILD_FURNACE
		_:
			assert(false, "unknown interaction mode")
			return GameActionKind.Kind.EXCAVATE

static func display_name(mode: int) -> String:
	match mode:
		Kind.EXCAVATE:
			return "Excavate"
		Kind.BUILD_WALL:
			return "Build Wall"
		Kind.BUILD_FURNACE:
			return "Build Furnace"
		_:
			return "?"
```

The renderer's `_draw_hover_overlay` uses `to_action_kind(mode)` to
pick the colour — adding `BUILD_FURNACE` here automatically gives
the right green-on-excavated-floor / red-on-everything-else preview
for free.

### `client/input_reader.gd` (amend)

Three changes. Add the new `mode_build_furnace` action, add a
`craft_weapon_requested` signal handler hook (handled in
`main.gd`), and intercept right-click on furnace tiles.

```gdscript
func _input(event: InputEvent) -> void:
	if session == null or layout == null:
		return
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
	elif event.is_action_pressed("mode_build_furnace"):
		interaction_mode = GameInteractionMode.Kind.BUILD_FURNACE
	elif event.is_action_pressed("cancel_action"):
		_pending.append(CancelActionCommand.new())
	elif event.is_action_pressed("start_expedition"):
		_pending.append(StartActionCommand.new(GameActionKind.Kind.EXPEDITION, null))

func _on_right_click() -> void:
	if not (hovered_tile is Vector2i):
		return
	if session.state.world.get_tile(hovered_tile) == WorldTileType.Kind.FURNACE:
		_pending.append(FuelFurnaceCommand.new(hovered_tile))
		return
	var kind: int = GameInteractionMode.to_action_kind(interaction_mode)
	_pending.append(StartActionCommand.new(kind, hovered_tile))
```

Notes:

- The right-click → `FuelFurnaceCommand` branch fires whenever the
  hovered tile is a furnace, regardless of `interaction_mode`. That
  diverges from C# (which gates it on `_interactionMode ==
  BuildFurnace`), but it removes a usability papercut: a player in
  Excavate mode who right-clicks a furnace tile expects *something*
  to happen. The valid action kinds for that tile under
  `Excavate`/`BuildWall` are all empty (excavate doesn't apply to
  furnace tiles, build-wall can't replace furnace), so without
  this branch the click is silently dropped. Calling out the
  divergence here so a future reader doesn't think we forgot.
- `_on_left_click` is unchanged; left-click on a furnace tile (when
  it isn't the player tile) still queues `MovePlayerCommand` —
  walking onto a furnace remains valid because furnace tiles are
  open space (`WorldTileType.is_open_space` returns true).
- `queue_command` is already exposed by phase 4 — `main.gd`'s new
  craft signal forwards through it.

### `client/world_renderer.gd` (amend)

Add a single overlay branch in `_draw`. Insert after
`_draw_active_action_target()` and before `_draw_hover_overlay()`:

```gdscript
const _FURNACE_BURNING_OVERLAY_COLOR: Color = Color(1.0, 0.55, 0.18, 0.45)

func _draw_active_furnace_overlays() -> void:
	for y in range(state.world.height):
		for x in range(state.world.width):
			var tile: Vector2i = Vector2i(x, y)
			if state.world.get_tile(tile) != WorldTileType.Kind.FURNACE:
				continue
			if not state.has_active_furnace_at(tile):
				continue
			var rect: Rect2 = layout.tile_to_rect(tile)
			var inset: float = rect.size.x * 0.15
			var inner: Rect2 = Rect2(
				rect.position + Vector2(inset, inset),
				rect.size - Vector2(inset * 2, inset * 2))
			draw_rect(inner, _FURNACE_BURNING_OVERLAY_COLOR, true)
```

Call it inside `_draw`:

```gdscript
func _draw() -> void:
	if state == null or layout == null:
		return
	for y in range(state.world.height):
		for x in range(state.world.width):
			_draw_tile(Vector2i(x, y))
	_draw_active_action_target()
	_draw_active_furnace_overlays()
	_draw_hover_overlay()
	_draw_player()
```

Notes:

- O(width × height) per redraw, but the 24×16 grid keeps the inner
  loop at 384 iterations — well below any sensible budget. If a
  larger grid arrives, swap to iterating
  `state._furnace_burn_seconds_remaining.keys()` (which would
  require either making the dict public or adding a public iterator
  helper). Don't pre-optimise.
- The orange overlay is intentionally chunky (45 % alpha) so an
  active furnace looks distinct from an unlit one without needing
  a sprite. Phase 7 may swap this for a flame glyph.

### `client/hud.gd` (amend)

Three new labels, one new button, one new signal. The `Furnaces` /
`Weapon` / `Heat at player` lines slot in after the existing
`Last expedition` line; the `Craft Weapon` button is added after
the `Start Expedition` button, in the same `VBoxContainer`.

Top of the class body:

```gdscript
signal craft_weapon_requested
```

Field declarations next to the existing ones:

```gdscript
var _furnace_label: Label
var _weapon_label: Label
var _heat_label: Label
var _craft_weapon_button: Button
```

In `_ready`, after `_last_expedition_label = _make_label(box)`:

```gdscript
_furnace_label = _make_label(box)
_weapon_label = _make_label(box)
_heat_label = _make_label(box)
```

After the existing `box.add_child(_expedition_button)`:

```gdscript
_craft_weapon_button = Button.new()
_craft_weapon_button.text = "Craft Weapon (3 scrap)"
_craft_weapon_button.mouse_filter = Control.MOUSE_FILTER_STOP
_craft_weapon_button.add_theme_font_size_override("font_size", _LABEL_FONT_SIZE)
_craft_weapon_button.pressed.connect(_on_craft_weapon_pressed)
box.add_child(_craft_weapon_button)
```

In `refresh(state, interaction_mode)`, after the existing
`_expedition_button.disabled = ...` line:

```gdscript
_furnace_label.text = "Furnaces %d active" % state.active_furnace_count()
_weapon_label.text = "Weapon %s" % _weapon_text(state)
_heat_label.text = "Heat at player +%0.1f" % state.get_furnace_heat_bonus(state.player.tile_position)
_craft_weapon_button.disabled = not _can_craft_weapon(state)
```

New helpers next to `_can_start_expedition`:

```gdscript
static func _weapon_text(state: GameState) -> String:
	if state.player.equipped_weapon == EquippedWeapon.Slot.SIMPLE_WEAPON:
		return "Simple"
	return "--"

static func _can_craft_weapon(state: GameState) -> bool:
	return state.active_action == null and RecipeRules.can_craft(state, RecipeId.Id.SIMPLE_WEAPON)
```

New signal handler:

```gdscript
func _on_craft_weapon_pressed() -> void:
	craft_weapon_requested.emit()
```

Notes:

- `_can_craft_weapon` checks `state.active_action == null` *in
  addition to* `RecipeRules.can_craft` because the `CraftRecipeCommand`
  branch in `SimulationStep` enforces that guard at execution time;
  reflecting it in the button's disabled state means the player
  can't queue a click that silently no-ops. (Phase 4's
  `_can_start_expedition` does the same thing via
  `GameActionRules.can_start_action`, which already includes the
  active-action check.)
- The `Heat at player +X.X` line ranges from `0.0` (no nearby
  furnace) to `22.0` (standing on the furnace itself). It's a
  designer-visible signal for tuning.
- The button has no keyboard shortcut. A `K` key binding would be
  cheap, but the high-level plan's MVP spec doesn't call for one
  and the button is enough for the visual-check loop.

### `scripts/main.gd` (amend)

Three changes: connect the new craft signal, bump the boot string,
add the handler.

After the existing `_hud.start_expedition_requested.connect(...)`:

```gdscript
_hud.craft_weapon_requested.connect(_on_craft_weapon_requested)
```

Bottom of the file, next to `_on_start_expedition_requested`:

```gdscript
func _on_craft_weapon_requested() -> void:
	_input_reader.queue_command(CraftRecipeCommand.new(RecipeId.Id.SIMPLE_WEAPON))
```

Boot string update — `phase 4 boot ok` → `phase 5 boot ok`. The
line printed from `_ready`:

```gdscript
print("alien_godot: phase 5 boot ok — mode=%s clock=%.2fh day=%d season=%s player=%s" % [
	GameInteractionMode.display_name(_input_reader.interaction_mode),
	_session.state.clock.time_of_day_hours(),
	_session.state.clock.day_of_season,
	Season.Kind.keys()[_session.state.clock.season],
	_session.state.player.tile_position,
])
```

### `project.godot` (amend)

Add one input action to `[input]`. Physical keycode 51 = `3`:

```
mode_build_furnace={
"deadzone": 0.5,
"events": [Object(InputEventKey,"physical_keycode":51)]
}
```

Insert it between the existing `mode_build_wall` entry and
`cancel_action` so the actions stay grouped by category. No
`[autoload]` / `[display]` / `[rendering]` changes.

## Tests

All tests are `extends SceneTree` scripts under `tests/`, named
`test_*.gd`, and exit with `quit(0)` on success. The smoke test
(`tests/test_core_smoke.gd`) automatically picks up the five new
core files; no manual registration.

### `tests/test_recipe_rules.gd` (new)

Direct port of `RecipeRulesTests.cs`, plus one extra case for the
"already-equipped → can't craft again" rule the C# `RecipeRules`
encodes but doesn't have a dedicated test for.

```gdscript
extends SceneTree

const GameStateScript = preload("res://scripts/core/simulation/game_state.gd")
const PlayerStateScript = preload("res://scripts/core/gameplay/player_state.gd")
const PlayerStatsScript = preload("res://scripts/core/gameplay/player_stats.gd")
const InventoryStateScript = preload("res://scripts/core/inventory/inventory_state.gd")
const ClockStateScript = preload("res://scripts/core/time/clock_state.gd")
const WorldGridScript = preload("res://scripts/core/world/world_grid.gd")
const SeasonScript = preload("res://scripts/core/time/season.gd")
const ItemIdScript = preload("res://scripts/core/inventory/item_id.gd")
const EquippedWeaponScript = preload("res://scripts/core/gameplay/equipped_weapon.gd")
const RecipeRulesScript = preload("res://scripts/core/crafting/recipe_rules.gd")
const RecipeIdScript = preload("res://scripts/core/crafting/recipe_id.gd")

func _init() -> void:
	_test_try_craft_when_resources_are_missing_returns_false()
	_test_try_craft_simple_weapon_consumes_scrap_and_equips_weapon()
	_test_try_craft_simple_weapon_when_already_equipped_returns_false()
	_test_can_afford_walls_and_furnaces_against_inventory()
	print("test_recipe_rules: ok")
	quit(0)

func _test_try_craft_when_resources_are_missing_returns_false() -> void:
	var state: GameState = _make_state(scrap=2, fuel=0)
	var crafted: bool = RecipeRulesScript.try_craft(state, RecipeIdScript.Id.SIMPLE_WEAPON)
	assert(not crafted, "expected try_craft to fail when scrap is short")
	assert(state.player.equipped_weapon == EquippedWeaponScript.Slot.NONE,
		"expected weapon slot empty after failed craft")
	assert(state.inventory.get_count(ItemIdScript.Id.SIMPLE_WEAPON) == 0,
		"expected no SIMPLE_WEAPON in inventory")
	assert(state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL) == 2,
		"expected scrap untouched after failed craft, got %d" %
			state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL))

func _test_try_craft_simple_weapon_consumes_scrap_and_equips_weapon() -> void:
	var state: GameState = _make_state(scrap=6, fuel=0)
	var crafted: bool = RecipeRulesScript.try_craft(state, RecipeIdScript.Id.SIMPLE_WEAPON)
	assert(crafted, "expected try_craft to succeed with 6 scrap")
	assert(state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL) == 3,
		"expected 3 scrap remaining, got %d" %
			state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL))
	assert(state.inventory.get_count(ItemIdScript.Id.SIMPLE_WEAPON) == 1,
		"expected 1 SIMPLE_WEAPON in inventory")
	assert(state.player.equipped_weapon == EquippedWeaponScript.Slot.SIMPLE_WEAPON,
		"expected SIMPLE_WEAPON equipped")
	assert(state.player.combat_power_bonus() == 2,
		"expected combat_power_bonus 2, got %d" % state.player.combat_power_bonus())

func _test_try_craft_simple_weapon_when_already_equipped_returns_false() -> void:
	var state: GameState = _make_state(scrap=9, fuel=0)
	# Craft once, then try again with enough scrap on the second pass.
	var first: bool = RecipeRulesScript.try_craft(state, RecipeIdScript.Id.SIMPLE_WEAPON)
	assert(first, "first craft should succeed")
	var second: bool = RecipeRulesScript.try_craft(state, RecipeIdScript.Id.SIMPLE_WEAPON)
	assert(not second, "second craft should fail — weapon already equipped")
	assert(state.inventory.get_count(ItemIdScript.Id.SIMPLE_WEAPON) == 1,
		"expected SIMPLE_WEAPON count to stay 1")
	# Scrap consumed only once: 9 → 6 after first craft, then 6 with no more drain.
	assert(state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL) == 6,
		"expected scrap untouched on rejected craft, got %d" %
			state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL))

func _test_can_afford_walls_and_furnaces_against_inventory() -> void:
	var state: GameState = _make_state(scrap=4, fuel=1)
	assert(RecipeRulesScript.can_afford(state.inventory, RecipeIdScript.Id.SCRAP_METAL_WALL),
		"4 scrap is enough for a wall")
	assert(RecipeRulesScript.can_afford(state.inventory, RecipeIdScript.Id.FURNACE),
		"4 scrap + 1 fuel is exactly enough for a furnace")
	state.inventory.try_remove(ItemIdScript.Id.FUEL, 1)
	assert(not RecipeRulesScript.can_afford(state.inventory, RecipeIdScript.Id.FURNACE),
		"furnace should fail without fuel even with 4 scrap")

func _make_state(scrap: int = 0, fuel: int = 0) -> GameState:
	var world: WorldGrid = WorldGridScript.create_default(12, 10, 4)
	var player: PlayerState = PlayerStateScript.new(
		Vector2i(5, 3),
		PlayerStatsScript.new(100),
		100.0, 100.0, 0)
	var inventory: InventoryState = InventoryStateScript.new()
	if scrap > 0:
		inventory.add(ItemIdScript.Id.SCRAP_METAL, scrap)
	if fuel > 0:
		inventory.add(ItemIdScript.Id.FUEL, fuel)
	var clock: ClockState = ClockStateScript.new(SeasonScript.Kind.SUMMER, 1, 0.0)
	return GameStateScript.new(player, world, inventory, clock)
```

Notes:

- The `_make_state` helper deliberately *doesn't* go through
  `GameStateFactory.create_new` because that factory seeds 8 scrap
  / 3 fuel; the C# test uses a hand-built `GameState` to keep the
  starting inventory under tight control.
- The fourth case is a spot-check that `can_afford` matches the
  recipe definitions — guards against an off-by-one if anyone
  edits `recipe_catalog.gd` later.

### `tests/test_furnace_state.gd` (new)

Covers the `GameState` furnace lifecycle without going through
`SimulationStep`. The simulation-step file already gets a build /
fuel completion test; this file isolates the per-method contract.

```gdscript
extends SceneTree

const GameStateScript = preload("res://scripts/core/simulation/game_state.gd")
const PlayerStateScript = preload("res://scripts/core/gameplay/player_state.gd")
const PlayerStatsScript = preload("res://scripts/core/gameplay/player_stats.gd")
const InventoryStateScript = preload("res://scripts/core/inventory/inventory_state.gd")
const ClockStateScript = preload("res://scripts/core/time/clock_state.gd")
const WorldGridScript = preload("res://scripts/core/world/world_grid.gd")
const WorldTileTypeScript = preload("res://scripts/core/world/world_tile_type.gd")
const SeasonScript = preload("res://scripts/core/time/season.gd")
const ItemIdScript = preload("res://scripts/core/inventory/item_id.gd")

func _init() -> void:
	_test_try_build_furnace_only_on_excavated_floor()
	_test_try_fuel_furnace_requires_furnace_tile_and_fuel()
	_test_advance_furnaces_decreases_burn_remaining()
	_test_get_furnace_heat_bonus_distance_falloff()
	_test_get_furnace_heat_bonus_after_burn_out_returns_zero()
	print("test_furnace_state: ok")
	quit(0)

func _test_try_build_furnace_only_on_excavated_floor() -> void:
	var state: GameState = _make_state()
	var soil_tile: Vector2i = Vector2i(5, 5)
	assert(state.world.get_tile(soil_tile) == WorldTileTypeScript.Kind.SOIL, "expected SOIL precondition")
	assert(not state.try_build_furnace(soil_tile),
		"try_build_furnace on SOIL should fail")
	state.world.set_tile(soil_tile, WorldTileTypeScript.Kind.EXCAVATED_FLOOR)
	assert(state.try_build_furnace(soil_tile),
		"try_build_furnace on EXCAVATED_FLOOR should succeed")
	assert(state.world.get_tile(soil_tile) == WorldTileTypeScript.Kind.FURNACE,
		"tile should now be FURNACE")
	assert(state.get_furnace_burn_seconds_remaining(soil_tile) == 0.0,
		"freshly built furnace should have 0 burn seconds")
	assert(not state.has_active_furnace_at(soil_tile),
		"freshly built furnace should not be active")
	assert(state.active_furnace_count() == 0,
		"a 0-burn furnace shouldn't count as active")

func _test_try_fuel_furnace_requires_furnace_tile_and_fuel() -> void:
	var state: GameState = _make_state(fuel=1)
	var furnace_tile: Vector2i = Vector2i(5, 5)
	state.world.set_tile(furnace_tile, WorldTileTypeScript.Kind.EXCAVATED_FLOOR)
	state.try_build_furnace(furnace_tile)
	# Wrong tile: AIR cell.
	var air_tile: Vector2i = Vector2i(5, 1)
	assert(not state.try_fuel_furnace(air_tile, 90.0),
		"fueling AIR tile should fail")
	assert(state.inventory.get_count(ItemIdScript.Id.FUEL) == 1,
		"fuel must not be consumed when target tile isn't a furnace")
	# Right tile, has fuel.
	assert(state.try_fuel_furnace(furnace_tile, 90.0),
		"fueling a real furnace with fuel should succeed")
	assert(state.has_active_furnace_at(furnace_tile),
		"furnace should be active after fueling")
	assert(state.get_furnace_burn_seconds_remaining(furnace_tile) == 90.0,
		"expected 90 burn seconds, got %f" %
			state.get_furnace_burn_seconds_remaining(furnace_tile))
	assert(state.inventory.get_count(ItemIdScript.Id.FUEL) == 0,
		"fuel should be consumed")
	# Right tile, no fuel.
	assert(not state.try_fuel_furnace(furnace_tile, 90.0),
		"fueling without fuel should fail")

func _test_advance_furnaces_decreases_burn_remaining() -> void:
	var state: GameState = _make_state(fuel=1)
	var furnace_tile: Vector2i = Vector2i(5, 5)
	state.world.set_tile(furnace_tile, WorldTileTypeScript.Kind.EXCAVATED_FLOOR)
	state.try_build_furnace(furnace_tile)
	state.try_fuel_furnace(furnace_tile, 90.0)
	state.advance_furnaces(30.0)
	assert(state.get_furnace_burn_seconds_remaining(furnace_tile) == 60.0,
		"expected 60 burn seconds after 30s advance, got %f" %
			state.get_furnace_burn_seconds_remaining(furnace_tile))
	state.advance_furnaces(120.0)  # past zero
	assert(state.get_furnace_burn_seconds_remaining(furnace_tile) == 0.0,
		"burn seconds should clamp to 0")
	assert(not state.has_active_furnace_at(furnace_tile),
		"burned-out furnace should be inactive")

func _test_get_furnace_heat_bonus_distance_falloff() -> void:
	var state: GameState = _make_state(fuel=1)
	var furnace_tile: Vector2i = Vector2i(5, 5)
	state.world.set_tile(furnace_tile, WorldTileTypeScript.Kind.EXCAVATED_FLOOR)
	state.try_build_furnace(furnace_tile)
	state.try_fuel_furnace(furnace_tile, 90.0)
	assert(state.get_furnace_heat_bonus(furnace_tile) == 22.0,
		"expected +22 bonus on the furnace tile itself")
	assert(state.get_furnace_heat_bonus(Vector2i(6, 5)) == 16.0,
		"expected +16 at distance 1")
	assert(state.get_furnace_heat_bonus(Vector2i(5, 7)) == 10.0,
		"expected +10 at distance 2")
	assert(state.get_furnace_heat_bonus(Vector2i(8, 5)) == 5.0,
		"expected +5 at distance 3")
	assert(state.get_furnace_heat_bonus(Vector2i(9, 5)) == 0.0,
		"expected 0 at distance 4")
	# Diagonal — Manhattan distance 2 still matters.
	assert(state.get_furnace_heat_bonus(Vector2i(6, 6)) == 10.0,
		"expected +10 at Manhattan-2 diagonal")

func _test_get_furnace_heat_bonus_after_burn_out_returns_zero() -> void:
	var state: GameState = _make_state(fuel=1)
	var furnace_tile: Vector2i = Vector2i(5, 5)
	state.world.set_tile(furnace_tile, WorldTileTypeScript.Kind.EXCAVATED_FLOOR)
	state.try_build_furnace(furnace_tile)
	state.try_fuel_furnace(furnace_tile, 90.0)
	state.advance_furnaces(91.0)
	assert(state.get_furnace_heat_bonus(furnace_tile) == 0.0,
		"burned-out furnace should not contribute heat")

func _make_state(fuel: int = 0) -> GameState:
	var world: WorldGrid = WorldGridScript.create_default(12, 10, 4)
	var player: PlayerState = PlayerStateScript.new(
		Vector2i(5, 3),
		PlayerStatsScript.new(100),
		100.0, 100.0, 0)
	var inventory: InventoryState = InventoryStateScript.new()
	if fuel > 0:
		inventory.add(ItemIdScript.Id.FUEL, fuel)
	var clock: ClockState = ClockStateScript.new(SeasonScript.Kind.SUMMER, 1, 0.0)
	return GameStateScript.new(player, world, inventory, clock)
```

Notes:

- The diagonal heat-bonus assertion (`Vector2i(6, 6) → +10`)
  documents the Manhattan-distance choice. A Euclidean lookup
  would give a smaller bonus there; locking the L1 metric in a
  test prevents a future drive-by from "fixing" the metric.
- `advance_furnaces(91.0)` (past the 90s budget) verifies the
  `maxf(0.0, ...)` clamp.

### `tests/test_simulation_step.gd` (amend — add four cases)

Append four helpers and call them from `_init`. The existing nine
cases remain unchanged.

1. `_test_advance_when_build_furnace_completes_consumes_scrap_and_sets_furnace_tile`
   - `state = GameStateFactory.create_new()`. Excavate a soil tile
     first (`StartActionCommand(EXCAVATE, target)` → 2.0s advance).
   - Capture starting scrap and starting fuel.
   - `step.advance(state, 4.0,
     [StartActionCommand(BUILD_FURNACE, target)])`.
   - Assert `state.world.get_tile(target) == FURNACE`, scrap drops
     by 4, fuel drops by 1, `state.has_active_furnace_at(target)`
     returns false (just built, not yet fueled).
2. `_test_advance_when_fuel_furnace_command_lights_furnace`
   - Build a furnace as above.
   - Capture starting fuel.
   - `step.advance(state, 0.0, [FuelFurnaceCommand(target)])`.
   - Assert `state.has_active_furnace_at(target)`, fuel drops by 1,
     `state.get_furnace_burn_seconds_remaining(target) > 0.0`.
3. `_test_advance_when_fuel_furnace_command_targets_non_furnace_does_nothing`
   - `state = GameStateFactory.create_new()`. Pick the soil tile
     under the player (no furnace).
   - Capture starting fuel.
   - `step.advance(state, 0.0, [FuelFurnaceCommand(soil_tile)])`.
   - Assert fuel unchanged, no entry exists in
     `_furnace_burn_seconds_remaining` (verified indirectly via
     `state.active_furnace_count() == 0`).
4. `_test_advance_when_craft_recipe_command_simple_weapon_equips_weapon`
   - `state = GameStateFactory.create_new()` (8 scrap, 0 weapons).
   - Capture starting scrap.
   - `step.advance(state, 0.0,
     [CraftRecipeCommand(SIMPLE_WEAPON)])`.
   - Assert `state.player.equipped_weapon == SIMPLE_WEAPON`,
     `state.inventory.get_count(SIMPLE_WEAPON) == 1`,
     `state.inventory.get_count(SCRAP_METAL) == starting_scrap - 3`.

The existing test
`_test_advance_when_action_is_already_running_ignores_new_start`
case asserts `state.active_action.kind == EXPEDITION` after queueing
`Expedition` then `Attack` in the same advance. That stays
untouched; the new `_apply_command` ordering still iterates
commands in submission order.

Required additional preloads at the top of
`test_simulation_step.gd`:

```gdscript
const FuelFurnaceCommandScript = preload("res://scripts/core/simulation/fuel_furnace_command.gd")
const CraftRecipeCommandScript = preload("res://scripts/core/simulation/craft_recipe_command.gd")
const RecipeIdScript = preload("res://scripts/core/crafting/recipe_id.gd")
const EquippedWeaponScript = preload("res://scripts/core/gameplay/equipped_weapon.gd")
```

`ItemIdScript`, `WorldTileTypeScript`, `GameActionKindScript`,
`StartActionCommandScript` are already imported.

### `tests/test_game_action_rules.gd` (amend — add two cases)

Append two helpers and call them from `_init`. The existing three
cases stay; the BUILD_WALL one continues to work because
`RecipeRules.can_afford(SCRAP_METAL_WALL)` against an empty
inventory yields the same `false` that the `BuildCosts` lookup did.

1. `_test_can_start_build_furnace_requires_recipe_and_excavated_floor`
   - `state = GameStateFactory.create_new()`.
   - Soil tile under player's column at the surface row: not
     valid (can_build_furnace_at returns false on SOIL).
   - Excavate it (set_tile to EXCAVATED_FLOOR).
   - Now it's valid.
   - Drain the inventory's scrap below 4: not valid.
   - Restore scrap; valid again.
   - The player's own tile is invalid even on EXCAVATED_FLOOR —
     drop the player onto a hand-built floor and check.
2. `_test_can_start_build_wall_uses_recipe_catalog`
   - Already tested via `BuildCosts` in phase 2's case. Replace
     the existing case body's `try_remove(SCRAP_METAL, starting)`
     drain + assertion with a comment that `RecipeRules.can_afford`
     drives the negative branch — same observable outcome, but the
     test name should reflect the new dependency. The case stays;
     the assertion that `BUILD_WALL` is invalid without scrap is
     the load-bearing part.

### Existing tests (should still pass without edits)

- `test_inventory_state.gd`, `test_clock_state.gd`,
  `test_world_tile_type.gd`, `test_world_grid.gd`,
  `test_game_state_factory.gd`, `test_expedition_resolver.gd` —
  no change in observable behaviour. The factory still seeds
  8 scrap / 3 fuel / 4 food.
- `test_survival_rules.gd` — already exercises
  `state.get_furnace_heat_bonus(...)` indirectly through
  `get_ambient_temperature`. Phase 5 turns the no-op into a real
  lookup, but the phase-3 tests build worlds with *no* furnaces,
  so the lookup returns `0.0` — same as the no-op did. The
  `_test_excavated_winter_shelter_keeps_player_alive` case
  is the most exposed one because it advances time in a 4-tile
  excavated pocket; with no furnace placed, it should still pass.
  (If a future phase wants to extend that test to *include* a
  fueled furnace, that's a separate amendment.)
- `test_simulation_step.gd` cases 1-9 — unchanged.
- `test_core_smoke.gd` — recursive walker picks up the five new
  files under `scripts/core/crafting/` and the new
  `craft_recipe_command.gd`; all extend `RefCounted`, no `Node`
  imports.

### Client tests?

Same answer as phases 2-4: no headless tests for `hud.gd` or
`input_reader.gd`. Visual verification is what `./run.sh`
provides.

## Run / verify

After all files exist and `./run-tests.sh` is green:

```
./run-headless.sh
# expected: "alien_godot: phase 5 boot ok — mode=Excavate clock=6.00h
# day=1 season=SUMMER player=(12, 5)" then exit cleanly.

./run.sh
# window opens. HUD now shows three new lines under Last:
#   Furnaces 0 active
#   Weapon --
#   Heat at player +0.0
# and a "Craft Weapon (3 scrap)" button below the Start Expedition button.
```

Visual checks in `./run.sh`:

- Press `1` to enter Excavate mode. Right-click the soil tile
  directly below the player. After ~1.75s the tile turns the
  excavated-floor colour. Repeat for an adjacent tile.
- Press `3` to flip mode to "Build Furnace". Right-click an
  excavated-floor tile (not the player's tile). Hover preview is
  green; right-click starts a 3-second `BuildFurnace`. On
  completion the tile turns furnace-orange and the inventory
  drops by 4 scrap + 1 fuel. `Furnaces` HUD line still says
  `0 active` — built but not fueled.
- Right-click the new furnace tile (any mode). `Furnaces` flips
  to `1 active`. Walk onto an adjacent tile: `Heat at player`
  jumps from `0.0` to `+16.0`. Walk onto the furnace tile itself
  (it's open space — `WorldTileType.is_open_space` includes
  `FURNACE`): `+22.0`.
- Click the `Craft Weapon (3 scrap)` button. Inventory drops by
  3 scrap; `Weapon` line flips from `--` to `Simple`. Button
  becomes disabled (already equipped). Try clicking it again —
  nothing happens.
- Drain enough scrap (right-click a few wall tiles) so the button
  goes disabled because of cost; alternatively start at a state
  where cost is short. Either way the button reflects affordability.
- Right-click the furnace tile a second time when fuel is empty.
  No effect: `Furnaces` count unchanged, fuel inventory still 0.
  (The hover overlay still draws — we don't gate the preview on
  fuelability; that'd be a phase-7 polish item.)
- Wait ~30 real seconds (not in-game-seconds — `90 / 144 × 60` ≈
  37 wall-clock seconds; just under 90 game-seconds of burn).
  Actually since `state.advance_furnaces(delta_seconds)` is
  driven by *real* delta-seconds, the burn lasts 90 wall-clock
  seconds. Watch the `Furnaces` flip back to `0 active` and
  `Heat at player` drop to `+0.0`. Refuel to extend.
- During an expedition (`E`), the `Craft Weapon` button is
  disabled (`active_action != null`). After return, it re-enables.

Regression check: phase-2 / 3 / 4 visual behaviours all still work
— clock ticks, nutrition / hygiene drift, indoor / surface label
flips, left-click on player consumes food, `1` / `2` / `3` toggle
mode, `C` cancels, `E` starts expedition, expedition `Last` line
updates with `+N scrap …`, etc.

If any of the above fails, fix before declaring phase 5 done.

## Design decisions worth flagging

- **Recipes via `Dictionary` cache, not a `const` table.** GDScript
  doesn't permit `const Array[RecipeCost]` literals at module
  scope (typed arrays are not constant-evaluable in 4.6). A
  `static var _recipes: Dictionary` lazily initialised on first
  access is the smallest workaround that keeps the catalog cheap
  and avoids `_init`-on-every-call work.
- **`get_recipe`, not `get`.** Object's built-in `get(property:
  StringName)` is virtual; a `static get(int)` on
  `RecipeCatalog` would parse but is asking for shadow-related
  surprises in client code. The C# `RecipeCatalog.Get(...)` is
  PascalCase regardless; `get_recipe` is the snake_case
  rename that doesn't collide.
- **Delete `BuildCosts` rather than redirect through it.** Phase 2
  added it as a "wait until phase 5" scaffold. Keeping it now
  would mean two sources of truth for the wall cost — the
  catalog *and* the stub constant. The CLAUDE.md rule "avoid
  backwards-compatibility hacks like… re-exporting types"
  applies; delete it cleanly.
- **`FuelFurnaceCommand` resolves immediately, not via an
  action.** Same shape as `CraftRecipeCommand`. The fuel
  operation is a one-instant inventory transfer; wrapping it in a
  `GameAction` would be conceptually clean but imposes a
  duration / cancellation surface that the C# port doesn't
  provide. The 90-second burn is itself the "duration" the
  player feels.
- **Right-click on a furnace tile fuels regardless of mode.**
  Diverges from the C# `_interactionMode == BuildFurnace` gate.
  Rationale: with three interaction modes, requiring a mode-flip
  to fuel an existing furnace is a usability papercut, and the
  furnace-tile predicate is unambiguous (no other action targets
  furnace tiles). Documented at the call site so future
  port-correctness reviews know it's intentional.
- **Single `Craft Weapon` button instead of a popup panel.** The
  high-level plan says "Crafting panel". The C# port has a full
  `HudOverlayScreen.Crafting` overlay, but that overlay only
  matters because the C# build flow lets you craft *any* recipe
  from one place — including the wall and furnace, which then
  consume resources without placing a tile. In our port the
  wall and furnace are tile-targeted via right-click; the only
  recipe with a non-tile effect is `SIMPLE_WEAPON`. A button
  expresses that one path in one HUD line; a popup with three
  rows would imply that crafting wall / furnace from the popup
  is meaningful, which would be a UX trap. Phase 7 may revisit
  if a fourth recipe lands.
- **`_FUEL_FURNACE_SECONDS = 90.0` as a private const, not on
  `GameBalance`.** Same reasoning as
  `SurvivalRules._WINTER_EXPEDITION_WINDCHILL`: matches the C#
  `fuelSeconds: 90f` literal at the call site, and the magic
  number is local to this one call. Promote to `GameBalance` if
  phase 7 wants to tune it.
- **No `get_furnace_heat_bonus` cache.** A naive 24×16 grid lookup
  would be O(grid × furnaces), but the lookup is per-player-tile
  not per-grid-tile in `SurvivalRules`. With ≤ 8 furnaces in a
  reasonable game state, the 8-element loop is well below any
  budget worth caching for.
- **`active_furnace_count()` iterates the dictionary.** Could be
  cached in a `var _active_count: int` updated on
  `try_fuel_furnace` / `advance_furnaces`, but the cache adds a
  state-sync invariant (every burn-out tick must decrement, every
  re-fuel of a burned-out furnace must increment) that's easy to
  break. The on-demand count is correct by construction; cache
  if a profile says it matters.
- **Furnace dictionary keyed by `Vector2i`.** Godot 4 hashes
  `Vector2i` natively (it's a built-in struct), so no custom
  comparer is needed. Same key shape the C# port uses
  (`Dictionary<TilePoint, float>`).

## Implementation order

Bottom-up, each step independently testable:

1. Add `crafting/recipe_id.gd`, `crafting/recipe_cost.gd`,
   `crafting/recipe_definition.gd`, `crafting/recipe_catalog.gd`,
   `crafting/recipe_rules.gd`. Re-run
   `tests/test_core_smoke.gd` — the new files should be picked
   up cleanly; no `Node` deps.
2. Add `tests/test_recipe_rules.gd` with all four cases. Run it.
3. Add `simulation/craft_recipe_command.gd`. Smoke-test still
   passes.
4. Amend `game_state.gd`: new field, new methods, replace the
   `get_furnace_heat_bonus` no-op, update header comment. Add
   `tests/test_furnace_state.gd` with all five cases. Run it.
5. Amend `game_action_rules.gd`: route BUILD_WALL through
   `RecipeRules.can_afford` + `_try_pay_recipe`, add the
   BUILD_FURNACE branches. Run
   `tests/test_game_action_rules.gd` (with the two new cases).
6. Delete `simulation/build_costs.gd` and the matching `.uid`
   sibling. `rg "BuildCosts"` must report zero matches.
7. Amend `simulation/simulation_step.gd`: new
   `CraftRecipeCommand` and `FuelFurnaceCommand` branches,
   `state.advance_furnaces` call, `_FUEL_FURNACE_SECONDS`
   constant, header comment update.
8. Add the four new cases to `tests/test_simulation_step.gd`.
   Run it.
9. `./run-tests.sh` end-to-end — all phase-1 / 2 / 3 / 4 cases
   plus the phase-5 additions must pass.
10. Amend `project.godot` with the `mode_build_furnace` action.
11. Amend `client/game_interaction_mode.gd` (BUILD_FURNACE
    member, to_action_kind / display_name).
12. Amend `client/input_reader.gd` (mode_build_furnace handler,
    fuel-on-furnace right-click).
13. Amend `client/world_renderer.gd` (active-furnace overlay).
14. Amend `client/hud.gd` (three labels, button, signal,
    helpers).
15. Amend `scripts/main.gd` (signal connection, handler, boot
    string).
16. `./run-headless.sh` — verify the boot print updates and the
    process exits cleanly.
17. `./run.sh` — verify each visual check in "Run / verify". Pay
    attention to: (a) build-furnace flow consumes 4 scrap + 1
    fuel and turns the tile orange, (b) right-clicking a
    furnace tile in any mode fuels it (not just BUILD_FURNACE
    mode), (c) the active-furnace overlay shows up only when
    `has_active_furnace_at` is true, (d) `Heat at player` line
    matches the falloff (22 / 16 / 10 / 5 / 0).
18. Final `./run-tests.sh` pass. Phase 5 complete.

## Open questions

- **Should the `Craft Weapon` button have a `K` keyboard shortcut?**
  Phase 4 added `E` because expeditions are something a fast-twitch
  player wants to retrigger; weapon crafting is a one-time act in
  MVP. Skipping the binding keeps `[input]` short and the keyboard
  surface focused on the dynamic actions. If a future weapon /
  reroll system arrives, add it then.
- **Should `try_fuel_furnace` return the new burn-seconds value
  instead of `bool`?** The C# version returns `bool`; the GDScript
  port matches. The dictionary is queryable via
  `get_furnace_burn_seconds_remaining`, so the bool-return doesn't
  withhold information. Match C#.
- **Should `active_furnace_count` be a `Variant`-typed property
  (`@onready var active_furnace_count := func(): …`) instead of a
  function?** No — phase 1 settled on the lowercase getter-func
  convention (`is_alive()`, `current_hit_points()`,
  `time_of_day_hours()`). Match it.
- **Should the renderer iterate `_furnace_burn_seconds_remaining`
  directly via a public iterator?** Could be done with `for tile
  in state.get_active_furnace_tiles():`. The 24×16 grid scan in
  `_draw_active_furnace_overlays` is cheap enough that exposing
  the dictionary surface isn't yet justified. Phase 7 may revisit
  if a larger world demands it.
- **Should `RecipeCatalog._build` be called from `_static_init` so
  the dictionary is warm before first use?** GDScript 4.6 does
  expose `static func _static_init()`, but it triggers on
  `class_name` resolution which happens at script load. The lazy
  `if _recipes.is_empty(): _build()` path matches the existing
  no-static-init convention used by other catalogs in the codebase
  (none yet, but phase 6's `EnemyCatalog` will face the same
  question). Lazy init keeps the pattern consistent.
- **Should fueling a furnace from inventory consume more than 1
  fuel per top-up?** The C# version is exactly 1 fuel per call;
  matching that. A "consume up to N fuel for N×90 seconds in a
  single click" is a phase-7 quality-of-life polish, not a phase-5
  port concern.
- **Should an active furnace on a wall-replace target prevent
  build-wall?** `WorldGrid.can_build_wall_at(FURNACE)` returns
  false because `WorldTileType.can_be_replaced_with_wall` only
  accepts AIR / EXCAVATED_FLOOR. So a built furnace tile is
  protected from being walled over, with or without an active
  burn. No additional check needed.
