# Phase 6 — Combat

This is the detailed implementation plan for phase 6 of `high_level_plan.md`.
Phase 5 left a phase-6-shaped hole in three places: `GameState` has no
`active_combat` / `last_combat_round_outcome` / `combat_encounters_won`,
`GameActionRules.complete_action` auto-completes every expedition (the
`HOSTILE_ANIMAL` encounter never branches into combat), and
`SimulationStep._apply_command` has no `state.active_combat == null` guard
on the deferred commands. Phase 6 closes all three holes by porting the
C# `Alien.Core.Combat` namespace (`EnemyKind`, `EnemyDefinition`,
`EnemyCatalog`, `CombatEncounter`, `CombatResolution`,
`CombatRoundOutcome`, `CombatResolver`) and wiring it through
`GameState` / `GameActionRules` / `SimulationStep` / the client. The
end product is a slice in which an expedition that rolls
`HOSTILE_ANIMAL` puts the player into a turn-based duel against a
single Razor Maw, the HUD shows the enemy's HP bar, the player presses
`E` (or clicks the repurposed action button) to swing once per ATTACK
action, and victory pays out the held expedition rewards while defeat
interrupts the expedition and may kill the player.

The phase ends when:

- `./run-tests.sh` passes a suite that now includes
  `tests/test_combat_resolver.gd` (lethal-damage drops pending loot,
  weapon shortens fight, combat-skill rule, expedition-rewards-on-victory
  — direct ports of the four C# `CombatResolverTests` cases),
  `tests/test_combat_encounter.gd` (defaults to `enemy.max_health`,
  `take_damage` clamps to zero, custom `current_health` is honoured),
  `tests/test_enemy_catalog.gd` (RAZOR_MAW tunables match the C# numbers,
  `get_for_encounter` rejects `NONE`), and four new cases in
  `tests/test_simulation_step.gd` (attack action records a round and
  doesn't clear `active_combat` on a non-lethal hit, expedition with a
  hostile encounter triggers `begin_combat` with the pending outcome
  held back, craft / fuel / move commands are no-ops while combat is
  active, an attack that defeats the enemy applies the pending
  expedition reward exactly once). `tests/test_game_action_rules.gd`
  gains two cases (`ATTACK` valid only when `active_combat` is set,
  `BUILD_WALL` / `BUILD_FURNACE` / `EXCAVATE` invalid during combat).
  The phase-1 / 2 / 3 / 4 / 5 tests still pass.
- `./run.sh` opens a window in which:
  - Starting an expedition that rolls `HOSTILE_ANIMAL` (use seed 3 from
    `GameSession.new(3)` for a deterministic visual trigger — see the
    "Repro recipe" subsection) flips the HUD's `Last expedition` line to
    `Last: combat — Razor Maw 7/7` and the existing `Start Expedition`
    button retitles to `Attack (E)` and changes colour to amber.
  - Pressing `E` (or clicking the repurposed button) starts a 1.5 s
    `Attacking` action. On completion the HUD's new `Combat` line
    updates to e.g. `you hit 4   they missed   skill +1`, and the
    enemy bar drains by the dealt damage.
  - Repeated attacks either defeat the enemy — at which point the held
    expedition reward is applied (HUD `Last` flips to the loot summary,
    `Expeditions done` ticks up, `Combat won` ticks up) — or the player
    dies (HUD goes red, all bars freeze, no further commands resolve).
  - During combat a half-opacity red rectangle tints the world view
    (mirrors the C# combat tint), and right-click on a tile is silently
    swallowed (no excavate / build / fuel can interrupt the fight).
  - Cancelling an `ATTACK` mid-progress with `C` clears the pending
    swing but leaves `active_combat` set; the player is still locked
    into the duel.
- `./run-headless.sh` still boots and exits cleanly with an updated
  `phase 6 boot ok` line.

## Scope

### In scope

Core (still no `Node` imports under `scripts/core/`):

- `combat/enemy_kind.gd` — new. One-value enum (`RAZOR_MAW`), matching
  `EnemyKind.cs`. New directory `scripts/core/combat/`.
- `combat/enemy_definition.gd` — new. Plain `RefCounted` carrying
  `kind: int`, `name: String`, `max_health: int`,
  `minimum_damage: int`, `maximum_damage: int`,
  `hit_chance_percent: int`. Asserts mirror the C# constructor
  (`name` non-empty, `max_health > 0`, `minimum_damage >= 0`,
  `maximum_damage >= minimum_damage`,
  `0 <= hit_chance_percent <= 100`).
- `combat/enemy_catalog.gd` — new. Static `get_hostile_animal()` and
  `get_for_encounter(encounter_kind: int) -> EnemyDefinition`. The
  Razor Maw definition is a `static var` initialised lazily on first
  call (same shape as `RecipeCatalog`).
- `combat/combat_encounter.gd` — new. Plain `RefCounted` carrying
  `enemy: EnemyDefinition`, `current_health: int`. Constructor takes
  optional `current_health` (null → enemy.max_health). Methods:
  `max_health()`, `is_defeated()`, `take_damage(damage: int)`. Asserts
  match `CombatEncounter.cs` (damage non-negative, current_health in
  `[1, max_health]` if explicit).
- `combat/combat_resolution.gd` — new. Three-value enum (`ONGOING`,
  `ENEMY_DEFEATED`, `PLAYER_DIED`), matching `CombatResolution.cs`.
- `combat/combat_round_outcome.gd` — new. Plain `RefCounted` carrying
  every per-round field the HUD reads
  (`enemy_name`, `enemy_max_health`, `enemy_health_remaining`,
  `player_hit`, `player_damage`, `enemy_hit`, `enemy_damage`,
  `player_health_remaining`, `combat_skill_gained`, `resolution`).
  Convenience getters `enemy_defeated()` / `player_died()` map to
  `resolution == ENEMY_DEFEATED` / `PLAYER_DIED` (no setters — the
  field is constructor-frozen).
- `combat/combat_resolver.gd` — new. Static
  `resolve_attack(state: GameState) -> CombatRoundOutcome`. One-for-one
  port of `CombatResolver.cs`: rolls the player hit, applies damage,
  awards `+1` combat skill on a hit and `+1` again on victory, dispatches
  through `state.win_combat(...)` / `state.lose_combat(...)` /
  `state.record_combat_round(...)`. Helpers
  `_get_player_hit_chance_percent(state)` (clamp `55 + skill*3 +
  bonus*8` to `[25, 95]`) and `_roll_percent(state, chance_percent)` /
  `_roll_inclusive(state, min, max)` mirror the C# private helpers.

- `simulation/game_state.gd` — amend. Add three fields
  (`active_combat: CombatEncounter = null`,
  `last_combat_round_outcome: CombatRoundOutcome = null`,
  `combat_encounters_won: int = 0`) plus four methods
  (`begin_combat(encounter, pending_outcome=null)`,
  `record_combat_round(outcome)`,
  `win_combat(outcome)`,
  `lose_combat(outcome)`). The header comment block is updated to call
  out that the phase-4 "phase 6 adds combat side" stub is now
  realised. The phase-5 furnace bookkeeping is unchanged in this
  phase. The `try_start_action` method does *not* need a special case
  for `ATTACK`: the `active_combat` precondition is enforced inside
  `GameActionRules.can_start_action`, which `try_create_action`
  already calls.
- `simulation/game_action_rules.gd` — amend.
  - `can_start_action`: insert the `active_combat` short-circuit
    *before* the `match` block. When combat is active, `ATTACK` is
    valid (no target tile required); every other kind is invalid.
    Without the short-circuit, the existing `BUILD_WALL` /
    `BUILD_FURNACE` / `EXCAVATE` branches would still allow the
    player to e.g. build a wall mid-fight, which doesn't match the
    C# behaviour and lets the duel be sidestepped.
  - The existing `_:` fall-through that currently makes `ATTACK`
    default-true changes to a dedicated `GameActionKind.Kind.ATTACK`
    branch returning `state.active_combat != null`. This mirrors
    `GameActionRules.cs:35`, where `Attack => false` is the *non-combat*
    return and the `ActiveCombat is not null` short-circuit at line
    18 carries `Attack`'s in-combat truth value.
  - `complete_action`: rewrite the `EXPEDITION` branch to dispatch into
    combat. After `ExpeditionResolver.resolve(state)`, branch on
    `outcome.encounter_kind`: `NONE` → unchanged
    `state.complete_expedition(outcome)`; `HOSTILE_ANIMAL` →
    `state.begin_combat(CombatEncounter.new(EnemyCatalog.get_for_encounter(...)), outcome)`.
    Add an `ATTACK` branch that calls
    `CombatResolver.resolve_attack(state)`. The phase-5 comment about
    "Phase 6 reads outcome.encounter_kind to dispatch HOSTILE_ANIMAL
    into state.begin_combat(...). Phase 5 still auto-completes; the
    encounter kind rides along for the HUD." is removed; the new code
    *is* that dispatch.
- `simulation/simulation_step.gd` — amend. Insert
  `state.active_combat == null` guards on `ConsumeFoodCommand`,
  `CraftRecipeCommand`, `FuelFurnaceCommand`, and `MovePlayerCommand`.
  Mirrors `SimulationStep.cs:52-70`. The `StartActionCommand` branch
  is *not* guarded — `GameActionRules.can_start_action` already
  rejects every kind except `ATTACK` while combat is active, so the
  outer guard would only duplicate the inner one. Update the header
  comment block from
  > Phase 5 wires CraftRecipeCommand and FuelFurnaceCommand through to
  > RecipeRules and GameState's furnace bookkeeping, and inserts
  > state.advance_furnaces between the active-action tick and the
  > survival update. ActiveCombat checks remain phase-6.
  to
  > Phase 6 adds the active_combat == null guards on the deferred
  > commands (ConsumeFoodCommand, CraftRecipeCommand,
  > FuelFurnaceCommand, MovePlayerCommand) so a fight cannot be
  > sidestepped by interleaving a craft / fuel / move. The
  > StartActionCommand branch is unguarded — GameActionRules already
  > limits combat-active starts to ATTACK.

Client:

- `client/input_reader.gd` — amend. Three changes:
  1. Repoint the `start_expedition` action key (`E`) to a runtime
     branch: when `state.active_combat != null`, it queues a
     `StartActionCommand(ATTACK)`; otherwise it stays
     `StartActionCommand(EXPEDITION, null)`. Mirrors
     `GameInputReader.cs:68-71`.
  2. Add a new `attack` input action bound to physical key `Space`
     (keycode 32) that always queues `StartActionCommand(ATTACK)`.
     Following the C# port, this is in addition to the `E` retitle so
     keyboard-only players have a stable bind. The `attack` action
     is *only* honoured while `active_combat != null`; otherwise it's
     a no-op (the resulting `StartActionCommand` will be rejected by
     `GameActionRules` anyway, but the explicit guard avoids queueing
     dead commands).
  3. Add an `active_combat`-suppressing branch on the `_on_left_click`
     and `_on_right_click` paths: while combat is active, left-click
     on the world view is silently dropped (no move, no consume),
     right-click is silently dropped (no excavate / build / fuel).
     This is one notch stricter than the C# port — `GameInputReader.cs`
     funnels left-click on a tile through `MovePlayerCommand` and
     `SimulationStep` filters it out via the `state.ActiveCombat is
     null` guard. The Godot client filters at the input layer instead
     so the `_pending` queue stays clean and the commands never make
     it to the simulation step. Calling out the divergence so a
     future reader doesn't think we dropped the inner guard.
- `client/hud.gd` — amend. Repurpose the existing `Start Expedition`
  button into a dual-mode `Expedition` / `Attack (E)` button. Add two
  HUD lines: `Combat` (hidden when no combat is or has been active —
  see the `_combat_text` helper) and `Combat won` (the running tally
  of `combat_encounters_won`). The enemy HP isn't a `ProgressBar` —
  the same `Label` rendering used by the rest of the HUD shows
  `Razor Maw 7/7` / `4/7` / `0/7`. A real bar is a phase-7 polish
  candidate; the goal here is "the player can read the fight state
  from the HUD without staring at the world view".
- `client/world_renderer.gd` — amend. Add a single
  `_draw_combat_tint()` call after `_draw_player()` in `_draw`:
  when `state.active_combat != null`, paint a half-opacity dark-red
  rectangle covering the entire world bounds. Mirrors
  `GameRenderer.cs:94-97`.
- `scripts/main.gd` — amend. Bump the boot string from `phase 5` to
  `phase 6`. No new signal connections — the phase-5
  `start_expedition_requested` signal stays, but the `_on_start_expedition_requested`
  handler now routes to ATTACK when `state.active_combat != null`.
  The `craft_weapon_requested` signal handler from phase 5 is
  unchanged — it'll silently no-op during combat because
  `RecipeRules.try_craft` is called via `CraftRecipeCommand`, which
  is now guarded inside `_apply_command`.

Project config:

- `project.godot` — add a single `attack` input action bound to physical
  key `Space` (keycode 32). No `[autoload]` / `[display]` / `[rendering]`
  changes.

### Deferred to later phases

- **Damage numbers / floating combat text on the world view.** The C#
  port doesn't render them either. The HUD `Combat` line is enough
  for the visual-check loop. Phase 7 may layer on flash overlays.
- **Multiple simultaneous enemies.** `EnemyCatalog` ships with one
  enemy (`RAZOR_MAW`); `state.active_combat` is a single
  `CombatEncounter`, not a list. The C# port works the same way and
  the high-level plan calls out "may trigger combat with a single
  enemy type". A multi-enemy fight is out of MVP.
- **Different enemies per season / per expedition tier.** Phase 7's
  "winter pressure + balancing" pass may extend `EnemyCatalog` to
  return cold-weather variants. Phase 6 ships only the one Razor Maw.
- **Combat-only HUD overlay (centered popup with cards / actions).**
  The C# port has a `HudOverlayScreen` enum, but `Combat` isn't one
  of its values — combat shares the world view. Our HUD follows
  the same pattern: combat is a button retitle plus two extra labels,
  not a separate panel.
- **Combat skill cap or skill-driven loot bonus.** `PlayerState.combat_skill`
  has no upper bound and only feeds into the hit-chance clamp
  `[25, 95]`. The C# version is the same. Capping or rewarding the
  skill is a balancing decision for phase 7.
- **Flee / negotiate / retreat actions.** The C# port has no flee
  command and the high-level plan doesn't list one. The duel is to
  the death. `CancelActionCommand` cancels the in-progress *swing*
  but leaves `active_combat` set, mirroring the C# behaviour where
  cancelling an `Attack` only zeros `ActiveAction`.
- **Save / load mid-combat.** Saves are out of MVP. The
  `CombatEncounter`'s `current_health` field is a friendly
  serialisation target (single int), but no serializer is added here.
- **Expedition button colour-coding by combat resolution state.** The
  C# `DrawExpeditionButton` switches between four colours based on
  `ExpeditionStatus` and `ActiveAction.Kind == Attack`. Our Godot
  HUD swaps the *text* (`Expedition` ↔ `Attack (E)`) but keeps the
  default `Button` palette. A coloured `Button` requires either a
  `StyleBoxFlat` per state or an explicit theme override; that's
  phase-7 polish.

## Core port (file-by-file)

All paths are under `scripts/core/`. New files note their full path;
amended files point at the changed sections. Tests are in their own
section below.

### `combat/enemy_kind.gd` (new)

```gdscript
class_name EnemyKind
extends RefCounted

enum Kind {
	RAZOR_MAW,
}
```

Same enum-on-RefCounted-shell as `ItemId`, `Season`, `RecipeId`,
`ExpeditionEncounterKind`. Mirrors `EnemyKind.cs`. The C# enum has a
single `RazorMaw` member; we name ours `RAZOR_MAW` to match the
project's `SCREAMING_SNAKE` convention for enum values.

### `combat/enemy_definition.gd` (new)

```gdscript
class_name EnemyDefinition
extends RefCounted

var kind: int
var name: String
var max_health: int
var minimum_damage: int
var maximum_damage: int
var hit_chance_percent: int

func _init(
		p_kind: int,
		p_name: String,
		p_max_health: int,
		p_minimum_damage: int,
		p_maximum_damage: int,
		p_hit_chance_percent: int) -> void:
	assert(not p_name.strip_edges().is_empty(), "name required")
	assert(p_max_health > 0, "max_health must be positive")
	assert(p_minimum_damage >= 0, "minimum_damage must be non-negative")
	assert(p_maximum_damage >= p_minimum_damage, "maximum_damage must be >= minimum_damage")
	assert(p_hit_chance_percent >= 0 and p_hit_chance_percent <= 100, "hit_chance_percent must be in [0, 100]")
	kind = p_kind
	name = p_name
	max_health = p_max_health
	minimum_damage = p_minimum_damage
	maximum_damage = p_maximum_damage
	hit_chance_percent = p_hit_chance_percent
```

Notes:

- `name` is a constructor argument rather than a static lookup against
  `kind` because the test suite needs to construct hand-rolled
  enemies (`new EnemyDefinition(RAZOR_MAW, "Test Hunter", ...)`) the
  same way the C# `CombatResolverTests` do. Mirroring the C# shape
  one-for-one keeps the test ports trivial.
- The asserts are guards on the *catalog* — the only production caller
  is `EnemyCatalog`, which always passes valid values. Tests can
  therefore rely on the asserts to catch typos. A typo in the catalog
  surfaces under `--check-only` because the constructor is invoked
  during `EnemyCatalog._build()`.

### `combat/enemy_catalog.gd` (new)

```gdscript
class_name EnemyCatalog
extends RefCounted

static var _razor_maw: EnemyDefinition = null

static func get_hostile_animal() -> EnemyDefinition:
	if _razor_maw == null:
		_razor_maw = EnemyDefinition.new(
			EnemyKind.Kind.RAZOR_MAW,
			"Razor Maw",
			7,
			14,
			20,
			62)
	return _razor_maw

static func get_for_encounter(encounter_kind: int) -> EnemyDefinition:
	match encounter_kind:
		ExpeditionEncounterKind.Kind.HOSTILE_ANIMAL:
			return get_hostile_animal()
		_:
			assert(false, "no enemy for encounter_kind %d" % encounter_kind)
			return null
```

Notes:

- Tunables (`max_health: 7`, `min_dmg: 14`, `max_dmg: 20`, `hit: 62`)
  match `EnemyCatalog.cs:8-12` exactly. Don't drift them. The
  player has `max_hit_points = 100` and the C# tests assert specific
  weapon-vs-unarmed round counts using these numbers; changing them
  invalidates the test seeds.
- `get_for_encounter(NONE)` asserts and returns `null` rather than
  throwing — GDScript has no exceptions, and the only caller
  (`GameActionRules.complete_action`) only invokes it on the
  `HOSTILE_ANIMAL` branch. The assert is a backstop that fires under
  `--check-only` if a future encounter kind is added without a
  catalog entry.
- `static var _razor_maw` is a single field instead of a `Dictionary`
  because the C# version has only one entry. If a second enemy
  arrives in phase 7, swap to a dict (same shape as
  `RecipeCatalog._recipes`) without touching call sites.

### `combat/combat_encounter.gd` (new)

```gdscript
class_name CombatEncounter
extends RefCounted

var enemy: EnemyDefinition
var current_health: int

func _init(p_enemy: EnemyDefinition, p_current_health: Variant = null) -> void:
	assert(p_enemy != null, "enemy required")
	enemy = p_enemy
	var resolved: int = p_enemy.max_health if p_current_health == null else int(p_current_health)
	assert(resolved > 0 and resolved <= p_enemy.max_health,
		"current_health must be in (0, max_health]; got %d" % resolved)
	current_health = resolved

func max_health() -> int:
	return enemy.max_health

func is_defeated() -> bool:
	return current_health <= 0

func take_damage(damage: int) -> void:
	assert(damage >= 0, "damage must be non-negative")
	current_health = maxi(0, current_health - damage)
```

Notes:

- The optional second argument is `Variant` so callers can pass `null`
  to mean "default to `enemy.max_health`" without GDScript widening
  the type to `Variant` everywhere it's read. The runtime cast
  `int(p_current_health)` rejects ill-typed values via the
  surrounding assert.
- `current_health` is *not* read-only after construction — the C# field
  has a `private set` and `take_damage` is the only mutator. GDScript
  has no access modifiers, so we rely on convention: only
  `take_damage` mutates `current_health`, and `CombatResolver` is the
  only caller of `take_damage`.
- `maxi` is the integer `max` built-in; using `max` works but returns
  a float for `int` inputs in some Godot versions (same caveat as
  `absi` in `GameState.get_furnace_heat_bonus`).

### `combat/combat_resolution.gd` (new)

```gdscript
class_name CombatResolution
extends RefCounted

enum Kind {
	ONGOING,
	ENEMY_DEFEATED,
	PLAYER_DIED,
}
```

Mirrors `CombatResolution.cs`. Same shell pattern as `Season` /
`ExpeditionStatus`.

### `combat/combat_round_outcome.gd` (new)

```gdscript
class_name CombatRoundOutcome
extends RefCounted

var enemy_name: String
var enemy_max_health: int
var enemy_health_remaining: int
var player_hit: bool
var player_damage: int
var enemy_hit: bool
var enemy_damage: int
var player_health_remaining: int
var combat_skill_gained: int
var resolution: int

func _init(
		p_enemy_name: String,
		p_enemy_max_health: int,
		p_enemy_health_remaining: int,
		p_player_hit: bool,
		p_player_damage: int,
		p_enemy_hit: bool,
		p_enemy_damage: int,
		p_player_health_remaining: int,
		p_combat_skill_gained: int,
		p_resolution: int) -> void:
	assert(not p_enemy_name.strip_edges().is_empty(), "enemy_name required")
	assert(p_enemy_max_health > 0, "enemy_max_health must be positive")
	assert(p_enemy_health_remaining >= 0 and p_enemy_health_remaining <= p_enemy_max_health,
		"enemy_health_remaining out of range")
	assert(p_player_damage >= 0, "player_damage must be non-negative")
	assert(p_enemy_damage >= 0, "enemy_damage must be non-negative")
	assert(p_player_health_remaining >= 0, "player_health_remaining must be non-negative")
	assert(p_combat_skill_gained >= 0, "combat_skill_gained must be non-negative")
	enemy_name = p_enemy_name
	enemy_max_health = p_enemy_max_health
	enemy_health_remaining = p_enemy_health_remaining
	player_hit = p_player_hit
	player_damage = p_player_damage
	enemy_hit = p_enemy_hit
	enemy_damage = p_enemy_damage
	player_health_remaining = p_player_health_remaining
	combat_skill_gained = p_combat_skill_gained
	resolution = p_resolution

func enemy_defeated() -> bool:
	return resolution == CombatResolution.Kind.ENEMY_DEFEATED

func player_died() -> bool:
	return resolution == CombatResolution.Kind.PLAYER_DIED
```

Notes:

- The constructor takes 10 arguments — verbose but every one is
  load-bearing for the HUD's `Combat` line and the test assertions.
  The C# version has the same shape (`CombatRoundOutcome.cs:5-15`).
- `enemy_defeated()` / `player_died()` are functions rather than
  fields because GDScript fields can't have lazy getters without
  `static set/get` blocks (same precedent as `active_furnace_count`
  in `GameState`).
- The asserts mirror the C# `ArgumentOutOfRangeException` set. They're
  not strictly necessary at runtime because the only caller
  (`CombatResolver.resolve_attack`) constructs the outcome from
  validated state — but they catch test-level mistakes (e.g.
  `enemy_health_remaining < 0` from a hand-built fixture).

### `combat/combat_resolver.gd` (new)

```gdscript
class_name CombatResolver
extends RefCounted

static func resolve_attack(state: GameState) -> CombatRoundOutcome:
	assert(state != null, "state required")
	assert(state.player.is_alive(), "the player cannot attack after death")
	assert(state.active_combat != null, "no combat encounter is active")

	var encounter: CombatEncounter = state.active_combat
	var combat_skill_gained: int = 0
	var player_hit: bool = _roll_percent(state, _get_player_hit_chance_percent(state))
	var player_damage: int = 0

	if player_hit:
		player_damage = 2 + state.player.combat_power_bonus() \
			+ (state.player.combat_skill / 3) + state.next_random_int(2)
		encounter.take_damage(player_damage)
		state.player.increase_combat_skill(1)
		combat_skill_gained += 1

	if encounter.is_defeated():
		state.player.increase_combat_skill(1)
		combat_skill_gained += 1

		var victory: CombatRoundOutcome = CombatRoundOutcome.new(
			encounter.enemy.name,
			encounter.max_health(),
			encounter.current_health,
			player_hit,
			player_damage,
			false,
			0,
			state.player.current_hit_points(),
			combat_skill_gained,
			CombatResolution.Kind.ENEMY_DEFEATED)
		state.win_combat(victory)
		return victory

	var enemy_hit: bool = _roll_percent(state, encounter.enemy.hit_chance_percent)
	var enemy_damage: int = 0

	if enemy_hit:
		enemy_damage = _roll_inclusive(state,
			encounter.enemy.minimum_damage,
			encounter.enemy.maximum_damage)
		state.player.health.take_damage(enemy_damage)

	var resolution: int = (CombatResolution.Kind.ONGOING
		if state.player.is_alive()
		else CombatResolution.Kind.PLAYER_DIED)

	var round_outcome: CombatRoundOutcome = CombatRoundOutcome.new(
		encounter.enemy.name,
		encounter.max_health(),
		encounter.current_health,
		player_hit,
		player_damage,
		enemy_hit,
		enemy_damage,
		state.player.current_hit_points(),
		combat_skill_gained,
		resolution)

	if state.player.is_alive():
		state.record_combat_round(round_outcome)
	else:
		state.lose_combat(round_outcome)
	return round_outcome

static func _get_player_hit_chance_percent(state: GameState) -> int:
	var hit_chance: int = 55 \
		+ (state.player.combat_skill * 3) \
		+ (state.player.combat_power_bonus() * 8)
	return clampi(hit_chance, 25, 95)

static func _roll_percent(state: GameState, chance_percent: int) -> bool:
	return state.next_random_int(100) < chance_percent

static func _roll_inclusive(state: GameState, minimum: int, maximum: int) -> int:
	return minimum + state.next_random_int((maximum - minimum) + 1)
```

Notes:

- Order of operations is *load-bearing*. The hit-chance roll happens
  first; if the player misses, no damage is dealt and the
  `is_defeated()` branch isn't entered. The combat skill increments
  *after* the roll succeeds (mirroring `CombatResolver.cs:27`) and
  *again* on victory (`:33`). The
  `_test_resolve_attack_combat_skill_gains_only_for_successful_hits_and_victory`
  test asserts `successful_hits + 1 == combat_skill` exactly — the
  off-by-one comes from the second increment.
- The damage formula `2 + combat_power_bonus + (combat_skill / 3) +
  random(2)` matches `CombatResolver.cs:25`. Integer division on
  `combat_skill / 3` is correct (GDScript truncates toward zero for
  non-negative ints, matching C# `int` division).
- `state.next_random_int(2)` consumes one LCG value per attack,
  *additionally* to the percent roll. That matters for seed-driven
  tests: each `resolve_attack` call advances the RNG by 2 (miss) or 3
  (hit) state ticks.
- `state.player.health.take_damage(enemy_damage)` calls into the
  existing `PlayerStats.take_damage` from phase 1 — no new method.
  `state.player.is_alive()` reads `health.current_health > 0`, which
  flips at exactly the right moment for the
  `PlayerDied` resolution.
- `state.win_combat(...)` and `state.lose_combat(...)` are added in
  the `GameState` amend below. `state.record_combat_round(...)`
  assigns to `last_combat_round_outcome` without touching
  `active_combat`, so the player can swing again next tick.
- The function does *not* return early when the player misses — it
  falls through to the enemy roll. The `combat_skill_gained` stays
  at zero in that case (no `+1` on miss, `+1` on hit, `+2` on
  victory).

### `simulation/game_state.gd` (amend)

The phase-6 diff is a header-comment update plus three new fields and
four new methods. Nothing in the phase-5 furnace plumbing or the
phase-4 expedition plumbing is touched.

Update the header comment from

> Phase 4 adds expedition reward state (last_expedition_outcome,
> pending_expedition_outcome, expeditions_completed,
> complete_expedition). Phase 5 adds furnace bookkeeping
> (try_build_furnace, try_fuel_furnace,
> get_furnace_burn_seconds_remaining, has_active_furnace_at,
> active_furnace_count, advance_furnaces, get_furnace_heat_bonus —
> now a real Manhattan-distance lookup). Phase 6 adds the combat side
> (active_combat, last_combat_round_outcome, combat_encounters_won,
> begin_combat / win_combat / lose_combat).

to

> Phase 5 adds furnace bookkeeping (try_build_furnace,
> try_fuel_furnace, get_furnace_burn_seconds_remaining,
> has_active_furnace_at, active_furnace_count, advance_furnaces,
> get_furnace_heat_bonus). Phase 6 adds the combat side
> (active_combat, last_combat_round_outcome, combat_encounters_won,
> begin_combat / record_combat_round / win_combat / lose_combat).
> The pending_expedition_outcome field — phase-4 dormant — comes alive
> here: begin_combat stashes the expedition reward, win_combat applies
> it on victory, lose_combat drops it on defeat.

Add the three fields next to `expeditions_completed`:

```gdscript
# null or CombatEncounter — non-null while a fight is in progress.
var active_combat: Variant = null
# null or CombatRoundOutcome — populated each round; null until the
# first attack resolves. Cleared on begin_combat to avoid stale HUD.
var last_combat_round_outcome: Variant = null
var combat_encounters_won: int = 0
```

Notes:

- `Variant` for the two object-or-null fields matches the precedent
  set by `last_completed_action_kind`, `last_expedition_outcome`, and
  `pending_expedition_outcome`. The C# uses nullable reference types
  (`CombatEncounter?`, `CombatRoundOutcome?`); GDScript collapses
  that to `Variant`.
- The HUD reads `combat_encounters_won` directly — no lazy getter
  function needed because the field is a plain `int`.

Add the four methods next to `complete_expedition`:

```gdscript
func begin_combat(encounter: CombatEncounter, p_pending_expedition_outcome: Variant = null) -> void:
	assert(encounter != null, "encounter required")
	active_combat = encounter
	pending_expedition_outcome = p_pending_expedition_outcome
	last_combat_round_outcome = null
	last_expedition_outcome = null
	expedition_status = ExpeditionStatus.Kind.AWAY

func record_combat_round(outcome: CombatRoundOutcome) -> void:
	assert(outcome != null, "outcome required")
	last_combat_round_outcome = outcome

func win_combat(outcome: CombatRoundOutcome) -> void:
	record_combat_round(outcome)
	active_combat = null
	combat_encounters_won += 1
	if pending_expedition_outcome != null:
		complete_expedition(pending_expedition_outcome)
		return
	expedition_status = ExpeditionStatus.Kind.RETURNED

func lose_combat(outcome: CombatRoundOutcome) -> void:
	record_combat_round(outcome)
	active_combat = null
	pending_expedition_outcome = null
	last_expedition_outcome = null
	expedition_status = ExpeditionStatus.Kind.INTERRUPTED
```

Notes:

- `begin_combat` keeps `expedition_status = AWAY` because the player
  is still away on the expedition that triggered the fight. The C#
  port does the same (`GameState.cs:122`). The HUD `Last expedition`
  line therefore reads `--` while the fight is in progress — the
  `Combat` line takes over the user-facing status.
- `win_combat`'s order matters: `complete_expedition` mutates the
  inventory and flips `expedition_status` to `RETURNED`, so the
  fallback `expedition_status = RETURNED` line *only* fires when
  `pending_expedition_outcome == null`. The fallback handles the
  test-only case where `begin_combat` is called without a pending
  outcome (mirrors `Advance_WhenAttackActionCompletes_RecordsCombatRound`).
- `lose_combat` zeroes both `pending_expedition_outcome` *and*
  `last_expedition_outcome`. Phase-4's `cancel_action` already does
  the same trio (`last_expedition_outcome = null;
  pending_expedition_outcome = null; expedition_status = INTERRUPTED`)
  on an expedition cancel — the C# port deliberately reuses the
  "expedition was interrupted" semantics for combat death. Don't
  invent a new `LOST_TO_COMBAT` status; the existing `INTERRUPTED`
  is the right signal for the HUD.
- `record_combat_round` is its own method (not inlined) because
  `win_combat` and `lose_combat` both call it, and the test
  `_test_resolve_attack_combat_skill_gains_only_for_successful_hits_and_victory`
  drives the resolver in a loop and reads `last_combat_round_outcome`
  between calls — the resolver writes through `record_combat_round`
  on the ongoing branch, so this is the public contract.
- The `cancel_action` method is *unchanged* in phase 6. Cancelling an
  in-progress `Attack` action zeroes `active_action` but leaves
  `active_combat` set, which mirrors C# (`GameState.cs:62-72`
  doesn't touch `ActiveCombat`). The player therefore can't escape
  combat by hitting `C` — they have to keep swinging until one side
  drops. Calling out the (intentional) divergence so a phase-7 reader
  doesn't think we lost a branch.

### `simulation/game_action_rules.gd` (amend)

The header comment becomes:

> Phase 6 adds the active_combat short-circuit at the top of
> can_start_action: while combat is in progress, only ATTACK is
> valid — every other action kind (EXCAVATE / BUILD_WALL /
> BUILD_FURNACE / EXPEDITION / CRAFT) is rejected. The complete_action
> EXPEDITION branch dispatches HOSTILE_ANIMAL into state.begin_combat;
> the new ATTACK branch calls CombatResolver.resolve_attack.

`can_start_action` body:

```gdscript
static func can_start_action(state: GameState, action_kind: int, target_tile: Variant) -> bool:
	if not state.player.is_alive() or state.active_action != null:
		return false
	if state.active_combat != null:
		return action_kind == GameActionKind.Kind.ATTACK
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
		GameActionKind.Kind.ATTACK:
			return false
		_:
			return true
```

Notes:

- The `state.active_combat != null` short-circuit goes *between* the
  `is_alive / active_action` guard and the `match` block. That order
  matters: a dead player can't attack either, and a player with a
  half-finished `Attack` action can't start a second one. Reordering
  loses both invariants.
- The new explicit `ATTACK` branch (returning `false` outside combat)
  replaces the phase-1-style `_:` fall-through default-true behaviour
  for `ATTACK`. The C# port has the same explicit `Attack => false`
  on line 35; the existing `_:` still covers `CRAFT` (default-true).
- `EXPEDITION` validity is unchanged — the existing default-true
  `_:` branch covers it. An expedition started while
  `active_combat != null` is rejected by the new short-circuit; an
  expedition started while a furnace burns or the player is hungry
  remains valid (the survival cost is the player's problem, not the
  rules layer's).

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
			var outcome: ExpeditionOutcome = ExpeditionResolver.resolve(state)
			if outcome.encounter_kind == ExpeditionEncounterKind.Kind.NONE:
				state.complete_expedition(outcome)
			else:
				var enemy: EnemyDefinition = EnemyCatalog.get_for_encounter(outcome.encounter_kind)
				state.begin_combat(CombatEncounter.new(enemy), outcome)
		GameActionKind.Kind.ATTACK:
			CombatResolver.resolve_attack(state)
		_:
			pass
```

Notes:

- The `EXPEDITION` branch swap is the heart of the phase. The phase-5
  branch was `var outcome = ...; state.complete_expedition(outcome)`;
  the phase-6 branch `if outcome.encounter_kind == NONE:
  state.complete_expedition(outcome) else:
  state.begin_combat(CombatEncounter.new(enemy), outcome)`. The
  pending outcome (the loot the player would have received) is
  stashed on `state.pending_expedition_outcome` — `win_combat` cashes
  it out, `lose_combat` discards it.
- `ATTACK` is now a real branch, not an `_:` fall-through. The
  resolver does all the work, including state mutation; the rules
  layer just dispatches.
- The `_:` fall-through still covers `CRAFT`. Crafting via the
  `Craft` `GameActionKind` is unused — `CraftRecipeCommand` resolves
  inside `SimulationStep` without going through `active_action`.
  Don't fold it into `ATTACK`; the kinds remain semantically
  distinct.
- The duration / description tables (`_get_duration_seconds`,
  `_get_description`) are *unchanged*. `ATTACK` already had a 1.5 s
  duration and an "Attacking" description ported in phase 1.

### `simulation/simulation_step.gd` (amend)

`_apply_command` gains an `active_combat` guard on every deferred
command branch except `StartActionCommand` and `CancelActionCommand`:

```gdscript
func _apply_command(state: GameState, command: GameCommand) -> void:
	assert(command != null, "command required")
	if command is CancelActionCommand:
		state.cancel_action()
		return
	if not state.player.is_alive():
		return
	if command is ConsumeFoodCommand:
		if state.active_combat == null:
			SurvivalRules.try_consume_canned_food(state)
	elif command is CraftRecipeCommand:
		if state.active_action == null and state.active_combat == null:
			var craft_command: CraftRecipeCommand = command
			RecipeRules.try_craft(state, craft_command.recipe_id)
	elif command is FuelFurnaceCommand:
		if state.active_action == null and state.active_combat == null:
			var fuel_command: FuelFurnaceCommand = command
			state.try_fuel_furnace(fuel_command.target_tile, _FUEL_FURNACE_SECONDS)
	elif command is MovePlayerCommand:
		if state.active_action == null and state.active_combat == null:
			var move_command: MovePlayerCommand = command
			if state.world.is_walkable(move_command.target_tile):
				state.player.move_to(move_command.target_tile)
	elif command is StartActionCommand:
		var start_command: StartActionCommand = command
		var action: GameAction = GameActionRules.try_create_action(state, start_command)
		if action != null:
			state.try_start_action(action)
```

Notes:

- The `CancelActionCommand` branch is *not* gated on
  `active_combat == null`. A player should always be able to cancel
  their in-progress swing — that's the only "out" they have if
  they queued an `Attack` and want to wait for the next tick. The
  cancel zeroes `active_action`, leaves `active_combat` set, and
  the duel continues. Mirrors C# (`SimulationStep.cs:39-43` is also
  unguarded).
- `ConsumeFoodCommand` is gated on `active_combat == null` only,
  *not* `active_action == null`. Same as phase 5: mid-action eating
  is a deliberate design choice (you can chew while excavating but
  not while a Razor Maw is biting you). Mirrors C# line 52.
- `StartActionCommand` is unguarded; `GameActionRules.can_start_action`
  rejects every kind except `ATTACK` while `active_combat` is set.
  Adding an outer guard would be redundant and would make `ATTACK`
  itself fail to start during combat — the opposite of the goal.

The `advance` method is *unchanged* — `state.advance_furnaces` is
still called between the active-action tick and the survival update.
Furnaces don't pause during combat; the C# port runs them on the same
schedule.

### `simulation/game_state_factory.gd` (untouched)

Phase 5 already seeds 8 scrap, 3 fuel, 4 food. Combat doesn't change
the inventory shape. The factory deliberately doesn't call
`state.begin_combat(...)` — a fresh game starts out of combat.

### Untouched core files

`game_action.gd`, `game_action_kind.gd`, `game_command.gd`,
`cancel_action_command.gd`, `consume_food_command.gd`,
`craft_recipe_command.gd`, `fuel_furnace_command.gd`,
`move_player_command.gd`, `start_action_command.gd`,
`expedition_*.gd`, `recipe_*.gd`, `player_state.gd`,
`player_stats.gd`, `equipped_weapon.gd`, `clock_state.gd`,
`season.gd`, `inventory_state.gd`, `item_id.gd`, `world_grid.gd`,
`world_tile_type.gd`, `survival_rules.gd`, `game_balance.gd` — *no
changes in phase 6.*

`SurvivalRules.update` still drains nutrition, hygiene, and psyche
during combat. The C# port's `SurvivalRules` is also unchanged
between phases 5 and 6 — there's no "combat freezes survival" rule.
A long fight against a missy enemy continues to drain the player's
nutrition and (in winter) temperature, which is intended pressure.

`PlayerStats.take_damage` (phase 1) and `PlayerState.increase_combat_skill`
(phase 1) and `PlayerState.combat_power_bonus` (phase 1) are all
called by `CombatResolver` without modification.

## Client port

### `client/input_reader.gd` (amend)

Three changes — none to the field declarations, all in `_input` and
the click handlers.

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
		if session.state.active_combat != null:
			_pending.append(StartActionCommand.new(GameActionKind.Kind.ATTACK, null))
		else:
			_pending.append(StartActionCommand.new(GameActionKind.Kind.EXPEDITION, null))
	elif event.is_action_pressed("attack"):
		if session.state.active_combat != null:
			_pending.append(StartActionCommand.new(GameActionKind.Kind.ATTACK, null))

func _on_left_click() -> void:
	if not (hovered_tile is Vector2i):
		return
	if session.state.active_combat != null:
		return
	if hovered_tile == session.state.player.tile_position:
		_pending.append(ConsumeFoodCommand.new())
	else:
		_pending.append(MovePlayerCommand.new(hovered_tile))

func _on_right_click() -> void:
	if not (hovered_tile is Vector2i):
		return
	if session.state.active_combat != null:
		return
	if session.state.world.get_tile(hovered_tile) == WorldTileType.Kind.FURNACE:
		_pending.append(FuelFurnaceCommand.new(hovered_tile))
		return
	var kind: int = GameInteractionMode.to_action_kind(interaction_mode)
	_pending.append(StartActionCommand.new(kind, hovered_tile))
```

Notes:

- The `start_expedition` action key (`E`) handles *both* the
  out-of-combat "start expedition" and the in-combat "swing weapon"
  flows. Same physical bind — the meaning shifts when
  `active_combat != null`. Mirrors `GameInputReader.cs:68-71`.
- The `attack` action (Space) is in *addition* to `E`. Two binds,
  same command. The C# port wires both keys; we keep parity.
- The `_on_left_click` / `_on_right_click` early returns are at the
  input layer, *not* the simulation layer (which already has its
  own guards now via `_apply_command`). The double-guard means the
  `_pending` queue stays empty during combat and the test
  `_test_advance_when_combat_active_ignores_move_and_craft_commands`
  doesn't have to worry about how the input reader filters — it can
  just queue a `MovePlayerCommand` directly and verify the
  simulation drops it.
- `interaction_mode` remains responsive during combat (the player
  can still press `1`/`2`/`3` to change it) — that's harmless because
  `_on_right_click` is gated. The mode displays correctly in the HUD
  the moment combat ends.

### `client/world_renderer.gd` (amend)

Add a single new branch and constant:

```gdscript
const _COMBAT_TINT_COLOR: Color = Color(0.45, 0.10, 0.10, 0.20)
```

(Insert next to `_FURNACE_BURNING_OVERLAY_COLOR`.)

```gdscript
func _draw_combat_tint() -> void:
	if state.active_combat == null:
		return
	var bounds: Rect2 = Rect2(
		Vector2.ZERO,
		Vector2(state.world.width * layout.tile_size,
			state.world.height * layout.tile_size))
	draw_rect(bounds, _COMBAT_TINT_COLOR, true)
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
	_draw_combat_tint()
```

Notes:

- The tint goes *last* — it sits on top of the player marker, the
  hover overlay, the furnace overlays, and the action-target
  highlight. That mirrors `GameRenderer.cs:94-97`, which paints the
  combat tint after the world rect is filled but in the same
  spritebatch pass. The visual effect: the entire world dims and
  reddens, the HUD stays bright (different `Control` node, no tint).
- The bounds are computed from `state.world.width / height` and
  `layout.tile_size` rather than from the visible viewport. The
  Godot world renderer is a `Node2D` placed at origin, so this is
  equivalent. If phase 7 introduces camera scrolling (the C# client
  has it), the tint will need to read from the same camera-relative
  bounds the rest of the renderer uses. Phase 6 doesn't introduce
  scrolling; flag the assumption so a future reader doesn't think
  we forgot it.
- The C# `TileLayout` exposes `tile_size`; if the GDScript port
  doesn't, add a `tile_size` getter to `client/tile_layout.gd` (a
  one-line `func tile_size() -> float: return _tile_size`) and
  reuse it. Verify by reading `tile_layout.gd` before edit; the
  current file is 26 lines and already exposes the metric the
  renderer needs.

### `client/hud.gd` (amend)

Two new labels, one button retitle, no new signals.

Field declarations next to the existing `_heat_label`:

```gdscript
var _combat_label: Label
var _combat_won_label: Label
```

In `_ready`, after the existing `_heat_label = _make_label(box)` line:

```gdscript
_combat_label = _make_label(box)
_combat_won_label = _make_label(box)
```

In `refresh(state, interaction_mode)`, after the
`_heat_label.text = ...` line:

```gdscript
_combat_label.text = _combat_text(state)
_combat_won_label.text = "Combat won %d" % state.combat_encounters_won
```

Update the `_expedition_button` retitle in the same `refresh` body
(replace the existing `_expedition_button.disabled = ...` line):

```gdscript
if state.active_combat != null:
	_expedition_button.text = "Attack (E)"
	_expedition_button.disabled = not GameActionRules.can_start_action(state, GameActionKind.Kind.ATTACK, null)
else:
	_expedition_button.text = "Start Expedition (E)"
	_expedition_button.disabled = not _can_start_expedition(state)
```

New helper next to `_can_craft_weapon`:

```gdscript
static func _combat_text(state: GameState) -> String:
	if state.active_combat != null:
		var encounter: CombatEncounter = state.active_combat
		var prefix: String = "Combat %s %d/%d" % [
			encounter.enemy.name,
			encounter.current_health,
			encounter.max_health(),
		]
		if state.last_combat_round_outcome == null:
			return prefix
		return "%s — %s" % [prefix, _last_round_text(state.last_combat_round_outcome)]
	if state.last_combat_round_outcome != null:
		var outcome: CombatRoundOutcome = state.last_combat_round_outcome
		if outcome.player_died():
			return "Combat lost — defeated by %s" % outcome.enemy_name
		if outcome.enemy_defeated():
			return "Combat won — defeated %s" % outcome.enemy_name
	return "Combat --"

static func _last_round_text(outcome: CombatRoundOutcome) -> String:
	var hit_text: String = ("hit %d" % outcome.player_damage) if outcome.player_hit else "miss"
	var taken_text: String = ("took %d" % outcome.enemy_damage) if outcome.enemy_hit else "dodged"
	var skill_text: String = ""
	if outcome.combat_skill_gained > 0:
		skill_text = " (skill +%d)" % outcome.combat_skill_gained
	return "%s, %s%s" % [hit_text, taken_text, skill_text]
```

Notes:

- The button retitle is *text-only*; the C# port colour-codes the
  same button, but we leave that to phase 7 (see the deferred list
  above). The text swap is enough for the visual-check loop.
- `_combat_text` keeps the previous round's summary on the `Combat`
  line *after* the fight ends until the next combat starts. The C#
  port drops the line entirely; we keep it because the HUD has
  static label rows and removing the row would shift every label
  below it on every fight. Sticky text is the cheaper fix.
- The label is named `_combat_label`, not `_enemy_label`, because
  the same row carries pre-fight, mid-fight, and post-fight text.
  Naming it after the enemy would mislead readers when no enemy
  exists.

### `scripts/main.gd` (amend)

One change: the boot string. The signal connections are unchanged
because the existing `_on_start_expedition_requested` handler
delegates to the `InputReader.queue_command(...)` path, which routes
the command through the simulation step's `start_expedition` action
binding — the same runtime branch that picks `ATTACK` vs
`EXPEDITION` based on `state.active_combat`.

```gdscript
print("alien_godot: phase 6 boot ok — mode=%s clock=%.2fh day=%d season=%s player=%s" % [
	GameInteractionMode.display_name(_input_reader.interaction_mode),
	_session.state.clock.time_of_day_hours(),
	_session.state.clock.day_of_season,
	Season.Kind.keys()[_session.state.clock.season],
	_session.state.player.tile_position,
])
```

Notes:

- The HUD button click still emits `start_expedition_requested`, and
  `_on_start_expedition_requested` still queues
  `StartActionCommand(EXPEDITION, null)`. That command is rejected
  by `GameActionRules.can_start_action` when `active_combat != null`,
  so the in-combat `Attack (E)` button click does *not* go through
  the HUD signal — it'd be a no-op. The combat-active button click
  has to queue an `ATTACK` command, which the *input reader* handles
  for the `E` keybind. To make the *button* fire correctly during
  combat, update the HUD signal handler in `main.gd` to inspect
  `_session.state.active_combat`:

```gdscript
func _on_start_expedition_requested() -> void:
	if _session.state.active_combat != null:
		_input_reader.queue_command(StartActionCommand.new(GameActionKind.Kind.ATTACK, null))
	else:
		_input_reader.queue_command(StartActionCommand.new(GameActionKind.Kind.EXPEDITION, null))
```

The HUD doesn't know which command to send — it only knows the user
clicked the button. `main.gd` is the right adapter point because it
already owns the wiring between HUD signals and the input reader.
Mirrors `GameInputReader.cs:68-71`'s "decide based on `isInCombat`"
runtime branch.

### `project.godot` (amend)

Add one input action to `[input]`. Physical keycode 32 = Space:

```
attack={
"deadzone": 0.5,
"events": [Object(InputEventKey,"physical_keycode":32)]
}
```

Insert it between the existing `mode_build_furnace` entry and
`cancel_action` (alphabetic-by-purpose: mode keys, then `attack`,
then `cancel_action`, then `start_expedition`). No `[autoload]` /
`[display]` / `[rendering]` changes.

## Tests

All tests are `extends SceneTree` scripts under `tests/`, named
`test_*.gd`, and exit with `quit(0)` on success. The smoke test
(`tests/test_core_smoke.gd`) automatically picks up the seven new
core files; no manual registration.

### `tests/test_combat_resolver.gd` (new)

Direct port of all four `CombatResolverTests.cs` cases. The
`ResolveUntilCombatEnds` helper from C# becomes
`_resolve_until_combat_ends(state) -> int`.

```gdscript
extends SceneTree

const GameStateFactoryScript = preload("res://scripts/core/simulation/game_state_factory.gd")
const GameStateScript = preload("res://scripts/core/simulation/game_state.gd")
const ItemIdScript = preload("res://scripts/core/inventory/item_id.gd")
const ExpeditionStatusScript = preload("res://scripts/core/simulation/expedition_status.gd")
const ExpeditionEncounterKindScript = preload("res://scripts/core/simulation/expedition_encounter_kind.gd")
const ExpeditionOutcomeScript = preload("res://scripts/core/simulation/expedition_outcome.gd")
const EnemyDefinitionScript = preload("res://scripts/core/combat/enemy_definition.gd")
const EnemyKindScript = preload("res://scripts/core/combat/enemy_kind.gd")
const CombatEncounterScript = preload("res://scripts/core/combat/combat_encounter.gd")
const CombatResolverScript = preload("res://scripts/core/combat/combat_resolver.gd")
const EquippedWeaponScript = preload("res://scripts/core/gameplay/equipped_weapon.gd")

func _init() -> void:
	_test_resolve_attack_when_enemy_deals_lethal_damage_kills_player_and_drops_pending_loot()
	_test_resolve_attack_with_weapon_defeats_enemy_in_fewer_rounds_than_unarmed()
	_test_resolve_attack_combat_skill_gains_only_for_successful_hits_and_victory()
	_test_resolve_attack_when_combat_starts_from_expedition_holds_rewards_until_victory()
	print("test_combat_resolver: ok")
	quit(0)

func _test_resolve_attack_when_enemy_deals_lethal_damage_kills_player_and_drops_pending_loot() -> void:
	var state: GameState = GameStateFactoryScript.create_new(1)
	var starting_scrap: int = state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL)
	var starting_fuel: int = state.inventory.get_count(ItemIdScript.Id.FUEL)
	var starting_food: int = state.inventory.get_count(ItemIdScript.Id.CANNED_FOOD)

	state.player.health.take_damage(93)
	var enemy: EnemyDefinition = EnemyDefinitionScript.new(
		EnemyKindScript.Kind.RAZOR_MAW, "Test Hunter", 9, 7, 7, 100)
	state.begin_combat(
		CombatEncounterScript.new(enemy),
		ExpeditionOutcomeScript.new(3, 1, 2, ExpeditionEncounterKindScript.Kind.HOSTILE_ANIMAL))

	var outcome: CombatRoundOutcome = CombatResolverScript.resolve_attack(state)

	assert(outcome.player_died(), "expected player_died true")
	assert(not state.player.is_alive(), "expected player dead")
	assert(state.active_combat == null, "expected active_combat cleared on death")
	assert(state.expedition_status == ExpeditionStatusScript.Kind.INTERRUPTED,
		"expected INTERRUPTED, got %d" % state.expedition_status)
	assert(state.last_expedition_outcome == null,
		"expected last_expedition_outcome cleared")
	assert(state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL) == starting_scrap,
		"expected scrap unchanged on combat loss")
	assert(state.inventory.get_count(ItemIdScript.Id.FUEL) == starting_fuel,
		"expected fuel unchanged")
	assert(state.inventory.get_count(ItemIdScript.Id.CANNED_FOOD) == starting_food,
		"expected food unchanged")

func _test_resolve_attack_with_weapon_defeats_enemy_in_fewer_rounds_than_unarmed() -> void:
	var armed_state: GameState = GameStateFactoryScript.create_new(5)
	var unarmed_state: GameState = GameStateFactoryScript.create_new(5)
	var enemy: EnemyDefinition = EnemyDefinitionScript.new(
		EnemyKindScript.Kind.RAZOR_MAW, "Sparring Beast", 8, 0, 0, 0)

	armed_state.player.equip_weapon(EquippedWeaponScript.Slot.SIMPLE_WEAPON)
	armed_state.begin_combat(CombatEncounterScript.new(enemy))
	unarmed_state.begin_combat(CombatEncounterScript.new(enemy))

	var armed_rounds: int = _resolve_until_combat_ends(armed_state)
	var unarmed_rounds: int = _resolve_until_combat_ends(unarmed_state)

	assert(armed_rounds < unarmed_rounds,
		"expected armed (%d) < unarmed (%d)" % [armed_rounds, unarmed_rounds])

func _test_resolve_attack_combat_skill_gains_only_for_successful_hits_and_victory() -> void:
	var state: GameState = GameStateFactoryScript.create_new(5)
	var enemy: EnemyDefinition = EnemyDefinitionScript.new(
		EnemyKindScript.Kind.RAZOR_MAW, "Practice Beast", 7, 0, 0, 0)
	state.begin_combat(CombatEncounterScript.new(enemy))

	var successful_hits: int = 0
	var final_outcome: CombatRoundOutcome = null

	while state.active_combat != null:
		final_outcome = CombatResolverScript.resolve_attack(state)
		if final_outcome.player_hit:
			successful_hits += 1

	assert(final_outcome != null, "expected at least one round resolved")
	assert(final_outcome.enemy_defeated(), "expected enemy_defeated on the final round")
	assert(state.player.combat_skill == successful_hits + 1,
		"expected combat_skill == hits+1; got skill=%d, hits=%d" %
			[state.player.combat_skill, successful_hits])

func _test_resolve_attack_when_combat_starts_from_expedition_holds_rewards_until_victory() -> void:
	var state: GameState = GameStateFactoryScript.create_new(5)
	var starting_scrap: int = state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL)
	var starting_fuel: int = state.inventory.get_count(ItemIdScript.Id.FUEL)
	var starting_food: int = state.inventory.get_count(ItemIdScript.Id.CANNED_FOOD)
	var pending: ExpeditionOutcome = ExpeditionOutcomeScript.new(
		2, 1, 1, ExpeditionEncounterKindScript.Kind.HOSTILE_ANIMAL)
	var enemy: EnemyDefinition = EnemyDefinitionScript.new(
		EnemyKindScript.Kind.RAZOR_MAW, "Cave Stalker", 8, 0, 0, 0)
	state.begin_combat(CombatEncounterScript.new(enemy), pending)

	var first: CombatRoundOutcome = CombatResolverScript.resolve_attack(state)

	assert(state.active_combat != null, "expected combat ongoing after first swing")
	assert(state.expedition_status == ExpeditionStatusScript.Kind.AWAY,
		"expected AWAY mid-fight, got %d" % state.expedition_status)
	assert(state.last_expedition_outcome == null,
		"expected last_expedition_outcome held until victory")
	assert(state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL) == starting_scrap,
		"expected scrap unchanged mid-fight")
	assert(state.inventory.get_count(ItemIdScript.Id.FUEL) == starting_fuel,
		"expected fuel unchanged mid-fight")
	assert(state.inventory.get_count(ItemIdScript.Id.CANNED_FOOD) == starting_food,
		"expected food unchanged mid-fight")
	assert(not first.enemy_defeated(), "first swing on 8-HP beast shouldn't defeat it")

	var final_outcome: CombatRoundOutcome = first
	while state.active_combat != null:
		final_outcome = CombatResolverScript.resolve_attack(state)

	assert(final_outcome.enemy_defeated(), "expected enemy_defeated by loop end")
	assert(state.expedition_status == ExpeditionStatusScript.Kind.RETURNED,
		"expected RETURNED after victory, got %d" % state.expedition_status)
	assert(state.last_expedition_outcome != null,
		"expected last_expedition_outcome populated on victory")
	assert(state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL) == starting_scrap + pending.scrap_metal,
		"expected scrap +%d, got %d" %
			[pending.scrap_metal, state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL)])
	assert(state.inventory.get_count(ItemIdScript.Id.FUEL) == starting_fuel + pending.fuel,
		"expected fuel +%d" % pending.fuel)
	assert(state.inventory.get_count(ItemIdScript.Id.CANNED_FOOD) == starting_food + pending.canned_food,
		"expected food +%d" % pending.canned_food)

func _resolve_until_combat_ends(state: GameState) -> int:
	for round in range(1, 21):
		CombatResolverScript.resolve_attack(state)
		if state.active_combat == null:
			return round
	assert(false, "combat did not resolve within 20 rounds")
	return -1
```

Notes:

- Direct port of `CombatResolverTests.cs:9-110`. Each Godot test
  function name is the C# method name lowercased with underscore
  separators. Asserts mirror the C# `Assert.X` calls one-for-one.
- The "weapon defeats enemy in fewer rounds" test uses
  `min_dmg = max_dmg = 0` and `hit_chance = 0` on the enemy so the
  fight is determined entirely by the player's hit chance (the
  enemy's only role is providing 8 HP to chew through). With seed 5
  and the same RNG, the armed run should finish in fewer rounds —
  the assertion is a strict inequality, not a fixed delta.
- The "combat skill gains" test uses `enemy.hit_chance_percent = 0`
  to make the loop deterministic about damage. The exact round count
  varies with the player's hit-chance sequence (clamped to `[25, 95]`),
  but `successful_hits + 1 == combat_skill` must hold every run.
- The 20-round cap on `_resolve_until_combat_ends` matches the C#
  `for round in 1..20` cap. Hitting it indicates a bug in the
  resolver (or the player's hit chance was clamped to 25% and got
  unlucky 20 times in a row — at p=0.75 of a miss, that's `0.75^20
  ≈ 0.32%`, well within test-flake territory if the RNG were random).
  With a fixed LCG seed, it's deterministic; if the assert fires,
  bisect the resolver, don't bump the cap.

### `tests/test_combat_encounter.gd` (new)

Small isolated test for `CombatEncounter` lifecycle. Doesn't drive
the resolver — exercises the constructor, `take_damage`,
`is_defeated` directly.

```gdscript
extends SceneTree

const EnemyDefinitionScript = preload("res://scripts/core/combat/enemy_definition.gd")
const EnemyKindScript = preload("res://scripts/core/combat/enemy_kind.gd")
const CombatEncounterScript = preload("res://scripts/core/combat/combat_encounter.gd")

func _init() -> void:
	_test_default_current_health_uses_enemy_max_health()
	_test_explicit_current_health_is_honoured()
	_test_take_damage_clamps_to_zero_and_marks_defeated()
	print("test_combat_encounter: ok")
	quit(0)

func _test_default_current_health_uses_enemy_max_health() -> void:
	var enemy: EnemyDefinition = EnemyDefinitionScript.new(
		EnemyKindScript.Kind.RAZOR_MAW, "Default", 7, 1, 2, 50)
	var encounter: CombatEncounter = CombatEncounterScript.new(enemy)
	assert(encounter.current_health == 7, "expected current_health == max_health 7, got %d" % encounter.current_health)
	assert(encounter.max_health() == 7, "expected max_health() == 7")
	assert(not encounter.is_defeated(), "fresh encounter should not be defeated")

func _test_explicit_current_health_is_honoured() -> void:
	var enemy: EnemyDefinition = EnemyDefinitionScript.new(
		EnemyKindScript.Kind.RAZOR_MAW, "Wounded", 10, 0, 0, 0)
	var encounter: CombatEncounter = CombatEncounterScript.new(enemy, 3)
	assert(encounter.current_health == 3, "expected explicit current_health 3, got %d" % encounter.current_health)
	assert(encounter.max_health() == 10, "expected max_health() unchanged")

func _test_take_damage_clamps_to_zero_and_marks_defeated() -> void:
	var enemy: EnemyDefinition = EnemyDefinitionScript.new(
		EnemyKindScript.Kind.RAZOR_MAW, "Glass", 5, 0, 0, 0)
	var encounter: CombatEncounter = CombatEncounterScript.new(enemy)
	encounter.take_damage(3)
	assert(encounter.current_health == 2, "expected 2 HP after 3 damage, got %d" % encounter.current_health)
	assert(not encounter.is_defeated(), "still alive at 2 HP")
	encounter.take_damage(99)
	assert(encounter.current_health == 0, "expected 0 HP after overkill, got %d" % encounter.current_health)
	assert(encounter.is_defeated(), "expected defeated at 0 HP")
```

Notes:

- This is a unit test for the encounter wrapper, separate from the
  resolver. Catches regressions in the constructor's
  `current_health` defaulting / clamping that would otherwise be
  invisible in `test_combat_resolver` (which always uses defaults).

### `tests/test_enemy_catalog.gd` (new)

Locks in the Razor Maw tunables so a future edit to
`enemy_catalog.gd` shows up as a test failure rather than a silent
balance drift.

```gdscript
extends SceneTree

const EnemyCatalogScript = preload("res://scripts/core/combat/enemy_catalog.gd")
const EnemyKindScript = preload("res://scripts/core/combat/enemy_kind.gd")
const ExpeditionEncounterKindScript = preload("res://scripts/core/simulation/expedition_encounter_kind.gd")

func _init() -> void:
	_test_get_hostile_animal_returns_razor_maw_with_canonical_tunables()
	_test_get_for_encounter_routes_hostile_animal_to_razor_maw()
	print("test_enemy_catalog: ok")
	quit(0)

func _test_get_hostile_animal_returns_razor_maw_with_canonical_tunables() -> void:
	var enemy: EnemyDefinition = EnemyCatalogScript.get_hostile_animal()
	assert(enemy.kind == EnemyKindScript.Kind.RAZOR_MAW, "expected RAZOR_MAW")
	assert(enemy.name == "Razor Maw", "expected name 'Razor Maw', got %s" % enemy.name)
	assert(enemy.max_health == 7, "expected max_health 7, got %d" % enemy.max_health)
	assert(enemy.minimum_damage == 14, "expected minimum_damage 14")
	assert(enemy.maximum_damage == 20, "expected maximum_damage 20")
	assert(enemy.hit_chance_percent == 62, "expected hit_chance_percent 62")
	# Cached: a second call returns the same instance.
	assert(EnemyCatalogScript.get_hostile_animal() == enemy,
		"expected catalog to cache the EnemyDefinition")

func _test_get_for_encounter_routes_hostile_animal_to_razor_maw() -> void:
	var enemy: EnemyDefinition = EnemyCatalogScript.get_for_encounter(
		ExpeditionEncounterKindScript.Kind.HOSTILE_ANIMAL)
	assert(enemy != null, "expected an enemy for HOSTILE_ANIMAL")
	assert(enemy.kind == EnemyKindScript.Kind.RAZOR_MAW, "expected RAZOR_MAW")
```

Notes:

- The cache assertion is "the same instance". GDScript's `==` on
  `RefCounted` compares references, so this works. If a future
  refactor swaps the lazy `static var` for a fresh allocation per
  call, the test catches it — and the call site
  (`GameActionRules.complete_action` → `EnemyCatalog.get_for_encounter` →
  `CombatEncounter.new(enemy)`) keeps the catalog allocation cost
  constant.
- The `NONE` case is *not* tested here. The catalog asserts on
  unknown kinds, and GDScript asserts can't be caught — testing the
  assert path would fail the test. The behavioural contract
  ("HOSTILE_ANIMAL routes to Razor Maw") is what matters; the
  failure mode for unknown encounter kinds is covered by the assert
  message itself.

### `tests/test_simulation_step.gd` (amend)

Four new cases. The existing 14 cases (phase 1 / 2 / 3 / 4 / 5) stay
unchanged. The new cases use `state.begin_combat(...)` directly to
set up the encounter — that decouples the combat tests from the
expedition LCG seeds and makes them robust against unrelated balance
tuning.

Add to the `_init` list (in order):

```gdscript
_test_advance_when_attack_action_records_combat_round()
_test_advance_when_attack_defeats_enemy_applies_pending_expedition_reward()
_test_advance_when_combat_active_ignores_move_and_craft_commands()
_test_advance_when_expedition_resolves_to_hostile_animal_begins_combat()
```

Add the imports next to the existing `EquippedWeaponScript`:

```gdscript
const EnemyCatalogScript = preload("res://scripts/core/combat/enemy_catalog.gd")
const EnemyDefinitionScript = preload("res://scripts/core/combat/enemy_definition.gd")
const EnemyKindScript = preload("res://scripts/core/combat/enemy_kind.gd")
const CombatEncounterScript = preload("res://scripts/core/combat/combat_encounter.gd")
const ExpeditionOutcomeScript = preload("res://scripts/core/simulation/expedition_outcome.gd")
const ExpeditionEncounterKindScript = preload("res://scripts/core/simulation/expedition_encounter_kind.gd")
```

The four new bodies:

```gdscript
func _test_advance_when_attack_action_records_combat_round() -> void:
	var state: GameState = GameStateFactoryScript.create_new(5)
	var step: SimulationStep = SimulationStepScript.new()
	# Defang the enemy so a single round can't end the fight: 0 damage,
	# 0 hit-chance, 9 HP — the player will hit but won't deal lethal damage
	# in 1.5s of combat (one ATTACK action).
	var enemy: EnemyDefinition = EnemyDefinitionScript.new(
		EnemyKindScript.Kind.RAZOR_MAW, "Test Beast", 9, 0, 0, 0)
	state.begin_combat(CombatEncounterScript.new(enemy))

	step.advance(state, 1.5, [StartActionCommandScript.new(GameActionKindScript.Kind.ATTACK)])

	assert(state.active_action == null, "expected ATTACK action cleared after 1.5s")
	assert(state.last_combat_round_outcome != null, "expected a combat round recorded")
	assert(state.active_combat != null, "9-HP beast should not die in one round")

func _test_advance_when_attack_defeats_enemy_applies_pending_expedition_reward() -> void:
	var state: GameState = GameStateFactoryScript.create_new(5)
	var step: SimulationStep = SimulationStepScript.new()
	var starting_scrap: int = state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL)
	var pending: ExpeditionOutcome = ExpeditionOutcomeScript.new(
		3, 1, 1, ExpeditionEncounterKindScript.Kind.HOSTILE_ANIMAL)
	# 1-HP enemy guarantees defeat on the first hit.
	var enemy: EnemyDefinition = EnemyDefinitionScript.new(
		EnemyKindScript.Kind.RAZOR_MAW, "Glass", 1, 0, 0, 0)
	state.begin_combat(CombatEncounterScript.new(enemy), pending)

	# Loop attacks until victory — depending on the RNG, the first ATTACK
	# may miss; cap at 5 swings to keep the test bounded.
	for _i in range(5):
		if state.active_combat == null:
			break
		step.advance(state, 1.5, [StartActionCommandScript.new(GameActionKindScript.Kind.ATTACK)])
	assert(state.active_combat == null, "expected enemy defeated within 5 swings")
	assert(state.combat_encounters_won == 1, "expected combat_encounters_won == 1")
	assert(state.expedition_status == ExpeditionStatusScript.Kind.RETURNED,
		"expected RETURNED after victory, got %d" % state.expedition_status)
	assert(state.last_expedition_outcome != null, "expected loot applied on victory")
	assert(state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL) == starting_scrap + pending.scrap_metal,
		"expected scrap +%d on victory" % pending.scrap_metal)

func _test_advance_when_combat_active_ignores_move_and_craft_commands() -> void:
	var state: GameState = GameStateFactoryScript.create_new(5)
	var step: SimulationStep = SimulationStepScript.new()
	var starting_position: Vector2i = state.player.tile_position
	var starting_scrap: int = state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL)
	var enemy: EnemyDefinition = EnemyDefinitionScript.new(
		EnemyKindScript.Kind.RAZOR_MAW, "Anchor", 9, 0, 0, 0)
	state.begin_combat(CombatEncounterScript.new(enemy))

	var destination: Vector2i = Vector2i(starting_position.x + 2, starting_position.y)
	assert(state.world.is_walkable(destination), "test setup: destination must be walkable")
	step.advance(state, 0.0, [
		MovePlayerCommandScript.new(destination),
		CraftRecipeCommandScript.new(RecipeIdScript.Id.SIMPLE_WEAPON),
	])

	assert(state.player.tile_position == starting_position,
		"expected move ignored mid-combat, got pos=%s" % state.player.tile_position)
	assert(state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL) == starting_scrap,
		"expected craft ignored mid-combat, scrap drained to %d" %
			state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL))
	assert(state.player.equipped_weapon == EquippedWeaponScript.Slot.NONE,
		"expected weapon slot still NONE")

