class_name GameActionRules
extends RefCounted

const EnemyCatalogScript = preload("res://scripts/core/combat/enemy_catalog.gd")
const CombatEncounterScript = preload("res://scripts/core/combat/combat_encounter.gd")
const CombatResolverScript = preload("res://scripts/core/combat/combat_resolver.gd")
const ActorActionRulesScript = preload("res://scripts/core/simulation/actor_action_rules.gd")

# Phase 6 adds the active_combat short-circuit at the top of
# can_start_action: while combat is in progress, only ATTACK is
# valid. The complete_action EXPEDITION branch dispatches
# HOSTILE_ANIMAL into state.begin_combat; the ATTACK branch calls
# CombatResolver.resolve_attack.

static func can_start_action(state: GameState, action_kind: int, target_tile: Variant, actor_slot: int = 0) -> bool:
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
		GameActionKind.Kind.HARVEST:
			return ActorActionRulesScript.can_actor_do_action(
				state,
				actor_slot,
				action_kind,
				target_tile)
		GameActionKind.Kind.ATTACK:
			return false
		_:
			return true

static func try_create_action(state: GameState, command: StartActionCommand) -> GameAction:
	if not can_start_action(state, command.action_kind, command.target_tile, command.actor_slot):
		return null
	return GameAction.new(
		command.action_kind,
		_get_duration_seconds(command.action_kind),
		_get_description(command.action_kind),
		command.target_tile,
		command.actor_slot)

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
				var enemy = EnemyCatalogScript.get_for_encounter(outcome.encounter_kind)
				state.begin_combat(CombatEncounterScript.new(enemy), outcome)
		GameActionKind.Kind.HARVEST:
			if action.target_tile is Vector2i:
				state.harvest_fruit_bush(action.target_tile)
		GameActionKind.Kind.ATTACK:
			CombatResolverScript.resolve_attack(state)
		_:
			pass

static func _try_pay_recipe(state: GameState, recipe_id: int) -> bool:
	var recipe: RecipeDefinition = RecipeCatalog.get_recipe(recipe_id)
	for cost in recipe.costs:
		if not state.inventory.try_remove(cost.item_id, cost.amount):
			return false
	return true

static func _get_duration_seconds(action_kind: int) -> float:
	match action_kind:
		GameActionKind.Kind.EXCAVATE:
			return 1.75
		GameActionKind.Kind.BUILD_WALL:
			return 2.5
		GameActionKind.Kind.BUILD_FURNACE:
			return 3.0
		GameActionKind.Kind.EXPEDITION:
			return 5.0
		GameActionKind.Kind.CRAFT:
			return 2.0
		GameActionKind.Kind.HARVEST:
			return GameBalance.HARVEST_DURATION_REAL_SECONDS
		GameActionKind.Kind.ATTACK:
			return 1.5
		_:
			assert(false, "unknown action_kind")
			return 1.0

static func _get_description(action_kind: int) -> String:
	match action_kind:
		GameActionKind.Kind.EXCAVATE:
			return "Excavating"
		GameActionKind.Kind.BUILD_WALL:
			return "Building Wall"
		GameActionKind.Kind.BUILD_FURNACE:
			return "Building Furnace"
		GameActionKind.Kind.EXPEDITION:
			return "Expedition"
		GameActionKind.Kind.CRAFT:
			return "Crafting"
		GameActionKind.Kind.HARVEST:
			return "Harvesting"
		GameActionKind.Kind.ATTACK:
			return "Attacking"
		_:
			return "Unknown"
