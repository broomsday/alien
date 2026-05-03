class_name WorldGrid
extends RefCounted

const _NEIGHBOR_OFFSETS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
]

var width: int
var height: int
var surface_row: int
var _tiles: PackedInt32Array

func _init(p_width: int, p_height: int, p_surface_row: int, p_tiles: PackedInt32Array) -> void:
	assert(p_width > 0, "width must be positive")
	assert(p_height > 0, "height must be positive")
	assert(p_surface_row >= 1 and p_surface_row < p_height, "surface_row out of range")
	assert(p_tiles.size() == p_width * p_height, "tile count must match grid dimensions")
	width = p_width
	height = p_height
	surface_row = p_surface_row
	_tiles = p_tiles

static func create_default(p_width: int, p_height: int, p_surface_row: int) -> WorldGrid:
	var tiles: PackedInt32Array = PackedInt32Array()
	tiles.resize(p_width * p_height)
	for y in range(p_height):
		for x in range(p_width):
			tiles[(y * p_width) + x] = (
				WorldTileType.Kind.AIR if y < p_surface_row
				else WorldTileType.Kind.SOIL
			)
	return WorldGrid.new(p_width, p_height, p_surface_row, tiles)

func is_within_bounds(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.x < width and tile.y >= 0 and tile.y < height

func get_tile(tile: Vector2i) -> int:
	assert(is_within_bounds(tile), "tile out of bounds")
	return _tiles[(tile.y * width) + tile.x]

func set_tile(tile: Vector2i, kind: int) -> void:
	assert(is_within_bounds(tile), "tile out of bounds")
	_tiles[(tile.y * width) + tile.x] = kind

func is_walkable(tile: Vector2i) -> bool:
	if not is_within_bounds(tile):
		return false
	return WorldTileType.is_open_space(get_tile(tile))

func is_excavatable(tile: Vector2i) -> bool:
	if not is_within_bounds(tile):
		return false
	if tile.y < surface_row:
		return false
	return get_tile(tile) == WorldTileType.Kind.SOIL

func can_build_wall_at(tile: Vector2i) -> bool:
	if not is_within_bounds(tile):
		return false
	return WorldTileType.can_be_replaced_with_wall(get_tile(tile))

func can_build_furnace_at(tile: Vector2i) -> bool:
	if not is_within_bounds(tile):
		return false
	return WorldTileType.can_be_replaced_with_furnace(get_tile(tile))

func try_excavate(tile: Vector2i) -> bool:
	if not is_excavatable(tile):
		return false
	set_tile(tile, WorldTileType.Kind.EXCAVATED_FLOOR)
	return true

func try_build_wall(tile: Vector2i) -> bool:
	if not can_build_wall_at(tile):
		return false
	set_tile(tile, WorldTileType.Kind.SCRAP_METAL_WALL)
	return true

func try_build_furnace(tile: Vector2i) -> bool:
	if not can_build_furnace_at(tile):
		return false
	set_tile(tile, WorldTileType.Kind.FURNACE)
	return true

func is_indoors(tile: Vector2i) -> bool:
	assert(is_within_bounds(tile), "tile out of bounds")
	if not WorldTileType.is_open_space(get_tile(tile)):
		return false
	var visited: Dictionary = {}
	var frontier: Array[Vector2i] = [tile]
	visited[tile] = 1
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		if current.x == 0 or current.x == width - 1 or current.y == 0 or current.y == height - 1 or current.y < surface_row:
			return false
		for offset in _NEIGHBOR_OFFSETS:
			var neighbor: Vector2i = current + offset
			if visited.has(neighbor):
				continue
			if not is_within_bounds(neighbor):
				continue
			if not WorldTileType.is_open_space(get_tile(neighbor)):
				continue
			visited[neighbor] = 1
			frontier.append(neighbor)
	return true