func _test_advance_when_expedition_resolves_to_hostile_animal_begins_combat() -> void:
	# Iterate a small range of seeds to find one whose ExpeditionResolver
	# rolls HOSTILE_ANIMAL on the first run. The LCG is deterministic, so
	# the chosen seed is stable across runs — but we don't hard-code the
	# value because a balance tweak (e.g. encounter_chance from 35 → 30)
	# would shift it.
	var state: GameState = null
	for seed in range(1, 64):
		var candidate: GameState = GameStateFactoryScript.create_new(seed)
		var step: SimulationStep = SimulationStepScript.new()
		step.advance(candidate, 5.0, [StartActionCommandScript.new(GameActionKindScript.Kind.EXPEDITION)])
		if candidate.active_combat != null:
			state = candidate
			break
	assert(state != null, "expected at least one seed in [1, 64) to roll HOSTILE_ANIMAL")
	assert(state.expedition_status == ExpeditionStatusScript.Kind.AWAY,
		"expected AWAY mid-fight, got %d" % state.expedition_status)
	assert(state.last_expedition_outcome == null,
		"expected last_expedition_outcome held until victory or defeat")
	assert(state.pending_expedition_outcome != null,
		"expected pending_expedition_outcome set when combat begins")
	assert(state.active_combat.enemy.kind == EnemyKindScript.Kind.RAZOR_MAW,
		"expected RAZOR_MAW enemy")
