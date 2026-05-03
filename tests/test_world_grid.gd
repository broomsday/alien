extends SceneTree

const WorldGridScript = preload("res://scripts/core/world/world_grid.gd")
const WorldTileTypeScript = preload("res://scripts/core/world/world_tile_type.gd")

func _init() -> void:
	_test_is_excavatable_returns_true_only_for_soil_below_surface_in_bounds()
	_test_can_build_wall_at_classifies_tile_kinds()
	_test_can_build_furnace_at_only_excavated_floor()
	_test_is_walkable_matches_open_space()
	_test_try_excavate_mutates_and_returns_true_then_false()
	_test_try_build_wall_only_in_replaceable_cells()
	_test_is_indoors_when_pocket_is_sealed_returns_true()
	_test_is_indoors_when_pocket_is_open_to_surface_returns_false()
	_test_is_indoors_when_tile_is_blocking_returns_false()
	print("test_world_grid: ok")
	quit(0)

func _make_world() -> WorldGrid:
	return WorldGridScript.create_default(8, 8, 3)

func _test_is_excavatable_returns_true_only_for_soil_below_surface_in_bounds() -> void:
	var world: WorldGrid = _make_world()
	assert(world.is_excavatable(Vector2i(3, 4)), "soil below surface should be excavatable")
	assert(world.is_excavatable(Vector2i(3, 3)), "soil at surface row should be excavatable")
	assert(not world.is_excavatable(Vector2i(3, 2)), "air above surface should not be excavatable")
	world.set_tile(Vector2i(3, 4), WorldTileTypeScript.Kind.EXCAVATED_FLOOR)
	assert(not world.is_excavatable(Vector2i(3, 4)), "already-excavated tile should not be excavatable")
	assert(not world.is_excavatable(Vector2i(-1, 4)), "out-of-bounds tile should not be excavatable")

func _test_can_build_wall_at_classifies_tile_kinds() -> void:
	var world: WorldGrid = _make_world()
	var t: Vector2i = Vector2i(2, 2)
	world.set_tile(t, WorldTileTypeScript.Kind.AIR)
	assert(world.can_build_wall_at(t), "AIR replaceable")
	world.set_tile(t, WorldTileTypeScript.Kind.EXCAVATED_FLOOR)
	assert(world.can_build_wall_at(t), "FLOOR replaceable")
	world.set_tile(t, WorldTileTypeScript.Kind.SOIL)
	assert(not world.can_build_wall_at(t), "SOIL not replaceable")
	world.set_tile(t, WorldTileTypeScript.Kind.SCRAP_METAL_WALL)
	assert(not world.can_build_wall_at(t), "WALL not replaceable")
	world.set_tile(t, WorldTileTypeScript.Kind.FURNACE)
	assert(not world.can_build_wall_at(t), "FURNACE not replaceable")

func _test_can_build_furnace_at_only_excavated_floor() -> void:
	var world: WorldGrid = _make_world()
	var t: Vector2i = Vector2i(2, 4)
	world.set_tile(t, WorldTileTypeScript.Kind.EXCAVATED_FLOOR)
	assert(world.can_build_furnace_at(t), "FLOOR can become furnace")
	world.set_tile(t, WorldTileTypeScript.Kind.AIR)
	assert(not world.can_build_furnace_at(t), "AIR cannot become furnace")
	world.set_tile(t, WorldTileTypeScript.Kind.SOIL)
	assert(not world.can_build_furnace_at(t), "SOIL cannot become furnace")

func _test_is_walkable_matches_open_space() -> void:
	var world: WorldGrid = _make_world()
	var t: Vector2i = Vector2i(2, 2)
	world.set_tile(t, WorldTileTypeScript.Kind.AIR)
	assert(world.is_walkable(t), "AIR walkable")
	world.set_tile(t, WorldTileTypeScript.Kind.EXCAVATED_FLOOR)
	assert(world.is_walkable(t), "FLOOR walkable")
	world.set_tile(t, WorldTileTypeScript.Kind.FURNACE)
	assert(world.is_walkable(t), "FURNACE walkable")
	world.set_tile(t, WorldTileTypeScript.Kind.SOIL)
	assert(not world.is_walkable(t), "SOIL not walkable")
	world.set_tile(t, WorldTileTypeScript.Kind.SCRAP_METAL_WALL)
	assert(not world.is_walkable(t), "WALL not walkable")
	assert(not world.is_walkable(Vector2i(-1, 0)), "out-of-bounds not walkable")

func _test_try_excavate_mutates_and_returns_true_then_false() -> void:
	var world: WorldGrid = _make_world()
	var t: Vector2i = Vector2i(3, 4)
	assert(world.try_excavate(t), "first try_excavate should succeed")
	assert(world.get_tile(t) == WorldTileTypeScript.Kind.EXCAVATED_FLOOR, "tile should be excavated")
	assert(not world.try_excavate(t), "second try_excavate should fail")

func _test_try_build_wall_only_in_replaceable_cells() -> void:
	var world: WorldGrid = _make_world()
	var air_tile: Vector2i = Vector2i(3, 1)
	assert(world.try_build_wall(air_tile), "AIR -> wall should succeed")
	assert(world.get_tile(air_tile) == WorldTileTypeScript.Kind.SCRAP_METAL_WALL, "tile should be wall")
	var soil_tile: Vector2i = Vector2i(3, 5)
	assert(not world.try_build_wall(soil_tile), "SOIL -> wall should fail")
	assert(world.get_tile(soil_tile) == WorldTileTypeScript.Kind.SOIL, "tile should remain soil")

func _test_is_indoors_when_pocket_is_sealed_returns_true() -> void:
	var world: WorldGrid = _make_world()
	world.set_tile(Vector2i(3, 4), WorldTileTypeScript.Kind.EXCAVATED_FLOOR)
	assert(world.is_indoors(Vector2i(3, 4)), "sealed pocket should be indoors")

func _test_is_indoors_when_pocket_is_open_to_surface_returns_false() -> void:
	var world: WorldGrid = _make_world()
	world.set_tile(Vector2i(3, 4), WorldTileTypeScript.Kind.EXCAVATED_FLOOR)
	world.set_tile(Vector2i(3, 3), WorldTileTypeScript.Kind.EXCAVATED_FLOOR)
	world.set_tile(Vector2i(3, 2), WorldTileTypeScript.Kind.AIR)
	assert(not world.is_indoors(Vector2i(3, 4)), "pocket open to surface should not be indoors")

func _test_is_indoors_when_tile_is_blocking_returns_false() -> void:
	var world: WorldGrid = _make_world()
	assert(not world.is_indoors(Vector2i(3, 5)), "soil tile should not be indoors")
