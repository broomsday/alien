extends SceneTree

const ActorActionRulesScript = preload("res://scripts/core/simulation/actor_action_rules.gd")
const GameActionKindScript = preload("res://scripts/core/simulation/game_action_kind.gd")
const GameStateFactoryScript = preload("res://scripts/core/simulation/game_state_factory.gd")
const StartActionCommandScript = preload("res://scripts/core/simulation/start_action_command.gd")
const SimulationStepScript = preload("res://scripts/core/simulation/simulation_step.gd")
const WorldObjectKindScript = preload("res://scripts/core/world/world_object_kind.gd")

func _init() -> void:
	_test_get_capable_actor_slots_returns_player_for_fruit_bush()
	_test_get_harvestable_object_kinds_returns_fruit_bush()
	_test_find_nearest_harvestable_target_tile_returns_closest_bush()
	_test_get_capable_actor_slots_returns_empty_when_an_action_is_active()
	print("test_actor_action_rules: ok")
	quit(0)

func _test_get_capable_actor_slots_returns_player_for_fruit_bush() -> void:
	var state: GameState = GameStateFactoryScript.create_new()
	var bush_tile: Vector2i = _first_fruit_bush_tile(state)
	var actor_slots: Array[int] = ActorActionRulesScript.get_capable_actor_slots(
		state,
		GameActionKindScript.Kind.HARVEST,
		bush_tile)
	assert(actor_slots == [0], "expected player slot [0], got %s" % [actor_slots])

func _test_get_capable_actor_slots_returns_empty_when_an_action_is_active() -> void:
	var state: GameState = GameStateFactoryScript.create_new()
	var step: SimulationStep = SimulationStepScript.new()
	var bush_tile: Vector2i = _first_fruit_bush_tile(state)
	step.advance(state, 0.0, [
		StartActionCommandScript.new(GameActionKindScript.Kind.EXPEDITION),
	])
	var actor_slots: Array[int] = ActorActionRulesScript.get_capable_actor_slots(
		state,
		GameActionKindScript.Kind.HARVEST,
		bush_tile)
	assert(actor_slots.is_empty(), "expected no capable actors while busy, got %s" % [actor_slots])

func _test_get_harvestable_object_kinds_returns_fruit_bush() -> void:
	var state: GameState = GameStateFactoryScript.create_new()
	var object_kinds: Array[int] = ActorActionRulesScript.get_harvestable_object_kinds(state, 0)
	assert(object_kinds == [WorldObjectKindScript.Kind.FRUIT_BUSH],
		"expected [FRUIT_BUSH], got %s" % [object_kinds])

func _test_find_nearest_harvestable_target_tile_returns_closest_bush() -> void:
	var state: GameState = GameStateFactoryScript.create_new()
	var nearest_tile: Variant = ActorActionRulesScript.find_nearest_harvestable_target_tile(
		state,
		0,
		WorldObjectKindScript.Kind.FRUIT_BUSH)
	assert(nearest_tile is Vector2i, "expected a Vector2i nearest tile")
	var nearest_distance: int = _tile_distance(state.player.tile_position, nearest_tile)
	var expected_distance: int = 999999
	for tile_position in state.world_objects.object_tiles():
		if not state.has_world_object_kind(tile_position, WorldObjectKindScript.Kind.FRUIT_BUSH):
			continue
		expected_distance = mini(expected_distance, _tile_distance(state.player.tile_position, tile_position))
	assert(nearest_distance == expected_distance,
		"expected nearest bush distance %d, got %d at %s" % [expected_distance, nearest_distance, nearest_tile])

func _first_fruit_bush_tile(state: GameState) -> Vector2i:
	for tile_position in state.world_objects.object_tiles():
		if state.has_world_object_kind(tile_position, WorldObjectKindScript.Kind.FRUIT_BUSH):
			return tile_position
	assert(false, "expected at least one fruit bush")
	return Vector2i.ZERO

func _tile_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
