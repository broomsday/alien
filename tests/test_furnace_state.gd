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
	assert(state.world.get_tile(soil_tile) == WorldTileTypeScript.Kind.SOIL,
		"expected SOIL precondition")
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
	var state: GameState = _make_state(1)
	var furnace_tile: Vector2i = Vector2i(5, 5)
	state.world.set_tile(furnace_tile, WorldTileTypeScript.Kind.EXCAVATED_FLOOR)
	state.try_build_furnace(furnace_tile)
	var air_tile: Vector2i = Vector2i(5, 1)
	assert(not state.try_fuel_furnace(air_tile, 90.0),
		"fueling AIR tile should fail")
	assert(state.inventory.get_count(ItemIdScript.Id.FUEL) == 1,
		"fuel must not be consumed when target tile isn't a furnace")
	assert(state.try_fuel_furnace(furnace_tile, 90.0),
		"fueling a real furnace with fuel should succeed")
	assert(state.has_active_furnace_at(furnace_tile),
		"furnace should be active after fueling")
	assert(state.get_furnace_burn_seconds_remaining(furnace_tile) == 90.0,
		"expected 90 burn seconds, got %f" %
			state.get_furnace_burn_seconds_remaining(furnace_tile))
	assert(state.inventory.get_count(ItemIdScript.Id.FUEL) == 0,
		"fuel should be consumed")
	assert(not state.try_fuel_furnace(furnace_tile, 90.0),
		"fueling without fuel should fail")

func _test_advance_furnaces_decreases_burn_remaining() -> void:
	var state: GameState = _make_state(1)
	var furnace_tile: Vector2i = Vector2i(5, 5)
	state.world.set_tile(furnace_tile, WorldTileTypeScript.Kind.EXCAVATED_FLOOR)
	state.try_build_furnace(furnace_tile)
	state.try_fuel_furnace(furnace_tile, 90.0)
	state.advance_furnaces(30.0)
	assert(state.get_furnace_burn_seconds_remaining(furnace_tile) == 60.0,
		"expected 60 burn seconds after 30s advance, got %f" %
			state.get_furnace_burn_seconds_remaining(furnace_tile))
	state.advance_furnaces(120.0)
	assert(state.get_furnace_burn_seconds_remaining(furnace_tile) == 0.0,
		"burn seconds should clamp to 0")
	assert(not state.has_active_furnace_at(furnace_tile),
		"burned-out furnace should be inactive")

func _test_get_furnace_heat_bonus_distance_falloff() -> void:
	var state: GameState = _make_state(1)
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
	assert(state.get_furnace_heat_bonus(Vector2i(6, 6)) == 10.0,
		"expected +10 at Manhattan-2 diagonal")

func _test_get_furnace_heat_bonus_after_burn_out_returns_zero() -> void:
	var state: GameState = _make_state(1)
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
