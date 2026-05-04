extends SceneTree

const GameStateFactoryScript = preload("res://scripts/core/simulation/game_state_factory.gd")
const SimulationStepScript = preload("res://scripts/core/simulation/simulation_step.gd")
const StartActionCommandScript = preload("res://scripts/core/simulation/start_action_command.gd")
const CancelActionCommandScript = preload("res://scripts/core/simulation/cancel_action_command.gd")
const MovePlayerCommandScript = preload("res://scripts/core/simulation/move_player_command.gd")
const FuelFurnaceCommandScript = preload("res://scripts/core/simulation/fuel_furnace_command.gd")
const CraftRecipeCommandScript = preload("res://scripts/core/simulation/craft_recipe_command.gd")
const GameActionKindScript = preload("res://scripts/core/simulation/game_action_kind.gd")
const ExpeditionStatusScript = preload("res://scripts/core/simulation/expedition_status.gd")
const ExpeditionOutcomeScript = preload("res://scripts/core/simulation/expedition_outcome.gd")
const ExpeditionEncounterKindScript = preload("res://scripts/core/simulation/expedition_encounter_kind.gd")
const WorldTileTypeScript = preload("res://scripts/core/world/world_tile_type.gd")
const ItemIdScript = preload("res://scripts/core/inventory/item_id.gd")
const RecipeIdScript = preload("res://scripts/core/crafting/recipe_id.gd")
const EquippedWeaponScript = preload("res://scripts/core/gameplay/equipped_weapon.gd")
const EnemyDefinitionScript = preload("res://scripts/core/combat/enemy_definition.gd")
const EnemyKindScript = preload("res://scripts/core/combat/enemy_kind.gd")
const CombatEncounterScript = preload("res://scripts/core/combat/combat_encounter.gd")

func _init() -> void:
	_test_advance_starts_and_completes_action_over_time()
	_test_advance_when_action_is_already_running_ignores_new_start()
	_test_advance_when_expedition_starts_sets_away_status_and_consumes_time()
	_test_advance_when_expedition_completes_adds_rewards_exactly_once()
	_test_advance_when_expedition_cancelled_does_not_apply_rewards()
	_test_advance_when_excavation_completes_converts_soil_to_excavated_floor()
	_test_advance_when_build_wall_completes_consumes_scrap_and_sets_wall_tile()
	_test_advance_when_build_target_is_invalid_does_not_start_action()
	_test_advance_when_move_command_targets_walkable_tile_moves_player()
	_test_advance_when_move_command_targets_blocked_tile_does_not_move()
	_test_advance_when_build_furnace_completes_consumes_scrap_and_sets_furnace_tile()
	_test_advance_when_fuel_furnace_command_lights_furnace()
	_test_advance_when_fuel_furnace_command_targets_non_furnace_does_nothing()
	_test_advance_when_craft_recipe_command_simple_weapon_equips_weapon()
	_test_advance_when_attack_action_records_combat_round()
	_test_advance_when_attack_defeats_enemy_applies_pending_expedition_reward()
	_test_advance_when_combat_active_ignores_move_and_craft_commands()
	_test_advance_when_expedition_resolves_to_hostile_animal_begins_combat()
	print("test_simulation_step: ok")
	quit(0)

func _test_advance_starts_and_completes_action_over_time() -> void:
	var state: GameState = GameStateFactoryScript.create_new()
	var step: SimulationStep = SimulationStepScript.new()

	step.advance(state, 1.25, [StartActionCommandScript.new(GameActionKindScript.Kind.EXPEDITION)])

	assert(state.active_action != null, "expected active action after first advance")
	assert(state.active_action.kind == GameActionKindScript.Kind.EXPEDITION,
		"expected expedition action")
	assert(absf(state.active_action.progress() - 0.25) < 0.0001,
		"expected progress ~0.25, got %f" % state.active_action.progress())

	step.advance(state, 3.75, [])

	assert(state.active_action == null, "expected action cleared after completion")
	assert(state.last_completed_action_kind == GameActionKindScript.Kind.EXPEDITION,
		"expected last_completed_action_kind == EXPEDITION")

func _test_advance_when_action_is_already_running_ignores_new_start() -> void:
	var state: GameState = GameStateFactoryScript.create_new()
	var step: SimulationStep = SimulationStepScript.new()

	step.advance(state, 0.0, [
		StartActionCommandScript.new(GameActionKindScript.Kind.EXPEDITION),
		StartActionCommandScript.new(GameActionKindScript.Kind.ATTACK),
	])

	assert(state.active_action != null, "expected an active action")
	assert(state.active_action.kind == GameActionKindScript.Kind.EXPEDITION,
		"expected first command to win, got kind=%d" % state.active_action.kind)