```

Notes:

- The seed-loop in
  `_test_advance_when_expedition_resolves_to_hostile_animal_begins_combat`
  is robust to LCG drift between platforms and to encounter-chance
  rebalancing. The C# port hard-codes seed 3 (`SimulationStepTests.cs:165`);
  we deliberately *don't* mirror that, because the test ports
  in this project have a stated rule of "rewritten from observed
  behavior in GDScript, not transcribed one-for-one". A 64-seed
  search at a 35% encounter rate has a `1 - (1-0.35)^64 ≈ 1 - 6e-12`
  chance of finding at least one combat seed — comfortably
  guaranteed.
- The assertion on `pending_expedition_outcome != null` is what
  makes this test load-bearing for the `begin_combat` contract: the
  reward must be *held*, not applied or lost.
- The "1 HP enemy" trick in
  `_test_advance_when_attack_defeats_enemy_applies_pending_expedition_reward`
  guarantees a single-hit victory, but the player still has to
  *land* the hit. With the player's base 55% hit chance and seed 5,
  the loop should resolve in 1–2 swings; the cap of 5 is a generous
  bound.
- The new tests require the resolver to leave `last_combat_round_outcome`
  populated even after `win_combat` clears `active_combat`. Verify
  by reading the resolver's victory branch — `state.win_combat(victory)`
  goes through `record_combat_round` first, which sets the field
  before the encounter is cleared.

### `tests/test_game_action_rules.gd` (amend)

Two new cases. Existing four are unchanged.

Add to the `_init` list:

```gdscript
_test_can_start_attack_only_during_active_combat()
_test_can_start_excavate_or_build_returns_false_during_combat()
```

Add the imports next to the existing `WorldTileTypeScript`:

```gdscript
const EnemyDefinitionScript = preload("res://scripts/core/combat/enemy_definition.gd")
const EnemyKindScript = preload("res://scripts/core/combat/enemy_kind.gd")
const CombatEncounterScript = preload("res://scripts/core/combat/combat_encounter.gd")
```

The two new bodies:

```gdscript
func _test_can_start_attack_only_during_active_combat() -> void:
	var state: GameState = GameStateFactoryScript.create_new()
	assert(not GameActionRulesScript.can_start_action(state, GameActionKindScript.Kind.ATTACK, null),
		"ATTACK should be invalid outside combat")
	var enemy: EnemyDefinition = EnemyDefinitionScript.new(
		EnemyKindScript.Kind.RAZOR_MAW, "Test", 5, 0, 0, 0)
	state.begin_combat(CombatEncounterScript.new(enemy))
	assert(GameActionRulesScript.can_start_action(state, GameActionKindScript.Kind.ATTACK, null),
		"ATTACK should be valid during combat")

