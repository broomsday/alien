# Phase 7 — Winter Pressure + Balancing

This is the detailed implementation plan for phase 7 of
`high_level_plan.md`.

Phase 6 left a phase-7-shaped hole in three places:

- `scripts/core/simulation/game_balance.gd` still only defines one
  number (`CLOCK_SECONDS_PER_REAL_SECOND = 144.0`), which means a full
  in-game day lasts 10 real minutes and winter from the default summer
  start arrives after roughly 10 real hours. That is far beyond a
  normal MVP play session.
- `scripts/core/simulation/survival_rules.gd` already has a first-pass
  winter model, but its numbers are still phase-3 / phase-5 gentle:
  winter is colder than summer, yet the code is not explicitly tuned
  around the phase-7 goal of “prepare or die” and its thresholds are
  hard-coded inside the rules layer rather than gathered in one balance
  surface.
- The client exposes temperature only as plain text in `hud.gd`, and
  the world view only has the phase-6 combat tint in
  `world_renderer.gd`. The MonoGame source project already ships
  stronger winter readability via season warnings, dynamic temperature
  coloring, and a cold-season / critical-cold overlay. The Godot port
  has not picked those up yet.

Phase 7 closes all three holes by expanding `GameBalance`,
retuning `SurvivalRules`, and adding winter/cold feedback to the HUD
and world renderer. The end product is a slice in which winter can
arrive during a single play session, idling on the winter surface is
meaningfully dangerous, excavated shelter remains viable, an active
furnace materially improves survival margins, and the player can read
“prepare now / seek shelter now” from the UI without guessing.

The phase ends when:

- `./run-tests.sh` passes a suite that now includes a stronger
  winter-focused `tests/test_survival_rules.gd`:
  - port the MonoGame `Advance_ActiveFurnaceRaisesNearbyAmbientTemperature`
    case,
  - port the MonoGame
    `Advance_UndergroundShelterAndFurnaceMateriallyReduceWinterExposureRisk`
    case,
  - keep the current “winter harsher than summer” and “excavated winter
    shelter keeps player alive” cases,
  - add one new Godot-specific case asserting winter expeditions cool
    the player faster than idling on the winter surface.
  `tests/test_clock_state.gd` is updated so the configured scale
  advances one full in-game day in 2 real minutes instead of 10.
  If phase-7 tuning changes starting inventory or recipe costs,
  `tests/test_game_state_factory.gd` and/or `tests/test_recipe_rules.gd`
  are amended to match. The phase-1 / 2 / 3 / 4 / 5 / 6 tests still
  pass.
- `./run.sh` opens a window in which:
  - the HUD shows a season-warning line (`Winter in 60d` outside winter,
    `Winter day 01` during winter),
  - the temperature line changes color as the player gets colder
    (blue when safe, warmer warning tones in the middle, red at
    critical cold),
  - the world view gains a pale winter wash in winter and a stronger
    blue exposure tint when ambient/body temperature crosses danger
    thresholds,
  - if the player idles on the winter surface, body temperature falls,
    the alert line escalates to winter/cold warnings, and HP
    eventually drops,
  - if the player instead stands in an excavated indoor pocket, and
    especially next to an active furnace, the alert line de-escalates
    and temperature stabilizes or recovers.
- `./run-headless.sh` still boots and exits cleanly with an updated
  `phase 7 boot ok` line.

## Scope

### In scope

Core (still no `Node` imports under `scripts/core/`):

- `simulation/game_balance.gd` — expand. Phase 7 is the first real
  balance pass, so this file stops being a one-constant stub and
  becomes the single typed home for:
  - calendar pace (`CLOCK_SECONDS_PER_REAL_SECOND`),
  - survival decay/damage thresholds that are shared between the
    rules layer and client warning logic,
  - winter-only ambient / expedition modifiers,
  - “prepare for winter” warning horizon in days.
  The concrete starting target is `720.0` clock-seconds per real
  second, i.e. one in-game day per 2 real minutes, which puts first
  winter roughly 120 real minutes from the default summer start.
- `simulation/survival_rules.gd` — retune and de-hardcode. The local
  `const`s move to `GameBalance`, and the seasonal curve is adjusted so
  winter is the first season where the surface is not “free.”
  Expedition windchill stays as a separate winter penalty and becomes
  strong enough that winter expeditions are riskier than simply
  standing outside.
