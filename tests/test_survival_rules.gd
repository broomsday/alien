extends SceneTree

const SurvivalRulesScript = preload("res://scripts/core/simulation/survival_rules.gd")
const GameStateScript = preload("res://scripts/core/simulation/game_state.gd")
const GameStateFactoryScript = preload("res://scripts/core/simulation/game_state_factory.gd")
const SimulationStepScript = preload("res://scripts/core/simulation/simulation_step.gd")
const ConsumeFoodCommandScript = preload("res://scripts/core/simulation/consume_food_command.gd")
const PlayerStateScript = preload("res://scripts/core/gameplay/player_state.gd")
const PlayerStatsScript = preload("res://scripts/core/gameplay/player_stats.gd")
const InventoryStateScript = preload("res://scripts/core/inventory/inventory_state.gd")
const ItemIdScript = preload("res://scripts/core/inventory/item_id.gd")
const ClockStateScript = preload("res://scripts/core/time/clock_state.gd")
const SeasonScript = preload("res://scripts/core/time/season.gd")
const WorldGridScript = preload("res://scripts/core/world/world_grid.gd")
const WorldTileTypeScript = preload("res://scripts/core/world/world_tile_type.gd")
const StartActionCommandScript = preload("res://scripts/core/simulation/start_action_command.gd")
const GameActionKindScript = preload("res://scripts/core/simulation/game_action_kind.gd")

func _init() -> void:
	_test_decreases_energy_over_time()
	_test_consume_food_restores_energy_and_consumes_inventory()
	_test_critical_energy_depletion_damages_integrity()
	_test_low_temperature_damages_integrity()
	_test_comfortable_state_recovers_psyche()
	_test_cold_low_energy_state_drops_psyche()
	_test_underground_at_night_stays_warmer_than_surface()
	_test_winter_surface_harsher_than_summer()
	_test_active_furnace_raises_nearby_ambient_temperature()
	_test_underground_shelter_and_furnace_materially_reduce_winter_exposure_risk()
	_test_excavated_winter_shelter_keeps_player_alive()
	_test_winter_expedition_cools_faster_than_winter_surface_idle()
	_test_outdoor_temperature_drops_at_night_and_rises_during_day()
	print("test_survival_rules: ok")
	quit(0)

func _test_decreases_energy_over_time() -> void:
	var state: GameState = GameStateFactoryScript.create_new()
	var step: SimulationStep = SimulationStepScript.new()
	var starting: float = state.player.current_energy

	step.advance(state, 10.0, [])

	assert(state.player.current_energy < starting,
		"expected energy to drop, got %f" % state.player.current_energy)

func _test_consume_food_restores_energy_and_consumes_inventory() -> void:
	var state: GameState = GameStateFactoryScript.create_new()
	var step: SimulationStep = SimulationStepScript.new()
	state.player.drain_energy(50.0)
	var starting_food: int = state.inventory.get_count(ItemIdScript.Id.CANNED_FOOD)

	step.advance(state, 0.0, [ConsumeFoodCommandScript.new()])

	assert(state.player.current_energy > 50.0,
		"expected energy restored, got %f" % state.player.current_energy)
	assert(state.inventory.get_count(ItemIdScript.Id.CANNED_FOOD) == starting_food - 1,
		"expected one canned food consumed, got %d" %
			state.inventory.get_count(ItemIdScript.Id.CANNED_FOOD))

func _test_critical_energy_depletion_damages_integrity() -> void:
	var state: GameState = GameStateFactoryScript.create_new()
	var step: SimulationStep = SimulationStepScript.new()
	state.player.drain_energy(100.0)
	var starting_integrity: int = state.player.current_integrity()

	step.advance(state, 5.0, [])

	assert(state.player.current_integrity() < starting_integrity,
		"expected integrity to drop from energy depletion, got %d" %
			state.player.current_integrity())

func _test_low_temperature_damages_integrity() -> void:
	var state: GameState = GameStateFactoryScript.create_new()
	state.player.move_temperature_toward(0.0, 500.0, 1.0)
	assert(state.player.current_temperature == 0.0,
		"precondition: expected body temperature 0.0, got %f" % state.player.current_temperature)
	var starting_integrity: int = state.player.current_integrity()

	_advance_in_steps(state, 5.0, 1.0)

	assert(state.player.current_integrity() < starting_integrity,
		"expected integrity to drop from hypothermia, got %d" %
			state.player.current_integrity())

