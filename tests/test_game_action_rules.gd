extends SceneTree

const GameStateFactoryScript = preload("res://scripts/core/simulation/game_state_factory.gd")
const GameActionRulesScript = preload("res://scripts/core/simulation/game_action_rules.gd")
const GameActionKindScript = preload("res://scripts/core/simulation/game_action_kind.gd")
const StartActionCommandScript = preload("res://scripts/core/simulation/start_action_command.gd")
const SimulationStepScript = preload("res://scripts/core/simulation/simulation_step.gd")
const ItemIdScript = preload("res://scripts/core/inventory/item_id.gd")
const WorldTileTypeScript = preload("res://scripts/core/world/world_tile_type.gd")
const EnemyDefinitionScript = preload("res://scripts/core/combat/enemy_definition.gd")
const EnemyKindScript = preload("res://scripts/core/combat/enemy_kind.gd")
const CombatEncounterScript = preload("res://scripts/core/combat/combat_encounter.gd")

func _init() -> void:
	_test_can_start_excavate_only_with_target_tile_that_is_excavatable()
	_test_can_start_build_wall_requires_scrap_and_replaceable_tile()
	_test_can_start_action_returns_false_when_an_action_is_active()
	_test_can_start_build_furnace_requires_recipe_and_excavated_floor()
	_test_can_start_attack_only_during_active_combat()
	_test_can_start_excavate_or_build_returns_false_during_combat()
	print("test_game_action_rules: ok")
	quit(0)

func _test_can_start_excavate_only_with_target_tile_that_is_excavatable() -> void:
	var state: GameState = GameStateFactoryScript.create_new()
	assert(not GameActionRulesScript.can_start_action(state, GameActionKindScript.Kind.EXCAVATE, null),
		"EXCAVATE without target_tile should be invalid")
	var soil_tile: Vector2i = Vector2i(state.player.tile_position.x, state.world.surface_row)
	assert(GameActionRulesScript.can_start_action(state, GameActionKindScript.Kind.EXCAVATE, soil_tile),
		"EXCAVATE on soil at surface row should be valid")
	state.world.set_tile(soil_tile, WorldTileTypeScript.Kind.EXCAVATED_FLOOR)
	assert(not GameActionRulesScript.can_start_action(state, GameActionKindScript.Kind.EXCAVATE, soil_tile),
		"EXCAVATE on excavated tile should be invalid")

func _test_can_start_build_wall_requires_scrap_and_replaceable_tile() -> void:
	var state: GameState = GameStateFactoryScript.create_new()
	var air_tile: Vector2i = Vector2i(state.player.tile_position.x - 1, state.player.tile_position.y)
	assert(state.world.get_tile(air_tile) == WorldTileTypeScript.Kind.AIR, "expected AIR for sanity")
	assert(GameActionRulesScript.can_start_action(state, GameActionKindScript.Kind.BUILD_WALL, air_tile),
		"BUILD_WALL on non-player AIR tile with scrap should be valid")
	assert(not GameActionRulesScript.can_start_action(state, GameActionKindScript.Kind.BUILD_WALL, state.player.tile_position),
		"BUILD_WALL on the player's own tile should be invalid")
	var starting: int = state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL)
	assert(starting > 0, "expected starting scrap")
	assert(state.inventory.try_remove(ItemIdScript.Id.SCRAP_METAL, starting), "drain failed")
	assert(not GameActionRulesScript.can_start_action(state, GameActionKindScript.Kind.BUILD_WALL, air_tile),
		"BUILD_WALL without scrap should be invalid")

func _test_can_start_action_returns_false_when_an_action_is_active() -> void:
	var state: GameState = GameStateFactoryScript.create_new()
	var step: SimulationStep = SimulationStepScript.new()
	step.advance(state, 0.0, [StartActionCommandScript.new(GameActionKindScript.Kind.EXPEDITION)])
	assert(state.active_action != null, "expected active action set up")
	var soil_tile: Vector2i = Vector2i(state.player.tile_position.x, state.world.surface_row)
	assert(not GameActionRulesScript.can_start_action(state, GameActionKindScript.Kind.EXCAVATE, soil_tile),
		"EXCAVATE should fail while an action is active")

