class_name StartActionCommand
extends GameCommand

var action_kind: int
# null or Vector2i — some action kinds have no target tile.
var target_tile: Variant

func _init(p_action_kind: int, p_target_tile: Variant = null) -> void:
	action_kind = p_action_kind
	target_tile = p_target_tile