func _test_advance_when_expedition_starts_sets_away_status_and_consumes_time() -> void:
	var state: GameState = GameStateFactoryScript.create_new()
	var step: SimulationStep = SimulationStepScript.new()
	var starting_time: float = state.clock.time_of_day_seconds

	step.advance(state, 2.0, [StartActionCommandScript.new(GameActionKindScript.Kind.EXPEDITION)])

	assert(state.active_action != null, "expected active action after start")
	assert(state.active_action.kind == GameActionKindScript.Kind.EXPEDITION,
		"expected expedition action")
	assert(state.expedition_status == ExpeditionStatusScript.Kind.AWAY,
		"expected AWAY, got %d" % state.expedition_status)
	assert(state.clock.time_of_day_seconds > starting_time,
		"expected clock to advance past %f, got %f" % [starting_time, state.clock.time_of_day_seconds])

func _test_advance_when_expedition_completes_adds_rewards_exactly_once() -> void:
	var state: GameState = GameStateFactoryScript.create_new(1)
	var step: SimulationStep = SimulationStepScript.new()
	var starting_scrap: int = state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL)
	var starting_fuel: int = state.inventory.get_count(ItemIdScript.Id.FUEL)
	var starting_food: int = state.inventory.get_count(ItemIdScript.Id.CANNED_FOOD)

	step.advance(state, 5.0, [StartActionCommandScript.new(GameActionKindScript.Kind.EXPEDITION)])

	assert(state.last_expedition_outcome != null, "expected last_expedition_outcome to be set")
	assert(state.expedition_status == ExpeditionStatusScript.Kind.RETURNED,
		"expected RETURNED, got %d" % state.expedition_status)
	assert(state.expeditions_completed == 1,
		"expected expeditions_completed == 1, got %d" % state.expeditions_completed)
	var outcome: ExpeditionOutcome = state.last_expedition_outcome
	var expected_scrap: int = starting_scrap + outcome.scrap_metal
	var expected_fuel: int = starting_fuel + outcome.fuel
	var expected_food: int = starting_food + outcome.canned_food
	assert(state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL) == expected_scrap,
		"expected scrap %d, got %d" % [expected_scrap, state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL)])
	assert(state.inventory.get_count(ItemIdScript.Id.FUEL) == expected_fuel,
		"expected fuel %d, got %d" % [expected_fuel, state.inventory.get_count(ItemIdScript.Id.FUEL)])
	assert(state.inventory.get_count(ItemIdScript.Id.CANNED_FOOD) == expected_food,
		"expected food %d, got %d" % [expected_food, state.inventory.get_count(ItemIdScript.Id.CANNED_FOOD)])

	step.advance(state, 5.0, [])

	assert(state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL) == expected_scrap,
		"rewards reapplied: scrap changed to %d" % state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL))
	assert(state.inventory.get_count(ItemIdScript.Id.FUEL) == expected_fuel,
		"rewards reapplied: fuel changed to %d" % state.inventory.get_count(ItemIdScript.Id.FUEL))
	assert(state.inventory.get_count(ItemIdScript.Id.CANNED_FOOD) == expected_food,
		"rewards reapplied: food changed to %d" % state.inventory.get_count(ItemIdScript.Id.CANNED_FOOD))
	assert(state.expeditions_completed == 1,
		"expected expeditions_completed to remain 1, got %d" % state.expeditions_completed)

func _test_advance_when_expedition_cancelled_does_not_apply_rewards() -> void:
	var state: GameState = GameStateFactoryScript.create_new()
	var step: SimulationStep = SimulationStepScript.new()
	var starting_scrap: int = state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL)

	step.advance(state, 1.0, [StartActionCommandScript.new(GameActionKindScript.Kind.EXPEDITION)])
	step.advance(state, 0.0, [CancelActionCommandScript.new()])

	assert(state.expedition_status == ExpeditionStatusScript.Kind.INTERRUPTED,
		"expected INTERRUPTED, got %d" % state.expedition_status)
	assert(state.active_action == null, "expected no active action after cancel")
	assert(state.last_expedition_outcome == null,
		"expected last_expedition_outcome cleared on cancel")
	assert(state.expeditions_completed == 0,
		"expected expeditions_completed == 0, got %d" % state.expeditions_completed)
	assert(state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL) == starting_scrap,
		"expected scrap unchanged, got %d" % state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL))