func _test_can_start_excavate_or_build_returns_false_during_combat() -> void:
	var state: GameState = GameStateFactoryScript.create_new()
	var soil_tile: Vector2i = Vector2i(state.player.tile_position.x, state.world.surface_row)
	# Without combat, EXCAVATE on SOIL is valid (sanity check).
	assert(GameActionRulesScript.can_start_action(state, GameActionKindScript.Kind.EXCAVATE, soil_tile),
		"EXCAVATE on SOIL should be valid out of combat")

	var enemy: EnemyDefinition = EnemyDefinitionScript.new(
		EnemyKindScript.Kind.RAZOR_MAW, "Test", 5, 0, 0, 0)
	state.begin_combat(CombatEncounterScript.new(enemy))

	assert(not GameActionRulesScript.can_start_action(state, GameActionKindScript.Kind.EXCAVATE, soil_tile),
		"EXCAVATE should be invalid during combat")
	# Set up a valid BUILD_WALL target so we know combat is the only blocker.
	var air_tile: Vector2i = Vector2i(state.player.tile_position.x - 1, state.player.tile_position.y)
	assert(state.world.get_tile(air_tile) == WorldTileTypeScript.Kind.AIR, "expected AIR sanity")
	assert(not GameActionRulesScript.can_start_action(state, GameActionKindScript.Kind.BUILD_WALL, air_tile),
		"BUILD_WALL should be invalid during combat")
	# BUILD_FURNACE on excavated floor.
	state.world.set_tile(soil_tile, WorldTileTypeScript.Kind.EXCAVATED_FLOOR)
	assert(not GameActionRulesScript.can_start_action(state, GameActionKindScript.Kind.BUILD_FURNACE, soil_tile),
		"BUILD_FURNACE should be invalid during combat")
	assert(not GameActionRulesScript.can_start_action(state, GameActionKindScript.Kind.EXPEDITION, null),
		"EXPEDITION should be invalid during combat")