func _test_can_start_build_furnace_requires_recipe_and_excavated_floor() -> void:
	var state: GameState = GameStateFactoryScript.create_new()
	var soil_tile: Vector2i = Vector2i(state.player.tile_position.x, state.world.surface_row)
	assert(state.world.get_tile(soil_tile) == WorldTileTypeScript.Kind.SOIL, "expected SOIL")
	assert(not GameActionRulesScript.can_start_action(state, GameActionKindScript.Kind.BUILD_FURNACE, soil_tile),
		"BUILD_FURNACE on SOIL should be invalid")
	state.world.set_tile(soil_tile, WorldTileTypeScript.Kind.EXCAVATED_FLOOR)
	assert(GameActionRulesScript.can_start_action(state, GameActionKindScript.Kind.BUILD_FURNACE, soil_tile),
		"BUILD_FURNACE on EXCAVATED_FLOOR with full recipe should be valid")
	assert(not GameActionRulesScript.can_start_action(state, GameActionKindScript.Kind.BUILD_FURNACE, state.player.tile_position),
		"BUILD_FURNACE on the player's own tile should be invalid")
	# Drain fuel to break recipe affordability.
	var fuel_count: int = state.inventory.get_count(ItemIdScript.Id.FUEL)
	assert(state.inventory.try_remove(ItemIdScript.Id.FUEL, fuel_count), "drain fuel failed")
	assert(not GameActionRulesScript.can_start_action(state, GameActionKindScript.Kind.BUILD_FURNACE, soil_tile),
		"BUILD_FURNACE without fuel should be invalid")
	state.inventory.add(ItemIdScript.Id.FUEL, 1)
	assert(GameActionRulesScript.can_start_action(state, GameActionKindScript.Kind.BUILD_FURNACE, soil_tile),
		"BUILD_FURNACE valid again with restored fuel")
	# Drain scrap below 4 to break recipe affordability.
	var scrap_count: int = state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL)
	assert(state.inventory.try_remove(ItemIdScript.Id.SCRAP_METAL, scrap_count - 3), "drain scrap to 3 failed")
	assert(not GameActionRulesScript.can_start_action(state, GameActionKindScript.Kind.BUILD_FURNACE, soil_tile),
		"BUILD_FURNACE without enough scrap should be invalid")

func _test_can_start_attack_only_during_active_combat() -> void:
	var state: GameState = GameStateFactoryScript.create_new()
	assert(not GameActionRulesScript.can_start_action(state, GameActionKindScript.Kind.ATTACK, null),
		"ATTACK should be invalid outside combat")
	var enemy = EnemyDefinitionScript.new(
		EnemyKindScript.Kind.RAZOR_MAW, "Test", 5, 0, 0, 0)
	state.begin_combat(CombatEncounterScript.new(enemy))
	assert(GameActionRulesScript.can_start_action(state, GameActionKindScript.Kind.ATTACK, null),
		"ATTACK should be valid during combat")

func _test_can_start_excavate_or_build_returns_false_during_combat() -> void:
	var state: GameState = GameStateFactoryScript.create_new()
	var soil_tile: Vector2i = Vector2i(state.player.tile_position.x, state.world.surface_row)
	assert(GameActionRulesScript.can_start_action(state, GameActionKindScript.Kind.EXCAVATE, soil_tile),
		"EXCAVATE on SOIL should be valid out of combat")

	var enemy = EnemyDefinitionScript.new(
		EnemyKindScript.Kind.RAZOR_MAW, "Test", 5, 0, 0, 0)
	state.begin_combat(CombatEncounterScript.new(enemy))

	assert(not GameActionRulesScript.can_start_action(state, GameActionKindScript.Kind.EXCAVATE, soil_tile),
		"EXCAVATE should be invalid during combat")
	var air_tile: Vector2i = Vector2i(state.player.tile_position.x - 1, state.player.tile_position.y)
	assert(state.world.get_tile(air_tile) == WorldTileTypeScript.Kind.AIR, "expected AIR sanity")
	assert(not GameActionRulesScript.can_start_action(state, GameActionKindScript.Kind.BUILD_WALL, air_tile),
		"BUILD_WALL should be invalid during combat")
	state.world.set_tile(soil_tile, WorldTileTypeScript.Kind.EXCAVATED_FLOOR)
	assert(not GameActionRulesScript.can_start_action(state, GameActionKindScript.Kind.BUILD_FURNACE, soil_tile),
		"BUILD_FURNACE should be invalid during combat")
	assert(not GameActionRulesScript.can_start_action(state, GameActionKindScript.Kind.EXPEDITION, null),
		"EXPEDITION should be invalid during combat")
