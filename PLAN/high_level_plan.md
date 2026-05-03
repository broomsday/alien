# Alien — Godot 4 port: high-level plan

This document describes the high-level approach for porting the MonoGame
project at `../alien/` to a Godot 4 / GDScript project rooted at this
directory. It mirrors the code-first conventions from `../aerial/CLAUDE.md`.

## Source game (one-paragraph summary)

Top-down tile-grid survival sim with one playable character. Tiles are
open-air / soil / excavated floor / wall / furnace. The player has health,
nutrition, and a tile position; inventory tracks `scrap_metal`, `fuel`,
`canned_food`, and `simple_weapon`. A single `GameState` is advanced by a
`SimulationStep` that consumes commands (move, excavate, build, expedition,
craft, fuel furnace, eat, cancel) and a clock that progresses time-of-day and
seasons. Expeditions are discrete timed activities with deterministic loot
tables that may trigger combat with a single enemy type. Winter introduces
exposure pressure that underground rooms and a fueled furnace mitigate. Saves
are out of MVP scope.

## Architecture: core / client split

The MonoGame project enforces a hard split: `Alien.Core` is pure C# with no
MonoGame types; `Alien.Client` is the only place that touches `SpriteBatch`,
`KeyboardState`, etc. The Godot port preserves that split.

| MonoGame layer | Godot equivalent |
| --- | --- |
| `Alien.Core` (pure simulation) | Pure GDScript classes (`extends RefCounted`, `class_name`) under `scripts/core/` — must not import or reference `Node`, `SceneTree`, `PackedScene`, rendering APIs, or input APIs |
| `Alien.Client/Game1.cs` | `scenes/main.tscn` + `scripts/main.gd` — script populates children in `_ready()` |
| `Alien.Client/Input` | Godot input map (text-edited `[input]` in `project.godot`) → command struct → core |
| `Alien.Client/Rendering` (SpriteBatch) | `_draw()` callback over the world grid (see "Tile rendering" below) |
| `Alien.Client/Simulation/ClientGameSession` | A `Node` that owns one core `GameState` and ticks it from `_process(delta)` |
| `Alien.Core.Tests` (xUnit) | Headless `SceneTree` scripts under `tests/` returning `quit(0)` / `quit(1)` |

The single non-negotiable: nothing under `scripts/core/` imports anything
Godot-specific. This is what keeps tests fast and the rules portable.

## Project layout

```
alien_godot/
├── CLAUDE.md                 # adapted from aerial's, plus a core/client section
├── project.godot             # input map + autoloads, hand-edited
├── run.sh / run-headless.sh  # mirror aerial's
├── scenes/
│   └── main.tscn             # single root, script-populated
├── scripts/
│   ├── main.gd               # boots world, owns GameSession
│   ├── core/                 # pure simulation (no Node imports)
│   │   ├── world/            # WorldGrid, TilePoint, WorldTileType
│   │   ├── gameplay/         # PlayerState, PlayerStats, EquippedWeapon
│   │   ├── inventory/        # InventoryState, ItemId
│   │   ├── time/             # ClockState, Season
│   │   ├── crafting/         # Recipe catalog + rules
│   │   ├── combat/           # EnemyCatalog, CombatResolver
│   │   └── simulation/       # GameState, SimulationStep, commands,
│   │                         # expedition resolver, survival rules, balance
│   ├── client/
│   │   ├── input_reader.gd
│   │   ├── game_session.gd   # owns + ticks GameState
│   │   ├── world_renderer.gd # _draw() over the grid; per-tile draw fn
│   │   └── hud.gd
│   └── client/screens/       # interaction modes (build / excavate / expedition)
├── resources/                # reserved; not used for balance in MVP
├── tests/
│   ├── test_inventory.gd
│   ├── test_world_grid.gd
│   ├── test_simulation_step.gd
│   ├── test_expedition_resolver.gd
│   ├── test_combat_resolver.gd
│   └── test_survival_rules.gd
└── tools/                    # one-off headless scripts if needed
```

## Tile rendering

Use a single `Node2D` whose `_draw()` walks the visible region of `WorldGrid`
and calls a per-tile draw function for each cell. The per-tile function takes
the `TilePoint` and `WorldTileType` and is responsible for *all* visuals at
that cell. For MVP each call paints one solid rectangle, but the function is
designed so it can grow into sprite composition later — a tile may eventually
draw a floor base, then any object/feature on top (furnace, scrap pile, etc.),
then overlays (hover/selection). Keep the draw function pure with respect to
the simulation: it reads `GameState`, never mutates it, and never queues
follow-up state changes during a draw pass.