- `simulation/environment_danger_level.gd` — new, optional but
  recommended. Small enum shell for the client-readable warning states:
  `STABLE`, `PREPARE_FOR_WINTER`, `WINTER_EXPOSURE`,
  `CRITICAL_COLD`, `DEAD`. This lets the HUD and renderer share the
  same coarse state without copying a nest of thresholds into each
  client script.
- `simulation/survival_rules.gd` — add a pure helper
  `get_danger_level(state)` if the enum above is added. This helper
  performs no mutation; it only reads `GameState`, `ClockState`, and
  the phase-7 balance thresholds. The logic mirrors
  `StatusTitleFormatter.BuildDangerText` from the MonoGame client:
  dead → critical cold → winter exposure → prepare-for-winter →
  stable.
- `simulation/game_state_factory.gd` — balance-only review surface.
  Keep the API unchanged. Starting scrap / fuel / food counts are
  allowed to move if the faster clock and harsher winter make the
  existing `8 scrap / 3 fuel / 4 food` start unwinnable, but no new
  inventory item types are introduced.
- `crafting/recipe_catalog.gd` — balance-only review surface.
  Furnace and simple-weapon costs are allowed to move if the new
  winter timing shows that the current costs are either trivial or
  impossible to hit before winter. No new recipes are added in phase 7.
- `simulation/expedition_resolver.gd` — balance-only review surface.
  Reward ranges and hostile-encounter chance may be tuned if the
  faster calendar makes current expedition economics too stingy or
  too generous for winter prep.
- `combat/enemy_catalog.gd` — balance-only review surface.
  A winter-only second enemy is explicitly *not* required for phase 7.
  If the accelerated calendar leaves the phase-6 Razor Maw too punishing
  or too soft relative to the shortened prep window, adjust its
  existing numbers in place rather than adding a “Frost Maw.”

Client:

- `client/hud.gd` — amend for winter readability:
  - add a dedicated `Season` line: `Winter in Nd` outside winter,
    `Winter day DD` in winter,
  - add a dedicated `Alert` line backed by the core danger-state
    helper (or the same thresholds if the helper is skipped),
  - dynamically color the temperature label using the same four bands
    as the MonoGame renderer:
    `<= 20%` body-temperature progress = red,
    `<= 40%` = amber,
    `<= 60%` = pale blue,
    else = blue,
  - optionally tint the clock/season line by season
    (summer gold, autumn rust, winter ice-blue, spring green) to
    mirror `GameRenderer.GetSeasonColor(...)`.
- `client/world_renderer.gd` — add a winter/environment overlay
  separate from the phase-6 combat tint:
  - base winter overlay alpha `22`,
  - ambient-temperature danger bump to `44`,
  - critical-body-temperature bump to `84`,
  - icy-blue overlay color that sits *under* the combat tint if both
    are active, so the red “in combat” signal still wins visually.
- `scripts/main.gd` — amend. Bump the boot string from `phase 6` to
  `phase 7`. No signal-wiring changes.

Tests:

- `tests/test_clock_state.gd` — amend. Replace
  `_test_advance_with_configured_scale_advances_one_full_day_in_ten_real_minutes`
  with the phase-7 scale assertion for 2 real minutes per in-game day.
- `tests/test_survival_rules.gd` — amend.
  Add the two MonoGame winter/furnace mitigation ports plus one
  Godot-specific expedition-cold test. The existing winter cases stay.
- `tests/test_game_state_factory.gd` — amend only if starting inventory
  changes.
- `tests/test_recipe_rules.gd` — amend only if recipe costs change.
- `tests/test_enemy_catalog.gd` — amend only if Razor Maw tunables
  change.

### Deferred to later phases / explicitly out of scope

- **New items, recipes, fuel types, or clothing/armor systems.** Phase 7
  is a tuning pass over the current MVP surfaces, not a second crafting
  expansion.
- **Weather beyond the season curve.** No snowstorms, rain, wind map, or
  per-tick random weather states.
- **A separate winter HUD scene or popup.** The current inline HUD
  remains the client surface. Extra feedback is additive labels/colors,
  not a screen-mode refactor.
- **Camera scrolling, zoom, or a new renderer architecture.** The world
  tint continues to draw against the current fixed world bounds.
- **Removing hygiene/psyche from the repo.** The source `mvp_plan.md`
  talks about MVP cuts, but those systems are already integrated and
  tested in this port. Stripping them now would be churn, not leverage.
