class_name WorldTileType
extends RefCounted

enum Kind {
	AIR,
	SOIL,
	EXCAVATED_FLOOR,
	SCRAP_METAL_WALL,
	FURNACE,
}

static func is_open_space(kind: int) -> bool:
	return kind == Kind.AIR or kind == Kind.EXCAVATED_FLOOR or kind == Kind.FURNACE

static func is_blocking(kind: int) -> bool:
	return not is_open_space(kind)

static func can_be_replaced_with_wall(kind: int) -> bool:
	return kind == Kind.AIR or kind == Kind.EXCAVATED_FLOOR

static func can_be_replaced_with_furnace(kind: int) -> bool:
	return kind == Kind.EXCAVATED_FLOOR
