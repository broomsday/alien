class_name StartActionCommand
extends GameCommand

var action_kind: int
# null or Vector2i — some action kinds have no target tile.
var target_tile: Variant
var actor_slot: int

func _init(p_action_kind: int, p_target_tile: Variant = null, p_actor_slot: int = 0) -> void:
	action_kind = p_action_kind
	target_tile = p_target_tile
	actor_slot = p_actor_slot
