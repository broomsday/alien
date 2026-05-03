class_name SimulationStep
extends RefCounted

# Phase 6 adds the active_combat == null guards on the deferred
# commands (ConsumeFoodCommand, CraftRecipeCommand,
# FuelFurnaceCommand, MovePlayerCommand) so a fight cannot be
# sidestepped by interleaving a craft / fuel / move. The
# StartActionCommand branch is unguarded — GameActionRules already
# limits combat-active starts to ATTACK.

const _FUEL_FURNACE_SECONDS: float = 90.0

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
