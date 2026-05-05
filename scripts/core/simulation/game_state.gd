class_name GameState
extends RefCounted

# Phase 4 adds expedition reward state (last_expedition_outcome,
# pending_expedition_outcome, expeditions_completed,
# complete_expedition). Phase 5 adds furnace bookkeeping
# (try_build_furnace, try_fuel_furnace,
# get_furnace_burn_seconds_remaining, has_active_furnace_at,
# active_furnace_count, advance_furnaces, get_furnace_heat_bonus).
# Phase 6 adds the combat side (active_combat,
# last_combat_round_outcome, combat_encounters_won,
# begin_combat / record_combat_round / win_combat / lose_combat).
# The pending_expedition_outcome field — phase-4 dormant — comes
# alive here: begin_combat stashes the expedition reward, win_combat
# applies it on victory, lose_combat drops it on defeat.

const _LCG_MULT: int = 1664525
const _LCG_INC: int = 1013904223
const _U32_MASK: int = 0xFFFFFFFF
const WorldObjectMapScript = preload("res://scripts/core/world/world_object_map.gd")
const WorldObjectKindScript = preload("res://scripts/core/world/world_object_kind.gd")

var player: PlayerState
var world: WorldGrid
var world_objects: WorldObjectMapScript
var inventory: InventoryState
var clock: ClockState

var active_action: GameAction = null
# null or GameActionKind.Kind enum value
var last_completed_action_kind: Variant = null
var current_ambient_temperature: float = 0.0
var current_outdoor_temperature: float = 0.0
var current_ambient_gas: float = 0.0
var is_player_indoors: bool = false
var is_player_underground: bool = false
var expedition_status: int = ExpeditionStatus.Kind.NONE
# null or ExpeditionOutcome
var last_expedition_outcome: Variant = null
# null or ExpeditionOutcome — used by phase 6 to hold expedition loot
# while combat is in progress.
var pending_expedition_outcome: Variant = null
var expeditions_completed: int = 0
# null or CombatEncounter — non-null while a fight is in progress.
var active_combat: Variant = null
# null or CombatRoundOutcome — cleared on begin_combat to avoid stale HUD.
var last_combat_round_outcome: Variant = null
var combat_encounters_won: int = 0
var last_harvest_rewards: Dictionary = {}

var _random_state: int

# Vector2i -> float seconds remaining on each furnace's current burn.
var _furnace_burn_seconds_remaining: Dictionary = {}

func _init(
		p_player: PlayerState,
		p_world: WorldGrid,
		p_inventory: InventoryState,
		p_clock: ClockState,
		p_random_seed: int = 0x00C0FFEE,
		p_world_objects: WorldObjectMapScript = null) -> void:
	assert(p_player != null, "player required")
	assert(p_world != null, "world required")
	assert(p_inventory != null, "inventory required")
	assert(p_clock != null, "clock required")
	player = p_player
	world = p_world
	world_objects = p_world_objects if p_world_objects != null else WorldObjectMapScript.new()
	inventory = p_inventory
	clock = p_clock
	_random_state = (1 if p_random_seed == 0 else p_random_seed) & _U32_MASK

func try_start_action(action: GameAction) -> bool:
	assert(action != null, "action required")
	if active_action != null:
		return false
	if action.kind == GameActionKind.Kind.HARVEST and action.target_tile is Vector2i:
		move_actor_to(action.actor_slot, action.target_tile)
	active_action = action
	if action.kind == GameActionKind.Kind.EXPEDITION:
		expedition_status = ExpeditionStatus.Kind.AWAY
		last_expedition_outcome = null
		pending_expedition_outcome = null
	return true

func cancel_action() -> void:
	if active_action != null and active_action.kind == GameActionKind.Kind.EXPEDITION:
		expedition_status = ExpeditionStatus.Kind.INTERRUPTED
		last_expedition_outcome = null
		pending_expedition_outcome = null
	active_action = null

func set_environment_status(ambient_temperature: float, p_is_indoors: bool, p_is_underground: bool, ambient_gas: float = 0.0) -> void:
	current_ambient_temperature = ambient_temperature
	current_ambient_gas = ambient_gas
	is_player_indoors = p_is_indoors
	is_player_underground = p_is_underground

func actor_slot_count() -> int:
	return 1

func is_valid_actor_slot(actor_slot: int) -> bool:
	return actor_slot == 0

func is_actor_alive(actor_slot: int) -> bool:
	return is_valid_actor_slot(actor_slot) and player.is_alive()

func get_actor_display_name(actor_slot: int) -> String:
	assert(is_valid_actor_slot(actor_slot), "invalid actor_slot")
	return "Crew %02d" % [actor_slot + 1]