func _test_comfortable_state_recovers_psyche() -> void:
	var state: GameState = GameStateFactoryScript.create_new()
	var step: SimulationStep = SimulationStepScript.new()
	state.player.reduce_psyche(12.0)
	var starting_psyche: float = state.player.current_psyche

	step.advance(state, 15.0, [])

	assert(state.player.current_psyche > starting_psyche,
		"expected psyche to recover above %f, got %f" %
			[starting_psyche, state.player.current_psyche])
	assert(state.player.current_psyche > 88.0,
		"expected psyche > 88, got %f" % state.player.current_psyche)

func _test_cold_low_energy_state_drops_psyche() -> void:
	var state: GameState = GameStateFactoryScript.create_new()
	var step: SimulationStep = SimulationStepScript.new()
	state.player.drain_energy(80.0)
	state.player.move_temperature_toward(10.0, 500.0, 1.0)
	var starting_psyche: float = state.player.current_psyche

	step.advance(state, 10.0, [])

	assert(state.player.current_psyche < starting_psyche,
		"expected psyche to drop, got %f" % state.player.current_psyche)

func _test_underground_at_night_stays_warmer_than_surface() -> void:
	var surface_world: WorldGrid = WorldGridScript.create_default(12, 10, 4)
	var underground_world: WorldGrid = WorldGridScript.create_default(12, 10, 4)
	underground_world.set_tile(Vector2i(5, 6), WorldTileTypeScript.Kind.EXCAVATED_FLOOR)

	var surface_state: GameState = _make_state(
		surface_world, Vector2i(5, 3), SeasonScript.Kind.SUMMER, 0.0)
	var underground_state: GameState = _make_state(
		underground_world, Vector2i(5, 6), SeasonScript.Kind.SUMMER, 0.0)

	_advance_in_steps(surface_state, 10.0, 1.0)
	_advance_in_steps(underground_state, 10.0, 1.0)

	assert(underground_state.player.current_temperature > surface_state.player.current_temperature,
		"expected underground body temp (%f) > surface body temp (%f)" %
			[underground_state.player.current_temperature,
				surface_state.player.current_temperature])
	assert(underground_state.current_ambient_temperature > surface_state.current_ambient_temperature,
		"expected underground ambient (%f) > surface ambient (%f)" %
			[underground_state.current_ambient_temperature,
				surface_state.current_ambient_temperature])

func _test_winter_surface_harsher_than_summer() -> void:
	var summer_world: WorldGrid = WorldGridScript.create_default(12, 10, 4)
	var winter_world: WorldGrid = WorldGridScript.create_default(12, 10, 4)

	var summer_state: GameState = _make_state(
		summer_world, Vector2i(5, 3), SeasonScript.Kind.SUMMER, 0.0)
	var winter_state: GameState = _make_state(
		winter_world, Vector2i(5, 3), SeasonScript.Kind.WINTER, 0.0)

	_advance_in_steps(summer_state, 20.0, 1.0)
	_advance_in_steps(winter_state, 20.0, 1.0)

	assert(winter_state.current_ambient_temperature < summer_state.current_ambient_temperature,
		"expected winter ambient (%f) < summer ambient (%f)" %
			[winter_state.current_ambient_temperature,
				summer_state.current_ambient_temperature])
	assert(winter_state.player.current_temperature < summer_state.player.current_temperature,
		"expected winter body temp (%f) < summer body temp (%f)" %
			[winter_state.player.current_temperature,
				summer_state.player.current_temperature])
	assert(winter_state.player.current_integrity() < summer_state.player.current_integrity(),
		"expected winter integrity (%d) < summer integrity (%d)" %
			[winter_state.player.current_integrity(),
				summer_state.player.current_integrity()])

func _test_active_furnace_raises_nearby_ambient_temperature() -> void:
	var unheated_state: GameState = _make_indoor_winter_furnace_state(false)
	var heated_state: GameState = _make_indoor_winter_furnace_state(true)

	_advance_in_steps(unheated_state, 40.0, 1.0)
	_advance_in_steps(heated_state, 40.0, 1.0)

	assert(heated_state.current_ambient_temperature > unheated_state.current_ambient_temperature,
		"expected heated ambient (%f) > unheated ambient (%f)" %
			[heated_state.current_ambient_temperature,
				unheated_state.current_ambient_temperature])
	assert(heated_state.player.current_temperature > unheated_state.player.current_temperature,
		"expected heated body temp (%f) > unheated body temp (%f)" %
			[heated_state.player.current_temperature,
				unheated_state.player.current_temperature])