- **A second enemy definition.** If winter balance needs combat relief or
  added pressure, tune the existing Razor Maw first.

## Detailed port plan

### `simulation/game_balance.gd` (amend)

This file is the center of the phase.

Current shape:

```gdscript
class_name GameBalance
extends RefCounted

const CLOCK_SECONDS_PER_REAL_SECOND: float = 144.0
```

Phase-7 shape:

- Keep `class_name GameBalance`.
- Replace the one-line stub with typed constants grouped by concern:
  - calendar pacing,
  - survival decay / damage,
  - temperature thresholds,
  - seasonal ambient curves,
  - winter warning horizon.

Minimum constants that should live here after the phase:

- `CLOCK_SECONDS_PER_REAL_SECOND: float = 720.0`
- `STARVATION_CRITICAL_THRESHOLD`
- `HYPOTHERMIA_DAMAGE_THRESHOLD`
- `COLD_AMBIENT_WARNING_THRESHOLD`
- `PREPARE_FOR_WINTER_DAYS`
- the four temperature-adjust rates
- winter expedition windchill
- the winter surface/underground ambient curve endpoints

Notes:

- `720.0` is the starting target, not sacred doctrine. It gives
  `86400 / 720 = 120` real seconds per in-game day, so first winter
  from `Summer, day 1` lands after `60 * 120 = 7200` real seconds
  (120 minutes). If manual play still makes autumn feel like dead air,
  the next adjustment knob is the scale constant, not another layer of
  special-case time skipping.
- Do *not* move client-only aesthetics (overlay alpha values, RGB
  colors, font sizes) into `GameBalance`. Those stay in the client.
  Balance thresholds that the client interprets are in scope;
  presentation values are not.

### `simulation/environment_danger_level.gd` (new, recommended)

If added, keep the same enum-shell pattern as `Season`,
`ExpeditionStatus`, and `CombatResolution`:

```gdscript
class_name EnvironmentDangerLevel
extends RefCounted

enum Kind {
	STABLE,
	PREPARE_FOR_WINTER,
	WINTER_EXPOSURE,
	CRITICAL_COLD,
	DEAD,
}
```

Why it is worth adding:

- `hud.gd` needs text.
- `world_renderer.gd` needs overlay strength.
- both depend on the same thresholds.

Without an enum, those thresholds either duplicate in two client files
or hide inside UI-only helpers that the test suite cannot reach. The
enum + `SurvivalRules.get_danger_level(...)` path keeps the warning
state pure-core and therefore testable.

### `simulation/survival_rules.gd` (amend)

Two kinds of work land here:

1. **De-hardcode the constants.**
   Every phase-3 / phase-5 survival number currently defined at the top
   of the file should read from `GameBalance` instead.

2. **Retune winter to be meaningfully dangerous.**

Concrete tuning targets:

- A winter surface player should cool noticeably faster than they do
  now and should begin losing HP from exposure in a short, observable
  window rather than after a long drift.
  Target band: “critical cold” should become visible within roughly
  `15..25` real seconds if the player idles outdoors in winter with no
  shelter or furnace.
- A winter expedition should be colder than winter surface idling.
  The current design already hints at that via
  `_WINTER_EXPEDITION_WINDCHILL`; phase 7 makes the difference obvious
  enough to deserve its own regression test.
- An excavated indoor underground pocket must remain survivable for the
  existing `180s` shelter test window.
- A nearby active furnace must materially improve both ambient and body
  temperature in winter; it is not enough for the furnace to be “a bit
  warmer.”

Recommended API addition if `EnvironmentDangerLevel` lands:

```gdscript
static func get_danger_level(state: GameState) -> int:
	if not state.player.is_alive():
		return EnvironmentDangerLevel.Kind.DEAD
	if state.player.current_temperature <= GameBalance.HYPOTHERMIA_DAMAGE_THRESHOLD:
		return EnvironmentDangerLevel.Kind.CRITICAL_COLD
	if state.current_ambient_temperature <= GameBalance.COLD_AMBIENT_WARNING_THRESHOLD:
		return EnvironmentDangerLevel.Kind.WINTER_EXPOSURE
	if state.clock.season != Season.Kind.WINTER \
			and state.clock.get_days_until_season(Season.Kind.WINTER) <= GameBalance.PREPARE_FOR_WINTER_DAYS:
		return EnvironmentDangerLevel.Kind.PREPARE_FOR_WINTER
	return EnvironmentDangerLevel.Kind.STABLE
```