```

Notes:

- `_test_can_start_attack_only_during_active_combat` covers both
  sides of the short-circuit. The C# port has no equivalent unit
  test (it's covered indirectly through the
  `Advance_WhenAttackActionCompletes_RecordsCombatRound` integration
  test); we call it out explicitly because the rules layer is the
  cleanest place to assert the contract.
- `_test_can_start_excavate_or_build_returns_false_during_combat`
  is the inverse: it exercises every non-`ATTACK` kind to confirm
  the short-circuit doesn't accidentally let one through. Don't
  collapse into a `for kind in [...]` loop — explicit assertions
  are easier to debug than loop-failure messages.

### `tests/test_game_state_factory.gd` (amend, optional)

If the existing test doesn't already assert combat fields default to
their zero values, add one. The factory creates a state outside of
combat; `state.active_combat == null`,
`state.last_combat_round_outcome == null`,
`state.combat_encounters_won == 0`. If the file already has a
"defaults sanity" case, fold the three asserts into it; otherwise add
a new `_test_create_new_starts_outside_combat()`. The smoke test
catches structural regressions, but the factory contract deserves a
dedicated assertion since the HUD relies on it (an uninitialised
`active_combat` would throw a null-deref in `_combat_text`).

```gdscript
func _test_create_new_starts_outside_combat() -> void:
	var state: GameState = GameStateFactoryScript.create_new()
	assert(state.active_combat == null, "expected fresh state with no active combat")
	assert(state.last_combat_round_outcome == null, "expected no prior combat round")
	assert(state.combat_encounters_won == 0, "expected 0 victories on a fresh state")