func _test_underground_shelter_and_furnace_materially_reduce_winter_exposure_risk() -> void:
	var surface_world: WorldGrid = WorldGridScript.create_default(12, 12, 4)
	var surface_state: GameState = _make_state(
		surface_world, Vector2i(5, 3), SeasonScript.Kind.WINTER, 0.0)
	var shelter_state: GameState = _make_indoor_winter_furnace_state(false)
	var heated_state: GameState = _make_indoor_winter_furnace_state(true)

	_advance_in_steps(surface_state, 40.0, 1.0)
	_advance_in_steps(shelter_state, 40.0, 1.0)
	_advance_in_steps(heated_state, 40.0, 1.0)

	assert(shelter_state.world.is_indoors(shelter_state.player.tile_position),
		"expected shelter tile %s to remain indoors" % shelter_state.player.tile_position)
	assert(shelter_state.player.current_integrity() > surface_state.player.current_integrity(),
		"expected shelter integrity (%d) > surface integrity (%d)" %
			[shelter_state.player.current_integrity(),
				surface_state.player.current_integrity()])
	assert(shelter_state.player.current_temperature > surface_state.player.current_temperature,
		"expected shelter body temp (%f) > surface body temp (%f)" %
			[shelter_state.player.current_temperature,
				surface_state.player.current_temperature])
	assert(heated_state.current_ambient_temperature > shelter_state.current_ambient_temperature,
		"expected heated ambient (%f) > shelter ambient (%f)" %
			[heated_state.current_ambient_temperature,
				shelter_state.current_ambient_temperature])
	assert(heated_state.player.current_temperature > shelter_state.player.current_temperature,
		"expected heated body temp (%f) > shelter body temp (%f)" %
			[heated_state.player.current_temperature,
				shelter_state.player.current_temperature])

func _test_excavated_winter_shelter_keeps_player_alive() -> void:
	var world: WorldGrid = WorldGridScript.create_default(12, 12, 4)
	world.set_tile(Vector2i(5, 5), WorldTileTypeScript.Kind.EXCAVATED_FLOOR)
	world.set_tile(Vector2i(6, 5), WorldTileTypeScript.Kind.EXCAVATED_FLOOR)
	world.set_tile(Vector2i(5, 6), WorldTileTypeScript.Kind.EXCAVATED_FLOOR)
	world.set_tile(Vector2i(6, 6), WorldTileTypeScript.Kind.EXCAVATED_FLOOR)

	var state: GameState = _make_state(
		world, Vector2i(5, 5), SeasonScript.Kind.WINTER, 0.0)

	_advance_in_steps(state, 180.0, 1.0)

	assert(state.player.is_alive(), "expected player to survive sheltered winter")
	assert(state.world.is_indoors(Vector2i(5, 5)),
		"expected (5,5) pocket to remain indoors after advance")
	assert(state.player.current_integrity() == 100,
		"expected integrity to remain 100, got %d" % state.player.current_integrity())

func _test_winter_expedition_cools_faster_than_winter_surface_idle() -> void:
	var idle_world: WorldGrid = WorldGridScript.create_default(12, 10, 4)
	var expedition_world: WorldGrid = WorldGridScript.create_default(12, 10, 4)
	var idle_state: GameState = _make_state(
		idle_world, Vector2i(5, 3), SeasonScript.Kind.WINTER, 0.0)
	var expedition_state: GameState = _make_state(
		expedition_world, Vector2i(5, 3), SeasonScript.Kind.WINTER, 0.0)
	var step: SimulationStep = SimulationStepScript.new()

	step.advance(
		expedition_state,
		0.0,
		[StartActionCommandScript.new(GameActionKindScript.Kind.EXPEDITION)])
	_advance_in_steps(idle_state, 4.0, 1.0)
	_advance_in_steps(expedition_state, 4.0, 1.0)

	assert(expedition_state.player.current_temperature < idle_state.player.current_temperature,
		"expected expedition body temp (%f) < idle body temp (%f)" %
			[expedition_state.player.current_temperature,
				idle_state.player.current_temperature])