func _test_advance_when_excavation_completes_converts_soil_to_excavated_floor() -> void:
	var state: GameState = GameStateFactoryScript.create_new()
	var step: SimulationStep = SimulationStepScript.new()
	var target: Vector2i = Vector2i(state.player.tile_position.x, state.world.surface_row)
	assert(state.world.get_tile(target) == WorldTileTypeScript.Kind.SOIL, "expected SOIL target")

	step.advance(state, 2.0, [StartActionCommandScript.new(GameActionKindScript.Kind.EXCAVATE, target)])

	assert(state.world.get_tile(target) == WorldTileTypeScript.Kind.EXCAVATED_FLOOR,
		"expected target tile excavated")
	assert(state.last_completed_action_kind == GameActionKindScript.Kind.EXCAVATE,
		"expected last_completed_action_kind == EXCAVATE")

func _test_advance_when_build_wall_completes_consumes_scrap_and_sets_wall_tile() -> void:
	var state: GameState = GameStateFactoryScript.create_new()
	var step: SimulationStep = SimulationStepScript.new()
	var target: Vector2i = Vector2i(state.player.tile_position.x + 1, state.player.tile_position.y)
	assert(state.world.get_tile(target) == WorldTileTypeScript.Kind.AIR, "expected AIR target")
	var starting_scrap: int = state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL)

	step.advance(state, 3.0, [StartActionCommandScript.new(GameActionKindScript.Kind.BUILD_WALL, target)])

	assert(state.world.get_tile(target) == WorldTileTypeScript.Kind.SCRAP_METAL_WALL,
		"expected target tile to be SCRAP_METAL_WALL")
	assert(state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL) == starting_scrap - 1,
		"expected one scrap consumed")

func _test_advance_when_build_target_is_invalid_does_not_start_action() -> void:
	var state: GameState = GameStateFactoryScript.create_new()
	var step: SimulationStep = SimulationStepScript.new()
	var invalid_target: Vector2i = Vector2i(state.player.tile_position.x, state.world.surface_row)
	assert(state.world.get_tile(invalid_target) == WorldTileTypeScript.Kind.SOIL, "expected SOIL")

	step.advance(state, 0.0, [StartActionCommandScript.new(GameActionKindScript.Kind.BUILD_WALL, invalid_target)])

	assert(state.active_action == null, "expected no active action")
	assert(state.world.get_tile(invalid_target) == WorldTileTypeScript.Kind.SOIL, "tile should remain SOIL")

func _test_advance_when_move_command_targets_walkable_tile_moves_player() -> void:
	var state: GameState = GameStateFactoryScript.create_new()
	var step: SimulationStep = SimulationStepScript.new()
	var destination: Vector2i = Vector2i(state.player.tile_position.x + 2, state.player.tile_position.y)
	assert(state.world.is_walkable(destination), "expected walkable destination")

	step.advance(state, 0.0, [MovePlayerCommandScript.new(destination)])

	assert(state.player.tile_position == destination,
		"expected player to move to %s, got %s" % [destination, state.player.tile_position])

func _test_advance_when_move_command_targets_blocked_tile_does_not_move() -> void:
	var state: GameState = GameStateFactoryScript.create_new()
	var step: SimulationStep = SimulationStepScript.new()
	var origin: Vector2i = state.player.tile_position
	var blocked: Vector2i = Vector2i(state.player.tile_position.x, state.world.surface_row + 1)
	assert(state.world.get_tile(blocked) == WorldTileTypeScript.Kind.SOIL, "expected SOIL destination")

	step.advance(state, 0.0, [MovePlayerCommandScript.new(blocked)])

	assert(state.player.tile_position == origin,
		"expected player to stay at %s, got %s" % [origin, state.player.tile_position])

func _test_advance_when_build_furnace_completes_consumes_scrap_and_sets_furnace_tile() -> void:
	var state: GameState = GameStateFactoryScript.create_new()
	var step: SimulationStep = SimulationStepScript.new()
	var target: Vector2i = Vector2i(state.player.tile_position.x, state.world.surface_row)
	assert(state.world.get_tile(target) == WorldTileTypeScript.Kind.SOIL, "expected SOIL target")
	step.advance(state, 2.0, [StartActionCommandScript.new(GameActionKindScript.Kind.EXCAVATE, target)])
	assert(state.world.get_tile(target) == WorldTileTypeScript.Kind.EXCAVATED_FLOOR,
		"expected target excavated before BUILD_FURNACE")

	var starting_scrap: int = state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL)
	var starting_fuel: int = state.inventory.get_count(ItemIdScript.Id.FUEL)

	step.advance(state, 4.0, [StartActionCommandScript.new(GameActionKindScript.Kind.BUILD_FURNACE, target)])

	assert(state.world.get_tile(target) == WorldTileTypeScript.Kind.FURNACE,
		"expected target to be FURNACE")
	assert(state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL) == starting_scrap - 4,
		"expected 4 scrap consumed, got %d" %
			(starting_scrap - state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL)))
	assert(state.inventory.get_count(ItemIdScript.Id.FUEL) == starting_fuel - 1,
		"expected 1 fuel consumed, got %d" %
			(starting_fuel - state.inventory.get_count(ItemIdScript.Id.FUEL)))
	assert(not state.has_active_furnace_at(target),
		"freshly built furnace should not be active until fueled")

