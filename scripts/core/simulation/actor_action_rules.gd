class_name ActorActionRules
extends RefCounted

const WorldObjectKindScript = preload("res://scripts/core/world/world_object_kind.gd")

static func get_capable_actor_slots(state: GameState, action_kind: int, target_tile: Variant) -> Array[int]:
	assert(state != null, "state required")
	var out: Array[int] = []
	for actor_slot in range(state.actor_slot_count()):
		if can_actor_do_action(state, actor_slot, action_kind, target_tile):
			out.append(actor_slot)
	return out

static func get_harvestable_object_kinds(state: GameState, actor_slot: int) -> Array[int]:
	assert(state != null, "state required")
	var out: Array[int] = []
	if state.active_action != null or state.active_combat != null:
		return out
	if not state.is_valid_actor_slot(actor_slot) or not state.is_actor_alive(actor_slot):
		return out
	var seen: Dictionary = {}
	for tile_position in state.world_objects.object_tiles():
		var object_kind: Variant = state.get_world_object_kind(tile_position)
		if object_kind == null or seen.has(object_kind):
			continue
		if find_nearest_harvestable_target_tile(state, actor_slot, object_kind) == null:
			continue
		seen[object_kind] = true
		out.append(object_kind)
	return out

static func find_nearest_harvestable_target_tile(state: GameState, actor_slot: int, object_kind: int) -> Variant:
	assert(state != null, "state required")
	if state.active_action != null or state.active_combat != null:
		return null
	if not state.is_valid_actor_slot(actor_slot) or not state.is_actor_alive(actor_slot):
		return null
	var actor_tile: Vector2i = state.get_actor_tile_position(actor_slot)
	var best_tile: Variant = null
	var best_distance: int = 0
	for tile_position in state.world_objects.object_tiles():
		if state.get_world_object_kind(tile_position) != object_kind:
			continue
		if not can_actor_do_action(state, actor_slot, GameActionKind.Kind.HARVEST, tile_position):
			continue
		var distance: int = absi(tile_position.x - actor_tile.x) + absi(tile_position.y - actor_tile.y)
		if best_tile == null or distance < best_distance or (
				distance == best_distance and _is_tile_ordered_before(tile_position, best_tile)):
			best_tile = tile_position
			best_distance = distance
	return best_tile

static func can_actor_do_action(state: GameState, actor_slot: int, action_kind: int, target_tile: Variant) -> bool:
	assert(state != null, "state required")
	if state.active_action != null or state.active_combat != null:
		return false
	if not state.is_valid_actor_slot(actor_slot) or not state.is_actor_alive(actor_slot):
		return false
	match action_kind:
		GameActionKind.Kind.HARVEST:
			return target_tile is Vector2i \
				and state.world.is_walkable(target_tile) \
				and state.has_world_object_kind(target_tile, WorldObjectKindScript.Kind.FRUIT_BUSH)
		_:
			return false

static func _is_tile_ordered_before(a: Vector2i, b: Vector2i) -> bool:
	if a.x != b.x:
		return a.x < b.x
	return a.y < b.y