func get_actor_portrait_filename(actor_slot: int) -> String:
	assert(is_valid_actor_slot(actor_slot), "invalid actor_slot")
	return player.portrait_filename

func get_actor_physique(actor_slot: int) -> int:
	assert(is_valid_actor_slot(actor_slot), "invalid actor_slot")
	return player.physique

func get_actor_aptitude(actor_slot: int) -> int:
	assert(is_valid_actor_slot(actor_slot), "invalid actor_slot")
	return player.aptitude

func get_actor_tile_position(actor_slot: int) -> Vector2i:
	assert(is_valid_actor_slot(actor_slot), "invalid actor_slot")
	return player.tile_position

func move_actor_to(actor_slot: int, tile_position: Vector2i) -> void:
	assert(is_valid_actor_slot(actor_slot), "invalid actor_slot")
	player.move_to(tile_position)

func get_world_object_kind(tile_position: Vector2i) -> Variant:
	return world_objects.get_object_kind(tile_position)

func has_world_object_kind(tile_position: Vector2i, object_kind: int) -> bool:
	return world_objects.has_object_kind(tile_position, object_kind)

func count_world_objects(object_kind: int) -> int:
	return world_objects.count_kind(object_kind)

func harvest_fruit_bush(tile_position: Vector2i) -> Dictionary:
	last_harvest_rewards = {}
	if not has_world_object_kind(tile_position, WorldObjectKindScript.Kind.FRUIT_BUSH):
		return last_harvest_rewards
	var berries: int = _roll_range_inclusive(
		GameBalance.FRUIT_BUSH_BERRIES_MIN,
		GameBalance.FRUIT_BUSH_BERRIES_MAX)
	var wood: int = _roll_range_inclusive(
		GameBalance.FRUIT_BUSH_WOOD_MIN,
		GameBalance.FRUIT_BUSH_WOOD_MAX)
	var berry_seeds: int = _roll_range_inclusive(
		GameBalance.FRUIT_BUSH_BERRY_SEEDS_MIN,
		GameBalance.FRUIT_BUSH_BERRY_SEEDS_MAX)
	inventory.add(ItemId.Id.BERRIES, berries)
	inventory.add(ItemId.Id.WOOD, wood)
	inventory.add(ItemId.Id.BERRY_SEEDS, berry_seeds)
	world_objects.remove_object_at(tile_position)
	last_harvest_rewards = {
		"berries": berries,
		"wood": wood,
		"berry_seeds": berry_seeds,
	}
	return last_harvest_rewards

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

func complete_active_action() -> void:
	if active_action == null:
		return
	var completed: GameAction = active_action
	GameActionRules.complete_action(self, completed)
	last_completed_action_kind = completed.kind
	active_action = null

func complete_expedition(outcome: ExpeditionOutcome) -> void:
	assert(outcome != null, "outcome required")
	outcome.apply_to(inventory)
	last_expedition_outcome = outcome
	pending_expedition_outcome = null
	expedition_status = ExpeditionStatus.Kind.RETURNED
	expeditions_completed += 1

func begin_combat(encounter, p_pending_expedition_outcome: Variant = null) -> void:
	assert(encounter != null, "encounter required")
	active_combat = encounter
	pending_expedition_outcome = p_pending_expedition_outcome
	last_combat_round_outcome = null
	last_expedition_outcome = null
	expedition_status = ExpeditionStatus.Kind.AWAY

func record_combat_round(outcome) -> void:
	assert(outcome != null, "outcome required")
	last_combat_round_outcome = outcome

func win_combat(outcome) -> void:
	record_combat_round(outcome)
	active_combat = null
	combat_encounters_won += 1
	if pending_expedition_outcome != null:
		complete_expedition(pending_expedition_outcome)
		return
	expedition_status = ExpeditionStatus.Kind.RETURNED

func lose_combat(outcome) -> void:
	record_combat_round(outcome)
	active_combat = null
	pending_expedition_outcome = null
	last_expedition_outcome = null
	expedition_status = ExpeditionStatus.Kind.INTERRUPTED

func next_random_int(max_exclusive: int) -> int:
	assert(max_exclusive > 0, "max_exclusive must be positive")
	_random_state = ((_random_state * _LCG_MULT) + _LCG_INC) & _U32_MASK
	return _random_state % max_exclusive

func _roll_range_inclusive(min_value: int, max_value: int) -> int:
	assert(max_value >= min_value, "max_value must be >= min_value")
	return min_value + next_random_int((max_value - min_value) + 1)