```

Add to the `_init` list and the rest of the file lands as-is.

### Untouched test files

`test_clock_state.gd`, `test_inventory_state.gd`, `test_world_grid.gd`,
`test_world_tile_type.gd`, `test_furnace_state.gd`,
`test_recipe_rules.gd`, `test_survival_rules.gd`,
`test_expedition_resolver.gd`, `test_core_smoke.gd` — *no changes
in phase 6.* The smoke test picks up the seven new core files
automatically by walking `scripts/core/`.

## Repro recipe (visual check)

To verify the loop end-to-end in `./run.sh`:

1. Edit `scripts/main.gd`'s `GameSession.new(...)` call — temporarily
   pass seed 3 so the first expedition deterministically rolls
   `HOSTILE_ANIMAL`. (Don't commit the change; revert before
   finishing.)
2. Run `./run.sh`. Press `E` to start the expedition.
3. After ~5 s the world tints red, the HUD `Combat` line reads
   `Combat Razor Maw 7/7`, and the `Start Expedition` button
   retitles to `Attack (E)`.
4. Press `E` (or click the button, or press Space). After ~1.5 s
   the swing resolves and the HUD updates with the round summary.
5. Continue swinging. Either the enemy dies (loot applies, `Combat
   won` ticks to `1`) or the player dies (HUD goes red, all
   bars freeze).
6. Revert the seed override.

If step 3 doesn't trigger combat with seed 3, scan seeds `1..16` until
one rolls `HOSTILE_ANIMAL` on the first expedition — the LCG drift
between the C# `uint` arithmetic and the GDScript `int & 0xFFFFFFFF`
mask should be zero (both are mod 2^32), but a one-tick offset from
e.g. a different field-init order would shift the first roll by one.
Document the chosen seed in a `// TODO(phase 6): repro seed = N`
comment in `main.gd` while validating, then strip it before the
phase-6 commit lands.