Notes:

- This helper must be read-only. `update(...)` remains the mutation
  entry point.
- `get_ambient_temperature(...)` stays the single source of truth for
  the temperature model. Do not bolt winter modifiers into the HUD or
  renderer.
- Furnace heat remains additive to ambient temperature exactly where it
  already is today. Phase 7 is not a furnace-system rewrite.

### Balance-review surfaces (numbers only)

These files are in scope only if the winter loop proves unwinnable or
too trivial once the new clock scale and colder survival numbers land.

#### `simulation/game_state_factory.gd`

- Starting inventory (`8 scrap / 3 fuel / 4 food`) is the cleanest
  “give the player one more decision” knob if the accelerated calendar
  makes the opening impossible.
- Keep the starting season/time (`Summer`, day 1, `06:00`) unless the
  entire high-level plan changes. Phase 7 is a balance pass, not a new
  start scenario.

#### `crafting/recipe_catalog.gd`

- Review `FURNACE` cost first if the winter loop is too tight.
- Review `SIMPLE_WEAPON` only if phase-6 combat becomes the real reason
  the player cannot prepare for winter in time.
- `SCRAP_METAL_WALL` should remain cheap; walls are the entry-level
  shelter mechanic and phase 7 should not price them out of reach.

#### `simulation/expedition_resolver.gd`

- Reward ranges are allowed to move if expeditions no longer support the
  shelter/fuel loop once the faster calendar lands.
- Hostile-encounter chance is also a balance lever, but use it after
  economy numbers. The player should not feel like phase 7 “fixed”
  winter by just removing combat risk.

#### `combat/enemy_catalog.gd`

- If tuning reaches combat, adjust Razor Maw numbers in place.
- Do not add a winter-only enemy catalog entry unless the manual loop
  reveals a specific need that cannot be served by existing numbers.

## Client plan

### `client/hud.gd` (amend)

The current HUD has the raw data but not the stronger readouts.

Add two new label rows:

- `Season`
- `Alert`

Recommended display rules:

- `Season` line:
  - outside winter: `Winter in %dd`
  - in winter: `Winter day %02d`
- `Alert` line:
  - `Stable`
  - `Prepare for winter`
  - `Winter exposure`
  - `Critical cold`
  - `Dead`

Dynamic temperature coloring:

- Mirror the MonoGame bands from
  `GameRenderer.GetTemperatureColor(...)`.
- Compute progress from `current_temperature / max_temperature`.
- Apply the color to the existing temperature label on every `refresh`.

Optional polish that is still phase-7-appropriate:

- tint `_clock_label` by season using the MonoGame palette:
  - summer gold,
  - autumn rust,
  - winter blue,
  - spring green.

Notes:

- Keep the HUD inline. No new scene, no overlay-mode system.
- Do not remove the phase-6 combat rows. Winter feedback is additive.
- If the line count starts to feel crowded, collapse the current
  `Expedition` and `done-count` text before introducing any new panel.

### `client/world_renderer.gd` (amend)

Add a new `_draw_environment_tint()` helper and call it from `_draw`.

Recommended draw order:

1. tiles
2. action target
3. furnace overlays
4. hover overlay
5. player
6. environment tint
7. combat tint

Why this order:

- the environment wash should tint the world and the player,
- the combat tint should remain the top-most signal when both systems
  are active.

Recommended overlay logic, lifted from the MonoGame renderer:

- winter baseline alpha `22`
- if `state.current_ambient_temperature <= 12.0`, raise to at least `44`
- if `state.player.current_temperature <= 20.0`, raise to at least `84`
- color: pale icy blue

The world tint should read as “season/cold pressure,” not as a full
screen fade. Keep the alpha subtle enough that tiles and hover targets
stay legible.

### `scripts/main.gd` (amend)

- Boot string changes from `phase 6 boot ok` to `phase 7 boot ok`.
- No new signals or scene wiring.

## Test plan

### `tests/test_clock_state.gd` (amend)

Keep:

- `_test_advance_crossing_day_boundary_rolls_into_next_season`
- `_test_get_days_until_winter_from_summer_start_returns_sixty_days`

Replace:

- `_test_advance_with_configured_scale_advances_one_full_day_in_ten_real_minutes`

with:

- `_test_advance_with_configured_scale_advances_one_full_day_in_two_real_minutes`

This keeps the assertion concrete while letting the “winter arrives in a
session” requirement ride on the configured constant rather than on a
huge simulated loop inside the test.

### `tests/test_survival_rules.gd` (amend)

Keep the current tests, and add three more:

1. `_test_active_furnace_raises_nearby_ambient_temperature()`
   - direct port of the MonoGame test
   - compares a winter state on a furnace tile with and without active
     fuel
   - asserts both ambient temperature and player body temperature are
     higher in the heated state

2. `_test_underground_shelter_and_furnace_materially_reduce_winter_exposure_risk()`
   - direct port of the MonoGame test
   - compare:
     - surface winter state,
     - excavated indoor winter shelter without furnace,
     - excavated indoor winter shelter with active furnace
   - assert:
     - shelter is indoors,
     - sheltered body temp/HP are better than surface,
     - heated ambient/body temp are better than unheated shelter

3. `_test_winter_expedition_cools_faster_than_winter_surface_idle()`
   - Godot-specific
   - start two otherwise-identical winter surface states
   - one idles
   - one starts an expedition and advances for a short equal window
   - assert expedition body temp is lower

The current `180s` “excavated winter shelter keeps player alive” case
stays. It is the hard guardrail for “viable survival path.”

### `tests/test_game_state_factory.gd` / `tests/test_recipe_rules.gd` / `tests/test_enemy_catalog.gd`

Only amend if phase-7 tuning actually changes:

- starting inventory,
- recipe costs,
- Razor Maw tunables.

If those numbers do not move, leave the tests alone.

## Repro recipe (visual check)

To verify the winter/cold loop in `./run.sh` without waiting through a
full accelerated summer:

1. Temporarily change `GameStateFactory.create_new(...)` so the created
   clock starts at `Season.Kind.WINTER`, day `1`, time `0.0`.
   Do not commit the override.
2. Run `./run.sh`.
3. Confirm the HUD shows `Winter day 01`, the world has a faint icy
   tint, and the temperature label has the “safe cold” color.
4. Idle on the surface for ~20 seconds.
   Confirm:
   - body temperature falls,
   - the alert line escalates to winter / critical-cold warnings,
   - the tint deepens,
   - HP eventually starts to drop.
5. Move the player into an excavated indoor shelter. Confirm the alert
   weakens and temperature fall slows or stops.
6. Fuel a furnace in or next to the shelter. Confirm ambient and body
   temperature recover faster than in the unheated shelter.
7. Revert the factory override.

For the “prepare for winter” copy specifically, use a temporary clock of
`Season.Kind.AUTUMN`, day `21`, `06:00` and confirm the HUD shows
`Winter in 10d`.

## Risks / open questions

- **Exact day-length target.** `720.0` (2 real min/day, 2 real hours to
  first winter) is the recommended starting point. If that still makes
  autumn feel like filler, the next clock candidate is `960.0`
  (1.5 real min/day, 90 real min to winter). Pick one and lock the test
  to it; do not leave the plan half-tuned.
- **Balance-constant sprawl.** Moving every survival number to
  `GameBalance` is desirable, but resist turning the file into an
  undifferentiated dump. Group the constants by concern and keep names
  explicit.
- **Client threshold duplication.** If `hud.gd` and `world_renderer.gd`
  each reimplement “critical cold / winter exposure / prepare for
  winter” themselves, the UI will drift. Use a core helper or a shared
  constant set.
- **Winter tint vs combat tint.** The draw order matters. If the winter
  tint draws after the combat tint, the red combat state muddies into a
  dull purple/gray and becomes less readable.
- **Tuning by one system only.** If winter feels impossible, do not
  assume the answer is “make winter warmer.” The opening inventory,
  furnace cost, expedition fuel yield, and Razor Maw pace are all valid
  knobs. Phase 7 is the first pass that is allowed to use them together.

## Phase 7 ship state

After phase 7 lands:

- winter arrives on a human play-session timescale,
- the cold-pressure loop is visible both numerically and visually,
- shelter and furnace usage are no longer optional flavor,
- balance numbers live in an obvious place instead of being scattered
  across the rules/client boundary,
- the repo reaches the final high-level-plan milestone without adding
  new mechanical scope.