func _test_advance_when_fuel_furnace_command_lights_furnace() -> void:
	var state: GameState = GameStateFactoryScript.create_new()
	var step: SimulationStep = SimulationStepScript.new()
	var target: Vector2i = Vector2i(state.player.tile_position.x, state.world.surface_row)
	step.advance(state, 2.0, [StartActionCommandScript.new(GameActionKindScript.Kind.EXCAVATE, target)])
	step.advance(state, 4.0, [StartActionCommandScript.new(GameActionKindScript.Kind.BUILD_FURNACE, target)])
	assert(state.world.get_tile(target) == WorldTileTypeScript.Kind.FURNACE, "expected FURNACE")

	var starting_fuel: int = state.inventory.get_count(ItemIdScript.Id.FUEL)
	step.advance(state, 0.0, [FuelFurnaceCommandScript.new(target)])

	assert(state.has_active_furnace_at(target), "expected furnace to be active after fueling")
	assert(state.inventory.get_count(ItemIdScript.Id.FUEL) == starting_fuel - 1,
		"expected fuel to drop by 1")
	assert(state.get_furnace_burn_seconds_remaining(target) > 0.0,
		"expected positive burn seconds")

func _test_advance_when_fuel_furnace_command_targets_non_furnace_does_nothing() -> void:
	var state: GameState = GameStateFactoryScript.create_new()
	var step: SimulationStep = SimulationStepScript.new()
	var soil_tile: Vector2i = Vector2i(state.player.tile_position.x, state.world.surface_row + 1)
	assert(state.world.get_tile(soil_tile) == WorldTileTypeScript.Kind.SOIL, "expected SOIL precondition")

	var starting_fuel: int = state.inventory.get_count(ItemIdScript.Id.FUEL)
	step.advance(state, 0.0, [FuelFurnaceCommandScript.new(soil_tile)])

	assert(state.inventory.get_count(ItemIdScript.Id.FUEL) == starting_fuel,
		"fuel should be unchanged when target isn't a furnace")
	assert(state.active_furnace_count() == 0, "no furnace should exist")

func _test_advance_when_craft_recipe_command_simple_weapon_equips_weapon() -> void:
	var state: GameState = GameStateFactoryScript.create_new()
	var step: SimulationStep = SimulationStepScript.new()
	var starting_scrap: int = state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL)

	step.advance(state, 0.0, [CraftRecipeCommandScript.new(RecipeIdScript.Id.SIMPLE_WEAPON)])

	assert(state.player.equipped_weapon == EquippedWeaponScript.Slot.SIMPLE_WEAPON,
		"expected SIMPLE_WEAPON equipped")
	assert(state.inventory.get_count(ItemIdScript.Id.SIMPLE_WEAPON) == 1,
		"expected 1 SIMPLE_WEAPON in inventory")
	assert(state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL) == starting_scrap - 3,
		"expected 3 scrap consumed, got %d" %
			(starting_scrap - state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL)))

func _test_advance_when_attack_action_records_combat_round() -> void:
	var state: GameState = GameStateFactoryScript.create_new(5)
	var step: SimulationStep = SimulationStepScript.new()
	var enemy = EnemyDefinitionScript.new(
		EnemyKindScript.Kind.RAZOR_MAW, "Test Beast", 9, 0, 0, 0)
	state.begin_combat(CombatEncounterScript.new(enemy))

	step.advance(state, 1.5, [StartActionCommandScript.new(GameActionKindScript.Kind.ATTACK)])

	assert(state.active_action == null, "expected ATTACK action cleared after 1.5s")
	assert(state.last_combat_round_outcome != null, "expected a combat round recorded")
	assert(state.active_combat != null, "health-9 beast should not die in one round")

func _test_advance_when_attack_defeats_enemy_applies_pending_expedition_reward() -> void:
	var state: GameState = GameStateFactoryScript.create_new(5)
	var step: SimulationStep = SimulationStepScript.new()
	var starting_scrap: int = state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL)
	var pending: ExpeditionOutcome = ExpeditionOutcomeScript.new(
		3, 1, 1, ExpeditionEncounterKindScript.Kind.HOSTILE_ANIMAL)
	var enemy = EnemyDefinitionScript.new(
		EnemyKindScript.Kind.RAZOR_MAW, "Glass", 1, 0, 0, 0)
	state.begin_combat(CombatEncounterScript.new(enemy), pending)

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
	var enemy = EnemyDefinitionScript.new(
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