When sprites arrive, the per-tile function becomes the natural extension
point. Until then, no PNGs are needed.

## Tests

Tests are rewritten from observed behavior in GDScript, not transcribed
one-for-one from the C# `Alien.Core.Tests`. The MonoGame project is still
early enough that mirroring tests verbatim would lock in incidental shape;
rewriting lets each Godot test stay small, named for the GDScript API as it
emerges, and easy to tweak as ports of each system land.

Each test is a `SceneTree`-extending script that constructs core objects
directly, drives them through a few steps, asserts state, and calls `quit(0)`
on success / `quit(1)` on failure. No graphics, no `_process` loops.

## Balance data

Balance numbers (nutrition decay rate, expedition durations, recipe costs,
combat tunables, seasonal temperature curves) live as typed `const`s in
GDScript — most likely a `scripts/core/simulation/balance.gd` mirroring
`GameBalance.cs`. No `.tres` for MVP. If a number ever needs hot-tuning
without a code edit, promote that single number to a resource at that point.

## Phased delivery

Mirrors the MonoGame milestones (which are all marked complete in
`../alien/docs/mvp_plan.md`). Each phase ends with the simulation reachable
from tests, and — from phase 2 onward — visible in a running window.

1. **Bootstrap + simulation foundation.** `project.godot`, `main.tscn`/
   `main.gd`, `run.sh` / `run-headless.sh`, headless test runner. Port
   `GameState`, `PlayerState`, `InventoryState`, `ClockState`, `GameAction`,
   `SimulationStep`, command structs. Tests for fresh-state creation,
   inventory add/remove, action progression, clock rollover. No rendering
   yet.
2. **World grid + excavation/wall building.** Port `WorldGrid`, tile types,
   excavation/build rules, indoor flag. Add `world_renderer.gd` with the
   per-tile `_draw()` pattern. Hover preview + right-click commands. Tests
   for valid/invalid build targets, scrap consumption, indoor detection.
3. **Survival economy.** Nutrition decay, canned-food consumption,
   starvation damage, indoor-vs-surface temperature model. Minimal HUD
   (`Label`s). Tests cover decay, food consumption, starvation threshold,
   temperature differential.
4. **Expeditions + loot.** `ExpeditionResolver`, status states, deterministic
   seeded reward tables. Expedition button + away/returned status. Tests
   for reward bounds, time consumption, one-time payout, interruption.
5. **Crafting + furnace + weapon.** `RecipeCatalog`, furnace placement and
   fueling, equipped-weapon slot. Crafting panel. Tests for missing-resource
   failures, fueling, furnace heat radius.
6. **Combat.** `EnemyCatalog`, `CombatResolver`, encounter trigger from
   expeditions, skill gain. HUD reuses bars for enemy HP during fights.
   Tests for lethal resolution, weapon advantage, skill rules, reward
   interruption.
7. **Winter pressure + balancing.** Activate the harsher seasonal curve,
   exposure rates, furnace mitigation. Visual feedback (screen tint, dynamic
   temperature color). Tune until the loop is winnable but punishing.

Order matches the MonoGame project — each step stays playable and testable.

## Tooling and dev loop

Lifted from `aerial/CLAUDE.md`:

- Engine binary: `/home/broom/.local/bin/godot` (4.6.2-stable).
- `./run-headless.sh` for the default dev loop (quits after N seconds).
- `./run.sh` for visible runs.
- `godot --headless --script res://tests/test_*.gd` per test; a small shell
  loop runs the suite.
- Static typing everywhere; tabs; `snake_case` files/funcs, `PascalCase`
  classes; `@export` defaults so the editor isn't required to configure
  anything.
- All `.tscn` / `.tres` text-authored. Procedural visuals only for MVP.

## CLAUDE.md for this project

Near-copy of `../aerial/CLAUDE.md` with one added section that codifies the
core/client split: simulation files under `scripts/core/` may not import
`Node`, `SceneTree`, `PackedScene`, rendering APIs, or input APIs, and the
test suite enforces this by being able to instantiate any core file from a
`SceneTree` script with no scene graph.
