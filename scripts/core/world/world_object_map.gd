class_name WorldObjectMap
extends RefCounted

var _object_kinds_by_tile: Dictionary = {}

func has_object_at(tile_position: Vector2i) -> bool:
	return _object_kinds_by_tile.has(tile_position)

func get_object_kind(tile_position: Vector2i) -> Variant:
	return _object_kinds_by_tile.get(tile_position, null)

func has_object_kind(tile_position: Vector2i, object_kind: int) -> bool:
	return _object_kinds_by_tile.get(tile_position, null) == object_kind

func place_object(tile_position: Vector2i, object_kind: int) -> bool:
	if has_object_at(tile_position):
		return false
	_object_kinds_by_tile[tile_position] = object_kind
	return true

func remove_object_at(tile_position: Vector2i) -> bool:
	if not has_object_at(tile_position):
		return false
	_object_kinds_by_tile.erase(tile_position)
	return true

func object_count() -> int:
	return _object_kinds_by_tile.size()

func count_kind(object_kind: int) -> int:
	var count: int = 0
	for tile_position in _object_kinds_by_tile:
		if _object_kinds_by_tile[tile_position] == object_kind:
			count += 1
	return count

func object_tiles() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for tile_position in _object_kinds_by_tile:
		out.append(tile_position)
	return out
