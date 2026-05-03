class_name FuelFurnaceCommand
extends GameCommand

var target_tile: Vector2i

func _init(p_target_tile: Vector2i) -> void:
	target_tile = p_target_tile