func _test_outdoor_temperature_drops_at_night_and_rises_during_day() -> void:
	# Spring middle day, midnight. Brightness=0, temperature should drop.
	var night_world: WorldGrid = WorldGridScript.create_default(12, 10, 4)
	var night_state: GameState = _make_state_at_day(
		night_world, Vector2i(5, 3), SeasonScript.Kind.SPRING, 15, 0.0)
	var night_start: float = night_state.current_outdoor_temperature
	_advance_in_steps(night_state, 8.0, 1.0)
	assert(night_state.current_outdoor_temperature < night_start,
		"expected outdoor temp to drop at night (start %f, end %f)" %
			[night_start, night_state.current_outdoor_temperature])

	# Spring middle day, noon. Brightness=1, temperature should rise.
	var day_world: WorldGrid = WorldGridScript.create_default(12, 10, 4)
	var day_state: GameState = _make_state_at_day(
		day_world, Vector2i(5, 3), SeasonScript.Kind.SPRING, 15, 12.0 * 3600.0)
	var day_start: float = day_state.current_outdoor_temperature
	_advance_in_steps(day_state, 8.0, 1.0)
	assert(day_state.current_outdoor_temperature > day_start,
		"expected outdoor temp to rise at noon (start %f, end %f)" %
			[day_start, day_state.current_outdoor_temperature])

func _make_state_at_day(world: WorldGrid, player_tile: Vector2i, season: int, day_of_season: int, time_of_day_seconds: float) -> GameState:
	var player: PlayerState = PlayerStateScript.new(
		player_tile,
		PlayerStatsScript.new(100),
		100.0, 100.0, 0,
		100.0, 70.0)
	var inventory: InventoryState = InventoryStateScript.new()
	inventory.add(ItemIdScript.Id.CANNED_FOOD, 2)
	var clock: ClockState = ClockStateScript.new(season, day_of_season, time_of_day_seconds)
	var state: GameState = GameStateScript.new(player, world, inventory, clock)
	SurvivalRulesScript.bootstrap_outdoor_temperature(state)
	_refresh_environment(state)
	return state

func _make_state(world: WorldGrid, player_tile: Vector2i, season: int, time_of_day_seconds: float) -> GameState:
	var player: PlayerState = PlayerStateScript.new(
		player_tile,
		PlayerStatsScript.new(100),
		100.0, 100.0, 0,
		100.0, 70.0)
	var inventory: InventoryState = InventoryStateScript.new()
	inventory.add(ItemIdScript.Id.CANNED_FOOD, 2)
	var clock: ClockState = ClockStateScript.new(season, 1, time_of_day_seconds)
	var state: GameState = GameStateScript.new(player, world, inventory, clock)
	SurvivalRulesScript.bootstrap_outdoor_temperature(state)
	_refresh_environment(state)
	return state

func _make_indoor_winter_furnace_state(with_active_furnace: bool) -> GameState:
	var world: WorldGrid = _make_winter_shelter_world()
	var player_tile: Vector2i = Vector2i(5, 5)
	var state: GameState = _make_state(world, player_tile, SeasonScript.Kind.WINTER, 0.0)
	var built: bool = state.try_build_furnace(player_tile)
	assert(built, "expected furnace build to succeed at %s" % player_tile)
	if with_active_furnace:
		state.inventory.add(ItemIdScript.Id.FUEL, 1)
		var fueled: bool = state.try_fuel_furnace(player_tile, 90.0)
		assert(fueled, "expected furnace fuel to succeed at %s" % player_tile)
	_refresh_environment(state)
	return state

func _make_winter_shelter_world() -> WorldGrid:
	var world: WorldGrid = WorldGridScript.create_default(12, 12, 4)
	world.set_tile(Vector2i(5, 5), WorldTileTypeScript.Kind.EXCAVATED_FLOOR)
	world.set_tile(Vector2i(6, 5), WorldTileTypeScript.Kind.EXCAVATED_FLOOR)
	world.set_tile(Vector2i(5, 6), WorldTileTypeScript.Kind.EXCAVATED_FLOOR)
	world.set_tile(Vector2i(6, 6), WorldTileTypeScript.Kind.EXCAVATED_FLOOR)
	return world

func _refresh_environment(state: GameState) -> void:
	var step: SimulationStep = SimulationStepScript.new()
	step.advance(state, 0.0, [])

func _advance_in_steps(state: GameState, total_seconds: float, step_seconds: float = 1.0) -> void:
	var sim: SimulationStep = SimulationStepScript.new()
	var elapsed: float = 0.0
	while elapsed < total_seconds:
		var dt: float = minf(step_seconds, total_seconds - elapsed)
		sim.advance(state, dt, [])
		elapsed += dt
