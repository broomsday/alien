extends SceneTree

const WorldTileTypeScript = preload("res://scripts/core/world/world_tile_type.gd")

func _init() -> void:
	_test_is_open_space()
	_test_is_blocking()
	_test_can_be_replaced_with_wall()
	_test_can_be_replaced_with_furnace()
	print("test_world_tile_type: ok")
	quit(0)

func _test_is_open_space() -> void:
	assert(WorldTileTypeScript.is_open_space(WorldTileTypeScript.Kind.AIR), "AIR is open")
	assert(WorldTileTypeScript.is_open_space(WorldTileTypeScript.Kind.EXCAVATED_FLOOR), "EXCAVATED_FLOOR is open")
	assert(WorldTileTypeScript.is_open_space(WorldTileTypeScript.Kind.FURNACE), "FURNACE is open")
	assert(not WorldTileTypeScript.is_open_space(WorldTileTypeScript.Kind.SOIL), "SOIL is not open")
	assert(not WorldTileTypeScript.is_open_space(WorldTileTypeScript.Kind.SCRAP_METAL_WALL), "WALL is not open")

func _test_is_blocking() -> void:
	assert(not WorldTileTypeScript.is_blocking(WorldTileTypeScript.Kind.AIR), "AIR not blocking")
	assert(not WorldTileTypeScript.is_blocking(WorldTileTypeScript.Kind.EXCAVATED_FLOOR), "FLOOR not blocking")
	assert(not WorldTileTypeScript.is_blocking(WorldTileTypeScript.Kind.FURNACE), "FURNACE not blocking")
	assert(WorldTileTypeScript.is_blocking(WorldTileTypeScript.Kind.SOIL), "SOIL blocking")
	assert(WorldTileTypeScript.is_blocking(WorldTileTypeScript.Kind.SCRAP_METAL_WALL), "WALL blocking")

func _test_can_be_replaced_with_wall() -> void:
	assert(WorldTileTypeScript.can_be_replaced_with_wall(WorldTileTypeScript.Kind.AIR), "AIR replaceable")
	assert(WorldTileTypeScript.can_be_replaced_with_wall(WorldTileTypeScript.Kind.EXCAVATED_FLOOR), "FLOOR replaceable")
	assert(not WorldTileTypeScript.can_be_replaced_with_wall(WorldTileTypeScript.Kind.SOIL), "SOIL not replaceable")
	assert(not WorldTileTypeScript.can_be_replaced_with_wall(WorldTileTypeScript.Kind.SCRAP_METAL_WALL), "WALL not replaceable")
	assert(not WorldTileTypeScript.can_be_replaced_with_wall(WorldTileTypeScript.Kind.FURNACE), "FURNACE not replaceable")

func _test_can_be_replaced_with_furnace() -> void:
	assert(WorldTileTypeScript.can_be_replaced_with_furnace(WorldTileTypeScript.Kind.EXCAVATED_FLOOR), "FLOOR -> FURNACE ok")
	assert(not WorldTileTypeScript.can_be_replaced_with_furnace(WorldTileTypeScript.Kind.AIR), "AIR not furnaceable")
	assert(not WorldTileTypeScript.can_be_replaced_with_furnace(WorldTileTypeScript.Kind.SOIL), "SOIL not furnaceable")
	assert(not WorldTileTypeScript.can_be_replaced_with_furnace(WorldTileTypeScript.Kind.SCRAP_METAL_WALL), "WALL not furnaceable")
	assert(not WorldTileTypeScript.can_be_replaced_with_furnace(WorldTileTypeScript.Kind.FURNACE), "FURNACE not furnaceable")
