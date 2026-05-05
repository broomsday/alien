class_name GameAction
extends RefCounted

var kind: int
var duration_seconds: float
var elapsed_seconds: float = 0.0
var description: String
# null when no target tile is associated with this action; otherwise a Vector2i.
var target_tile: Variant
var actor_slot: int = 0

func _init(
		p_kind: int,
		p_duration_seconds: float,
		p_description: String,
		p_target_tile: Variant = null,
		p_actor_slot: int = 0) -> void:
	assert(p_duration_seconds > 0.0, "duration_seconds must be positive")
	assert(p_actor_slot >= 0, "actor_slot must be non-negative")
	kind = p_kind
	duration_seconds = p_duration_seconds
	description = p_description if not p_description.strip_edges().is_empty() else _default_description(p_kind)
	target_tile = p_target_tile
	actor_slot = p_actor_slot

func progress() -> float:
	return minf(1.0, elapsed_seconds / duration_seconds)

func is_complete() -> bool:
	return elapsed_seconds >= duration_seconds

func advance(delta_seconds: float) -> void:
	assert(delta_seconds >= 0.0, "delta_seconds must be non-negative")
	elapsed_seconds = minf(duration_seconds, elapsed_seconds + delta_seconds)

static func _default_description(p_kind: int) -> String:
	match p_kind:
		GameActionKind.Kind.EXCAVATE:
			return "Excavate"
		GameActionKind.Kind.BUILD_WALL:
			return "BuildWall"
		GameActionKind.Kind.BUILD_FURNACE:
			return "BuildFurnace"
		GameActionKind.Kind.EXPEDITION:
			return "Expedition"
		GameActionKind.Kind.CRAFT:
			return "Craft"
		GameActionKind.Kind.HARVEST:
			return "Harvest"
		GameActionKind.Kind.ATTACK:
			return "Attack"
		_:
			return "Unknown"