## Risks / open questions

- **LCG parity between C# and GDScript.** Both use the Numerical
  Recipes constants `1664525u` / `1013904223u` and a 32-bit modulus.
  `GameState._init` collapses seed 0 → 1 in both ports
  (`GameState.cs:20`, `game_state.gd:51`). The
  `next_random_int(N)` uses `state mod N` in both. Any divergence
  would manifest as an `_test_advance_when_expedition_resolves_to_hostile_animal_begins_combat`
  failure if the seed search runs out — the seed-loop guard is
  the regression alarm.
- **`PlayerStats.take_damage` overflow.** The phase-1 implementation
  clamps `current_health` to `[0, max_health]`. A `99`-damage hit
  on an already-wounded player works correctly. Lethal-damage tests
  in `test_combat_resolver.gd` assume this clamp; verify by re-reading
  `scripts/core/gameplay/player_stats.gd` before the resolver
  test lands.
- **`pending_expedition_outcome` flag rot.** The field has been
  declared since phase 4 but nothing wrote to it before phase 6. If
  any earlier code path zeroes it incorrectly (e.g. a phase-5 helper
  that resets state on craft), the `holds_rewards_until_victory`
  test will catch it. Re-grep `pending_expedition_outcome` after
  the phase-6 edit; only `cancel_action`, `complete_expedition`,
  `begin_combat`, `win_combat`, and `lose_combat` should touch it.
- **HUD label-row count growth.** Phase 6 adds two more `_make_label`
  rows (`_combat_label`, `_combat_won_label`). With the phase-5
  additions, the HUD now has 13 label rows + 2 buttons in a single
  `VBoxContainer`. At a `font_size: 14` and `separation: 4`, that's
  roughly 13×18 + 2×24 + 4×14 = 290 px — well within the 720 px
  viewport. If the HUD ever needs to scroll, it's a phase-7 polish
  job.
- **Combat tint vs camera scrolling.** The renderer's `_draw_combat_tint`
  uses world-grid bounds. If a future phase introduces camera scrolling
  (none does yet, but the C# client has it), the tint will need to
  be repositioned to track the visible viewport rather than the full
  world. Phase 6 doesn't introduce scrolling; flagging the assumption
  here so a future reader doesn't trip on it.
- **Static-cache pollution across tests.** `EnemyCatalog._razor_maw`
  is a `static var` cached on first access. Each `godot --headless
  --script test_*.gd` invocation gets a fresh process, so caches
  reset between tests; `run-tests.sh` runs each test in its own
  process. If we ever switch to an in-process test runner, the
  `static var` would leak between cases — flag the assumption so
  a future migrator knows to reset the catalog.

## Phase 6 → phase 7 hand-off

After phase 6 lands:

- `state.active_combat` is the exclusive single-enemy fight slot.
  Multi-enemy fights need a list, which is a phase-7 design call
  if it surfaces.
- `state.combat_encounters_won` is a running tally. Phase 7 may
  promote it to a HUD progression bar or a season-end summary.
- `EnemyCatalog._razor_maw` is the only enemy. Phase 7 winter
  pressure may add a "Frost Maw" with higher HP and a winter-only
  encounter check; the catalog shape (one `static var` per
  definition) extends naturally to a `Dictionary`.
- The combat-active guards in `_apply_command` mirror the C# port.
  Phase 7's "winter pressure" will likely add seasonal modifiers to
  `SurvivalRules.update`, but those modifiers run *during* combat
  (the C# port doesn't pause survival in combat either), so no
  guard refactor is needed.
- The HUD `Combat` line shows the previous round's summary post-fight
  until the next combat starts. Phase 7 may swap the line out for
  an animated banner or fold it into a "last event" overlay; for now,
  sticky text is the cheap win.
- The `attack` input action (Space) is a third combat bind in addition
  to the `E` retitle and the HUD button. Phase 7's "polish" pass may
  consolidate, but for now redundancy is the friendly default.
- The C# port has a `HudOverlayScreen.Combat` value reserved but
  unused (the combat HUD is inline, not popup). Phase 6 doesn't add
  an enum equivalent to the GDScript HUD; if a phase-7 popup overlay
  is added, mirror the enum at that point.
